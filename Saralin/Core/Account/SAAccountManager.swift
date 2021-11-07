//
//  SAAccountManager.swift
//  Saralin
//
//  Created by zhang on 1/17/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import Foundation
import WebKit;

/// There is only one active account at the same time, so
/// here I save it to a fixed name file
private let s_activeAccountPath = AppController.current.accountDirectory.path + "/active"

/// Accounts which have ever been logged in saved to this directory
private let s_accountHistoryDirectory = AppController.current.accountDirectory.path + "/history"

func Account() -> SAAccount {
    var account = AppController.current.getService(of: SAAccountManager.self)!.activeAccount
    if account == nil {
        account = SAAccountManager.guestAccount
    }
    return account!
}

extension Notification.Name {
    static let SAAccountManagerAccountStateChangedNotification = Notification.Name(rawValue: "SAAccountManagerAccountStateChangedNotification")
    static let SAUserLoggedInNotification = Notification.Name(rawValue: "SAUserLoggedInNotificatoin")
    static let SAUserLoggedOutNotification = Notification.Name(rawValue: "Notification.Name.SAUserLoggedOutNotification")
    static let SAUserPreferenceChangedNotification = Notification.Name(rawValue: "Notification.Name.SAUserPreferenceChangedNotification")
}

extension AnyHashable {
    static let SAAccountStateChangedNotificationValueKey = "value"
}

class SAAccountManager {
    
    enum AccountState {
        
        /// no previous active account found or logged out
        case notLoggedIn
        
        /// last active account found but not validated yet
        case notValidated
        
        case loggedIn
        
        case validatingFailed
    }
    
    
    var activeAccount: SAAccount?
    private(set) var accountState: AccountState = .notLoggedIn {
        didSet {
            let notification = Notification.init(name: .SAAccountManagerAccountStateChangedNotification, object: self, userInfo: [.SAAccountStateChangedNotificationValueKey:accountState])
            NotificationCenter.default.post(notification)
        }
    }
    
    class func accountFileSavePathOf(uid: String) -> String {
        let path = s_accountHistoryDirectory + "/" + uid
        return path
    }
    
    class func accountOf(uid: String) -> SAAccount {
        var account: SAAccount!
        let path = accountFileSavePathOf(uid: uid)
        if FileManager.default.fileExists(atPath: path) {
            let fileUrl = URL(fileURLWithPath: path)
            let fileData = try! Data(contentsOf: fileUrl)
            do {
                guard let savedAccount = try NSKeyedUnarchiver.unarchivedObject(ofClasses: SAAccount.archiveClasses, from: fileData) as? SAAccount else {
                    fatalError("failed to restore account info")
                }
                account = savedAccount
            } catch {
                fatalError("unarchivedObject failed: \(error.localizedDescription)")
            }
        } else {
            account = SAAccount()
        }
        
        account.uid = uid
        return account
    }
    
