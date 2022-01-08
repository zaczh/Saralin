//
//  SALoginWebviewScriptMessageHandler.swift
//  Saralin
//
//  Created by Junhui Zhang on 2020/6/7.
//  Copyright © 2020 zaczh. All rights reserved.
//

import UIKit
import WebKit

class SALoginWebviewScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var viewController: SAWebLoginViewController?
    init(viewController: SAWebLoginViewController?) {
        super.init()
        self.viewController = viewController
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String:AnyObject] else {
            sa_log_v2("[ScriptHandler] bad script message", type: .error)
            return
        }
        
        guard let action = body["action"] as? String else {
            return
        }
        
        guard let data = body["data"] as? [String:AnyObject] else {
            return
        }
        
        if action == "submit" {
            viewController?.willSubmitForm(data)
            return
        }
        
        
        if action == "fetchAccountInfo" {
            guard let accountInfoJson = data["info"] as? String else {
                return
            }
            
            viewController?.parseAccountInfoResult(data: accountInfoJson.data(using: .utf8)!)
            return
        }
    }
}
