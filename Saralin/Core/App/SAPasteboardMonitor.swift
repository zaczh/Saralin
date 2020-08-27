//
//  SAPasteboardMonitor.swift
//  Saralin
//
//  Created by zhang on 2019/6/21.
//  Copyright © 2019 zaczh. All rights reserved.
//

import Foundation
import UIKit

class SAPasteboardMonitor: NSObject {
    private var lastHandledURL: URL?
    override init() {
        super.init()
        NotificationCenter.default.addObserver(forName: UIPasteboard.changedNotification, object: nil, queue: nil) { [weak self] (notification) in
            DispatchQueue.main.async {
                self?.doCheck()
            }
        }
        
        // The `UIPasteboard.changedNotification` notification only get posted when App is in the foreground.
        // We need to support background pasting here.
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] (notification) in
            DispatchQueue.main.async {
                self?.doCheck()
            }
        }
    }
    
    private func doCheck() {
        let pasteboard = UIPasteboard.general
        if pasteboard.hasURLs {
            processURLs()
            return
        }
        
        if pasteboard.hasStrings {
            processStrings()
            return
        }
    }
    
    private func processStrings() {
        let pasteboard = UIPasteboard.general
        guard let urlStr = pasteboard.string else {
            return
        }
        
        guard let url = URL.init(string: urlStr) else {
            return
        }
        
        guard let scheme = url.scheme else {
            return
        }
        
        // only check http urls.
        if scheme.caseInsensitiveCompare("http") != .orderedSame && scheme.caseInsensitiveCompare("https") != .orderedSame {
            return
        }
        
        handle(url: url)
    }
    
    private func processURLs() {
        let pasteboard = UIPasteboard.general
        guard let url = pasteboard.url else {
            return
        }
        
        handle(url: url)
    }
    
    private func handle(url: URL) {
        if url == lastHandledURL {
            return
        }
        lastHandledURL = url
        
        if url.sa_isExternal() {
            return
        }
        
        guard let window = UIApplication.shared.keyWindow else {
            return
        }
        
        guard let rootViewController = window.rootViewController else { return }
        
        if rootViewController.presentedViewController != nil {
            // this will cause problem
            return
        }
        
        let alert = UIAlertController(title: "提示", message: "检测到论坛域名下的链接：\(url.absoluteString)，是否打开？", preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = window
        alert.popoverPresentationController?.sourceRect = window.bounds
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        let openAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { (action) in
            guard let content = SAContentViewController.viewControllerForURL(url: url, sender: nil) else {
                return
            }
            
            guard let navi = AppController.current.findDeailNavigationController(rootViewController: rootViewController) else {
                return
            }
            
            navi.pushViewController(content, animated: true)
        })
        alert.addAction(openAction)
        rootViewController.present(alert, animated: true, completion: nil)
    }
}
