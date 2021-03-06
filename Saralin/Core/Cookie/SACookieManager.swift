//
//  SACookieManager.swift
//  Saralin
//
//  Created by zhang on 4/3/17.
//  Copyright © 2017 zaczh. All rights reserved.
//

import Foundation
import WebKit

class SACookieManager {
    private var logoutNotificationObject: NSObjectProtocol?
    private var loginNotificationObject: NSObjectProtocol?
    private var lastTimeRefreshCookie: Date?
    private var lastTimeRefreshCookieLock = NSLock()
    init() {
        let center = NotificationCenter.default
        logoutNotificationObject = center.addObserver(forName: Notification.Name.SAUserLoggedOutNotification, object: nil, queue: nil, using: { [weak self] (notification) in
            guard let self = self else {
                return
            }
            self.lastTimeRefreshCookieLock.lock()
            self.lastTimeRefreshCookie = nil
            self.lastTimeRefreshCookieLock.unlock()
        })
        
        loginNotificationObject = center.addObserver(forName: Notification.Name.SAUserLoggedInNotification, object: nil, queue: nil, using: { [weak self] (notification) in
            guard let self = self else {
                return
            }
            self.lastTimeRefreshCookieLock.lock()
            self.lastTimeRefreshCookie = Date()
            self.lastTimeRefreshCookieLock.unlock()
        })
    }
    
    func syncWKCookiesToNSCookieStorage(completion:(() -> Void)?) {
        let cookieStorage = HTTPCookieStorage.shared
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies {
                if !(cookieStorage.cookies?.contains(cookie) ?? false) {
                    cookieStorage.setCookie(cookie)
                }
            }
            completion?()
        }
    }
    
    deinit {
        let center = NotificationCenter.default
        
        if let object = logoutNotificationObject {
            center.removeObserver(object)
        }
        
        if let object = loginNotificationObject {
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
        
        lastTimeRefreshCookieLock.lock()
        if let lastTimeRefreshCookie = lastTimeRefreshCookie as NSDate?, lastTimeRefreshCookie.timeIntervalSinceNow > -8 * 3600 {
            lastTimeRefreshCookieLock.unlock()
            return
        }
        lastTimeRefreshCookieLock.unlock()
        os_log("refresh cookie", log: .cookie, type: .info)
        
        var request = URLRequest(url: URL(string: SAGlobalConfig().forum_url)!)
        request.setValue(SAGlobalConfig().pc_useragent_string, forHTTPHeaderField: "User-Agent");
        let task = URLSession.saCustomized.downloadTask(with: request) { (url, response, error) in
            guard error == nil else {
                return
            }
            self.lastTimeRefreshCookieLock.lock()
            self.lastTimeRefreshCookie = Date()
            self.lastTimeRefreshCookieLock.unlock()
        }
        task.resume()
    }
}
