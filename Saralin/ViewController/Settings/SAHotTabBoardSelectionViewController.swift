//
//  SAHotTabBoardSelectionViewController.swift
//  Saralin
//
//  Created by zhang on 2020/9/27.
//  Copyright © 2020 zaczh. All rights reserved.
//

import UIKit

class SAHotTabBoardSelectionViewController: SABaseTableViewController {
    private var allBoards = NSDictionary(contentsOf: AppController.current.forumInfoConfigFileURL)?["items"] as! [[String:AnyObject]]
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "版块设置"
        
        let hotBoardInfo: [String:AnyObject] = ["name":"热门板块" as AnyObject,"fid":"0" as AnyObject]
        allBoards.insert(hotBoardInfo, at: 0)
        
        tableView.register(SAThemedTableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "header")
        tableView.estimatedRowHeight = 80
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var showsRefreshControl: Bool {
        return false
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allBoards.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SAThemedTableViewCell
        let forum = allBoards[indexPath.row]
        cell.textLabel?.text = forum["name"] as? String
        let fid = allBoards[indexPath.row]["fid"] as! String
        let selectedFid = Account().preferenceForkey(.hot_tab_board_fid) as? String ?? "6" // 默认为动漫论坛
        cell.accessoryType = fid == selectedFid ? .checkmark : .none
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let fid = allBoards[indexPath.row]["fid"] as! String
        Account().savePreferenceValue(fid as AnyObject, forKey: .hot_tab_board_fid)
        tableView.reloadData()
    }
}
