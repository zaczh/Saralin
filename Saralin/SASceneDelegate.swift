//
//  SASceneDelegate.swift
//  Saralin
//
//  Created by zhang on 11/30/15.
//  Copyright © 2015 zaczh. All rights reserved.
//

import UIKit

@available(iOS 13.0, *)
class SASceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
            
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let userActivity = connectionOptions.userActivities.first
        prepareStoryboard(for: window!, scene: windowScene, userActivity: userActivity)
        
        if let userActivity = userActivity {
            self.scene(scene, continue: userActivity)
            return
        }
        
        #if !targetEnvironment(macCatalyst)
        if let shortCut = connectionOptions.shortcutItem {
            _ = AppController.current.handleShortCutItem(shortCut, window: window)
            return
        }
        #endif
        
        if let userActivity = session.stateRestorationActivity {
            if !restore(window: window, with: userActivity) {
                os_log("Failed to restore from %@", log: .ui, type: .fault, userActivity.description)
            }
        }
    }
    
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let result = AppController.current.handleShortCutItem(shortcutItem, window: window)
        completionHandler(result)
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        AppController.current.applicationDidBecomeActive()
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        AppController.current.applicationWillResignActive()
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        AppController.current.applicationWillEnterForeground()
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        AppController.current.applicationDidEnterBackground()
    }
  
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return scene.userActivity
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        scene.title = userActivity.title
        
        let saactivityType = SAActivityType(rawValue: userActivity.activityType)
        switch saactivityType {
        case .viewThread:
            // this activity is not used for now.
            guard let url = userActivity.userInfo?["url"] as? URL else {
                fatalError("The viewThread activity must contains a url in its userinfo.")
            }
            
            var threadContent: SAThreadContentViewController!
            if let navi = window?.rootViewController as? UINavigationController, let vc = navi.topViewController as? SAThreadContentViewController {
                threadContent = vc
            } else {
                let navi = UIStoryboard(name: "ViewThread", bundle: nil).instantiateInitialViewController()! as UINavigationController
                threadContent = navi.topViewController! as? SAThreadContentViewController
                window?.rootViewController = navi
            }
            
            threadContent.config(url: url)
            return
        case .viewImage:
            guard let url = userActivity.userInfo?["url"] as? URL else {
                fatalError("The viewimage activity must contains a url in its userinfo.")
            }
                        
            var fullSizeImage: UIImage?
            if let fullSizeImageData = userActivity.userInfo?["fullSizeImageData"] as? Data {
                fullSizeImage = UIImage(data: fullSizeImageData)
            }

            var imageView: ImageViewController!
            if let vc = window?.rootViewController as? ImageViewController {
                imageView = vc
            } else {
                imageView = UIStoryboard(name: "ViewImage", bundle: nil).instantiateInitialViewController()! as ImageViewController
                window?.rootViewController = imageView
            }
            
            imageView.config(imageURL: url, thumbnailImage: nil, fullSizeImage: fullSizeImage, transitioningView: nil)
            return
        case .replyThread:
            guard let quoteInfo = userActivity.userInfo?["quoteInfo"] as? [String:AnyObject] else {
                fatalError("The replythread activity must contains a quoteInfo in its userinfo.")
            }
            
            var thread: SAReplyViewController!
            if let navi = window?.rootViewController as? UINavigationController, let vc = navi.topViewController as? SAReplyViewController {
                thread = vc
            } else {
                let navi = UIStoryboard(name: "ReplyThread", bundle: nil).instantiateInitialViewController()! as UINavigationController
                thread = navi.topViewController! as? SAReplyViewController
                window?.rootViewController = navi
            }
            
            thread.config(quoteInfo: quoteInfo)
            return
        case .composeThread:
            guard let fid = userActivity.userInfo?["fid"] as? String else {
                fatalError("The composeThread activity must contains a fid in its userinfo.")
            }
            
            var post: SAThreadCompositionViewController!
            if let navi = window?.rootViewController as? UINavigationController, let vc = navi.topViewController as? SAThreadCompositionViewController {
                post = vc
            } else {
                let navi = UIStoryboard(name: "ComposeThread", bundle: nil).instantiateInitialViewController()! as UINavigationController
                post = navi.topViewController! as? SAThreadCompositionViewController
                window?.rootViewController = navi
            }
            
            post.config(fid: fid)
            return
        case .settings:
            var settings: SASettingViewController!
            if let split = window?.rootViewController as? UISplitViewController, let navi = split.viewControllers.first as? UINavigationController, let vc = navi.topViewController as? SASettingViewController {
                settings = vc
            } else {
                let split = UIStoryboard(name: "Settings", bundle: nil).instantiateInitialViewController()! as UISplitViewController
                let navi = split.viewControllers.first as! UINavigationController
                settings = navi.topViewController! as? SASettingViewController
                window?.rootViewController = split
            }
            
            // dismiss warning of unused variable
            _ = settings.viewIfLoaded
            return
        default:
            break
        }
        
        scene.title = nil
        
        os_log("Failed to continue session from %@", log: .ui, type: .fault, userActivity.description)
    }
    
    // MARK: Restoration
    private func restore(window: UIWindow?, with activity: NSUserActivity) -> Bool {
        guard let window = window else {
            return false
        }
        
        if activity.title == SAActivityType.viewThread.title() {
            guard let url = activity.userInfo?["url"] as? URL else {
                return false
            }
            
            let split = window.rootViewController as! UISplitViewController
            if UIDevice.current.userInterfaceIdiom == .phone {
                let tab = split.viewController(for: .compact) as! UITabBarController
                for vcs in tab.viewControllers ?? [] {
                    if let navi = vcs as? UINavigationController, let vc = navi.topViewController, vc is SAForumViewController {
                        tab.selectedViewController = navi
                        break
                    }
                }
                let navigation = (tab.selectedViewController ?? tab.viewControllers?.first) as! UINavigationController
                if let fid = url.sa_queryString("fid") {
                    let boardVCUrl = URL(string: SAGlobalConfig().forum_base_url + "forum.php?mod=forumdisplay&fid=\(fid)&mobile=1")!
                    let board = SABoardViewController(url: boardVCUrl)
                    navigation.pushViewController(board, animated: false)
                    return true
                }
                return false
            }
            
            if let fid = url.sa_queryString("fid") {
                let boardVCUrl = URL(string: SAGlobalConfig().forum_base_url + "forum.php?mod=forumdisplay&fid=\(fid)&mobile=1")!
                let board = SABoardViewController(url: boardVCUrl)
                split.setViewController(SANavigationController(rootViewController: board), for: .supplementary)
            }
            
            let thread = SAThreadContentViewController(url: url)
            split.setViewController(SANavigationController(rootViewController: thread), for: .secondary)
            return true
        } else if activity.title == SAActivityType.replyThread.title() {
            
        }
        
        return false
    }
    
    // MARK: Initialization
    private func prepareStoryboard(for window: UIWindow, scene: UIWindowScene, userActivity: NSUserActivity?) {
        #if targetEnvironment(macCatalyst)
        guard let titlebar = scene.titlebar else {
            return
        }
        titlebar.titleVisibility = .hidden
        
        var newToolBar: NSToolbar?
        var saactivityType: SAActivityType = .main
        
        if let userActivity = userActivity, let type = SAActivityType(rawValue: userActivity.activityType) {
            saactivityType = type
        } else if let storyboardId = window.rootViewController?.restorationIdentifier, let type = SAActivityType(rawValue: storyboardId) {
            saactivityType = type
        } else {
            fatalError("unknown activity type")
        }
        
        switch saactivityType {
            case .replyThread:
                newToolBar = NSToolbar(identifier: SAToolbarIdentifierReplyThread)
                newToolBar!.centeredItemIdentifier = SAToolbarItemIdentifierTitle
            case .composeThread:
                newToolBar = NSToolbar(identifier: SAToolbarIdentifierComposeThread)
            case .viewImage:
                newToolBar = NSToolbar(identifier: SAToolbarIdentifierImageViewer)
            case .settings:
                newToolBar = NSToolbar(identifier: SAToolbarIdentifierSettings)
            case .main:
                newToolBar = NSToolbar(identifier: SAToolbarIdentifierMain)
            case .login:
                newToolBar = NSToolbar(identifier: SAToolbarIdentifierLogin)
            default:
                fatalError("unknown activity type")
        }
        
        newToolBar?.delegate = self
        titlebar.toolbar = newToolBar
//        guard let tab = AppController.current.findTabBarController(rootViewController: window.rootViewController!),
//            let split = tab.splitViewController else {
//            fatalError()
//        }
//        let sidebar = SACatalystSidebarController(managedTabBarController: tab)
//        let sidebarSplit = SASplitViewController()
//        sidebarSplit.maximumPrimaryColumnWidth = 250
//        sidebarSplit.minimumPrimaryColumnWidth = 250
//        sidebarSplit.primaryBackgroundStyle = .sidebar
//        sidebarSplit.viewControllers = [sidebar, split]
//        window.rootViewController = sidebarSplit
//        
//        split.maximumPrimaryColumnWidth = 320
//        split.minimumPrimaryColumnWidth = 320
        #endif
    }
    
    @objc func toolbarActionAdd(sender: UIAction) {
        print("Button add")
    }
    
    @objc func toolbarActionShare(sender: UIAction) {
        print("Button share")
    }
    
    @objc func toolbarActionSend(sender: UIAction) {
        print("Button send")
    }
    
    @objc func toolbarActionSubmit(sender: UIAction) {
        print("Button submit")
    }
    
    @objc func toolbarActionGoBack(sender: AnyObject) {
        print("Button Go Back")
        guard let sidebarSplit = window?.rootViewController as? UISplitViewController else {
            if let navigation = window?.rootViewController as? UINavigationController {
                navigation.popViewController(animated: true)
                return
            }
            return
        }
        
        guard let rightNavigation = sidebarSplit.viewController(for: .secondary) as? UINavigationController else {
            return
        }
        
        // check detail
        if rightNavigation.viewControllers.count > 1 {
            rightNavigation.popViewController(animated: true)
            return
        }
        
        // check master
        guard let selected = sidebarSplit.viewController(for: .supplementary) as? UINavigationController else {
            return
        }

        if selected.viewControllers.count > 1 {
            selected.popViewController(animated: true)
            return
        }        
    }
    
    @objc func toolbarActionSendMessage(sender: UIAction) {
        print("Button submit")
    }
}

