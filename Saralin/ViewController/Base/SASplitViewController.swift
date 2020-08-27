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
        #if !targetEnvironment(macCatalyst)
        if UIDevice.current.userInterfaceIdiom == .phone {
            delegate = self
        }
        #endif
    }
    
    override func showDetailViewController(_ vc: UIViewController, sender: Any?) {
        #if targetEnvironment(macCatalyst)
        guard let navi = vc as? UINavigationController else {
            super.showDetailViewController(SANavigationController(rootViewController: vc), sender: sender)
            return
        }
        super.showDetailViewController(navi, sender: sender)
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            guard let navi = vc as? UINavigationController else {
                super.showDetailViewController(SANavigationController(rootViewController: vc), sender: sender)
                return
            }
            super.showDetailViewController(navi, sender: sender)
        } else {
            super.showDetailViewController(vc, sender: sender)
        }
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
            if (traitCollection.userInterfaceStyle == .dark && Theme().colorScheme == 1) ||
                (traitCollection.userInterfaceStyle == .light && Theme().colorScheme == 0) {
                return
            }
            
            AppController.current.getService(of: SAThemeManager.self)?.switchTheme()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.SAUserPreferenceChangedNotification, object: nil)
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

    func splitViewController(_ splitViewController: UISplitViewController, showDetail vc: UIViewController, sender: Any?) -> Bool {
        
        if splitViewController.isCollapsed {
            if let tab = viewControllers.first as? UITabBarController {
                if let tabNavi = tab.selectedViewController as? UINavigationController {
                    if let navi = vc as? UINavigationController {
                        var vcs = tabNavi.viewControllers
                        vcs.append(contentsOf: navi.viewControllers)
                        tabNavi.setViewControllers(vcs, animated: true)
                    } else {
                        tabNavi.pushViewController(vc, animated: true)
                    }
                }
            } else if let tabNavi = viewControllers.first as? UINavigationController {
                if let navi = vc as? UINavigationController {
                    var vcs = tabNavi.viewControllers
                    vcs.append(contentsOf: navi.viewControllers)
                    tabNavi.setViewControllers(vcs, animated: true)
                } else {
                    tabNavi.pushViewController(vc, animated: true)
                }
            }
        } else {
            var navi = vc as? UINavigationController
            if navi == nil {
                navi = SANavigationController(rootViewController: vc)
            }
            
            if viewControllers.count > 1 {
                viewControllers[1] = navi!
            }
        }
        
        return true
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, show vc: UIViewController, sender: Any?) -> Bool {
        if let navi = splitViewController.viewControllers.first as? UINavigationController {
            navi.pushViewController(vc, animated: true)
        } else if let tab = splitViewController.viewControllers.first as? UITabBarController {
            if let tabNavi = tab.selectedViewController as? UINavigationController {
                if let navi = vc as? UINavigationController {
                    var vcs = tabNavi.viewControllers
                    vcs.append(contentsOf: navi.viewControllers)
                    tabNavi.setViewControllers(vcs, animated: true)
                } else {
                    tabNavi.pushViewController(vc, animated: true)
                }
            }
        } else {  
            if splitViewController.viewControllers.count > 0 {
                splitViewController.viewControllers[0] = vc
            }
        }
        return true
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        guard let secondary = secondaryViewController as? UINavigationController else {
            // when secondaryViewController is not an navigationController, let system manages it
            return false
        }
        
        if secondary.topViewController?.isKind(of: SAPlaceHolderViewController.self) ?? true {
            // do not collapse placeholder to master view controller
            return true
        }
        
        guard let primary = getPrimaryNavigationController() else {
            return false
        }
        
        if secondary.viewControllers.count > 0 {
            primary.setViewControllers(primary.viewControllers + secondary.viewControllers, animated: false)
        }
        return true
    }
    
    private func getPrimaryNavigationController() -> UINavigationController? {
        guard let primaryViewController = viewControllers.first else {
            return nil
        }
        
        var primaryNavigationController: UINavigationController?
        if let primaryTab = primaryViewController as? UITabBarController {
            primaryNavigationController = primaryTab.selectedViewController as? UINavigationController
        } else if let navi = primaryViewController as? UINavigationController {
            primaryNavigationController = navi
        }
        return primaryNavigationController
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        guard let primaryNavigationController = getPrimaryNavigationController() else {
            let placeholder = UIStoryboard(name: "Main_ipad", bundle: nil).instantiateViewController(withIdentifier: "Main_ipad_place_holder") as! SAPlaceHolderViewController
            let newNavi = SANavigationController(rootViewController: placeholder)
            return newNavi
        }
        
        var primaryVCs = primaryNavigationController.viewControllers
        var secondaryViewControllers: [UIViewController] = []
        for v in primaryVCs.reversed() {
            if v.isKind(of: SAContentViewController.self) ||
                v.isKind(of: SAPlainTextViewController.self) ||
                v.isKind(of: SAAboutViewController.self) ||
                v.isKind(of: SAUserThreadViewController<MyThreadModel>.self) ||
                v.isKind(of: SAUserThreadViewController<OthersThreadModel>.self) ||
                v.isKind(of: SAUserThreadViewController<ThreadSearchResultModel>.self) ||
                v.isKind(of: DatabaseRecordsViewController.self) {
                secondaryViewControllers.append(v)
            }
        }
        
        if !secondaryViewControllers.isEmpty {
            primaryVCs.removeAll { (v) -> Bool in
                return secondaryViewControllers.contains(v)
            }
            primaryNavigationController.setViewControllers(primaryVCs, animated: false)
            let newNavi = SANavigationController.init(nibName: nil, bundle: nil)
            newNavi.setViewControllers(secondaryViewControllers.reversed(), animated: false)
            return newNavi
        }
        
        let placeholder = UIStoryboard(name: "Main_ipad", bundle: nil).instantiateViewController(withIdentifier: "Main_ipad_place_holder") as! SAPlaceHolderViewController
        let newNavi = SANavigationController(rootViewController: placeholder)
        return newNavi
    }
}
