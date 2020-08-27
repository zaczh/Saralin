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
        // do the actually updating themes
        if isViewLoaded {
            updatingTheme(for: view, theme: newTheme)
        }
        
        needsUpdateTheme = false
        for vc in children {
            vc.needsUpdateTheme = true
            vc.viewThemeDidChange(newTheme)
            vc.needsUpdateTheme = false
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
        
        // do the actually updating font
        if isViewLoaded {
            updatingFont(for: view, theme: newTheme)
        }
        
        needsUpdateFont = false
        for vc in children {
            vc.needsUpdateFont = true
            vc.viewFontDidChange(newTheme)
            vc.needsUpdateFont = false
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
