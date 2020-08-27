//
//  SACookieManager.swift
//  Saralin
//
//  Created by zhang on 4/3/17.
//  Copyright © 2017 zaczh. All rights reserved.
//

import Foundation

class SACookieManager {
    private var cookieChangedNotificationObject: NSObjectProtocol?
    private var logoutNotificationObject: NSObjectProtocol?
    private var loginNotificationObject: NSObjectProtocol?
    private var lastTimeRefreshCookie: Date?
    init() {
        let center = NotificationCenter.default
        cookieChangedNotificationObject = center.addObserver(forName: NSNotification.Name.NSHTTPCookieManagerCookiesChanged, object: nil, queue: nil) { [weak self] (notication) in
            sa_log_v2("Cookie changed", module: .cookie, type: .debug)
            self?.syncCookiesAcrossDomains()
        }
        
        logoutNotificationObject = center.addObserver(forName: Notification.Name.SAUserLoggedOutNotification, object: nil, queue: nil, using: { [weak self] (notification) in
            self?.lastTimeRefreshCookie = nil
        })
        
        loginNotificationObject = center.addObserver(forName: Notification.Name.SAUserLoggedInNotification, object: nil, queue: nil, using: { [weak self] (notification) in
            self?.lastTimeRefreshCookie = Date()
        })
    }
    
    private func syncCookiesAcrossDomains() {
        let cookieStorage = HTTPCookieStorage.shared
        guard let _ = cookieStorage.cookies else {
            sa_log_v2("Cookie storage was emptied", module: .cookie, type: .info)
            return
        }
        
        //TODO: sync cookie?
    }
    
    deinit {
        let center = NotificationCenter.default
        if let object = self.cookieChangedNotificationObject {
            center.removeObserver(object)
        }
        
        if let object = logoutNotificationObject {
            center.removeObserver(object)
        }
    }
    
    // on iPad, App will stay in memory for a very long time. If we do not refresh cookies periodically,
    // then when we open a forum page after some days, we are logged out.
    func renewCookiesIfNeeded() {
        let account = Account()
        guard !account.uid.isEmpty else {
            return
        }
        
        if let lastTimeRefreshCookie = lastTimeRefreshCookie as NSDate?, lastTimeRefreshCookie.timeIntervalSinceNow > -8 * 3600 {
            return
        }
        sa_log_v2("refresh cookie", module: .cookie, type: .debug)
        
        var request = URLRequest(url: URL(string: SAGlobalConfig().forum_url)!)
        request.setValue(SAGlobalConfig().pc_useragent_string, forHTTPHeaderField: "User-Agent");
        let task = URLSession.saCustomized.downloadTask(with: request) { (url, response, error) in
            guard error == nil else {
                return
            }
            self.lastTimeRefreshCookie = Date()
        }
        task.resume()
    }
}
