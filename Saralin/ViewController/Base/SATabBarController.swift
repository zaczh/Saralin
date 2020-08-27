//
//  SATabBarController.swift
//  Saralin
//
//  Created by zhang on 2018/7/16.
//  Copyright © 2018年 zaczh. All rights reserved.
//

import UIKit

class SATabBarController: UITabBarController {
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
        guard let selected = selectedViewController else { return }
        viewControllers?.forEach({ (viewController) in
            if let navigationController = viewController as? SANavigationController, navigationController != selected {
                navigationController.popToRootViewController(animated: false)
            }
        })
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        doUpdateViewTheme(newTheme)
    }
    
    private func doUpdateViewTheme(_ newTheme: SATheme) {
        tabBar.tintColor = newTheme.globalTintColor.sa_toColor()
        tabBar.barStyle = newTheme.toolBarStyle
        if #available(iOS 13.0, *) {
            tabBar.standardAppearance.backgroundColor = newTheme.barTintColor.sa_toColor()
        } else {
            // Fallback on earlier versions
        }
    }
}
