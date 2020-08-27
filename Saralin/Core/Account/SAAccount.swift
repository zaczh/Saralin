//
//  SAAccount.swift
//  Saralin
//
//  Created by zhang on 2018/9/18.
//  Copyright © 2018年 zaczh. All rights reserved.
//

import UIKit

class SAAccount: NSObject, NSCoding {
    // keys
    enum Preference : String {
        case useGoogleSearch = "k_user_preferences_useGoogleSearch"
        case normalFontSize = "k_user_preferences_normalFontSize"
        case smallFontSize = "k_user_preferences_smallFontSize"
        case language = "k_user_preferences_language"
        case save_traffic = "k_user_preferences_save_traffic"
        case new_threads_order = "k_user_preferences_new_threads_order"
        case theme_id = "k_user_preferences_theme_id"
        case theme_id_before_night_switch = "k_user_preferences_theme_id_before_night_switch"
        case shown_boards_ids = "k_user_preferences_shown_block_ids"
        case bodyFontSizeOffset = "k_user_preferences_bodyFontSizeOffset"
        case thread_view_shows_avatar = "k_user_preferences_thread_view_shows_avatar"
        case remove_signature_and_last_editing_notice = "k_user_preferences_remove_signature_and_last_editing_notice"
        case forum_tab_default_sub_board_id = "k_forum_tab_default_sub_board_id"
        case insert_client_signature = "k_insert_client_signature"
        case uses_system_dynamic_type_font = "k_uses_system_dynamic_type_font"
        case automatically_change_theme_to_match_system_appearance = "k_automatically_change_theme_to_match_system_appearance"
        case enable_multi_windows = "k_enable_multi_windows"
        
        static let changedPreferenceNameKey = "key"
        static let allPreferences: [Preference] = [.useGoogleSearch, .normalFontSize, .smallFontSize, .language, .save_traffic, .new_threads_order, .theme_id, .theme_id_before_night_switch, .shown_boards_ids, .bodyFontSizeOffset, .thread_view_shows_avatar, .remove_signature_and_last_editing_notice, .forum_tab_default_sub_board_id, .insert_client_signature, .uses_system_dynamic_type_font, .automatically_change_theme_to_match_system_appearance, .enable_multi_windows]
    }
    
    
    var uid = "0"
    var name = "[未登录]"
    var readaccess: Int = 0
    var uploadhash = ""
    var groupId: Int = 0
    var formhash = ""
    var sid = ""
    var lastDayCheckIn: Date?
    var favoriteEmojis = NSArray()
    var lastDateAuthPass: Date?
    
    private var preferences = NSMutableDictionary()
    private var preferencesLock = NSLock()

    var avatarImageURL: URL? {
        if isGuest {
            return nil
        }
        return URL(string: SAGlobalConfig().avatar_base_url + "avatar.php?uid=\(uid)&size=middle")!
    }
    
    var isGuest: Bool {
        return uid == "0"
    }
    
    var hasCheckedInToday: Bool {
        if let date = lastDayCheckIn {
            let now = Date()
            return Calendar.current.isDate(now, inSameDayAs: date)
        }
        
        return false
    }
    
    override init() {
        super.init()
    }
    
    // MARK: - Coding
    func encode(with aCoder: NSCoder) {
        aCoder.encode(uid, forKey: "uid")
        aCoder.encode(name, forKey: "name")
        aCoder.encode(readaccess, forKey: "readaccess")
        aCoder.encode(uploadhash, forKey: "uploadhash")
        aCoder.encode(groupId, forKey: "groupId")
        aCoder.encode(preferences, forKey: "preferences")
        aCoder.encode(formhash, forKey: "formhash")
        aCoder.encode(sid, forKey: "sid")
        aCoder.encode(lastDayCheckIn, forKey: "lastDayCheckIn")
        aCoder.encode(favoriteEmojis, forKey: "favoriteEmojis")
        aCoder.encode(lastDateAuthPass, forKey: "lastDateAuthPass")
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init()
        uid = aDecoder.decodeObject(forKey: "uid") as? String ?? ""
        name = aDecoder.decodeObject(forKey: "name") as? String ?? ""
        readaccess = aDecoder.decodeInteger(forKey: "readaccess")
        uploadhash = aDecoder.decodeObject(forKey: "uploadhash") as? String ?? ""
        groupId = aDecoder.decodeInteger(forKey: "groupId")
        preferences = aDecoder.decodeObject(forKey: "preferences") as? NSMutableDictionary ?? NSMutableDictionary()
        formhash = aDecoder.decodeObject(forKey: "formhash") as? String ?? ""
        sid = aDecoder.decodeObject(forKey: "sid") as? String ?? ""
        lastDayCheckIn = aDecoder.decodeObject(forKey: "lastDayCheckIn") as? Date
        favoriteEmojis = aDecoder.decodeObject(forKey: "favoriteEmojis") as? NSArray ?? NSArray()
        lastDateAuthPass = aDecoder.decodeObject(forKey: "lastDateAuthPass") as? Date
    }
    
    override var description: String {
        return "uin: \(uid), name: \(name), readaccess:\(readaccess), groupid:\(groupId), formhash: \(formhash), sid: \(sid), lastDateAuthPass: \(lastDateAuthPass?.description ?? "none")"
    }
    
