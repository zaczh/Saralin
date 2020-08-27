//
//  SAMessageCompositionViewController.swift
//  Saralin
//
//  Created by zhang on 1/10/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import WebKit

class SAMessageCompositionViewController: ChatViewController {
    var isSubmitting: Bool = false
    
    init(url: Foundation.URL) {
        let touid = url.sa_queryString("touid")!
        let toUserName = url.sa_queryString("tousername")!
        let pmnum = url.sa_queryString("pmnum") ?? "0"
        let count = Int(pmnum)!
        let participants = Set.init(arrayLiteral: touid, Account().uid)
        let conversation = ChatViewController.Conversation(cid: touid, pmid: "", formhash: Account().formhash, name: toUserName, participants: participants, numberOfMessages:count)
        super.init(conversation: conversation)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
