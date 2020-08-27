//
//  SABoardArrangementViewController.swift
//  Saralin
//
//  Created by zhang on 10/2/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

class SABoardArrangementViewController: SABaseTableViewController {
    private var hiddenBoards: [[String:AnyObject]] = []
    private var shownBoards: [[String:AnyObject]] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "版块设置"
        
        let forumInfo = NSDictionary(contentsOf: AppController.current.forumInfoConfigFileURL)! as! [String:AnyObject]
        hiddenBoards.append(contentsOf: forumInfo["items"] as! [[String:AnyObject]])
        
        // Do any additional setup after loading the view.
        if let boards = Account().preferenceForkey(SAAccount.Preference.shown_boards_ids) as? [Int] {
            let forumInfo = NSDictionary(contentsOf: AppController.current.forumInfoConfigFileURL)! as! [String:AnyObject]
            let defaultList = forumInfo["items"] as! [[String:AnyObject]]
            for board in boards {
                guard let foundBoard = defaultList.first(where: { (obj) -> Bool in
                    if let fids = obj["fid"] as? String, let fid = Int(fids) {
                        return fid == board
                    }
                    return false
                }) else {
                    continue
                }
                shownBoards.append(foundBoard)
                hiddenBoards.removeAll { (hiddenBoard) -> Bool in
                    guard let foundBoardFid = foundBoard["fid"] as? String,
                        let hiddenBoardFid = hiddenBoard["fid"] as? String else {
                        return false
                    }
                    
                    return foundBoardFid == hiddenBoardFid
                }
            }
        }
        
        tableView.register(SAThemedTableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "header")

        tableView.estimatedRowHeight = 80
        tableView.sectionHeaderHeight = 60
        tableView.estimatedSectionHeaderHeight = 60
        tableView.isEditing = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            save()
        }
    }
    
    override var showsRefreshControl: Bool {
        return false
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return shownBoards.count
        } else {
            return hiddenBoards.count
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header")! as UITableViewHeaderFooterView
        if section == 0 {
            header.textLabel?.attributedText = NSAttributedString(string: "显示的版块", attributes: [NSAttributedString.Key.font:UIFont.sa_preferredFont(forTextStyle: .body), NSAttributedString.Key.foregroundColor: UIColor.sa_colorFromHexString(Theme().tableHeaderTextColor)])
        } else {
            header.textLabel?.attributedText = NSAttributedString(string: "隐藏的版块", attributes: [NSAttributedString.Key.font:UIFont.sa_preferredFont(forTextStyle: .body), NSAttributedString.Key.foregroundColor: UIColor.sa_colorFromHexString(Theme().tableHeaderTextColor)])
        }
        
        return header
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var dataSource: [[String:AnyObject]]
        if indexPath.section == 0 {
            dataSource = shownBoards
        } else {
            dataSource = hiddenBoards
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SAThemedTableViewCell
        let forum = dataSource[indexPath.row]
        cell.textLabel?.text = forum["name"] as? String
        
        if tableView.isEditing {
            cell.showsReorderControl = true
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if sourceIndexPath.section == 0 && destinationIndexPath.section == 0 {
            //reorder
            let obj = shownBoards[sourceIndexPath.row]
            shownBoards.remove(at: sourceIndexPath.row)
            shownBoards.insert(obj, at: destinationIndexPath.row)
        } else if sourceIndexPath.section == 0 && destinationIndexPath.section == 1 {
            //delete
            let obj = shownBoards[sourceIndexPath.row]
            shownBoards.remove(at: sourceIndexPath.row)
            hiddenBoards.insert(obj, at: destinationIndexPath.row)
        } else if sourceIndexPath.section == 1 && destinationIndexPath.section == 0 {
            //add
            let obj = hiddenBoards[sourceIndexPath.row]
            shownBoards.insert(obj, at: destinationIndexPath.row)
            hiddenBoards.remove(at: sourceIndexPath.row)
        }
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if indexPath.section == 0 {
            return .delete
        } else {
            return .insert
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            //remove
            let obj = shownBoards[indexPath.row]
            shownBoards.remove(at: indexPath.row)
            hiddenBoards.append(obj)
        } else {
            //add
            let obj = hiddenBoards[indexPath.row]
            shownBoards.append(obj)
            hiddenBoards.remove(at: indexPath.row)
        }
        reloadData()
    }
    
    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if sourceIndexPath.section == 1 && proposedDestinationIndexPath.section == 1 {
            return sourceIndexPath
        }
        
        return proposedDestinationIndexPath
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var fid: String!
        if indexPath.section == 0 {
            fid = shownBoards[indexPath.row]["fid"] as? String
        } else {
            fid = hiddenBoards[indexPath.row]["fid"] as? String
        }
        
        guard fid != nil else {
            return
        }
        
        let url = URL(string: SAGlobalConfig().forum_base_url + "forum.php?mod=forumdisplay&fid=\(fid!)&mobile=1")!
        let board = SABoardViewController(url: url)
        navigationController?.pushViewController(board, animated: true)
    }
    
    private func save() {
        var ids = [Int]()
        
        for board in shownBoards {
            guard let fidString = board["fid"] as? String else {
                continue
            }
            if let fid = Int(fidString) {
                ids.append(fid)
            }
        }
        Account().savePreferenceValue(ids as AnyObject, forKey:SAAccount.Preference.shown_boards_ids)
    }
}
