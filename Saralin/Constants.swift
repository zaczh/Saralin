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
    case main = "me.zaczh.saralin.useractivity.main"
    case viewBoard = "me.zaczh.saralin.useractivity.viewboard"
    case viewThread = "me.zaczh.saralin.useractivity.viewthread"
    case viewImage = "me.zaczh.saralin.useractivity.viewimage"
    case replyThread = "me.zaczh.saralin.useractivity.replythread"
    case composeThread = "me.zaczh.saralin.useractivity.composethread"
    case settings = "me.zaczh.saralin.useractivity.settings"
    case login = "me.zaczh.saralin.useractivity.login"

    func title() -> String {
        switch self {
        case .main:
            return ""
        case .viewBoard:
            return "查看板块"
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
        case .login:
            return "登录"
        }
    }
}

#if targetEnvironment(macCatalyst)

let SAToolbarIdentifierMain = NSToolbar.Identifier("Main")
let SAToolbarIdentifierImageViewer = NSToolbar.Identifier("ImageViewer")
let SAToolbarIdentifierReplyThread = NSToolbar.Identifier("ReplyThread")
let SAToolbarIdentifierComposeThread = NSToolbar.Identifier("ComposeThread")
let SAToolbarIdentifierSettings = NSToolbar.Identifier("Settings")

#endif

#if !targetEnvironment(macCatalyst)
typealias NSToolbarItem = UIMenu
#endif

let SAToolbarItemIdentifierAddButton = NSToolbarItem.Identifier(rawValue: "ToolbarItemAdd")
let SAToolbarItemIdentifierTitle = NSToolbarItem.Identifier(rawValue: "ToolbarItemTitle")
let SAToolbarItemIdentifierShare = NSToolbarItem.Identifier(rawValue: "ToolbarItemShare")
let SAToolbarItemIdentifierSearch = NSToolbarItem.Identifier(rawValue: "ToolbarItemSearch")
let SAToolbarItemIdentifierSelectCatagory = NSToolbarItem.Identifier(rawValue: "ToolbarItemSelectCatagory")
let SAToolbarItemIdentifierReorder = NSToolbarItem.Identifier(rawValue: "ToolbarItemReorder")
let SAToolbarItemIdentifierReply = NSToolbarItem.Identifier(rawValue: "ToolbarItemReply")
let SAToolbarItemIdentifierReplyInsertAlbumImage = NSToolbarItem.Identifier(rawValue: "ToolbarItemReplyInsertAlbumImage")
let SAToolbarItemIdentifierReplyInsertEmoji = NSToolbarItem.Identifier(rawValue: "ToolbarItemReplyInsertEmoji")
let SAToolbarItemIdentifierReplyInsertExternalLink = NSToolbarItem.Identifier(rawValue: "ToolbarItemReplyInsertExternalLink")
let SAToolbarItemIdentifierRefresh = NSToolbarItem.Identifier(rawValue: "ToolbarItemRefresh")
let SAToolbarItemIdentifierFavorite = NSToolbarItem.Identifier(rawValue: "ToolbarItemFavorite")
let SAToolbarItemIdentifierSubmit = NSToolbarItem.Identifier(rawValue: "ToolbarItemSubmit")
let SAToolbarItemIdentifierGoBack = NSToolbarItem.Identifier(rawValue: "ToolbarItemGoBack")
let SAToolbarItemIdentifierSendMessage = NSToolbarItem.Identifier(rawValue: "ToolbarItemSendMessage")
let SAToolbarItemIdentifierAddToWatchList = NSToolbarItem.Identifier(rawValue: "ToolbarItemAddToWatchList")
let SAToolbarItemIdentifierScrollToComment = NSToolbarItem.Identifier(rawValue: "ToolbarItemScrollToComment")
let SAToolbarItemIdentifierViewDeskTopPage = NSToolbarItem.Identifier(rawValue: "ToolbarItemViewDeskTopPage")

let SAToolbarItemWidth = CGFloat(40)
let SAToolbarItemSpacing = CGFloat(20)

let SAContextActionTitleICloudInfo = UIAction.Identifier(Bundle.main.bundleIdentifier! + ".context_action.iCloud_info")
let SAContextActionTitleDelete = UIAction.Identifier(Bundle.main.bundleIdentifier! + ".context_action.delete")

let SACloudKitImageShareContainerIdentifier = "iCloud.me.zaczh.saralin.imageShare"

let SACloudKitSyncRequestMaxAttempt = Int(2)

// for mac catalyst
extension Notification.Name {
    static let macKeyCommandNewThread = Notification.Name("mac_key_command_new_thread")
    static let macKeyCommandPreferencesPanel = Notification.Name("mac_key_command_preferences_panel")
}

// for ipad toolbar
extension Notification.Name {
    static let padToolBarActionCompose = Notification.Name("pad_toolbar_action_compose")
    static let padToolBarActionShare = Notification.Name("pad_toolbar_action_share")
    static let padToolBarActionReorder = Notification.Name("pad_toolbar_action_reorder")
    static let padToolBarActionAdd = Notification.Name("pad_toolbar_action_add")
}
