//
//  SAForumViewController.swift
//  Saralin
//
//  Created by zhang on 1/9/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import WebKit

class SAForumViewController: SABaseTableViewController {
    override var showsSearchItem: Bool {return true}
    private var dataSource: NSMutableArray = NSMutableArray()
    private var boardsSummaryData: [[String:AnyObject]]?
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(dataSource, forKey: "dataSource")
        coder.encode(boardsSummaryData, forKey: "boardsSummaryData")
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        dataSource = coder.decodeObject(forKey: "dataSource") as! NSMutableArray
        boardsSummaryData = coder.decodeObject(forKey: "boardsSummaryData") as? [[String : AnyObject]]
        if isViewLoaded, let table = tableView {
            table.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        tableView.register(SAThemedTableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.estimatedRowHeight = 60
        
        title = NSLocalizedString("FORUM_VC_TITLE", comment: "forum vc title")

        NotificationCenter.default.addObserver(self, selector: #selector(SAForumViewController.handleUserLoggedIn(_:)), name: .SAUserLoggedIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SAForumViewController.handleUserLoggedOut(_:)), name: .SAUserLoggedOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SAForumViewController.handleUserPreferenceChange(_:)), name: .SAUserPreferenceChanged, object: nil)
        
        refreshTableViewCompletion(nil)
    }
    
    override func getTableView() -> UITableView {
        return UITableView(frame: .zero, style: .plain)
    }
    
    override func refreshTableViewCompletion(_ completion: ((SALoadingViewController.LoadingResult, NSError?) -> Void)?) {
        guard let boards = Account().preferenceForkey(SAAccount.Preference.shown_boards_ids) as? [Int] else {
            completion?(.emptyData, nil)
            return
        }
        
        var newDataSource = [Any]()
        for board in boards {
            let forumInfo = NSDictionary(contentsOf: AppController.current.forumInfoConfigFileURL)! as! [String:AnyObject]
            let forumList = forumInfo["items"] as! [[String:AnyObject]]
            guard let foundBoard = forumList.first(where: { (obj) -> Bool in
                if let fids = obj["fid"] as? String, let fid = Int(fids) {
                    return fid == board
                }
                return false
            }) else {
                continue
            }
            newDataSource.append(foundBoard)
        }
        self.dataSource.removeAllObjects()
        self.dataSource.addObjects(from: newDataSource)
        self.tableView.reloadData()
        
        URLSession.saCustomized.getBoardsSummary { (obj, error) in
            guard error == nil else {
                return
            }
            
            guard let json = obj as? [String:AnyObject] else {
                return
            }
            
            guard let data = json["data"] as? [[String:AnyObject]] else {
                return
            }
                        
            DispatchQueue.main.async {
                self.boardsSummaryData = data
                self.tableView.reloadData()
                completion?(.newData, nil)
            }
        }
    }
    
    //MARK: - tableView datasource & delegate
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SAThemedTableViewCell
        
        let forum = dataSource[indexPath.row] as! NSDictionary
        cell.textLabel?.text = forum["name"] as? String
        
        if let forumIDStr = forum["fid"] as? String,
            let forumID = Int(forumIDStr),
            let boardSummary = getSummaryDataOfBoard(forumID),
            let todayPosts = boardSummary["todayposts"] as? String {
            cell.textLabel?.text = (cell.textLabel?.text ?? "") + " (\(todayPosts))"
        }
        
        return cell
    }
    
    private func getSummaryDataOfBoard(_ boardID : Int) -> [String:AnyObject]? {
        if boardsSummaryData == nil {
            return nil
        }
        
        for sub in boardsSummaryData! {
            if let child = sub["child"] as? [[String:AnyObject]] {
                for childForum in child {
                    if let fid = childForum["fid"] as? Int, fid == boardID {
                        return childForum
                    }
                }
            }
        }
        
        return nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let forum = dataSource[indexPath.row] as! NSDictionary
        let fid = forum["fid"] as! String
        let url = URL(string: SAGlobalConfig().forum_base_url + "forum.php?mod=forumdisplay&fid=\(fid)&mobile=1")!
        let board = SABoardViewController(url: url)
        show(board, sender: self)
        Account().savePreferenceValue(Int(fid)! as AnyObject, forKey: .forum_tab_default_sub_board_id)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - click event handling
    @objc func handleUserLoggedIn(_ notification: Notification) {
        refreshTableViewCompletion(nil)
    }
    
    @objc func handleUserLoggedOut(_ notification: Notification) {
        refreshTableViewCompletion(nil)
    }
    
    @objc func handleUserPreferenceChange(_ notification: Notification) {
        let userInfo = notification.userInfo
        guard let key = userInfo?[SAAccount.Preference.changedPreferenceNameKey] as? SAAccount.Preference else {
            return
        }
        if key == SAAccount.Preference.shown_boards_ids {
            refreshTableViewCompletion(nil)
        }
    }
}
