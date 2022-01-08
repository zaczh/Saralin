//
//  Extensions.swift
//  Saralin
//
//  Created by zhang on 2019/9/26.
//  Copyright © 2019 zaczh. All rights reserved.
//

import UIKit

extension UIView: SAViewTheming {
    static func sa_swizzleMethods() {
        let method0 = class_getInstanceMethod(UIView.self, #selector(UIView.didAddSubview(_:)))
        let method1 = class_getInstanceMethod(UIView.self, #selector(UIView.sa_didAddSubview(_:)))
        method_exchangeImplementations(method0!, method1!)
    }
    
    @objc func sa_didAddSubview(_ view: UIView) {
        sa_didAddSubview(view)
        let theme = Theme()
        view.themeDidUpdate(theme)
        view.fontDidUpdate(theme)
    }
    
    @objc func themeDidUpdate(_ newTheme: SATheme) {
    }
    
    @objc func fontDidUpdate(_ newTheme: SATheme) {
    }
}

private var kViewControllerNeedsUpdateTheme = ""
private var kViewControllerNeedsUpdateFont = ""
extension UIViewController: SAViewControllerTheming {
    static func sa_swizzleMethods() {
        repeat {
            let method0 = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.sa_viewDidLoad))
            let method1 = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.viewDidLoad))
            method_exchangeImplementations(method0!, method1!)
        } while(false)
        
        repeat {
            let method0 = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.sa_viewWillAppear(_:)))
            let method1 = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.viewWillAppear(_:)))
            method_exchangeImplementations(method0!, method1!)
        } while(false)
        
        repeat {
            let method0 = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.sa_viewDidAppear(_:)))
            let method1 = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.viewDidAppear(_:)))
            method_exchangeImplementations(method0!, method1!)
        } while(false)
        
        repeat {
            let method0 = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.sa_viewDidDisappear(_:)))
            let method1 = class_getInstanceMethod(UIViewController.self, #selector(UIViewController.viewDidDisappear(_:)))
            method_exchangeImplementations(method0!, method1!)
        } while(false)
    }
    
    var needsUpdateTheme: Bool {
        get {
            if let needsUpdateTheme = objc_getAssociatedObject(self, &kViewControllerNeedsUpdateTheme) as? Bool {
                return needsUpdateTheme
            }
            objc_setAssociatedObject(self, &kViewControllerNeedsUpdateTheme, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return true
        }
        set {
            objc_setAssociatedObject(self, &kViewControllerNeedsUpdateTheme, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var needsUpdateFont: Bool {
        get {
            if let needsUpdateFont = objc_getAssociatedObject(self, &kViewControllerNeedsUpdateFont) as? Bool {
                return needsUpdateFont
            }
            objc_setAssociatedObject(self, &kViewControllerNeedsUpdateFont, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return true
        }
        set {
            objc_setAssociatedObject(self, &kViewControllerNeedsUpdateFont, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    @objc func viewThemeDidChange(_ newTheme:SATheme){
        // the order is important
        if !needsUpdateTheme {
            return
        }
        
        if !isViewLoaded {
            return
        }
        
        // do the actually updating themes
        updatingTheme(for: view, theme: newTheme)
        needsUpdateTheme = false
        
        for vc in children {
            vc.needsUpdateTheme = true
            if vc.isViewLoaded {
                vc.viewThemeDidChange(newTheme)
                vc.needsUpdateTheme = false
            }
        }
        
        if let vc = presentedViewController {
            vc.needsUpdateTheme = true
            if vc.isViewLoaded {
                vc.viewThemeDidChange(newTheme)
                vc.needsUpdateTheme = false
            }
        }
    }
    
    private func updatingTheme(for view: UIView, theme: SATheme) {
        view.themeDidUpdate(theme)
        for sub in view.subviews {
            updatingTheme(for: sub, theme: theme)
        }
    }
    
    private func updatingFont(for view: UIView, theme: SATheme) {
        view.fontDidUpdate(theme)
        for sub in view.subviews {
            updatingFont(for: sub, theme: theme)
        }
    }
    
    @objc func viewFontDidChange(_ newTheme:SATheme){
        // the order is important
        if !needsUpdateFont {
            return
        }
        
        if !isViewLoaded {
            return
        }
        
        // do the actually updating font
        updatingFont(for: view, theme: newTheme)
        needsUpdateFont = false
        
        for vc in children {
            vc.needsUpdateFont = true
            if vc.isViewLoaded {
                vc.viewFontDidChange(newTheme)
                vc.needsUpdateFont = false
            }
        }
    }
    
    @objc func sa_viewDidLoad() {
        sa_viewDidLoad()
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] (_) in
            self?.viewDidBecomeActive()
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] (_) in
            self?.viewWillResignActive()
        }
        
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(forName: UIWindowScene.didActivateNotification, object: nil, queue: nil) { [weak self] (_) in
                self?.viewDidBecomeActive()
            }
            
            NotificationCenter.default.addObserver(forName: UIWindowScene.willDeactivateNotification, object: nil, queue: nil) { [weak self] (_) in
                self?.viewWillResignActive()
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    @objc func sa_viewWillAppear(_ animated: Bool) {
        let theme = Theme()
        if needsUpdateTheme {
            viewThemeDidChange(theme)
            needsUpdateTheme = false
        }
        
        if needsUpdateFont {
            viewFontDidChange(theme)
            needsUpdateFont = false
        }
        sa_viewWillAppear(animated)
    }
    
    @objc func sa_viewDidAppear(_ animated: Bool) {
        sa_viewDidAppear(animated)
        isViewVisible = true
    }
    
    @objc func sa_viewDidDisappear(_ animated: Bool) {
        sa_viewDidDisappear(animated)
        isViewVisible = false
    }
}

extension UIViewController: SAViewControllerActiveStateChanging {
    @objc func viewWillResignActive(){}
    @objc func viewDidBecomeActive(){}
}

// MARK: Restore Protocol
private var kViewControllerRestoreFlag = ""
extension UIViewController: SAViewControllerRestore {
    var isRestoredFromArchive: Bool {
        get {
            if let isRestore = objc_getAssociatedObject(self, &kViewControllerRestoreFlag) as? Bool {
                return isRestore
            }
            return false
        }
        set {
            objc_setAssociatedObject(self, &kViewControllerRestoreFlag, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: SAViewControllerVisibility
private var kViewControllerVisibilityFlag = ""
extension UIViewController: SAViewControllerVisibility {
    var isViewVisible: Bool {
        get {
            if let isViewVisible = objc_getAssociatedObject(self, &kViewControllerVisibilityFlag) as? Bool {
                return isViewVisible
            }
            return false
        }
        set {
            objc_setAssociatedObject(self, &kViewControllerVisibilityFlag, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: Loading Protocol
private var kLoadingController = ""
extension UIViewController: SAViewControllerLoading {
    @objc func loadingControllerDidRetry(_ controller: SALoadingViewController) {}
    var loadingController: SALoadingViewController {
        get {
            if let loading = objc_getAssociatedObject(self, &kLoadingController) {
                return loading as! SALoadingViewController
            }
            
            let loading = SALoadingViewController()
            objc_setAssociatedObject(self, &kLoadingController, loading, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return loading
        }
    }
    var loadingView: UIView {return loadingController.view}
}


extension UIImageView {
    static var saImageViewLoadingTasks: [URLSessionDataTask] = []
    static let saImageViewLoadingTasksLock = NSLock()
    static var kSAImageURLKey = ""
    private var saImageURLKey: URL? {
        get {
            return objc_getAssociatedObject(self, &UIImageView.kSAImageURLKey) as? URL
        }
        set {
            objc_setAssociatedObject(self, &UIImageView.kSAImageURLKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private func sa_set(image: UIImage, for url: URL) {
        if self.saImageURLKey == url {
            self.image = image
        } else {
            sa_log_v2("image changed", log:.network)
        }
    }
    
    func sa_setImage(with url: URL?) {
        guard let url = url else {
            self.image = nil
            saImageURLKey = nil
            return
        }
        
        saImageURLKey = url
        
        let request = URLRequest(url: url)
        if let cached = URLCache.shared.cachedResponse(for: request) {
            let data = cached.data
            let response = cached.response as! HTTPURLResponse
            if let image = UIImage(data: data) {
                dispatch_async_main { [weak self] in
                    self?.sa_set(image: image, for: url)
                }
                return
            }
            
            if response.statusCode == 301,
                let location = response.allHeaderFields["Location"] as? String,
                let locationURL = URL(string: location) {
                let request = URLRequest(url: locationURL)
                if let cached = URLCache.shared.cachedResponse(for: request) {
                    let data = cached.data
                    if let image = UIImage(data: data) {
                        dispatch_async_main { [weak self] in
                            self?.sa_set(image: image, for: url)
                        }
                        return
                    }
                }
            }
            
            URLCache.shared.removeCachedResponse(for: request)
            sa_log_v2("cached response corrupted, remove it. task: %@.", log:.network, url.absoluteString)
        }
        
        UIImageView.saImageViewLoadingTasksLock.lock()
        for task in UIImageView.saImageViewLoadingTasks {
            guard let taskUrl = task.originalRequest?.url else {
                continue
            }
            if taskUrl == url {
                UIImageView.saImageViewLoadingTasksLock.unlock()
                return
            }
        }
        UIImageView.saImageViewLoadingTasksLock.unlock()
        sa_log_v2("new task: %@", log:.network, url.absoluteString)
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: url) { [weak self] (data, response, error) in
            UIImageView.saImageViewLoadingTasksLock.lock()
            UIImageView.saImageViewLoadingTasks.removeAll { (task) -> Bool in
                guard let taskUrl = task.originalRequest?.url else {
                    return false
                }
                return taskUrl == url
            }
            UIImageView.saImageViewLoadingTasksLock.unlock()

            guard error == nil else {
                sa_log_v2("task failed: %@", log:.network, error!.localizedDescription)
                return
            }
            
            guard let data = data, let response = response, let responseURL = response.url else {
                sa_log_v2("task no data or response: %@", log:.network, url.absoluteString)
                return
            }
            
            guard let image = UIImage(data: data) else {
                sa_log_v2("task no image: %@", log:.network, url.absoluteString)
                return
            }
            
            let request = URLRequest(url: responseURL)
            let cached = CachedURLResponse.init(response: response, data: data, userInfo: nil, storagePolicy: .allowedInMemoryOnly)
            URLCache.shared.storeCachedResponse(cached, for: request)
            
            dispatch_async_main {
                self?.sa_set(image: image, for: url)
            }
        }
        task.resume()
        UIImageView.saImageViewLoadingTasksLock.lock()
        UIImageView.saImageViewLoadingTasks.append(task)
        UIImageView.saImageViewLoadingTasksLock.unlock()
    }
}
