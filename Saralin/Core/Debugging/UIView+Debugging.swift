//
//  UIView+Debugging.swift
//  Saralin
//
//  Created by Junhui Zhang on 2021/2/7.
//  Copyright © 2021 zaczh. All rights reserved.
//

import Foundation

class WeakDelegate: NSObject {
    private(set) weak var object: NSObject?
    init(object: NSObject) {
        self.object = object
    }
}

extension UIView {
    static func debugging_swizzleMethods() {
        #if DEBUG
        repeat {
            let method0 = class_getInstanceMethod(UIView.self, #selector(didMoveToWindow))
            let method1 = class_getInstanceMethod(UIView.self, #selector(debuggingDidMoveToWindow))
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
        return classNameStr.hasPrefix("SA") || classNameStr == "UIView" || classNameStr.contains("WKWebView")
    }
    
    @objc func debuggingDidMoveToWindow() {
        debuggingDidMoveToWindow()
        if !debuggingShouldCheckLeak() {
            return
        }
        let viewDelegate = WeakDelegate(object: self)
        let classNameStr = debuggingGetClassName()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
            if viewDelegate.object == nil {
                return
            }
            
            let view = viewDelegate.object! as! UIView
            if view.window != nil {
                return
            }
            
            sa_log_v2("maybe a view leak: %@ %p", log: .debugging, type: .debug, classNameStr, view)
        }
    }
}
