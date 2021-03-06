//
//  SAActivityItemProvider.swift
//  Saralin
//
//  Created by zhang on 4/24/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import SafariServices

class SAActivityItemProvider: UIActivityItemProvider {
    
    override var item : Any {
        let item = self.placeholderItem as! SAActivityItem
        item.prepare()
        return item
    }
}


class SAActivityItem: NSObject {
    var url: Foundation.URL?
    weak var viewController: UIViewController?
    func prepare() {
        os_log("prepare", log: .ui, type: .debug)
    }
}

class SAOpenDesktopPageActivity: UIActivity {
    
    var currentHandlingActivityItem: SAActivityItem?
    
    override class var activityCategory : UIActivity.Category {
        return .action
    }
    
    override var activityType : UIActivity.ActivityType? {
        return UIActivity.ActivityType.init("me.zaczh.saralin.activity.opendesktoppage")
    }
    
    override var activityTitle : String? {
        return NSLocalizedString("VIEW_DESKTOP_PAGE", comment: "查看桌面版页面")
    }
    
    override var activityImage : UIImage? {
        let appIcon = #imageLiteral(resourceName: "logo")
        return appIcon
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        os_log("canPerformWithActivityItems", log: .ui, type: .debug)
        for obj in activityItems {
            if (obj as AnyObject).isKind(of: SAActivityItem.self) {
                currentHandlingActivityItem = obj as? SAActivityItem
                return true
            }
        }
        
        return false
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        for item in activityItems {
            if (item as AnyObject).isKind(of: SAActivityItem.self) {
                os_log("prepareWithActivityItems", log: .ui, type: .debug)
            }
        }
    }
    
    override func perform() {
        
        guard let activity = currentHandlingActivityItem else {
            activityDidFinish(false)
            return
        }
        
        if let navigation = activity.viewController?.navigationController {
            let desktopPage = SAContentViewController(url: activity.url!)
            desktopPage.shouldSetDesktopBrowserUserAgent = true
            desktopPage.shouldLoadAllRequestsWithin = true
            desktopPage.title = NSLocalizedString("DESKTOP_PAGE", comment: "桌面版页面")
            navigation.pushViewController(desktopPage, animated: true)
        }
        activityDidFinish(true)
    }
    
}

class SASnapshotWebPageActivity: UIActivity {
    var currentHandlingActivityItem: SAActivityItem?

    override class var activityCategory : UIActivity.Category {
        return .action
    }
    
    override var activityType : UIActivity.ActivityType? {
        return UIActivity.ActivityType.init("me.zaczh.saralin.activity.snapshotwebpage")
    }
    
    override var activityTitle : String? {
        return NSLocalizedString("SHARE_ACTIVITY_TITLE_SNAPSHOT_WEBPAGE", comment: "生成网页截图")
    }
    
    override var activityImage : UIImage? {
        let appIcon = UIImage(named: "snap_shot_icon")
        return appIcon
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        os_log("canPerformWithActivityItems", log: .ui, type: .debug)
        for obj in activityItems {
            if (obj as AnyObject).isKind(of: SAActivityItem.self) {
                currentHandlingActivityItem = obj as? SAActivityItem
                return true
            }
        }
        
        return false
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        for item in activityItems {
            if (item as AnyObject).isKind(of: SAActivityItem.self) {
                os_log("prepareWithActivityItems", log: .ui, type: .debug)
            }
        }
    }
    
    override func perform() {
        
        guard let _ = currentHandlingActivityItem else {
            activityDidFinish(false)
            return
        }
        
//        guard let webViewController = activity.viewController as? SAThreadContentViewController else { return }
        
//        webViewController.webView.takeSnapshot(with: nil) { (img, error) in
//
//        }
        
        activityDidFinish(true)
    }
    
}

class SAOpenInSafariActivity: UIActivity {
    
    var currentHandlingActivityItem: SAActivityItem?
    
    override class var activityCategory : UIActivity.Category {
        return .action
    }
    
    override var activityType : UIActivity.ActivityType? {
        return UIActivity.ActivityType.init("me.zaczh.saralin.activity.openinsafari")
    }
    
    override var activityTitle : String? {
        return NSLocalizedString("SHARE_ACTIVITY_TITLE_OPEN_IN_SAFARI", comment: "用Safari打开")
    }
    
    override var activityImage : UIImage? {
        let appIcon = UIImage(named: "safari")
        return appIcon
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        os_log("canPerformWithActivityItems", log: .ui, type: .debug)
        for obj in activityItems {
            if (obj as AnyObject).isKind(of: SAActivityItem.self) {
                currentHandlingActivityItem = obj as? SAActivityItem
                return true
            }
        }
        
        return false
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        for item in activityItems {
            if (item as AnyObject).isKind(of: SAActivityItem.self) {
                os_log("prepareWithActivityItems", log: .ui, type: .debug)
            }
        }
    }
    
    override func perform() {
        guard let activity = currentHandlingActivityItem else {
            os_log("no activity", log: .ui, type: .debug)
            activityDidFinish(false)
            return
        }
        
        guard let sender = activity.viewController as? SAContentViewController else {
            os_log("no sender", log: .ui, type: .debug)
            activityDidFinish(false)
            return
        }
        
        guard let url = sender.url else {
            os_log("no url", log: .ui, type: .debug)
            activityDidFinish(false)
            return
        }
        
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:]) { (succeeded) in
                os_log("open in safari return: %@", log: .ui, type: .debug, succeeded ? "true" : "false")
            }
        } else {
            // Fallback on earlier versions
            UIApplication.shared.openURL(url)
        }
    }
    
}
