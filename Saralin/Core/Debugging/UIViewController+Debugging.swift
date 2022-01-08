//
//  UIViewController+Debugging.swift
//  Saralin
//
//  Created by Junhui Zhang on 2021/2/7.
//  Copyright © 2021 zaczh. All rights reserved.
//

import Foundation

extension UIViewController {
    static func debugging_swizzleMethods() {
        #if DEBUG
        repeat {
            let method0 = class_getInstanceMethod(UIViewController.self, #selector(didMove(toParent:)))
            let method1 = class_getInstanceMethod(UIViewController.self, #selector(debuggingDidMove(toParent:)))
            method_exchangeImplementations(method0!, method1!)
        } while(false)
        #endif
    }
    
    func debuggingGetClassName() -> String {
        let className = class_getName(type(of: self))
        let classNameStr = String(cString: className)
        return classNameStr
    }
    
    @objc func debuggingShouldCheckLeak() -> Bool {
        let classNameStr = debuggingGetClassName()
        return classNameStr.hasPrefix("Saralin") || classNameStr == "UIViewController" || classNameStr == "UIAlertController"
    }
    
    @objc func debuggingDidMove(toParent parent: UIViewController?) {
        debuggingDidMove(toParent: parent)
        if parent != nil || !debuggingShouldCheckLeak() {
            return
        }
        let viewControllerDelegate = WeakDelegate(object: self)
        let classNameStr = debuggingGetClassName()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
            if viewControllerDelegate.object == nil {
                return
            }
            
            let vc = viewControllerDelegate.object! as! UIViewController
            if vc.parent != nil {
                return
            }
            
            sa_log_v2("maybe a viewcontroller leak: %@ %p", log: .debugging, type: .debug, classNameStr, vc)
        }
    }
}
