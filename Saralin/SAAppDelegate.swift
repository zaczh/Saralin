//
//  SAAppDelegate.swift
//  Saralin
//
//  Created by zhang on 11/30/15.
//  Copyright © 2015 zaczh. All rights reserved.
//

import UIKit

@UIApplicationMain
class SAAppDelegate: UIResponder, UIApplicationDelegate, UITabBarControllerDelegate {
    
    var window: UIWindow?
    var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    lazy var appController = AppController.current
    
    //storing background fetching results
    var backgroundFetchedData: [String:AnyObject] = [:]
    
    /// Saved shortcut item used as a result of an app launch, used later when app is activated.
    private var launchedShortcutItem: UIApplicationShortcutItem?

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        sa_log_v2("application willFinishLaunchingWithOptions", module: .ui, type: .debug)
        self.launchOptions = launchOptions
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        sa_log_v2("application didFinishLaunchingWithOptions", module: .ui, type: .debug)
        
        #if DEBUG
        setSavingLogTypes(SALogType.allTypes)
        #endif
        
        application.setMinimumBackgroundFetchInterval(3600)
        
        URLCache.shared.diskCapacity = 1024 * 1024 * 400 //400M
        
        // do the runtime hook
        UIViewController.sa_swizzleMethods()
        UIView.sa_swizzleMethods()

        appController.applicationDidFinishLaunching()
        
        #if targetEnvironment(macCatalyst)
        let macCatalystExtensionBundlePath = Bundle.main.builtInPlugInsPath! + "/CatalystExtension.bundle"
        let bundle = Bundle.init(path: macCatalystExtensionBundlePath)!
        if let cls = bundle.principalClass as? NSObject.Type {
            let instance = cls.init()
            instance.perform(NSSelectorFromString("run"))
        }
        #endif
        
        var result = true
        
        // If a shortcut was launched, display its information and take the appropriate action.
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            
            launchedShortcutItem = shortcutItem
            
            // This will block "performActionForShortcutItem:completionHandler" from being called.
            result = false
        }
        
        return result
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        appController.applicationDidReceiveRemoteNotification(userInfo: userInfo, fetchCompletionHandler: completionHandler)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // The token is not currently available.
        appController.applicationDidFailToRegisterForRemoteNotificationsWithError(error: error)
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        appController.applicationPerformFetchWithCompletionHandler(completionHandler: completionHandler)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return appController.open(url: url, sender: app.keyWindow?.rootViewController)
    }
        
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        appController.applicationDidReceiveMemoryWarning()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        appController.applicationWillResignActive()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        appController.applicationDidEnterBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        appController.applicationWillEnterForeground()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        appController.applicationDidBecomeActive()
        
        guard let shortcut = launchedShortcutItem else { return }
        _ = appController.handleShortCutItem(shortcut, window: window)
        
        // Reset which shortcut was chosen for next time.
        launchedShortcutItem = nil
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        appController.applicationWillTerminate()
    }
    
    @available(iOS 13.0, *)
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return connectingSceneSession.configuration
        }
        
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: .windowApplication)
        config.sceneClass = UIWindowScene.self
        config.delegateClass = SASceneDelegate.self
        
        if let activity = options.userActivities.first, let activityType = SAActivityType(rawValue: activity.activityType) {
            switch activityType {
            case .viewThread:
                config.storyboard = UIStoryboard(name: "ViewThread", bundle: nil)
            case .viewImage:
                config.storyboard = UIStoryboard(name: "ViewImage", bundle: nil)
            case .replyThread:
                config.storyboard = UIStoryboard(name: "ReplyThread", bundle: nil)
            case .composeThread:
                config.storyboard = UIStoryboard(name: "ComposeThread", bundle: nil)
            case .settings:
                config.storyboard = UIStoryboard(name: "Settings", bundle: nil)
            }
        } else {
            if UIDevice.current.userInterfaceIdiom == .phone {
                config.storyboard = UIStoryboard(name: "Main", bundle: nil)
            } else {
                config.storyboard = UIStoryboard(name: "Main_ipad", bundle: nil)
            }
        }
        
        return config
    }
    
    /*
     Called when the user activates your application by selecting a shortcut on the home screen, except when
     application(_:,willFinishLaunchingWithOptions:) or application(_:didFinishLaunchingWithOptions) returns `false`.
     You should handle the shortcut in those callbacks and return `false` if possible. In that case, this
     callback is used if your application is already launched in the background.
     */
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let handledShortCutItem = appController.handleShortCutItem(shortcutItem, window: window)
        completionHandler(handledShortCutItem)
    }
    
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return appController.applicationShouldSaveApplicationState(coder: coder)
    }
    
    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        return appController.applicationShouldRestoreApplicationState(coder: coder)
    }
    
    func application(_ application: UIApplication, viewControllerWithRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        return appController.applicationViewControllerWithRestorationIdentifierPath(identifierComponents: identifierComponents, coder:coder)
    }
}