#if targetEnvironment(macCatalyst)

extension SASceneDelegate: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if (itemIdentifier == SAToolbarItemIdentifierAddButton) {
            let barButton = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
            let button = NSMenuToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            let newMenu = UIMenu(title: "", options: .displayInline, children: [UIAction(handler: { action in
                self.toolbarActionAdd(sender:action)
            })])
            button.itemMenu = newMenu
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierTitle) {
            var titleStr: String?
            if let root = window?.rootViewController as? UISplitViewController,
               let rightMaster = root.viewController(for: .secondary) as? UINavigationController {
                titleStr = rightMaster.topViewController?.title
            } else if let root = window?.rootViewController as? UINavigationController, let top = root.viewControllers.first {
                titleStr = top.title ?? top.navigationItem.title
            }
            let barButton = UIBarButtonItem(title: titleStr, style: .plain, target: nil, action: nil)
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierShare) {
            let barButton = UIBarButtonItem(barButtonSystemItem: .action, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierScrollToComment) {
            let barButton = UIBarButtonItem(image: UIImage(systemName: "arrow.up.arrow.down"), style: .plain, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierViewDeskTopPage) {
            let barButton = UIBarButtonItem(image: UIImage(systemName: "desktopcomputer"), style: .plain, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierRefresh) {
            let barButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierReorder) {
            let barButton = UIBarButtonItem(image: UIImage(systemName: "arrow.up.arrow.down"), style: .plain, target: nil, action: nil)
            let button = NSMenuToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            let newMenu = UIMenu(title: "", options: .displayInline, children: [UIAction(handler: { action in
                self.toolbarActionShare(sender:action)
            })])
            button.itemMenu = newMenu
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierFavorite) {
            let barButton = UIBarButtonItem(image: UIImage(systemName: "star"), style: .plain, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierSelectCatagory) {
            let barButton = UIBarButtonItem(image: UIImage(systemName: "square.grid.2x2"), style: .plain, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierReply) {
            let barButton = UIBarButtonItem(barButtonSystemItem: .reply, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierSubmit) {
            let barButton = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierGoBack) {
            let barButton = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain, target: self, action: #selector(toolbarActionGoBack(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            button.isNavigational = true
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierSendMessage) {
            let barButton = UIBarButtonItem(barButtonSystemItem: .close, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierAddToWatchList) {
            let barButton = UIBarButtonItem(image: UIImage(systemName: "eye"), style: .plain, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        }else if (itemIdentifier == SAToolbarItemIdentifierSearch) {
            let barButton = UIBarButtonItem(barButtonSystemItem: .search, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierReplyInsertAlbumImage) {
            let barButton = UIBarButtonItem(image: UIImage(systemName: "camera.badge.ellipsis"), style: .plain, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierReplyInsertEmoji) {
            let barButton = UIBarButtonItem(image: UIImage(systemName: "face.smiling"), style: .plain, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierReplyInsertExternalLink) {
            let barButton = UIBarButtonItem(image: UIImage(systemName: "link"), style: .plain, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierReplySubmit) {
            let barButton = UIBarButtonItem(barButtonSystemItem: .reply, target: nil, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        }
        return nil
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        if toolbar.identifier == SAToolbarIdentifierMain {
            return [
                NSToolbarItem.Identifier.toggleSidebar,
                NSToolbarItem.Identifier.primarySidebarTrackingSeparatorItemIdentifier,
                SAToolbarItemIdentifierGoBack,
                SAToolbarItemIdentifierAddButton,
                SAToolbarItemIdentifierReorder,
                SAToolbarItemIdentifierSelectCatagory,
                NSToolbarItem.Identifier.supplementarySidebarTrackingSeparatorItemIdentifier,
                SAToolbarItemIdentifierTitle,
                NSToolbarItem.Identifier.flexibleSpace,
                SAToolbarItemIdentifierScrollToComment, SAToolbarItemIdentifierViewDeskTopPage, SAToolbarItemIdentifierRefresh, SAToolbarItemIdentifierFavorite, SAToolbarItemIdentifierAddToWatchList, SAToolbarItemIdentifierReply, SAToolbarItemIdentifierShare, SAToolbarItemIdentifierSearch]
        }
        
        if toolbar.identifier == SAToolbarIdentifierImageViewer {
            return [NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierShare]
        }
        
        if toolbar.identifier == SAToolbarIdentifierReplyThread {
            return [SAToolbarItemIdentifierReplySubmit, NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierTitle, NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierReplyInsertAlbumImage, SAToolbarItemIdentifierReplyInsertEmoji, SAToolbarItemIdentifierReplyInsertExternalLink]
        }
        
        if toolbar.identifier == SAToolbarIdentifierComposeThread {
            return [NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierTitle, NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierSubmit]
        }
        
        if toolbar.identifier == SAToolbarIdentifierLogin {
            return [NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierTitle, NSToolbarItem.Identifier.flexibleSpace]
        }
        
        if toolbar.identifier == SAToolbarIdentifierSettings {
            return [SAToolbarItemIdentifierGoBack, NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierTitle, NSToolbarItem.Identifier.flexibleSpace]
        }
        
        return []
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }
}
#endif
