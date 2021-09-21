//
//  AppController.swift
//  Saralin
//
//  Created by zhang on 4/29/17.
//  Copyright © 2017 zaczh. All rights reserved.
//


import UIKit
import UserNotifications
import StoreKit
import OSLog

func Theme() -> SATheme {
    return AppController.current.getService(of: SAThemeManager.self)!.activeTheme
}

extension AppController {
    static let onlineConfigUpdatedNotification: Notification.Name = Notification.Name(rawValue: "SAOnlineConfigUpdatedNotification")
}

enum ShortcutIdentifier: String {
    case first
    case second
    case third
    case fourth
    
    // MARK: - Initializers
    
    init?(fullType: String) {
        guard let last = fullType.components(separatedBy: ".").last else { return nil }
        self.init(rawValue: last)
    }
    
    // MARK: - Properties
    
    var type: String {
        return Bundle.main.bundleIdentifier! + ".\(self.rawValue)"
    }
}

class AppController: NSObject {

    // MARK: components, too too many..
    private lazy var coreDataManager = SACoreDataManager.init(accountManager: accountManager)
    private lazy var cookieManager = SACookieManager()
    private lazy var notificationManager = SANotificationManager()
    private lazy var backgroundTaskManager = SABackgroundTaskManager(coreDataManager: coreDataManager)
    private lazy var iapManager = SAIAPManager()
    private lazy var accountManager = SAAccountManager()
    private lazy var themeManager = SAThemeManager()
    private lazy var reachability = SAReachability()
    
    private let pasteboardMonitor = SAPasteboardMonitor()
    
    private var launchTime = Date()
    var upTime: TimeInterval {
        return -launchTime.timeIntervalSinceNow
    }
        
