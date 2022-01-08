//
//  SAThemeManager.swift
//  Saralin
//
//  Created by zhang on 2/18/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

class SAThemeManager {
    var activeTheme: SATheme!
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserLoggedIn(_:)), name: Notification.Name.SAUserLoggedIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserLoggedOut(_:)), name: Notification.Name.SAUserLoggedOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserPreferenceChange(_:)), name: Notification.Name.SAUserPreferenceChanged, object: nil)
        
        loadUserTheme()
    }
    
    @objc func handleUserLoggedOut(_ notification: NSNotification) {
        // what should we do here?
    }
    
    @objc func handleUserLoggedIn(_ notification: NSNotification) {
        loadUserTheme()
    }
    
    @objc func handleUserPreferenceChange(_ notification: NSNotification) {
        let userInfo = notification.userInfo
        guard let key = userInfo?[SAAccount.Preference.changedPreferenceNameKey] as? SAAccount.Preference else {
            return
        }
        if key == SAAccount.Preference.theme_id {
            loadUserTheme()
        }
    }
    
    func loadUserTheme() {
        guard let themeID = Account().preferenceForkey(SAAccount.Preference.theme_id) as? Int,
            let theme = getThemeOf(id: themeID) else {
                return
        }
            
        activeTheme = theme
        if #available(iOS 13.0, *) {
            let autoSwitch = Account().preferenceForkey(.automatically_change_theme_to_match_system_appearance) as? Bool ?? true
            if !autoSwitch {
                return
            }
            
            let traitCollection = UITraitCollection.current
            let shouldSwitchTheme = (traitCollection.userInterfaceStyle == .dark && theme.colorScheme == 0) || (traitCollection.userInterfaceStyle == .light && theme.colorScheme == 1)
            if !shouldSwitchTheme {
                return
            }
            
            // theme not match
            var oldTheme: SATheme?
            if let oldThemeID = Account().preferenceForkey(.theme_id_before_night_switch) as? Int {
                oldTheme = getThemeOf(id: oldThemeID)
            }
            
            if let t = oldTheme, t.matchesTraitCollection(traitCollection) {
                activeTheme = t
                return
            }
            
            if theme.colorScheme == 0 {
                // switch to dark
                activeTheme = .darkTheme
                return
            }
            
            // switch to light
            activeTheme = .whiteTheme
            return
        }
    }
    
    func getThemeOf(id: Int) -> SATheme? {
        for theme in SATheme.allThemes {
            if theme.identifier == id {
                return theme
            }
        }
        
        return nil
    }
    
    func switchTheme() {
        let switchToNewTheme: ((SATheme) -> Void) = { (theme) in
            Account().savePreferenceValue(self.activeTheme.identifier as AnyObject, forKey: .theme_id_before_night_switch)
            self.activeTheme = theme
            Account().savePreferenceValue(theme.identifier as AnyObject, forKey: .theme_id)
        }
        
        if let oldThemeID = Account().preferenceForkey(.theme_id_before_night_switch) as? Int,
            let theme = getThemeOf(id: oldThemeID),
            theme.colorScheme != activeTheme.colorScheme {
            switchToNewTheme(theme)
            return
        }
        
        if activeTheme.colorScheme == 1 {
            // change to day
            let toTheme = SATheme.whiteTheme
            switchToNewTheme(toTheme)
        } else {
            // change to night
            let toTheme = SATheme.darkTheme
            switchToNewTheme(toTheme)
        }
    }
    
    func switchThemeBySystemStyleChange() {
        let switchToNewTheme: ((SATheme) -> Void) = { (theme) in
            if let oldThemeID = Account().preferenceForkey(.theme_id_before_night_switch) as? Int,
               let olodTheme = self.getThemeOf(id: oldThemeID),
               olodTheme.colorScheme == theme.colorScheme {
                self.activeTheme = olodTheme
                Account().savePreferenceValue(olodTheme.identifier as AnyObject, forKey: .theme_id)
                return
            }
            
            Account().savePreferenceValue(self.activeTheme.identifier as AnyObject, forKey: .theme_id_before_night_switch)
            self.activeTheme = theme
            Account().savePreferenceValue(theme.identifier as AnyObject, forKey: .theme_id)
        }
        
        if UITraitCollection.current.userInterfaceStyle == .light {
            // change to day
            let toTheme = SATheme.whiteTheme
            if activeTheme.identifier != toTheme.identifier {
                switchToNewTheme(toTheme)
            }
        } else if UITraitCollection.current.userInterfaceStyle == .dark {
            // change to night
            let toTheme = SATheme.darkTheme
            if activeTheme.identifier != toTheme.identifier {
                switchToNewTheme(toTheme)
            }
        }
    }
}


class SATheme: NSObject {
    static let allThemes = [SATheme.defaultTheme, SATheme.darkTheme, SATheme.whiteTheme]

    // unique theme ID
    var identifier = 0
    
    // color title
    var name: String = ""
    
    // main color scheme. 0 for light, 1 for dark
    var colorScheme = 0
    
    // global color
    var globalTintColor = "#000000"
    var barTintColor = "#000000"
    var textColor = "#000000"
    var backgroundColor = "#000000"
    var foregroundColor = "#000000"

    // web page
    var htmlLinkColor = "#000000"
    var htmlBlockQuoteBackgroundColor = "#000000"
    var htmlBlockQuoteTextColor = "#000000"
    
