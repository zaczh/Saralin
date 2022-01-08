//
//  SAUtility.swift
//  Saralin
//
//  Created by zhang on 4/30/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import Foundation
import UIKit
import Compression

func dispatch_async_main(_ job: @escaping (() -> Void)) {
    if Thread.isMainThread {
        job()
    } else {
        DispatchQueue.main.async(execute: job)
    }
}

extension Dictionary where Key == String {
    
    func sa_toAttributedStringKeys() -> [NSAttributedString.Key: Value] {
        return Dictionary<NSAttributedString.Key, Value>(uniqueKeysWithValues: map {
            key, value in (NSAttributedString.Key(key), value)
        })
    }
}

//make font a little smaller
extension UIFont {
    open class func sa_preferredFont(forTextStyle style: UIFont.TextStyle) -> UIFont {
        let account = Account()
        if (account.preferenceForkey(.uses_system_dynamic_type_font) as? Bool) ?? true {
            return preferredFont(forTextStyle: style)
        }
        
        let offset = account.preferenceForkey(.bodyFontSizeOffset) as! Float
        let font = preferredFont(forTextStyle: style)
        if abs(offset) < 0.1 {
            return font
        }
        return font.withSize(font.pointSize + CGFloat(offset))
    }
    
    class var sa_bodyFontSize: CGFloat {
        return sa_preferredFont(forTextStyle: .body).pointSize
    }
}

extension String {
    // WKURLSchemeHandler gives an encoded url from original one
    // and removes the semicolon. To make things complicated, we
    // make image loading via custom protocol by adding `sa-src`
    // before the <img> tag src attribute.
    // This method recovers the original url.
    func sa_recoverOriginalUrlFromCustomScheme() -> String {
        var str = self
        if !hasPrefix(sa_wk_url_scheme) {
            return self
        }
        
        if str.count <= sa_wk_url_scheme.count + 3 {
            return self
        }
        
        str.removeFirst(sa_wk_url_scheme.count + 3)
        
        guard let escpaed = str.removingPercentEncoding else {
            return self
        }
        str = escpaed
        str = str.replacingOccurrences(of: "\"", with: "")
        str = str.replacingOccurrences(of: "'", with: "")
        str = str.replacingOccurrences(of: "\n", with: "")
        
        guard let encoded = str.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) else {
            return self
        }
        str = encoded
        
        if str.hasPrefix("http//") {
            str.insert(contentsOf: ":", at: str.index(str.startIndex, offsetBy: 4))
        }
        if str.hasPrefix("https//") {
            str.insert(contentsOf: ":", at: str.index(str.startIndex, offsetBy: 5))
        }
        return str
    }
    
    //NOTE: You must parent the parameter with double quotes!!!
    func sa_escapedStringForJavaScriptInput() -> String {
        // valid JSON object need to be an array or dictionary
        let arrayForEncoding = [self]
        let data = try! JSONSerialization.data(withJSONObject: arrayForEncoding, options: [])
        let jsonString = String.init(data: data, encoding: .utf8)! as NSString
        
        let escapedString = jsonString.substring(with: NSMakeRange(2, jsonString.length - 4))
        return escapedString
    }
    
    func sa_stringByReplacingHTMLTags() -> NSString {
        let str = replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&reg;", with: "®").replacingOccurrences(of: "&ndash;", with: "-").replacingOccurrences(of: "&mdash;", with: "-").replacingOccurrences(of: "&emsp;", with: " ").replacingOccurrences(of: "&shy;", with: "").replacingOccurrences(of: "&copy;", with: "©").replacingOccurrences(of: "&trade;", with: "™")
        return str as NSString
    }
    
    func sa_toColor() -> UIColor {
        let ahex = trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var i = UInt64()
        Scanner(string: ahex).scanHexInt64(&i)
        let a, r, g, b: UInt64
        switch ahex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (i >> 8) * 17, (i >> 4 & 0xF) * 17, (i & 0xF) * 17)
            break
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, i >> 16, i >> 8 & 0xFF, i & 0xFF)
            break
        case 8: // RGBA (32-bit)
            (r, g, b, a) = (i >> 24, i >> 16 & 0xFF, i >> 8 & 0xFF, i & 0xFF)
            break
        default:
            return UIColor.clear
        }
        return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
    
    func sa_toDateFrom1970SecondsDate() -> Date? {
        if let interval = TimeInterval(self) {
            let date = Date.init(timeIntervalSince1970: interval)
            return date
        }
        
        return nil
    }
    
    func sa_formURLEncoded() -> String {
        // for x-www-form-urlencoded, &= need also encoded
        let charset = CharacterSet.urlQueryAllowed.subtracting(CharacterSet.init(charactersIn: "&=:/?"))
        let escapedMessage = addingPercentEncoding(withAllowedCharacters: charset) ?? ""
        return escapedMessage
    }
}

