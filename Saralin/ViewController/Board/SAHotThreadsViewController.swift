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
    override func configWith(url: URL) {
        let selectedFid = Account().preferenceForkey(.hot_tab_board_fid) as? String ?? SAGlobalConfig().hot_tab_default_board_fid
        let url = URL(string: SAGlobalConfig().forum_base_url + "forum.php?mod=forumdisplay&fid=\(selectedFid)&mobile=1")!
        super.configWith(url: url)
    }
    
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let selectedFid = Account().preferenceForkey(.hot_tab_board_fid) as? String ?? SAGlobalConfig().hot_tab_default_board_fid
        if selectedFid == self.fid {
            return
        }
        
        guard let navigation = navigationController else {
            return
        }
        
        var vcs = navigation.viewControllers
        for (index, vc) in vcs.enumerated() {
            if vc === self {
                let url = URL(string: SAGlobalConfig().forum_base_url + "forum.php?mod=forumdisplay&fid=\(selectedFid)&mobile=1")!
                let newvc = SAHotThreadsViewController(url: url)
                vcs[index] = newvc
                navigation.setViewControllers(vcs, animated: false)
                return
            }
        }
    }
}
