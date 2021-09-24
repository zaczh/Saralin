//
//  SANavigationController.swift
//  Saralin
//
//  Created by zhang on 2018/7/16.
//  Copyright © 2018年 zaczh. All rights reserved.
//

import UIKit

class SANavigationController: UINavigationController, UIViewControllerTransitioningDelegate, UINavigationControllerDelegate {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if let top = topViewController {
            return top.supportedInterfaceOrientations
        }
        
        return super.supportedInterfaceOrientations
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        #if targetEnvironment(macCatalyst)
        navigationBar.prefersLargeTitles = false
        #endif
    }
    
    override func viewThemeDidChange(_ activeTheme: SATheme) {
        super.viewThemeDidChange(activeTheme)
        navigationBar.barStyle = activeTheme.navigationBarStyle
        navigationBar.barTintColor = activeTheme.barTintColor.sa_toColor()
        navigationBar.tintColor = activeTheme.globalTintColor.sa_toColor()
        let titleColor = activeTheme.colorScheme == 0 ? UIColor.black : UIColor.white
        navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: titleColor]
        if #available(iOS 13.0, *) {
            navigationBar.standardAppearance.backgroundColor = activeTheme.barTintColor.sa_toColor()
        } else {
            // Fallback on earlier versions
        }
        navigationBar.scrollEdgeAppearance = UINavigationBarAppearance()
        navigationBar.scrollEdgeAppearance?.backgroundColor = activeTheme.barTintColor.sa_toColor()
    }
    
    override var prefersStatusBarHidden: Bool {
        return topViewController?.prefersStatusBarHidden ?? super.prefersStatusBarHidden
    }
}