extension Date {
    func sa_prettyDate() -> String {
        let now = Date()
        let interval = now.timeIntervalSince1970 - self.timeIntervalSince1970
        if interval < 0 {
            return NSLocalizedString("DATE_FORMATTED_STYLE_FUTURE", comment: "")
        } else if interval < 60 {
            return NSLocalizedString("DATE_FORMATTED_STYLE_NOW", comment: "")
        } else if interval < 60 * 60 {
            return String(format: NSLocalizedString("DATE_FORMATTED_STYLE_MINIUTES_AGO", comment: ""), "\(Int(interval/60))")
        } else if interval < 24 * 60 * 60 {
            return String(format: NSLocalizedString("DATE_FORMATTED_STYLE_HOUR_AGO", comment: ""), "\(Int(interval/(60 * 60)))")
        } else if interval < 30 * 24 * 60 * 60  {
            return String(format: NSLocalizedString("DATE_FORMATTED_STYLE_DAY_AGO", comment: ""), "\(Int(interval/(24 * 60 * 60)))")
        } else if interval < 12 * 30 * 24 * 60 * 60 {
            return String(format: NSLocalizedString("DATE_FORMATTED_STYLE_MONTH_AGO", comment: ""), "\(Int(interval/(30 * 24 * 60 * 60)))")
        } else {
            return String(format: NSLocalizedString("DATE_FORMATTED_STYLE_YEARS_AGO", comment: ""), "\(Int(interval/(12 * 30 * 24 * 60 * 60)))")
        }
    }
}

extension URL {
    func sa_isSecureURL(of another: URL) -> Bool {
        if self.scheme?.lowercased() != "https" {
            return false
        }
        
        if another.scheme?.lowercased() != "http" {
            return false
        }
        
        guard var anotherComponent = URLComponents(url: another, resolvingAgainstBaseURL: false) else {
            return false
        }
        
        anotherComponent.scheme = "https"
        return anotherComponent.url?.absoluteString.caseInsensitiveCompare(self.absoluteString) == .orderedSame
    }
    
    func sa_isCustomURLScheme() -> Bool {
        guard let scheme = self.scheme else {
            return false
        }
        return scheme == sa_wk_url_scheme
    }
    
    func sa_customURLSchemeToStandard() -> URL {
        let str = self.absoluteString.sa_recoverOriginalUrlFromCustomScheme()
        guard let url = URL.init(string: str) else {
            return self
        }
        return url
    }
    
    func sa_isInsecureURL(of another: URL) -> Bool {
        if self.scheme?.lowercased() != "http" {
            return false
        }
        
        if another.scheme?.lowercased() != "https" {
            return false
        }
        
        guard var anotherComponent = URLComponents(url: another, resolvingAgainstBaseURL: false) else {
            return false
        }
        
        anotherComponent.scheme = "http"
        return anotherComponent.url?.absoluteString.caseInsensitiveCompare(self.absoluteString) == .orderedSame
    }
    
    func sa_queryString(_ query: String) -> String? {
        let component = URLComponents(url: self, resolvingAgainstBaseURL: false)
        let mode: String? = component!.queryItems?.filter({ (i) -> Bool in
            return i.name == query
        }).first?.value
        return mode
    }
    
