//
//  SASplitViewController.swift
//  Saralin
//
//  Created by zhang on 6/26/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

class SASplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        #if targetEnvironment(macCatalyst)
        preferredDisplayMode = .twoBesideSecondary
        primaryBackgroundStyle = .sidebar
        #endif
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 13.0, *) {
            guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else {
                return
            }
            
            let autoSwitch = Account().preferenceForkey(.automatically_change_theme_to_match_system_appearance) as? Bool ?? true
            if !autoSwitch {
                overrideUserInterfaceStyle = Theme().colorScheme == 1 ? .dark : .light
                return
            }
            
            overrideUserInterfaceStyle = .unspecified
            
            AppController.current.getService(of: SAThemeManager.self)?.switchThemeBySystemStyleChange()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.SAUserPreferenceChanged, object: nil)
    }

    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        view.backgroundColor = UIColor.sa_colorFromHexString(Theme().tableCellSeperatorColor)
        if #available(iOS 13.0, *) {
            let autoSwitch = Account().preferenceForkey(.automatically_change_theme_to_match_system_appearance) as? Bool ?? true
            if !autoSwitch {
                overrideUserInterfaceStyle = Theme().colorScheme == 1 ? .dark : .light
            } else {
                overrideUserInterfaceStyle = .unspecified
            }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme().statusBarStyle
    }
}