    static var guestAccount: SAAccount {
        let account: SAAccount?
        let fm = FileManager.default
        let path = accountFileSavePathOf(uid: "0")
        if fm.fileExists(atPath: path) {
            let fileUrl = URL(fileURLWithPath: path)
            let fileData = try! Data(contentsOf: fileUrl)
            do {
                guard let savedAccount = try NSKeyedUnarchiver.unarchivedObject(ofClasses: SAAccount.archiveClasses, from: fileData) as? SAAccount else {
                    fatalError("failed to restore account info")
                }
                account = savedAccount
            } catch {
                fatalError("unarchivedObject failed: \(error.localizedDescription)")
            }
        } else {
            account = SAAccount()
            let fileUrl = URL.init(fileURLWithPath: path)
            let data = try! NSKeyedArchiver.archivedData(withRootObject: account!, requiringSecureCoding: false)
            try! data.write(to: fileUrl)
        }
        return account!
    }
    
    
    private var urlSession: URLSession! = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(30)
        return URLSession.init(configuration: configuration, delegate: nil, delegateQueue: nil)
    } ()
    
    private var enterbackgroundObserver: Any!
    private var becomeActiveObserver: Any!
    init() {
        ensureDirectoryExists()
        loadActiveAccount()
        
        enterbackgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] (notification) in
            self?.saveActiveAccount()
        }
        
        becomeActiveObserver = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] (notification) in
            self?.performAutoLogin(force: false)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(enterbackgroundObserver!)
        NotificationCenter.default.removeObserver(becomeActiveObserver!)
    }
    
    func ensureDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: s_accountHistoryDirectory) {
            try! fm.createDirectory(atPath: s_accountHistoryDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    func waitForAccountState(using filter: @escaping ((AccountState) -> Bool), completion: (() -> ())?) {
        if filter(accountState) {
            completion?()
            return
        }
        
        var ob: NSObjectProtocol?
        ob = NotificationCenter.default.addObserver(forName: .SAAccountManagerAccountStateChangedNotification, object: nil, queue: nil) { (notfication) in
            if let state = notfication.userInfo?["value"] as? AccountState, filter(state) {
                completion?()
                NotificationCenter.default.removeObserver(ob!)
                return
            }
        }
    }
    
    // must set activeAccount beforehand
    private func makeActiveAccountLoggedIn(accountVerified: Bool) {
        os_log("makeActiveAccountLoggedIn active account: %@", log: .account, type: .info, activeAccount!)
        
        if accountState != .notValidated {
            accountState = .notValidated
        }
        
        /// Set account loggedin state early because other components relying on
        /// the loggin state to do their jobs.
        /// We later verify this account and may change its state to others depending
        // on the verifying result.
        // Note that this process should be async to avoid blocking the initializing process
        accountState = .loggedIn
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            
            if self.accountState != .loggedIn {
                os_log("account login state not consistent, maybe verify failed? account: %@.", log: .account, type: .info, self.activeAccount!)
                return
            }
            
            os_log("on-disk account logged in %@.", log: .account, type: .info, self.activeAccount!)
            self.postUserLoggedInNotification()
            self.postPreferenceChangedNotification()
        }
        
        /// if we are sure of this account, we skip the verifying process.
        if accountVerified {
            os_log("account was verified, no need to auto login.", log: .account, type: .info)
            return
        }
        
        /// This account needs to be varified
        os_log("checking on-disk account...", log: .account, type: .info)
        
        // Keychain service has some conficts with application state restoration.
        // Keychain item can not be fetched before app state changes to active.
        // So we wait for state changing here.
        if UIApplication.shared.applicationState != .active {
            os_log("checking on-disk account app state not active, waiting", log: .account, type: .info)
            return
        }
        
        performAutoLogin(force: true)
    }
    
    private func postUserLoggedInNotification() {
        let notification = Notification(name: Notification.Name.SAUserLoggedInNotification, object: self, userInfo: nil)
        NotificationCenter.default.post(notification)
    }
    
    private func postPreferenceChangedNotification() {
        for preference in SAAccount.Preference.allPreferences {
            let notification = Notification(name: Notification.Name.SAUserPreferenceChangedNotification, object: self, userInfo: [SAAccount.Preference.changedPreferenceNameKey:preference])
            NotificationCenter.default.post(notification)
        }
    }
    
    private func saveAccountCredentialsToKeychain(_ credentials: CredentialInfo) {
        let saved = SAKeyChainService.saveCredential(credentials)
        os_log("keychain saved result: %@", log: .account, type: .info, saved ? "true" : "false")
    }
    
    private func getCurrentActiveAccountCredentials() -> CredentialInfo? {
        guard let activeAccount = self.activeAccount else {return nil}
        let savedAccounts = SAKeyChainService.loadAllCredentials()
        if savedAccounts.isEmpty {return nil}
        for account in savedAccounts {
            if activeAccount.name == account.username {
                return account
            }
        }
        
        os_log("fatal: keychain item missing.", log: .account, type: .fault)
        return nil
    }
    
    func parseAccountInfoResponse(_ dict: AnyObject, loginV2Response: AnyObject? = nil, credential: CredentialInfo) -> (NSError?) {
        guard let info = dict as? [String:AnyObject] else {
            let error = NSError.init(domain: "login", code: -1, userInfo: ["msg":"data serialization failed"])
            return error
        }
        
        guard let variables = info["Variables"] as? NSDictionary else {
            let error = NSError.init(domain: "login", code: -1, userInfo: ["msg":"data to NSDictionary failed"])
            return error
        }
        
        guard let uid = variables["member_uid"] as? String,
            let name = variables["member_username"] as? String,
            let gid = variables["groupid"] as? String,
            let readAccess = variables["readaccess"] as? String,
            let formhash = variables["formhash"] as? String, !formhash.isEmpty else {
                let error = NSError.init(domain: "login", code: -1, userInfo: ["msg":"data bad format"])
                return error
        }
        
        guard uid != "0" else {
            let error = NSError.init(domain: "login", code: -1, userInfo: ["msg":"not logged in"])
            return error
        }
        
        let account = SAAccountManager.accountOf(uid: uid)
        account.uid = uid
        account.name = name
        account.readaccess = Int(readAccess)!
        account.groupId = Int(gid)!
        account.formhash = formhash
        account.lastDateAuthPass = Date()
        
        if let loginV2 = loginV2Response as? [String:AnyObject], let data = loginV2["data"] as? [String:AnyObject], let sid = data["sid"] as? String {
            account.sid = sid
        }
        
        activeAccount = account
        saveActiveAccount()
        makeActiveAccountLoggedIn(accountVerified: true)
        saveAccountCredentialsToKeychain(credential)
        return nil
    }
    
    func clearCookie(_ completion: (() -> Void)?) {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        let store = WKWebsiteDataStore.default()
        store.removeData(ofTypes: [WKWebsiteDataTypeCookies], modifiedSince: Date.distantPast) {
            completion?()
        }
    }
    
    func logoutCurrentActiveAccount(_ completion: (() -> Void)?) {
        os_log("logged out %@", log: .account, type: .info, activeAccount!)
        if activeAccount!.isGuest {
            completion?()
            return
        }
        saveActiveAccount()
        deleteActiveAccountFile()
        let previousAccount = self.activeAccount!
        clearCookie {
            self.activeAccount = SAAccountManager.guestAccount
            self.accountState = .notLoggedIn
            let notification = Notification(name: Notification.Name.SAUserLoggedOutNotification, object: self, userInfo: ["account":previousAccount])
            NotificationCenter.default.post(notification)
            completion?()
        }
    }
    
    // This method can be called multi times.
    private func performAutoLogin(force: Bool) {
        guard let account = activeAccount else {
            os_log("[AccountManager] Auto login failed because no active account was found.", log: .account, type: .info)
            return
        }

        if !account.sid.isEmpty && !force && account.lastDateAuthPass != nil && account.lastDateAuthPass!.timeIntervalSinceNow > -2 * 24 * 3600 {
            os_log("[AccountManager] account does not expire yet, autologin finished.", log: .account, type: .info)
            return
        }
        
        guard let credential = getCurrentActiveAccountCredentials() else {
            os_log("[AccountManager] Auto login failed because no credentials. will log out", log: .account, type: .fault)
            DispatchQueue.main.async {
                self.logoutCurrentActiveAccount(nil)
            }
            return
        }
        
        os_log("[AccountManager] autologin start", log: .account, type: .info)
        
        let group = DispatchGroup()
        
        var loginObject: AnyObject?
        group.enter()
        urlSession.login(username: credential.username, password: credential.password, questionid: credential.questionid, answer: credential.answer) { (content, error) in
            defer {
                group.leave()
            }
            
            guard error == nil, let _ = content else {
                os_log("[AccountManager] Auto login failed due to network issue.", log: .account, type: .info)
                return
            }
            
            loginObject = content
        }
        
        var loginV2Obj: AnyObject?
        group.enter()
        urlSession.loginV2(username: credential.username, password: credential.password, questionid: credential.questionid, answer: credential.answer) { (loginV2Result, error) in
            defer {
                group.leave()
            }
            
            guard error == nil, let loginV2Result = loginV2Result else {
                return
            }
            
            loginV2Obj = loginV2Result
        }
        
        group.notify(queue: .global()) {
            guard let str = loginObject as? String, let loginV2 = loginV2Obj as? [String:AnyObject] else {
                os_log("[AccountManager] Auto login failed.", log: .account, type: .info)
                return
            }
            
            guard let parser = try? HTMLParser.init(string: str) else {
                os_log("[AccountManager] Auto login failed due to bad response from server.", log: .account, type: .info)
                return
            }
            
            guard let _ = parser.body()?.findChild(withAttribute: "title", matchingName: "退出", allowPartial: true) else {
                os_log("[AccountManager] auto login failed because of unknown response from server.", log: .account, type: .info)
                DispatchQueue.main.async {
                    self.accountState = .validatingFailed
                }
                return
            }
            
            guard let data = loginV2["data"] as? [String:AnyObject], let sid = data["sid"] as? String else {
                os_log("[AccountManager] auto login failed because of loginV2 failure.", log: .account, type: .info)
                DispatchQueue.main.async {
                    self.accountState = .validatingFailed
                }
                return
            }
            
            os_log("[AccountManager] autologin succeeded", log: .account, type: .info)
            DispatchQueue.main.async {
                account.sid = sid
                account.lastDateAuthPass = Date()
            }
        }
    }
    
    // MARK: - save, load & delete active account file
    func saveActiveAccount() {
        guard let account = activeAccount else {
            os_log("no active account", log: .account, type: .debug)
            return
        }
        
        // The history directory is under account info directory, so we only need
        // to check existence of the former
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: s_accountHistoryDirectory) {
            do {
                try fileManager.createDirectory(atPath: s_accountHistoryDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                os_log("create history directory failed with error: %@", log: .account, type: .error, error as NSError)
            }
            os_log("create history directory", log: .account, type: .debug)
        }
        
        //save to history accounts
        let historyPath = s_accountHistoryDirectory + "/\(account.uid)"
        account.saveToFile(historyPath)
        
        //save as active account
        account.saveToFile(s_activeAccountPath)
    }
    
    private func loadActiveAccount() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: s_activeAccountPath, isDirectory: nil) {
            activeAccount = SAAccountManager.guestAccount
            accountState = .notLoggedIn
            return
        }
        
        let fileUrl = URL(fileURLWithPath: s_activeAccountPath)
        let fileData = try! Data(contentsOf: fileUrl)
        
        do {
            guard let account = try NSKeyedUnarchiver.unarchivedObject(ofClasses: SAAccount.archiveClasses, from: fileData) as? SAAccount else {
                activeAccount = SAAccountManager.guestAccount
                accountState = .notLoggedIn
                return
            }
            
            if account.isGuest {
                activeAccount = account
                accountState = .notLoggedIn
                return
            }
            
            activeAccount = account
            makeActiveAccountLoggedIn(accountVerified: false)
        } catch {
            os_log("unarchivedObject failed: %@", log: .account, type: .fault, error as CVarArg)
        }
    }
    
    fileprivate func deleteActiveAccountFile() {
        do {
            try FileManager.default.removeItem(atPath: s_activeAccountPath)
        } catch {
            os_log("delete active account error: %@", log: .account, type: .debug, error as NSError)
        }
        os_log("active account file deleted", log: .account, type: .debug)
    }
}