    func sa_urlByReplacingQuery(_ name: String, value: String) -> URL {
        var component = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        var items = component.queryItems?.filter({ (item) -> Bool in
            return item.name.lowercased() != name.lowercased()
        })
        if items == nil {
            items = []
        }
        items!.append(URLQueryItem(name: name, value: value))
        component.queryItems = items
        
        if let aURL = component.url {
            return aURL
        } else {
            sa_log_v2("urlByReplacingQuery failed", log: .utility, type: .debug)
            return self
        }
    }

    
    func sa_uniformURL() -> URL {
        // http://bbs.saraba1st.com/2b/thread-520644-1-1.html
        // http://bbs.saraba1st.com/2b/forum.php?mod=viewthread&tid=520644&extra=page%3D1&page=1&mobile=1&simpletype=no
        
        //http://bbs.saraba1st.com/2b/space-uid-445568.html
        //http://bbs.saraba1st.com/2b/home.php?mod=space&uid=445568&do=profile&mobile=1
        
        //http://bbs.saraba1st.com/2b/forum-75-1.html
        //http://bbs.saraba1st.com/2b/forum.php?mod=forumdisplay&fid=75&page=2&mobile=1
        
        if let urlComponents = NSURLComponents(url: self, resolvingAgainstBaseURL: false) {
            if let queryItems = urlComponents.queryItems {
                for queryItem in queryItems {
                    let name = queryItem.name.lowercased()
                    if name == "mobile" || name == "mod" || name == "tid" || name == "fid" || name == "uid" {
                        return self
                    }
                }
            }
        }
        
        var components = self.deletingPathExtension().absoluteString.lowercased().components(separatedBy:"/")
        guard components.count > 1 else {
            return self
        }
        
        if (components.last!.hasPrefix("thread-")) {
            guard components.last!.components(separatedBy: "-").count >= 3 else {
                sa_log_v2("failed", log: .utility, type: .debug)
                return self
            }
            
            let threadID = (components.last!.components(separatedBy: "-")[1]) as String
            let pageID = (components.last!.components(separatedBy: "-")[2]) as String
            
            let lastComponent = "forum.php?mod=viewthread&tid=" + threadID + "&extra=page%3D1&page=" + pageID + "&mobile=1&simpletype=no"
            components.removeLast()
            components.append(lastComponent)
            
            let mobileUrl = components.joined(separator: "/")
            if let aURL = URL(string: mobileUrl) {
                return aURL
            } else {
                sa_log_v2("failed", log: .utility, type: .debug)
                return self
            }
        } else if (components.last!.hasPrefix("space-")) {
            guard components.last!.components(separatedBy: "-").count >= 3 else {
                sa_log_v2("failed", log: .utility, type: .debug)
                return self
            }
            
            let uid = components.last!.components(separatedBy: "-")[2]
            let lastComponent = "home.php?mod=space&uid=\(uid)&do=profile&mobile=1"
            components.removeLast()
            components.append(lastComponent)
            let mobileUrl = components.joined(separator: "/")
            if let aURL = URL(string: mobileUrl) {
                return aURL
            } else {
                sa_log_v2("failed", log: .utility, type: .debug)
                return self
            }
        } else if (components.last!.hasPrefix("forum-")) {
            guard components.last!.components(separatedBy: "-").count >= 3 else {
                sa_log_v2("failed", log: .utility, type: .debug)
                return self
            }
            
            let fid = components.last!.components(separatedBy: "-")[1]
            let page = components.last!.components(separatedBy: "-")[2]
            let lastComponent = "forum.php?mod=forumdisplay&fid=\(fid)&page=\(page)&mobile=1"
            components.removeLast()
            components.append(lastComponent)
            let mobileUrl = components.joined(separator: "/")
            if let aURL = URL(string: mobileUrl) {
                return aURL
            } else {
                sa_log_v2("failed", log: .utility, type: .debug)
                return self
            }
        }
        
        
        return self
    }
    
    func sa_isSimilarTo(_ url: URL) -> Bool {
        return sa_queryString("mod") == url.sa_queryString("mod") &&
               sa_queryString("action") == url.sa_queryString("action") &&
               sa_queryString("fid") == url.sa_queryString("fid")
    }
    