    // table view
    var tableCellTextColor = "#000000"
    var tableCellGrayedTextColor = "#000000"
    var tableCellSupplementTextColor = "#000000"
    var tableCellHighlightColor = "#000000"
    var tableCellTintColor = "#000000"
    var tableHeaderTextColor = "#000000"
    var tableCellSeperatorColor = "#000000"
    var tableHeaderBackgroundColor = "#000000"
    
    // bar
    var navigationBarStyle: UIBarStyle = .default
    var navigationBarTextColor = "#000000"
    var toolBarStyle: UIBarStyle = .default

    // other color & style
    var statusBarStyle: UIStatusBarStyle! = .default
    var threadTitleFontSizeInPt: CGFloat = 12
    var keyboardAppearence: UIKeyboardAppearance = .default
    var visualBlurEffectStyle: UIBlurEffect.Style = .dark
    var activityIndicatorStyle: UIActivityIndicatorView.Style = UIActivityIndicatorView.Style.medium
    
    func matchesTraitCollection(_ traitCollection: UITraitCollection) -> Bool {
        return (colorScheme == 0 && traitCollection.userInterfaceStyle == .light) ||
            (colorScheme == 1 && traitCollection.userInterfaceStyle == .dark)
    }
    
    static let defaultTheme: SATheme = { () in
        let theme = SATheme()
        theme.identifier = 0
        theme.name = "黄色主题"
        theme.colorScheme = 0
        
        theme.textColor = "#455c93"
        theme.globalTintColor = "#455c93"
        theme.barTintColor = "#fcfdfa"
        theme.navigationBarTextColor = "#000000"
        
        theme.htmlBlockQuoteBackgroundColor = "#d5e0af"
        theme.htmlBlockQuoteTextColor = "#455c93"
        theme.htmlLinkColor = "#4c6afa"
        
        theme.backgroundColor = "#fcfdfa"
        theme.foregroundColor = "#F6F7EB"
        theme.tableCellTintColor = "#455c93"
        theme.tableCellSeperatorColor = "#33333333"
        theme.tableCellTextColor = "#455c93"
        theme.tableCellGrayedTextColor = "#888888"
        
        theme.tableHeaderTextColor = "#455c93"
        theme.tableHeaderBackgroundColor = "#F6F7EB"
        theme.tableCellSupplementTextColor = "#5a5a5a"
        theme.tableCellHighlightColor = "#d5e0af"

        theme.navigationBarStyle = .default
        theme.toolBarStyle = .default
        
        theme.statusBarStyle = .default
        theme.keyboardAppearence = .default
        
        theme.visualBlurEffectStyle = .light
        theme.activityIndicatorStyle = .medium
        
        return theme
    }()
    
    static let darkTheme: SATheme = { () in
        let theme = SATheme()
        theme.identifier = 1
        theme.name = "夜间主题"
        theme.colorScheme = 1
        
        theme.textColor = "#BBBBBB"
        theme.globalTintColor = "#CB8841"
        theme.barTintColor = "#00000000"
        theme.navigationBarTextColor = "#d5d6e0"
        
        theme.htmlBlockQuoteBackgroundColor = "#221e27"
        theme.htmlBlockQuoteTextColor = "#8d9abc"
        theme.htmlLinkColor = "#8d9abc"
        
        theme.tableCellHighlightColor = "#222222"
        theme.backgroundColor = "#000000"
        theme.foregroundColor = "#1C1C1D"
        theme.tableCellSeperatorColor = "#434345" // RGBA
        theme.tableCellTextColor = "#BBBBBB"
        theme.tableHeaderTextColor = "#BBBBBB"
        theme.tableHeaderBackgroundColor = "#00000000"//clear color
        theme.tableCellTintColor = "#BBBBBB"
        theme.tableCellSupplementTextColor = "#636A6E"
        theme.tableCellGrayedTextColor = "#999999"

        theme.navigationBarStyle = .black
        theme.toolBarStyle = .black
        
        theme.statusBarStyle = .lightContent
        theme.keyboardAppearence = .dark
        
        theme.visualBlurEffectStyle = .dark
        theme.activityIndicatorStyle = .medium
        
        return theme
    }()
    
    static let whiteTheme: SATheme = { () in
        let theme = SATheme()
        theme.identifier = 2
        theme.name = "白色主题"
        theme.colorScheme = 0
        
        theme.textColor = "#3e3a3f"
        theme.globalTintColor = "#457cff"
        theme.barTintColor = "#ffffff"
        theme.navigationBarTextColor = "#000000"
        
        theme.backgroundColor = "#ececec"
        theme.foregroundColor = "#FFFFFF"

        theme.htmlBlockQuoteBackgroundColor = "#eeebf6"
        theme.htmlBlockQuoteTextColor = "#33333399"
        theme.htmlLinkColor = "#8b6214"
        
        theme.tableCellTintColor = "48463F"
        theme.tableCellSeperatorColor = "#33333333"
        theme.tableCellTextColor = "#3e3a3f"
        theme.tableCellGrayedTextColor = "#888888"
        theme.tableHeaderTextColor = "#48463F"
        theme.tableHeaderBackgroundColor = "#00000000"//clear color
        theme.tableCellSupplementTextColor = "#5a5a5a"
        theme.tableCellHighlightColor = "#b6b6b6"
        
        theme.navigationBarStyle = .default
        theme.toolBarStyle = .default
        
        theme.statusBarStyle = .default
        theme.keyboardAppearence = .default
        
        theme.visualBlurEffectStyle = .light
        theme.activityIndicatorStyle = .medium
        
        return theme
    }()
}
