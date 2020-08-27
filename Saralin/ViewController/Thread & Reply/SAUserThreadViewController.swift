//
//  SAUserThreadViewController.swift
//  Saralin
//
//  Created by zhang on 2/9/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

struct MyThreadModel {
    var json: [String:Any]?
}

struct OthersThreadModel {
    var tid: String?
    var title: String?
    var createDate: String?
    var authorName: String?
    var replyCount: String?
}

struct ThreadSearchResultModel {
    var tid: String?
    var title: String?
    var createDate: String?
    var authorName: String?
    var replyCount: String?
}

class SAUserThreadViewController<DataModel>: SABaseTableViewController {
    var fetchedData: [DataModel]? {
        didSet {
            guard let _ = fetchedData else { return }
            
            dispatch_async_main {
                _ = self.view
                self.reloadData()
            }
        }
    }
    var dataFiller: ((DataModel, SABoardTableViewCell, IndexPath) -> ())?
    var dataInteractor: ((SAUserThreadViewController<DataModel>, DataModel, IndexPath) -> ())?
    var themeUpdator: ((SAUserThreadViewController<DataModel>) -> ())?
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // Do any additional setup after loading the view.
        loadingController.emptyLabelTitle = "内容为空"
        
        tableView.estimatedRowHeight = 100
        tableView.register(SABoardTableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.tableFooterView?.frame = CGRect.zero
        
        loadingController.setLoading()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        
        themeUpdator?(self)
    }
    
    override func handleUserLoggedIn() {
        refreshTableViewCompletion(nil)
    }
    
    override func refreshTableViewCompletion(_ completion: ((SALoadingViewController.LoadingResult, NSError?) -> Void)?) {
        // this is a one-time loader, does not support refresh
        completion?(.newData, nil)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedData?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SABoardTableViewCell
        guard let data = fetchedData?[indexPath.row] else {
            return cell
        }
        
        dataFiller?(data, cell, indexPath)
        
        return cell
    }
        
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let data = fetchedData?[indexPath.row] else {
            return
        }
        
        dataInteractor?(self, data, indexPath)
    }
}
