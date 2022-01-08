//
//  SAKeyChain.swift
//  Saralin
//
//  Created by zhang on 2018/6/9.
//  Copyright © 2018 zaczh. All rights reserved.
//

import UIKit
import Security

struct CredentialInfo {
    let username: String
    let password: String
    let questionid: String
    let answer: String
}

private let sa_keychain_server = "bbs.saraba1st.com"
class SAKeyChainService {
    class func loadAllCredentials(accessGroup: String? = nil) -> [CredentialInfo] {
        let query = NSMutableDictionary.init()
        query.setObject(kSecClassGenericPassword, forKey: kSecClass as NSString)
        query.setObject(kSecMatchLimitAll, forKey: kSecMatchLimit as NSString)
        query.setObject(sa_keychain_server, forKey: kSecAttrService as NSString)
        query.setObject(kCFBooleanTrue as Any, forKey: kSecReturnAttributes as NSString)
        if let group = accessGroup {
            query.setObject(group, forKey: kSecAttrAccessGroup as NSString)
        }
        
        var items: CFTypeRef? = nil
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status != errSecSuccess {
            sa_log_v2("keychain SecItemCopyMatching error: %@", log: .keychain, type: .error, NSNumber(value: status))
            return []
        }
        
        guard let arr = items as? Array<CFDictionary> else {
            sa_log_v2("keychain SecItemCopyMatching empty", log: .keychain, type: .info)
            return []
        }
        
        var results: [CredentialInfo] = []
        arr.forEach { (item) in
            let account = (item as NSDictionary)[kSecAttrAccount as String] as! String
            if let credential = getCredential(of: account, accessGroup: accessGroup) {
                results.append(credential)
            }
        }
        return results
    }
    
    class func saveCredential(_ credential: CredentialInfo, accessGroup: String? = nil) -> Bool {
        var status = errSecSuccess
        let query = NSMutableDictionary.init()
        query.setObject(kSecClassGenericPassword, forKey: kSecClass as NSString)
        query.setObject(credential.username, forKey: kSecAttrAccount as NSString)
        query.setObject(sa_keychain_server, forKey: kSecAttrService as NSString)
        if let _ = accessGroup {
            query.setObject(accessGroup!, forKey: kSecAttrAccessGroup as NSString)
        }
        
        guard let passwordData = credential.password.data(using: .utf8) as NSData? else {
            return false
        }
        
        status = SecItemCopyMatching(query as CFDictionary, nil)
        let securityQuestionDictionary: NSDictionary = NSDictionary(objects: [credential.questionid as NSString, credential.answer as NSString], forKeys: ["questionid" as NSString, "answer" as NSString])
        let securityQuestionData = try! JSONSerialization.data(withJSONObject: securityQuestionDictionary, options: [])
        if status == errSecSuccess {
            // already exist
            let update = NSMutableDictionary.init(objects: [passwordData, securityQuestionData], forKeys: [kSecValueData as NSString, kSecAttrGeneric as NSString])
            status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            return status == errSecSuccess
        } else if status == errSecItemNotFound {
            query.setObject(passwordData as CFData, forKey: kSecValueData as NSString)
            query.setObject(securityQuestionData as CFData, forKey: kSecAttrGeneric as NSString)
            query.setObject(kSecAttrAccessibleWhenUnlocked as String, forKey: kSecAttrAccessible as NSString)
            status = SecItemAdd(query as CFDictionary, nil)
            return status == errSecSuccess
        }
        return false
    }
    
    private class func getCredential(of account: String, accessGroup: String? = nil) -> CredentialInfo? {
        let query = NSMutableDictionary.init()
        query.setObject(kSecClassGenericPassword, forKey: kSecClass as NSString)
        query.setObject(account, forKey: kSecAttrAccount as NSString)
        if let group = accessGroup {
            query.setObject(group, forKey: kSecAttrAccessGroup as NSString)
        }
        query.setObject(kCFBooleanTrue as Any, forKey: kSecReturnAttributes as NSString)
        query.setObject(kCFBooleanTrue as Any, forKey: kSecReturnData as NSString)
        query.setObject(kSecMatchLimitOne, forKey: kSecMatchLimit as NSString)
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else {
            sa_log_v2("keychain SecItemCopyMatching error: %@", log: .keychain, type: .error, NSNumber(value: status))
            return nil
        }
        
        guard let existingItem = item as? [String : Any],
            let passwordData = existingItem[kSecValueData as String] as? Data,
            let password = String(data: passwordData, encoding: String.Encoding.utf8),
            let account = existingItem[kSecAttrAccount as String] as? String
            else {
                return nil
        }
        
        if let securityQuesionData = existingItem[kSecAttrGeneric as String] as? Data,
           let securityQuestionDictionary = try? JSONSerialization.jsonObject(with: securityQuesionData, options: []) as? NSDictionary {
            let questionid = securityQuestionDictionary["questionid"] as! String
            let answer = securityQuestionDictionary["answer"] as! String
            return CredentialInfo(username: account, password: password, questionid: questionid, answer: answer)
        }
        
        return CredentialInfo(username: account, password: password, questionid: "", answer: "")
    }
}


// Device Identifier
private let sa_keychain_device_identifier_service = "me.zaczh.saralin.keychain.deviceidentifier"
extension SAKeyChainService {
    class func saveIdentifier(_ identifier: String, accessGroup: String? = nil) -> Bool {
        var status = errSecSuccess
        let query = NSMutableDictionary.init()
        query.setObject(kSecClassGenericPassword, forKey: kSecClass as NSString)
        if let _ = accessGroup {
            query.setObject(accessGroup!, forKey: kSecAttrAccessGroup as NSString)
        }
        query.setObject(sa_keychain_device_identifier_service, forKey: kSecAttrService as NSString)
        guard let identifierData = identifier.data(using: .utf8) as NSData? else {
            return false
        }
        
        status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            // already exist
            let update = NSMutableDictionary.init(objects: [identifierData], forKeys: [kSecValueData as NSString])
            status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            return status == errSecSuccess
        } else if status == errSecItemNotFound {
            query.setObject(identifierData as CFData, forKey: kSecValueData as NSString)
            query.setObject(kSecAttrAccessibleWhenUnlocked as String, forKey: kSecAttrAccessible as NSString)
            status = SecItemAdd(query as CFDictionary, nil)
            return status == errSecSuccess
        }
        return false
    }
    
    class func getIdentifier(accessGroup: String? = nil) -> String? {
        let query = NSMutableDictionary.init()
        query.setObject(kSecClassGenericPassword, forKey: kSecClass as NSString)
        query.setObject(sa_keychain_device_identifier_service, forKey: kSecAttrService as NSString)
        if let group = accessGroup {
            query.setObject(group, forKey: kSecAttrAccessGroup as NSString)
        }
        query.setObject(kCFBooleanTrue as Any, forKey: kSecReturnAttributes as NSString)
        query.setObject(kCFBooleanTrue as Any, forKey: kSecReturnData as NSString)
        query.setObject(kSecMatchLimitOne, forKey: kSecMatchLimit as NSString)
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else {
            sa_log_v2("keychain SecItemCopyMatching error: %@", log: .keychain, type: .error, NSNumber(value: status))
            return nil
        }
        
        guard let existingItem = item as? [String : Any],
            let itemData = existingItem[kSecValueData as String] as? Data,
            let deviceIdentifier = String(data: itemData, encoding: String.Encoding.utf8) else {
                return nil
        }
        
        return deviceIdentifier
    }
}
