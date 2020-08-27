//
//  SAHotThreadsViewController.swift
//  Saralin
//
//  Created by zhang on 10/21/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import CoreData

class SAHotThreadsViewController: SABoardViewController {
    override var showsComposeBarItem: Bool {return false}
    override var showsBottomRefreshView: Bool{return false}
    override var showsSubBoardBarItem: Bool{return false}

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
      
        restorationIdentifier = SAViewControllerRestorationIdentifier.hotThreads.rawValue

        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .automatic
        } else {
            // Fallback on earlier versions
        }
        
        title = NSLocalizedString("HOT_THREADS_VC_TITLE", comment: "热门帖子")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func fetchTopListOfCurrentPage(completion: ((NSError?) -> ())?) {
        urlSession.getHotThreads { [weak self] (data, error) in
            guard let strongSelf = self else {
                let error = NSError.init(domain: SAGeneralErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"请求被终止。"])
                completion?(error)
                return
            }
            
            guard error == nil else {
                completion?(error)
                return
            }
            
            guard data != nil, let variables = data!["Variables"] as? [String:AnyObject] else {
                let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"数据为空，该板块可能需要登录才能查看。"])
                completion?(error)
                return
            }
            
            guard let hotthreads = variables["data"] as? [[String:AnyObject]], !hotthreads.isEmpty else {
                completion?(nil)
                return
            }
            
            strongSelf.thisTimeReloadingDate = Date()
            strongSelf.dataSource = strongSelf.filterDataSource(hotthreads)
            strongSelf.unfilteredDataSource = hotthreads
            strongSelf.updateLastReplyCountOf(dataSource: strongSelf.unfilteredDataSource, completion: {
                completion?(nil)
            })
        }
    }
    
    override func doFetchingMore() {
        isFetchingMoreNoMoreData = true
        fetchingMoreCompletedNoMoreData()
    }
}