    var currentActiveWindow: UIWindow? {
        if #available(iOS 13.0, *) {
            for s in UIApplication.shared.connectedScenes {
                guard s.activationState == .foregroundActive || s.activationState == .foregroundInactive else {
                    continue
                }
                
                if let scene = s as? UIWindowScene, let firstWindow = scene.windows.first {
                    return firstWindow
                }
            }
            return nil
        } else {
            // Fallback on earlier versions
            return UIApplication.shared.keyWindow
        }
    }
    
    override init() {
        super.init()
        createDirectoriesIfNeeded()
        migrateLagacyFilesIfNeeded()
    }
    
    func findDeailNavigationController(rootViewController: UIViewController) -> UINavigationController? {
        guard let splitViewController = rootViewController as? UISplitViewController else {
            return nil
        }
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            let tab = splitViewController.viewController(for: .compact) as! UITabBarController
            let navigation = (tab.selectedViewController ?? tab.viewControllers?.first) as? UINavigationController
            return navigation
        }
        
        if let tab = splitViewController.viewControllers.first as? UITabBarController {
            if let navigation = (tab.selectedViewController ?? tab.viewControllers?.first) as? UINavigationController {
                return navigation
            }
            
            return nil
        }
        
        if splitViewController.viewControllers.count > 1,
            let rightSplit = splitViewController.viewControllers[1] as? UISplitViewController, rightSplit.viewControllers.count > 1,
            let rightDetail = rightSplit.viewControllers[1] as? UINavigationController {
            return rightDetail
        }
        
        return nil
    }
    
    @available(iOS 13.0, *)
    func findSceneSession(activityType: String? = nil) -> UISceneSession? {
        if let requestedType = activityType {
            for session in UIApplication.shared.openSessions {
                if let type = session.stateRestorationActivity?.activityType {
                    if type == requestedType {
                        os_log("findSceneSession reuse activity type: %@", log: .ui, type: .info, requestedType)
                        return session
                    }
                    continue
                } else {
                    return session
                }
            }
            return nil
        }
        
        os_log("findSceneSession return nil, will create new one.", log: .ui, type: .info)
        return nil
    }
    
    func instantiateInitialViewController(for activityType: SAActivityType) -> UIViewController? {
        if activityType == .settings {
            let split = UIStoryboard(name: "Settings", bundle: nil).instantiateInitialViewController()! as UISplitViewController
            return split
        }
        return nil
    }
    
    @available(iOS 13.0, *)
    func setupTabBarItemImagesForNewerSystemVersion(tabBarController: UITabBarController) {
        for vc in tabBarController.viewControllers ?? [] {
            let navi = vc as! UINavigationController
            if let hotVC = navi.viewControllers.first as? SAHotThreadsViewController {
                //hotVC.navigationController?.tabBarItem.title = NSLocalizedString("HOT_THREADS_VC_TITLE", comment: "Hot")
                hotVC.navigationController?.tabBarItem.image = UIImage(systemName: "flame.fill")
                hotVC.navigationController?.tabBarItem.selectedImage = UIImage(systemName: "flame.fill")
            } else if let forumVC = navi.viewControllers.first as? SAForumViewController {
                //forumVC.navigationController?.tabBarItem.title = NSLocalizedString("FORUM_VC_TITLE", comment: "Forum")
                forumVC.navigationController?.tabBarItem.image = UIImage(systemName: "house.fill")
                forumVC.navigationController?.tabBarItem.selectedImage = UIImage(systemName: "house.fill")
            } else if let favVC = navi.viewControllers.first as? SAFavouriteBoardsViewController {
                //favVC.navigationController?.tabBarItem.title = NSLocalizedString("FAVORITE_VC_TITLE", comment: "Favorites")
                favVC.navigationController?.tabBarItem.image = UIImage(systemName: "star.circle.fill")
                favVC.navigationController?.tabBarItem.selectedImage = UIImage(systemName: "star.circle.fill")
            } else if let accountVC = navi.viewControllers.first as? SAAccountCenterViewController {
                //accountVC.navigationController?.tabBarItem.title = NSLocalizedString("ACCOUNT_CENTER_VC_TITLE", comment: "Account")
                accountVC.navigationController?.tabBarItem.image = UIImage(systemName: "person.circle.fill")
                accountVC.navigationController?.tabBarItem.selectedImage = UIImage(systemName: "person.circle.fill")
            }
        }
    }
    
    // This is only a temporary solution. Component dependencies
    // should be explicitly specified in the initializers, which
    // have not been done yet.
    func getService<T>(of type: T.Type) -> T? {
        if type == SACookieManager.self {
            return cookieManager as? T
        } else if type == SANotificationManager.self {
            return notificationManager as? T
        } else if type == SABackgroundTaskManager.self {
            return backgroundTaskManager as? T
        } else if type == SAIAPManager.self {
            return iapManager as? T
        } else if type == SAAccountManager.self {
            return accountManager as? T
        } else if type == SACoreDataManager.self {
            return coreDataManager as? T
        } else if type == SAThemeManager.self {
            return themeManager as? T
        } else if type == SAReachability.self {
            return reachability as? T
        }
        
        return nil
    }
    
    @objc static let current = AppController()
    
    /// The temporary directory will be removed when app was terminated.
    let appTemporaryDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("Data", isDirectory: true)
    
    /// The persistent directory will keep alive until app was uninstalled.
    @objc let appPersistentDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("Data", isDirectory: true)

    // some top-level directories to store app data
    lazy var configDirectory : URL = { () in
        return appPersistentDirectory.appendingPathComponent("Config")
    } ()
    
    lazy var databaseDirectory : URL = { () in
        return appPersistentDirectory.appendingPathComponent("Database")
    } ()
    
    /// All account files are saved under this directory
    lazy var accountDirectory : URL = { () in
        return appPersistentDirectory.appendingPathComponent("Account")
    } ()

    lazy var emojiDirectory : URL = { () in
        return appPersistentDirectory.appendingPathComponent("Emoji")
    } ()
    
    lazy var threadHtmlFileDirectory : URL = { () in
        return appTemporaryDirectory.appendingPathComponent("threads_data", isDirectory: true)
    } ()
    
    lazy var appOnlineConfigFileURL : URL = { () in
        return configDirectory.appendingPathComponent("app_online_config.plist")
    } ()
    
    lazy var mahjongEmojiDirectory : URL = { () in
        return emojiDirectory.appendingPathComponent("Mahjong", isDirectory: true)
    } ()
    
    lazy var forumInfoConfigFileURL : URL = { () in
        return configDirectory.appendingPathComponent("forum_info.plist")
    } ()
    
    lazy var userGroupInfoConfigFileURL : URL = { () in
        return configDirectory.appendingPathComponent("user_group_info.plist")
    } ()
    
    lazy var coreDataDatebaseFileURL : URL = { () in
        return databaseDirectory.appendingPathComponent("SaralinCoreData.sqlite")
    } ()
    
    lazy var diagnosticsReportFilesDirectory : URL = { () in
        return appPersistentDirectory.appendingPathComponent("Diagnostics")
    } ()
    
    private func createDirectoriesIfNeeded() {
        let fm = FileManager.default
        for dir in [appTemporaryDirectory, appPersistentDirectory, threadHtmlFileDirectory, databaseDirectory, configDirectory, emojiDirectory, accountDirectory, diagnosticsReportFilesDirectory] {
            if !fm.fileExists(atPath: dir.path) {
                try! fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
                os_log("created directory at: %@", log: .ui, type: .info, dir.path)
            }
        }
        
        if !fm.fileExists(atPath: mahjongEmojiDirectory.path) {
            let bundleURL = Bundle.main.url(forResource: "Mahjong", withExtension: nil)!
            try? fm.copyItem(at: bundleURL, to: mahjongEmojiDirectory)
            os_log("created dir at: %@", log: .ui, type: .info, mahjongEmojiDirectory.path)
        }
        
        for file in [appOnlineConfigFileURL, forumInfoConfigFileURL, userGroupInfoConfigFileURL] {
            if fm.fileExists(atPath: file.path) {
                continue
            }
            let lastComponent = file.lastPathComponent as NSString
            let fileName = lastComponent.deletingPathExtension
            let fileExtension = lastComponent.pathExtension
            let bundleURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)!
            try? fm.copyItem(at: bundleURL, to: file)
            os_log("created file at: %@", log: .ui, type: .info, file.path)
        }
        
        os_log("appPersistentDirectory is: %@", log: .ui, type: .info, appPersistentDirectory.path)
    }
    
    private func migrateLagacyFilesIfNeeded() {
        let fm = FileManager.default
        if let lastMigratedVersion = UserDefaults.standard.string(forKey: SAUserDefaultsKey.appVersionOfLastLagacyFileMigration.rawValue) {
            os_log("No need to do migration this version, last version: %@", log: .config, type: .info, lastMigratedVersion)
            return
        }
        
        let localVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        UserDefaults.standard.set(localVersion, forKey: SAUserDefaultsKey.appVersionOfLastLagacyFileMigration.rawValue)
        
        // load lagacy files of older app versions
        os_log("begin migrating lagacy files.", log: .ui, type: .info)
        // Account
        repeat  {
            let existed = NSHomeDirectory() + "/Documents/account_v2"
            if fm.fileExists(atPath: existed) {
                do {
                    try fm.removeItem(at: accountDirectory)
                    try fm.moveItem(atPath: existed, toPath: accountDirectory.path)
                } catch {
                    os_log("failed to move file to: %@", log: .ui, type: .error, accountDirectory.path)
                }
                os_log("finished migrating files at %@", log: .ui, type: .info, existed)
            }
        } while false
        
        // CoreData
        repeat  {
            let files = [NSHomeDirectory() + "/Documents/SaralinCoreData.sqlite",
                         NSHomeDirectory() + "/Documents/SaralinCoreData.sqlite-shm",
                         NSHomeDirectory() + "/Documents/SaralinCoreData.sqlite-wal"]
            for existed in files {
                if fm.fileExists(atPath: existed) {
                    let newPlace = databaseDirectory.appendingPathComponent((existed as NSString).lastPathComponent)
                    do {
                        try  fm.moveItem(atPath: existed, toPath: newPlace.path)
                    } catch {
                        os_log("failed to move file at: %@", log: .ui, type: .error, newPlace.path)
                    }
                    os_log("finished migrating files at %@", log: .ui, type: .info, existed)
                }
            }
        } while false
        os_log("finished migrating lagacy files.", log: .ui, type: .info)
    }
    
    private func removeTemporaryDirectories() {
        let fm = FileManager.default
        if fm.fileExists(atPath: appTemporaryDirectory.path) {
            try! fm.removeItem(atPath: appTemporaryDirectory.path)
            os_log("removed directory at: %@", log: .ui, type: .info, appTemporaryDirectory.path)
        }
    }
    
    func registerForPushNotifications() {
        #if !(arch(i386) || arch(x86_64))
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.getNotificationSettings(completionHandler: { (settings) in
                if settings.authorizationStatus == .notDetermined {
                    notificationCenter.requestAuthorization(options: [.badge, .sound, .alert], completionHandler: { (result, error) in
                        os_log("requestAuthorization: %@", log: .ui, type: .info, result ? "true" : "false")
                    })
                }
                else if settings.authorizationStatus == .denied {
                    os_log("requestAuthorization denied", log: .ui, type: .info)
                }
                else if settings.authorizationStatus == .authorized {
                    os_log("requestAuthorization authorized", log: .ui, type: .info)
                }
            })
        #endif
    }
    
    func registerThemeAndFontNotifications() {
        let viewThemeDidChange = { () in
            if #available(iOS 13.0, *) {
                for scene in UIApplication.shared.connectedScenes {
                    guard let windowScene = scene as? UIWindowScene else {
                        continue
                    }
                    
                    for window in windowScene.windows {
                        guard let rootVC = window.rootViewController else {
                            return
                        }
                        
                        let theme = Theme()
                        rootVC.needsUpdateTheme = true
                        rootVC.viewThemeDidChange(theme)
                    }
                }
            } else {
                // Fallback on earlier versions
                guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else {
                    return
                }
                
                let theme = Theme()
                rootVC.needsUpdateTheme = true
                rootVC.viewThemeDidChange(theme)
            }
        }
        
        let viewFontDidChange = { () in
            if #available(iOS 13.0, *) {
                for scene in UIApplication.shared.connectedScenes {
                    guard let windowScene = scene as? UIWindowScene else {
                        continue
                    }
                    
                    for window in windowScene.windows {
                        guard let rootVC = window.rootViewController else {
                            return
                        }
                        
                        let theme = Theme()
                        rootVC.needsUpdateFont = true
                        rootVC.viewFontDidChange(theme)
                    }
                }
            } else {
                // Fallback on earlier versions
                guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else {
                    return
                }
                
                let theme = Theme()
                rootVC.needsUpdateFont = true
                rootVC.viewFontDidChange(theme)
            }
        }
        
        let nc = NotificationCenter.default
        nc.addObserver(forName: Notification.Name.SAUserPreferenceChangedNotification, object: nil, queue: nil) { (notification) in
            let userInfo = notification.userInfo
            guard let key = userInfo?[SAAccount.Preference.changedPreferenceNameKey] as? SAAccount.Preference else {
                return
            }
            
            if key == .theme_id || key == .automatically_change_theme_to_match_system_appearance  {
                viewThemeDidChange()
            } else if key == .bodyFontSizeOffset || key == .uses_system_dynamic_type_font {
                viewFontDidChange()
            }
        }
        
        nc.addObserver(forName: Notification.Name.SAUserLoggedInNotification, object: nil, queue: nil) { (notification) in
            viewThemeDidChange()
        }
        
        nc.addObserver(forName: Notification.Name.SAUserLoggedOutNotification, object: nil, queue: nil) { (notification) in
            viewThemeDidChange()
        }
        
        nc.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: nil) { (notification) in
            viewFontDidChange()
        }
    }
    
    private var isUpdatingOnlineConfigFiles = false
    func updateOnlineConfigFiles() {
        if isUpdatingOnlineConfigFiles {
            os_log("already downloading online config files", log: .config, type: .info)
            return
        }
        
        let fm = FileManager.default
        os_log("downloading online config files", log: .config, type: .info)
        let url = URL(string: SAGlobalConfig().online_config_file_url)!
        URLSession.saCustomized.dataTask(with: url) { (data, response, error) in
            defer {
                self.isUpdatingOnlineConfigFiles = false
            }
            guard let data = data else {
                os_log("online config fail to download", log: .network, type: .fault)
                return
            }
            
            guard let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String:AnyObject] else {
                os_log("online config bad format.", log: .network, type: .fault)
                return
            }
            
            if !fm.fileExists(atPath: self.appOnlineConfigFileURL.path)  {
                fm.createFile(atPath: self.appOnlineConfigFileURL.path, contents: data, attributes: nil)
                os_log("online config first time downloaded", log: .config, type: .info)
                return
            }
            
            guard let localData = try? Data.init(contentsOf: self.appOnlineConfigFileURL),
                let localDict = try? PropertyListSerialization.propertyList(from: localData, options: [], format: nil) as? [String:AnyObject],
                let onlineVersion = dict["ConfigVersion"] as? String,
                let minimumOnlineCompatibleAppVersion = dict["MinimumCompatibleAppVersion"] as? String,
                let maximumOnlineCompatibleAppVersion = dict["MaximumCompatibleAppVersion"] as? String,
                let localVersion = localDict["ConfigVersion"] as? String else {
                    os_log("config error", log: .config, type: .info)
                    return
            }
            
            if self.compare(version1: onlineVersion, version2: localVersion) == .orderedSame {
                os_log("online config same version: %@", log: .config, type: .info, onlineVersion)
                return
            }
            
            let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
            if self.compare(version1: bundleVersion, version2: minimumOnlineCompatibleAppVersion) == .orderedAscending {
                os_log("online config not compatible to this version of app, online config minimum compatible version: %@, app version: %@", log: .config, type: .info, minimumOnlineCompatibleAppVersion, bundleVersion)
                return
            }
            
            if self.compare(version1: bundleVersion, version2: maximumOnlineCompatibleAppVersion) == .orderedDescending {
                os_log("online config not compatible to this version of app, online config maximum compatible version: %@, app version: %@", log: .config, type: .info, maximumOnlineCompatibleAppVersion, bundleVersion)
                return
            }
            
            os_log("online config updated to version: %@", log: .config, type: .info, onlineVersion)
            try? data.write(to: self.appOnlineConfigFileURL)
            
            self.handleOnlineConfigFileNewVersion()
        }.resume()
        return
    }
    
    private func handleOnlineConfigFileNewVersion() {
        let group = DispatchGroup()
        downloadNewMahjongConfigFiles(with: group)
        downloadNewUserGroupInfoConfigFiles(with: group)
        downloadNewForumInfoConfigFiles(with: group)
        group.notify(queue: .main) {
            NotificationCenter.default.post(name: AppController.onlineConfigUpdatedNotification, object: nil, userInfo: nil)
        }
    }
    
    private func downloadNewForumInfoConfigFiles(with group: DispatchGroup) {
        guard let configData = try? Data.init(contentsOf: self.appOnlineConfigFileURL),
            let config = try? PropertyListSerialization.propertyList(from: configData, options: [], format: nil) as? [String:AnyObject] else {
                return
        }
        
        guard let configItems = config["ConfigItems"] as? [String:AnyObject],
            let subConfig = configItems["ForumInfo"] as? [String:AnyObject],
            let subConfigVersion = subConfig["Version"] as? String,
            let subConfigDownloadUrl = subConfig["DownloadUrl"] as? String,
            let downloadUrl = URL.init(string: subConfigDownloadUrl) else {
                os_log("no config url or url not recognized", log: .config, type: .error)
                return
        }
        
        guard let localData = try? Data.init(contentsOf: self.forumInfoConfigFileURL),
            let localDict = try? PropertyListSerialization.propertyList(from: localData, options: [], format: nil) as? [String:AnyObject],
            let localVersion = localDict["version"] as? String else {
                os_log("no config url or url not recognized", log: .config, type: .error)
                return
        }
        
        if self.compare(version1: localVersion, version2: subConfigVersion) != .orderedAscending {
            os_log("config same version: ForumInfo", log: .config, type: .error)
            return
        }
        
        group.enter()
        URLSession.saCustomized.dataTask(with: downloadUrl) { (data, response, error) in
            defer {
                group.leave()
            }
            guard let data = data else {
                os_log("no data", log: .config, type: .fault)
                return
            }
            
            do {
                try data.write(to: self.forumInfoConfigFileURL)
            } catch {
                os_log("write to file failed error: %@", log: .config, type: .fault, error.localizedDescription as CVarArg)
            }
            os_log("downloadNewForumInfoConfigFiles finished", log: .config, type: .info)
        }.resume()
    }
    
    private func downloadNewUserGroupInfoConfigFiles(with group: DispatchGroup) {
        guard let configData = try? Data.init(contentsOf: self.appOnlineConfigFileURL),
            let config = try? PropertyListSerialization.propertyList(from: configData, options: [], format: nil) as? [String:AnyObject] else {
                return
        }
        
        guard let configItems = config["ConfigItems"] as? [String:AnyObject],
            let subConfig = configItems["UserGroupInfo"] as? [String:AnyObject],
            let subConfigVersion = subConfig["Version"] as? String,
            let subConfigDownloadUrl = subConfig["DownloadUrl"] as? String,
            let downloadUrl = URL.init(string: subConfigDownloadUrl) else {
                os_log("no config url or url not recognized", log: .config, type: .error)
                return
        }
        
        guard let localData = try? Data.init(contentsOf: self.userGroupInfoConfigFileURL),
            let localDict = try? PropertyListSerialization.propertyList(from: localData, options: [], format: nil) as? [String:AnyObject],
            let localVersion = localDict["version"] as? String else {
                os_log("no config url or url not recognized", log: .config, type: .error)
                return
        }
        
        if self.compare(version1: localVersion, version2: subConfigVersion) != .orderedAscending {
            os_log("config same version: UserGroupInfo", log: .config, type: .error)
            return
        }
        
        group.enter()
        URLSession.saCustomized.dataTask(with: downloadUrl) { (data, response, error) in
            defer {
                group.leave()
            }
            guard let data = data else {
                os_log("no data", log: .config, type: .fault)
                return
            }
            
            do {
                try data.write(to: self.userGroupInfoConfigFileURL)
            } catch {
                os_log("write to file failed error: %@", log: .config, type: .fault, error.localizedDescription as CVarArg)
            }
            os_log("downloadNewUserGroupInfoConfigFiles finished", log: .config, type: .info)
        }.resume()
    }
    
    private func downloadNewMahjongConfigFiles(with group: DispatchGroup) {
        guard let configData = try? Data.init(contentsOf: self.appOnlineConfigFileURL),
            let config = try? PropertyListSerialization.propertyList(from: configData, options: [], format: nil) as? [String:AnyObject] else {
            return
        }
        
        guard let configItems = config["ConfigItems"] as? [String:AnyObject] else {
            return
        }
        
        guard let mahjongConfig = configItems["MahjongEmoji"] as? [String:AnyObject],
            let mahjongEmojiVersion = mahjongConfig["Version"] as? String,
            let mahjongEmojiDownloadUrl = mahjongConfig["DownloadUrl"] as? String else {
            return
        }
        
        let mahjongPlistFileURL = mahjongEmojiDirectory.appendingPathComponent("emoji.plist")
        guard let localData = try? Data.init(contentsOf: mahjongPlistFileURL),
            let localDict = try? PropertyListSerialization.propertyList(from: localData, options: [], format: nil) as? [String:AnyObject],
            let localVersion = localDict["version"] as? String else {
                os_log("no config url or url not recognized", log: .config, type: .error)
                return
        }
        
        if self.compare(version1: localVersion, version2: mahjongEmojiVersion) != .orderedAscending {
            os_log("config same version: MahjongEmoji", log: .config, type: .error)
            return
        }
        
        guard let url = URL(string: mahjongEmojiDownloadUrl) else {
            os_log("bad url", log: .config, type: .fault)
            return
        }
        
        group.enter()
        URLSession.saCustomized.downloadTask(with: url) { (url, response, error) in
            defer {
                group.leave()
            }
            
            guard error == nil else {
                os_log("download config error: %@", log: .config, type: .fault, error!.localizedDescription)
                return
            }
            
            guard let tempFileURL = url else {
                os_log("url is nil", log: .config, type: .fault)
                return
            }
            
            let targetPath = self.emojiDirectory
            do {
                try SSZipArchive.unzipFile(atPath: tempFileURL.path, toDestination: targetPath.path, overwrite: true, password: nil)
            } catch {
                os_log("decompress failed. error: %@", log: .config, type: .fault, error.localizedDescription)
                return
            }
            
            os_log("decompress finished", log: .config, type: .info)
        }.resume()
    }
    
    private(set) var currentDeviceIdentifier: String!
    private func updateKeychainDeviceIdentifierIfNeeded() {
        if currentDeviceIdentifier != nil {
            return
        }
        
        // keychain fetching must be made when app is active
        if UIApplication.shared.applicationState != .active {
            os_log("app no active, delay request.", log: .keychain, type: .info)
            var ob: NSObjectProtocol?
            ob = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] (_) in
                NotificationCenter.default.removeObserver(ob!, name: UIApplication.didBecomeActiveNotification, object: nil)
                self?.updateKeychainDeviceIdentifierIfNeeded()
            }
            return
        }
        
        // Is device id set?
        if let identifier = SAKeyChainService.getIdentifier() {
            os_log("found existed device identifier: %@", log: .keychain, type: .info, identifier)
            currentDeviceIdentifier = identifier
            return
        }
        
        let uuid = CFUUIDCreateString(nil, CFUUIDCreate(nil)) as String
        if !SAKeyChainService.saveIdentifier(uuid) {
            os_log("save keychain failed", log: .keychain, type: .error)
        }
        currentDeviceIdentifier = uuid
        os_log("create new device id: %@", log: .keychain, type: .info, uuid)
    }
    
    // call this method after user logged in
    func updateAccountInfo() {
        let account = Account()
        if !account.uid.isEmpty {
            os_log("update notification account: %@", log: .account, type: .info, "\(account.uid)")
        }
    }
    
    func promptForAppStoreReview() {
        if #available(iOS 10.3, *) {
            // frequency control
            let key = SAUserDefaultsKey.lastDateRequestedReviewInAppStore.rawValue
            let lastRequestedTime = UserDefaults.standard.object(forKey: key) as? Date
            if lastRequestedTime != nil {
                return
            }
            
            guard let scene = findSceneSession()?.scene as? UIWindowScene else {
                return
            }
            
            // request for review after playing for 10 miniutes
            if upTime > 10 * 60 {
                UserDefaults.standard.set(Date(), forKey: key)
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
    
    func presentLoginAlert(sender: UIViewController?, completion: (() -> Void)?) {
        let alert = UIAlertController(title: NSLocalizedString("HINT", comment: "Hint"), message: NSLocalizedString("TAB_ITEM_NEED_LOGIN", comment: "You need to be logged in to see this."), preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel) { (action) in
            completion?()
        }
        alert.addAction(cancelAction)
        
        let threadAction = UIAlertAction(title: NSLocalizedString("LOGIN_NOW", comment: "Login now"), style: .default) { (action) in
            self.presentLoginViewController(sender: nil, completion: completion)
        }
        alert.addAction(threadAction)
        currentActiveWindow?.rootViewController?.present(alert, animated: true, completion: nil)
    }
    
    func presentLoginViewController(sender: UIViewController?, completion: (() -> Void)?) {
        if UIApplication.shared.supportsMultipleScenes {
            let userActivity = NSUserActivity(activityType: SAActivityType.login.rawValue)
            userActivity.isEligibleForHandoff = true
            userActivity.title = SAActivityType.login.title()
            let options = UIScene.ActivationRequestOptions()
            options.requestingScene = self.currentActiveWindow?.windowScene
            UIApplication.shared.requestSceneSessionActivation(AppController.current.findSceneSession(), userActivity: userActivity, options: options) { (error) in
                os_log("request new scene returned: %@", error.localizedDescription)
            }
        } else {
            let loginContentViewer = UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController() as! SALoginViewController
            let loginVC = SANavigationController(rootViewController: loginContentViewer)
            loginVC.modalPresentationStyle = .formSheet
            sender?.present(loginVC, animated: true, completion: completion)
        }
    }
    
    private func setupAppAfterEulaAgreed(isNewInstall: Bool) {
        backgroundTaskManager.start()
    }
    
    private func presentEULAIfNeeded() {
        if let _ = UserDefaults.standard.value(forKey: SAUserDefaultsKey.lastDateEulaBeenAgreed.rawValue) {
            DispatchQueue.main.async {
                self.setupAppAfterEulaAgreed(isNewInstall: false)
            }
            return
        }
        
        DispatchQueue.main.async {
            let eula = SAPlainTextViewController()
            eula.title = NSLocalizedString("EULA", comment: "用户协议")
            if #available(iOS 13.0, *) {
                eula.isModalInPresentation = true
            } else {
                // Fallback on earlier versions
            }
            let eulaURL = Bundle.main.url(forResource: "eula", withExtension: "txt")!
            let text = try! String.init(contentsOf: eulaURL)
            eula.text = text
            #if targetEnvironment(macCatalyst)
            let rightItem = UIBarButtonItem(title: NSLocalizedString("AGREE", comment: "Agree"), style: .plain, target: self, action: #selector(self.handleEULAViewControllerCloseButtonClick(_:)))
            eula.toolbarItems = [rightItem]
            #else
            let rightItem = UIBarButtonItem(title: NSLocalizedString("AGREE", comment: "Agree"), style: .plain, target: self, action: #selector(self.handleEULAViewControllerCloseButtonClick(_:)))
            eula.navigationItem.rightBarButtonItem = rightItem
            #endif
            
            let navigation = SANavigationController.init(rootViewController: eula)
            #if targetEnvironment(macCatalyst)
            navigation.setToolbarHidden(false, animated: false)
            #endif
            self.currentActiveWindow?.rootViewController?.present(navigation, animated: true, completion: nil)
        }
    }
    
    @objc func handleEULAViewControllerCloseButtonClick(_ sender: UIBarButtonItem) {
        currentActiveWindow?.rootViewController?.dismiss(animated: true, completion: nil)
        DispatchQueue.main.async {
            UserDefaults.standard.set(Date(), forKey: SAUserDefaultsKey.lastDateEulaBeenAgreed.rawValue)
            self.setupAppAfterEulaAgreed(isNewInstall: true)
        }
    }
        
    // handles url within app
    func open(url: URL, sender: UIViewController?) -> Bool {
        guard let scheme = url.scheme, let host = url.host else {return false}
        
        if scheme == "salink" && host == "open" {
            if let target = url.sa_queryString("target") {
                if target == "bindsms" {
                    bindSMSNumber(sender: sender ?? currentActiveWindow?.rootViewController)
                }
            }
            return true
        }
        
        return false
    }
    
    func bindSMSNumber(sender: UIViewController?) {
        let config = SAGlobalConfig()
        guard let aurl = URL(string: "home.php?mod=spacecp&ac=phone&mobile=2", relativeTo: URL(string: config.forum_base_url)!) else {
            fatalError()
        }
        let sms = SAContentViewController.init(url: aurl)
        sender?.navigationController?.pushViewController(sms, animated: true)
    }
        
    func handleShortCutItem(_ shortcutItem: UIApplicationShortcutItem, window: UIWindow?) -> Bool {
        var handled = false
        
        // Verify that the provided `shortcutItem`'s `type` is one handled by the application.
        guard ShortcutIdentifier(fullType: shortcutItem.type) != nil else { return false }
        
        guard let shortCutType = shortcutItem.type as String? else { return false }
        
        guard let rootViewController = window?.rootViewController else { return false }
        
        switch shortCutType {
        case ShortcutIdentifier.first.type:
            // Handle shortcut 1 (static).
            handled = true
            if let navi = findDeailNavigationController(rootViewController: rootViewController) {
                let board = SAHotThreadsViewController(url: URL(string: SAGlobalConfig().forum_base_url + "forum.php?mod=forumdisplay&fid=0&mobile=1")!)
                navi.show(board, sender: nil)
            }
            break
        default:
            break
        }
        
        return handled
    }
    
    private var pendingGetImageCompletion: ((UIImage?, NSError?) -> Void)?
    func getImageFromPhotoLibrary(sender: UIViewController, completion: ((UIImage?, NSError?) -> Void)?) {
        let noPermissionBlock: (() -> Void) = {
            let alert = UIAlertController(title: "提示", message: "无法选择照片", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            sender.present(alert, animated: true) {
                let error = NSError(domain: "", code: -1, userInfo: nil)
                completion?(nil, error)
            }
            return
        }
        
        #if targetEnvironment(macCatalyst)
        let sheet = UIAlertController(title: "上传本地图片", message: "选择照片源", preferredStyle: .alert)
        #else
        let sheet = UIAlertController(title: "上传本地图片", message: "选择照片源", preferredStyle: .actionSheet)
        #endif
        sheet.popoverPresentationController?.sourceView = sender.view
        sheet.popoverPresentationController?.sourceRect = sender.view.bounds

        sheet.addAction(UIAlertAction(title: "系统相册", style: .default) { (action) in
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let types = UIImagePickerController.availableMediaTypes(for: .photoLibrary)
                guard types != nil else {
                    noPermissionBlock()
                    return
                }
                
                let imagePicker = UIImagePickerController()
                imagePicker.delegate = self
                imagePicker.sourceType = .photoLibrary
                imagePicker.mediaTypes = types!
                sender.present(imagePicker, animated: true, completion: nil)
                self.pendingGetImageCompletion = completion
            } else {
                noPermissionBlock()
            }
        })
        
        sheet.addAction(UIAlertAction(title: "拍摄", style: .default) { (action) in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let types = UIImagePickerController.availableMediaTypes(for: .camera)
                guard types != nil else {
                    noPermissionBlock()
                    return
                }
                
                let imagePicker = UIImagePickerController()
                imagePicker.delegate = self
                imagePicker.sourceType = .camera
                imagePicker.mediaTypes = types!
                sender.present(imagePicker, animated: true, completion: nil)
                self.pendingGetImageCompletion = completion
            }
        })
        
        sheet.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))
        sender.present(sheet, animated: true, completion: nil)
        pendingGetImageCompletion = completion
    }
    
    // MARK: - ViewController Vendor
    func createMyThreadsPage() -> SAUserThreadViewController<MyThreadModel> {
        let myThreads = SAUserThreadViewController<MyThreadModel>()
        myThreads.title = NSLocalizedString("MY_THREADS_VC_TITLE", comment: "my threads vc title")

        myThreads.dataFiller = { (model, cell, indexPath) in
            guard let json = model.json else {return}
            
            if let title = json["subject"] as? String {
                let threadTitle = title.sa_stringByReplacingHTMLTags() as String
                let attributedTitle = NSMutableAttributedString(string: threadTitle, attributes:[NSAttributedString.Key.font: UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline),NSAttributedString.Key.foregroundColor: UIColor.sa_colorFromHexString(Theme().tableCellTextColor)])
                cell.customTitleLabel.attributedText = attributedTitle
            } else {
                cell.customTitleLabel.attributedText = nil
            }
            
            if let reply = json["replies"] as? String {
                cell.customReplyLabel.text = NSLocalizedString("REPLY", comment: "reply wording") + " " + reply
            }
            
            if let intervalString = json["dbdateline"] as? String, let interval = Int(intervalString) {
                let date = Date(timeIntervalSince1970: TimeInterval(interval))
                cell.customTimeLabel.text = "发表于" + date.sa_prettyDate()
            }
        }
        
        myThreads.dataInteractor = { (vc, model, indexPath) in
            guard let tid = model.json?["tid"] as? String else {return}
            let link = SAGlobalConfig().forum_base_url + "forum.php?mod=viewthread&tid=\(tid)&page=1&mobile=1&simpletype=no"
            let url = URL(string: link)!
            let contentViewer = SAThreadContentViewController(url: url)
            vc.navigationController?.pushViewController(contentViewer, animated: true)
        }
        
        myThreads.themeUpdator = { (vc) in
            let textColor = UIColor.sa_colorFromHexString(Theme().textColor)
            let placeholder = NSMutableAttributedString()
            placeholder.append(NSAttributedString(string: "无数据\n\n", attributes: [NSAttributedString.Key.font:UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline), NSAttributedString.Key.foregroundColor:textColor]))
            placeholder.append(NSAttributedString(string: "你尚未在论坛发表过帖子", attributes: [NSAttributedString.Key.font:UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.subheadline), NSAttributedString.Key.foregroundColor:textColor]))
            vc.loadingController.emptyLabelAttributedTitle = placeholder
        }
        
        getThreads { (models, error) in
            guard let _ = models, error == nil else {return}
            
            myThreads.fetchedData = models!
        }
        return myThreads
    }
        
    private func getThreads(_ completion: (([MyThreadModel]?, NSError?) -> Void)?) {
        guard !Account().isGuest else {
            let error = NSError.init(domain: "Network.getComposedThreads", code: -1, userInfo: ["msg":"No account has logged in"])
            completion?(nil, error)
            return
        }
        
        URLSession.saCustomized.getComposedThreads(page: 1) { (result, error) in
            guard error == nil, result != nil,
                let resultDict = result as? [String:AnyObject],
                let variables = resultDict["Variables"] as? [String:AnyObject] else {
                    let error = NSError.init(domain: "Network.getComposedThreads", code: -1, userInfo: ["msg":"variables nil"])
                    completion?(nil, error)
                    return
            }
            
            if let _ = variables["data"] as? NSNull {
                let error = NSError.init(domain: "Network.getComposedThreads", code: -1, userInfo: ["msg":"data empty"])
                completion?(nil, error)
                return
            }
            
            guard let list = variables["data"] as? [[String:AnyObject]] else {
                let error = NSError.init(domain: "Network.getComposedThreads", code: -1, userInfo: ["msg":"list empty"])
                completion?(nil, error)
                return
            }
            
            var models: [MyThreadModel] = []
            for l in list {
                let model = MyThreadModel.init(json: l)
                models.append(model)
            }
            
            completion?(models, nil)
        }
    }
    
    
    // MARK: - Application State
    
    func applicationDidFinishLaunching() {
        presentEULAIfNeeded()
        registerThemeAndFontNotifications()
        updateKeychainDeviceIdentifierIfNeeded()
    }
    
    func applicationWillTerminate() {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        os_log("applicationWillTerminate uptime: %@", log: .ui, type: .info, "\(upTime)")
        removeTemporaryDirectories()
    }
    
    func applicationDidReceiveRemoteNotification(userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        os_log("didReceive notification: %@", log: .ui, type: .info, "\(userInfo)")
        notificationManager.handle(notification: userInfo, fetchCompletionHandler: completionHandler)
    }
    
    func applicationDidFailToRegisterForRemoteNotificationsWithError(error: Error) {
        // The token is not currently available.
        os_log("Remote notification support is unavailable due to error: %@", type: .error, error.localizedDescription)
    }
    
    func applicationPerformFetchWithCompletionHandler(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        os_log("perform background fetch", log: .ui, type: .info)
        backgroundTaskManager.startBackgroundTask(with: completionHandler)
    }
    
    func applicationOpen(url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        os_log("open url: %@", log: .ui, type: .info, url as CVarArg)
        return open(url: url, sender: currentActiveWindow?.rootViewController)
    }
    
    func applicationDidReceiveMemoryWarning() {
        os_log("applicationDidReceiveMemoryWarning", log: .ui, type: .info)
    }
    
    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        os_log("applicationWillResignActive uptime: %@", log: .ui, type: .info, "\(upTime)")
    }
    
    func applicationDidEnterBackground() {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        os_log("applicationDidEnterBackground uptime: %@", log: .ui, type: .info, "\(upTime)")
        
        // save core data
        coreDataManager.saveContext(completion: nil)
        
        // clear cache
        backgroundTaskManager.clearDiskCacheIfNeeded()
        backgroundTaskManager.stop()
        backgroundTaskManager.removeLogFilesIfNeeded()
    }
    
    func applicationWillEnterForeground() {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        os_log("applicationWillEnterForeground uptime: %@", log: .ui, type: .info, "\(upTime)")
        
        cookieManager.renewCookiesIfNeeded()
        backgroundTaskManager.start()
    }
    
    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        os_log("applicationDidBecomeActive uptime: %@", log: .ui, type: .info, "\(upTime)")
        updateOnlineConfigFiles()
    }
    
    func applicationShouldSaveApplicationState(coder: NSCoder) -> Bool {
        return true
    }
    
    private func compare(version1: String, version2: String) -> ComparisonResult {
        let components1 = version1.components(separatedBy: ".")
        let components2 = version2.components(separatedBy: ".")
        if components1.count == 0 {
            return .orderedDescending
        } else if components2.count == 0 {
            return .orderedAscending
        }
        
        let numberOfComponents = min(components1.count, components2.count)
        for i in 0 ..< numberOfComponents {
            let one = components1[i]
            let two = components2[i]
            // assum all component are numbers
            let oneInt = Int(one)!
            let twoInt = Int(two)!
            if oneInt > twoInt {
                return .orderedDescending
            } else if oneInt < twoInt {
                return .orderedAscending
            }
        }
        
        if components1.count > numberOfComponents {
            return .orderedDescending
        } else if components2.count > numberOfComponents {
            return .orderedAscending
        }
        
        return .orderedSame
    }
    
    func applicationShouldRestoreApplicationState(coder: NSCoder) -> Bool {
        let savedVersion = coder.decodeObject(forKey: UIApplication.stateRestorationBundleVersionKey) as! String
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        if compare(version1: savedVersion, version2: currentVersion) == .orderedSame {
            return true
        }
        
        return false
    }
    
    func applicationViewControllerWithRestorationIdentifierPath(identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        guard let identifier = identifierComponents.last else { return nil }
        
        var vc: UIViewController?
        if identifier == SAViewControllerRestorationIdentifier.threadContent.rawValue {
            let thread = SAThreadContentViewController.init(coder: coder)
            thread?.isRestoredFromArchive = true
            thread?.restorationIdentifier = identifier
            vc = thread
        } else if identifier == SAViewControllerRestorationIdentifier.setting.rawValue {
            let setting = SASettingViewController.init(coder: coder)
            setting?.isRestoredFromArchive = true
            setting?.restorationIdentifier = identifier
            vc = setting
        } else if identifier == SAViewControllerRestorationIdentifier.fontConfigure.rawValue {
            let font = SAFontConfigureViewController.init(coder: coder)
            font?.isRestoredFromArchive = true
            font?.restorationIdentifier = identifier
            vc = font
        } else if identifier == SAViewControllerRestorationIdentifier.board.rawValue {
            let font = SABoardViewController.init(coder: coder)
            font?.isRestoredFromArchive = true
            font?.restorationIdentifier = identifier
            vc = font
        } else {
            os_log("unhandled restoration identifier: %@", identifier)
        }
        return vc
    }
}

// view controllers which has no storyboard or storyboard not set restorationIdentifier
enum SAViewControllerRestorationIdentifier: String {
    case threadContent = "thread_content_vc"
    case setting = "setting_vc"
    case fontConfigure = "font_configure_vc"
    case board = "board_vc"
    case hotThreads = "hot_threads_vc"
}

extension AppController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) {
            if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
                self.pendingGetImageCompletion?(image, nil)
            } else {
                let error = NSError(domain: "", code: -1, userInfo: nil)
                self.pendingGetImageCompletion?(nil, error)
            }
            self.pendingGetImageCompletion = nil
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
