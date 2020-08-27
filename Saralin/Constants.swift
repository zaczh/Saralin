//
//  Constants.swift
//  Saralin
//
//  Created by junhui zhang on 2019/10/4.
//  Copyright © 2019 zaczh. All rights reserved.
//

import Foundation


/// The public error domains
let SAGeneralErrorDomain = "General Error"
let SAHTTPAPIErrorDomain = "API Error"


let SAContentViewControllerReadableAreaMaxWidth = 800

enum SAActivityType: String {
    
    case viewThread = "me.zaczh.saralin.useractivity.viewthread"
    case viewImage = "me.zaczh.saralin.useractivity.viewimage"
    case replyThread = "me.zaczh.saralin.useractivity.replythread"
    case composeThread = "me.zaczh.saralin.useractivity.composethread"
    case settings = "me.zaczh.saralin.useractivity.settings"
    
    func title() -> String {
        switch self {
        case .viewThread:
            return "查看帖子"
        case .viewImage:
            return "查看图片"
        case .replyThread:
            return "回复帖子"
        case .composeThread:
            return "创建帖子"
        case .settings:
            return "设置"
        }
    }
}

#if targetEnvironment(macCatalyst)
let SAToolbarIdentifierMain = NSToolbar.Identifier("Main")
let SAToolbarIdentifierImageViewer = NSToolbar.Identifier("ImageViewer")
let SAToolbarIdentifierReplyThread = NSToolbar.Identifier("ReplyThread")
let SAToolbarIdentifierComposeThread = NSToolbar.Identifier("ComposeThread")
let SAToolbarIdentifierSettings = NSToolbar.Identifier("Settings")


let SAToolbarItemIdentifierAddButton = NSToolbarItem.Identifier(rawValue: "Add")
let SAToolbarItemIdentifierTitle = NSToolbarItem.Identifier(rawValue: "Title")
let SAToolbarItemIdentifierShare = NSToolbarItem.Identifier(rawValue: "Share")
let SAToolbarItemIdentifierReply = NSToolbarItem.Identifier(rawValue: "Reply")
let SAToolbarItemIdentifierSubmit = NSToolbarItem.Identifier(rawValue: "Submit")
let SAToolbarItemIdentifierGoBack = NSToolbarItem.Identifier(rawValue: "GoBack")
let SAToolbarItemIdentifierSendMessage = NSToolbarItem.Identifier(rawValue: "SendMessage")
#endif

let SACloudKitImageShareContainerIdentifier = "iCloud.me.zaczh.saralin.imageShare"

let SACloudKitSyncRequestMaxAttempt = Int(2)
