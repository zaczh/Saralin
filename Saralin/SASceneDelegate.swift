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
                sa_log_v2("Failed to restore from %@", module: .ui, type: .fault, userActivity.description)
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
        #if targetEnvironment(macCatalyst)
        return nil
        #else
        return scene.userActivity
        #endif
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
            if let navi = window?.rootViewController as? UINavigationController, let vc = navi.topViewController as? SASettingViewController {
                settings = vc
            } else {
                let navi = UIStoryboard(name: "Settings", bundle: nil).instantiateInitialViewController()! as UINavigationController
                settings = navi.topViewController! as? SASettingViewController
                window?.rootViewController = navi
            }
            
            // dismiss warning of unused variable
            _ = settings.viewIfLoaded
            return
        default:
            break
        }
        
        scene.title = nil
        
        sa_log_v2("Failed to continue session from %@", module: .ui, type: .fault, userActivity.description)
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
            
            guard let navi = AppController.current.findDeailNavigationController(rootViewController: window.rootViewController!) else {
                return false
            }
            
            let thread = SAThreadContentViewController(url: url)
            navi.pushViewController(thread, animated: false)
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
        
        if let userActivity = userActivity {
            titlebar.titleVisibility = .hidden
            var newToolBar: NSToolbar?
            let saactivityType = SAActivityType(rawValue: userActivity.activityType)
            switch saactivityType {
            case .replyThread:
                newToolBar = NSToolbar(identifier: SAToolbarIdentifierReplyThread)
            case .composeThread:
                newToolBar = NSToolbar(identifier: SAToolbarIdentifierComposeThread)
            case .viewImage:
                newToolBar = NSToolbar(identifier: SAToolbarIdentifierImageViewer)
            case .settings:
                newToolBar = NSToolbar(identifier: SAToolbarIdentifierSettings)
            default:
                return
            }
            newToolBar?.delegate = self
            titlebar.toolbar = newToolBar
            return
        }
        
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
        
        titlebar.titleVisibility = .hidden
        let toolbar = NSToolbar(identifier: SAToolbarIdentifierMain)
        toolbar.delegate = self
        titlebar.toolbar = toolbar
        #endif
    }
    
    #if targetEnvironment(macCatalyst)
    @objc func toolbarActionAdd(sender: UIBarButtonItem) {
        print("Button add")
    }
    
    @objc func toolbarActionShare(sender: UIBarButtonItem) {
        print("Button share")
    }
    
    @objc func toolbarActionSend(sender: UIBarButtonItem) {
        print("Button send")
    }
    
    @objc func toolbarActionSubmit(sender: UIBarButtonItem) {
        print("Button submit")
    }
    
    @objc func toolbarActionGoBack(sender: UIBarButtonItem) {
        print("Button Go Back")
        guard let sidebarSplit = window?.rootViewController as? UISplitViewController else {
            if let navigation = window?.rootViewController as? UINavigationController {
                navigation.popViewController(animated: true)
                return
            }
            
            return
        }
                
        guard let rightSplit = sidebarSplit.viewControllers[1] as? UISplitViewController else {
            return
        }
        
        guard let rightNavigation = rightSplit.viewControllers[1] as? UINavigationController else {
            return
        }
        
        // check detail
        if rightNavigation.viewControllers.count > 1 {
            rightNavigation.popViewController(animated: true)
            return
        }
        
        // check master
        guard let selected = sidebarSplit.viewControllers.first as? UINavigationController else {
            return
        }

        if selected.viewControllers.count > 1 {
            selected.popViewController(animated: true)
            return
        }        
    }
    
    @objc func toolbarActionSendMessage(sender: UIBarButtonItem) {
        print("Button submit")
    }
    #endif
}

#if targetEnvironment(macCatalyst)

extension SASceneDelegate: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if (itemIdentifier == SAToolbarItemIdentifierAddButton) {
            let barButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(toolbarActionAdd(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            button.isEnabled = false // disabled by default
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierTitle) {
            var titleStr: String?
            if let root = window?.rootViewController as? UISplitViewController, root.viewControllers.count > 1, let rightSplit = root.viewControllers[1] as? UISplitViewController, let rightMaster = rightSplit.viewControllers.first as? UINavigationController {
                titleStr = rightMaster.topViewController?.title
            } else if let root = window?.rootViewController as? UINavigationController, let top = root.viewControllers.first {
                titleStr = top.title ?? top.navigationItem.title
            }
            let barButton = UIBarButtonItem(title: titleStr, style: .plain, target: nil, action: nil)
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierShare) {
            let barButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(toolbarActionShare(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            button.isEnabled = false
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierReply) {
            let barButton = UIBarButtonItem(barButtonSystemItem: .reply, target: self, action: #selector(toolbarActionSend(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            button.isEnabled = false
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierSubmit) {
            let barButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(toolbarActionSubmit(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierGoBack) {
            let image = UIImage(named: "Back-50")?.scaledToSize(CGSize(width: 14, height: 14)).withRenderingMode(.alwaysTemplate)
            let barButton = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(toolbarActionGoBack(sender:)))
            let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
            return button
        } else if (itemIdentifier == SAToolbarItemIdentifierSendMessage) {
           let barButton = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(toolbarActionSendMessage(sender:)))
           let button = NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: barButton)
           return button
        }
        return nil
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        if toolbar.identifier == SAToolbarIdentifierMain {
            return [SAToolbarItemIdentifierGoBack, NSToolbarItem.Identifier.space, NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierTitle, NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierShare, SAToolbarItemIdentifierReply, SAToolbarItemIdentifierAddButton]
        }
        
        if toolbar.identifier == SAToolbarIdentifierImageViewer {
            return [NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierShare]
        }
        
        if toolbar.identifier == SAToolbarIdentifierReplyThread {
            return [NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierTitle, NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierReply]
        }
        
        if toolbar.identifier == SAToolbarIdentifierComposeThread {
            return [NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierTitle, NSToolbarItem.Identifier.flexibleSpace, SAToolbarItemIdentifierSubmit]
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