    func saveToFile(_ filePath: String) {
        let fileUrl = URL.init(fileURLWithPath: filePath)
        
        let data = NSKeyedArchiver.archivedData(withRootObject: self)
        try! data.write(to: fileUrl)
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let anotherAccount = object as? SAAccount {
            return anotherAccount.uid == self.uid
        }
        
        return false
    }
    
    func checkSmsBindingState(completion: @escaping (Bool, NSError?) -> Void) {
        guard let url = URL(string: "home.php?mod=spacecp&ac=phone&mobile=1", relativeTo: URL(string: SAGlobalConfig().forum_base_url)!) else {
            fatalError()
        }
        
        var request = URLRequest.init(url: url)
        request.setValue(SAGlobalConfig().mobile_useragent_string, forHTTPHeaderField: "User-Agent")
        URLSession.saCustomized.dataTask(with: request, completionHandler: { (data, response, error) in
            guard error == nil else {
                completion(false, error! as NSError)
                return
            }
            guard data != nil else {
                completion(false, NSError.init(domain: "Network", code: -1, userInfo: ["msg":"data is empty"]))
                return
            }
            
            let str = String.init(data: data!, encoding: String.Encoding.utf8)!
            guard let parser = try? HTMLParser.init(string: str) else {
                completion(false, NSError.init(domain: "Network", code: -1, userInfo: ["msg":"data not xml format"]))
                return
            }
            
            if let input = parser.body()?.findChild(withAttribute: "name", matchingName: "phone", allowPartial: true) {
                if let phone = input.getAttributeNamed("value"), !phone.isEmpty {
                    completion(true, nil)
                    return
                }
            }
            
            completion(false, NSError.init(domain: "Network", code: -1, userInfo: ["msg":"data bad format"]))
        }).resume()
    }
    
    
    class func allOptionsForKey(_ key: Preference) -> [String] {
        if key == .new_threads_order {
            return ["dateline", "lastpost"]
        }
        
        return []
    }
    
    /// Options with recognizable names for displaying, match 1 by 1 with `allOptionsForKey`
    class func allOptionNamesForKey(_ key: Preference) -> [String] {
        if key == .new_threads_order {
            return [NSLocalizedString("OPTION_THREADS_DISPLAY_ORDER_CREATE_TIME", comment: "OPTION_THREADS_DISPLAY_ORDER_CREATE_TIME"), NSLocalizedString("OPTION_THREADS_DISPLAY_ORDER_REPLY_TIME", comment: "OPTION_THREADS_DISPLAY_ORDER_REPLY_TIME")]
        }
        
        return []
    }
    
    class func defaultOptionForKey(_ key: Preference) -> String {
        if key == .new_threads_order {
            return "lastpost" /*dateline*/
        }
        
        return ""
    }
    
    func preferenceForkey(_ key: Preference, defaultValue: AnyObject) -> AnyObject {
        return preferenceForkey(key) ?? defaultValue
    }

    func preferenceForkey(_ key: Preference) -> AnyObject? {
        preferencesLock.lock()
        defer {
            preferencesLock.unlock()
        }
        if let value = preferences[key.rawValue] {
            if key == .enable_multi_windows {
                // multi window support on the ipad is not good enough.
                #if targetEnvironment(macCatalyst)
                return true as AnyObject
                #else
                return false as AnyObject
                #endif
            }
            return value as AnyObject?
        }
        
        // set some default value
        var value: AnyObject?
        switch key {
        case .useGoogleSearch:
            value = true as AnyObject
        case .normalFontSize:
            value = Int(13) as AnyObject
        case .smallFontSize:
            value = Int(11) as AnyObject
        case .language:
            value = "Zh-CN" as AnyObject
        case .save_traffic:
            value = true as AnyObject
        case .new_threads_order:
            value = SAAccount.defaultOptionForKey(key) as AnyObject
        case .theme_id:
            value = Int(2) as AnyObject
        case .shown_boards_ids:
            value = [93,4,75,77,6,51,48,50,27,74,24,115,136] as AnyObject
        case .bodyFontSizeOffset:
            value = Float(0.0) as AnyObject
        case .thread_view_shows_avatar:
            value = true as AnyObject
        case .remove_signature_and_last_editing_notice:
            value = false as AnyObject
        case .forum_tab_default_sub_board_id:
            value = 75 as AnyObject
        case .insert_client_signature:
            value = false as AnyObject
        case .enable_multi_windows:
            #if targetEnvironment(macCatalyst)
            value = true as AnyObject
            #else
            value = false as AnyObject
            #endif
        default:
            return nil
        }
        
        preferences[key.rawValue] = value
        return value
    }
    
    func savePreferenceValue(_ someValue: AnyObject, forKey someKey: Preference) {
        preferencesLock.lock()
        preferences[someKey.rawValue] = someValue
        preferencesLock.unlock()
        AppController.current.getService(of: SAAccountManager.self)!.saveActiveAccount()
        let notification = Notification(name: Notification.Name.SAUserPreferenceChangedNotification, object: self, userInfo: [SAAccount.Preference.changedPreferenceNameKey:someKey])
        NotificationCenter.default.post(notification)
    }
}
