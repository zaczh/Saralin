//
//  SANotificationManager.swift
//  Saralin
//
//  Created by zhang on 4/29/17.
//  Copyright © 2017 zaczh. All rights reserved.
//

import UIKit
import UserNotifications


class SANotificationManager: NSObject, UNUserNotificationCenterDelegate {
    enum SANotificationRequestIdentifier: String {
        case viewWatchList = "sa-view-watch-list"
        case viewDirectMessageList = "sa-view-direct-message-list"
    }
    
    enum SANotificationActionIdentifier: String {
        case viewNewReplyDetail = "sa-view-new-reply-detail"
    }
    
    enum SANotificationCategoryIdentifier: String {
        case general = "sa-general-category"
        case custom = "sa-custom-category"
    }

    override init() {
        super.init()
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        } else {
            // Fallback on earlier versions
        }
        
        registerNotificationCategories()
    }
    
    func registerNotifications() {
        AppController.current.registerForPushNotifications()
    }
    
    /// check if should prompt user for notification permission
    ///
    /// - Parameter completion: shouldPrompt: shouldPrompt, shouldOpenInSettings: should open in settings
    func checkIfNeedPrompt(_ completion: ((_ shouldPrompt: Bool, _ shouldOpenInSettings: Bool) -> Void)?) {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            DispatchQueue.main.async {
                if #available(iOS 12.0, *) {
                    if settings.authorizationStatus == .provisional {
                        completion?(false, false)
                        return
                    }
                }
                
                if settings.authorizationStatus == .notDetermined {
                    completion?(true, false)
                    return
                }
                
                if settings.authorizationStatus == .denied {
                    completion?(true, true)
                    return
                }
                
                completion?(false, false)
            }
        }
    }
    
    private func registerNotificationCategories() {
        if #available(iOS 10.0, *) {
            let generalCategory = UNNotificationCategory(identifier: SANotificationCategoryIdentifier.general.rawValue,
                                                         actions: [],
                                                         intentIdentifiers: [],
                                                         options: .customDismissAction)
        
            let detailAction = UNNotificationAction(identifier: SANotificationActionIdentifier.viewNewReplyDetail.rawValue,
                                                    title: "Detail",
                                                    options: .foreground)
            let expiredCategory = UNNotificationCategory(identifier: SANotificationCategoryIdentifier.custom.rawValue,
                                                         actions: [detailAction],
                                                         intentIdentifiers: [],
                                                         options: UNNotificationCategoryOptions(rawValue: 0))
            
            // Register the notification categories.
            let center = UNUserNotificationCenter.current()
            center.setNotificationCategories([generalCategory, expiredCategory])
            
        } else {
            // Fallback on earlier versions
        }
    }
    
    func handle(notification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        if let customInfo = userInfo["custom"] as? [AnyHashable:Any] {
            if let additionalInfo = customInfo["a"] as? [AnyHashable:Any] {
                /* handle push commands here */
                if let _ = additionalInfo["sa_fetch"] {
                    sa_log_v2("receive background fetch notification", log: .ui, type: .info)
                    AppController.current.getService(of: SABackgroundTaskManager.self)!.startBackgroundTask(with: completionHandler)
                    return
                } else  if let _ = additionalInfo["sa_clear"] {
                    // TODO: remove all runtime-generated files
                }
            }
        }
        
        completionHandler(.noData)
    }
    
    // MARK: - delegate
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Swift.Void) {
        completionHandler([.list, .banner, .sound])
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        sa_log_v2("user clicked notification %@", log: .ui, type: .info, response)
        defer {
            completionHandler()
        }
        
        var rootViewController: UIViewController?
        
        UIApplication.shared.connectedScenes.forEach { (s) in
            if s.activationState == .foregroundActive && rootViewController == nil {
                rootViewController = (s.delegate as? UIWindowSceneDelegate)?.window??.rootViewController
            }
        }
        
        guard rootViewController != nil else {
            return
        }
        
        guard let navigationController = AppController.current.findDeailNavigationController(rootViewController: rootViewController!) else {
           sa_log_v2("found no tab bar controller", log: .ui, type: .info)
            return
        }
        
        if response.notification.request.identifier == SANotificationRequestIdentifier.viewWatchList.rawValue {
            let favoritesViewController = SAFavouriteBoardsViewController()
            favoritesViewController.segmentedControl.selectedSegmentIndex = SAFavouriteBoardsViewController.SegmentedControlIndex.watchList.rawValue
            navigationController.show(favoritesViewController, sender: self)
        } else if response.notification.request.identifier == SANotificationRequestIdentifier.viewDirectMessageList.rawValue {
            let inbox = SAMessageInboxViewController()
            navigationController.show(inbox, sender: self)
        }
    }
}