    func sa_documentDirectory() -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }
    
    func sa_isExternal() -> Bool {
        guard let scheme = self.scheme else {
            return true
        }
        
        if scheme.compare("file", options: String.CompareOptions.caseInsensitive, range: nil, locale: nil) == .orderedSame {
            return false
        }
        
        if scheme.compare("about", options: .caseInsensitive, range: nil, locale: nil) == .orderedSame {
            return false
        }
        
        guard let host = self.host else {
            return true
        }
        
        if let avatarHost = URL.init(string: SAGlobalConfig().avatar_base_url)?.host, avatarHost.caseInsensitiveCompare(host) == .orderedSame {
            return false
        }
        
        if host.hasSuffix(SAGlobalConfig().forum_domain) {
            return false
        }
        
        for sub in SAGlobalConfig().forum_sub_domains {
            if host.hasSuffix(sub) {
                return false
            }
        }
        
        return true
    }
    
    func sa_isFavoriteURL() -> Bool {
        guard let mod = self.sa_queryString("mod"), let ac = self.sa_queryString("ac") else {
            return false
        }
        let _ = self.sa_queryString("type")
        
        return mod == "spacecp" && ac == "favorite"
    }
    
    func sa_isLikelyADesktopThreadURL() -> Bool {
        let components = absoluteString.components(separatedBy: "/")
        guard components.count > 1 else {
            return false
        }
        
        if (components.last!.hasPrefix("thread-")) {
            return true
        }
        
        return false
    }
}

extension UIImage {
    func scaledToSize(_ newSize:CGSize) -> UIImage {
        //UIGraphicsBeginImageContext(newSize);
        // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
        // Pass 1.0 to force exact pixel size.
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext();
        return newImage!
    }
        
    // http://stackoverflow.com/a/40177870/4488252
    func imageWithColor(newColor: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        
        let context = UIGraphicsGetCurrentContext()!
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.setBlendMode(.normal)
        
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        context.clip(to: rect, mask: cgImage!)
        
        newColor.setFill()
        context.fill(rect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        newImage.accessibilityIdentifier = accessibilityIdentifier
        return newImage
    }
    
    class func sa_imageFromColor(_ color: UIColor, size: CGSize, cornerRadius: CGFloat = 0) -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: size.width, height: size.height))
        let context = UIGraphicsGetCurrentContext()
        if cornerRadius > 0 {
            let path = UIBezierPath.init(roundedRect: CGRect.init(origin: .zero, size: size), cornerRadius: cornerRadius)
            path.addClip()
        }
        context!.setFillColor(color.cgColor)
        context!.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    class func imageWithSystemName(_ systemName: String, fallbackName:String) -> UIImage? {
        if #available(iOS 13.0, *) {
            return UIImage(systemName: systemName)
        } else {
            // Fallback on earlier versions
            return UIImage(named: fallbackName)
        }
    }
}

extension UIColor {
    class func sa_colorFromHexString(_ hex: String) -> UIColor {
        let ahex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var i = UInt64()
        Scanner(string: ahex).scanHexInt64(&i)
        let a, r, g, b: UInt64
        switch ahex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (i >> 8) * 17, (i >> 4 & 0xF) * 17, (i & 0xF) * 17)
            break
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, i >> 16, i >> 8 & 0xFF, i & 0xFF)
            break
        case 8: // RGBA (32-bit)
            (r, g, b, a) = (i >> 24, i >> 16 & 0xFF, i >> 8 & 0xFF, i & 0xFF)
            break
        default:
            return UIColor.clear
        }
        return UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
    
    func sa_toHexString() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0;
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        let str = String(format: "#%02x%02x%02x%02x", arguments: [Int(255 * r), Int(255 * g), Int(255 * b), Int(255 * a)])
        return str
    }
    
    func sa_toHtmlCssColorFunction() -> String {
        var seperatorColorR: CGFloat = 0
        var seperatorColorG: CGFloat = 0
        var seperatorColorB: CGFloat = 0
        var seperatorColorA: CGFloat = 0
        self.getRed(&seperatorColorR, green: &seperatorColorG, blue: &seperatorColorB, alpha: &seperatorColorA)
        return "rgba(\(Int(seperatorColorR * 255)), \(Int(seperatorColorG * 255)), \(Int(seperatorColorB * 255)), \(seperatorColorA))"
    }
}

extension UIApplication {
    func showNetworkIndicator() {
        // TODO: create new network indicator view
    }
    
    func hideNetworkIndicator() {
        // TODO: create new network indicator view
    }
}

extension FileManager {
    func sa_removeAllFilesIn(dir: URL, fileNameMatching: ((String) -> Bool)?) {
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey])
        let directoryEnumerator = enumerator(at: dir, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)!
        for case let fileURL as URL in directoryEnumerator {
            if fileNameMatching?(fileURL.lastPathComponent) ?? true {
                try? removeItem(at: fileURL)
            }
        }
    }
}
