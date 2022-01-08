//
//  SAWKURLSchemeHandler.swift
//  Saralin
//
//  Created by zhang on 18/11/2017.
//  Copyright © 2017 zaczh. All rights reserved.
//

import UIKit
import WebKit

enum SAURLSchemeHostType: String {
    case loading = "loading"
    case failure = "failure"
    case image = "image"
    case attachment = "attachment"
    case imageFormatNotSupported = "imageformatnotsupported"
}

@available(iOS 11.0, *)
@objc protocol SAWKURLSchemeHandlerDelegate {
    
    // after downloading the image, tell page to reload img tag to which this image belongs.
    // if toURL is nil, mark this image loading failure
    func schemeHandlerRequestReloadHTMLPlaceholderImageTag(_ schemeHandler: SAWKURLSchemeHandler?, fromURL: URL, toURL: URL)
    
    // NOTE: methods below may be called from non-main thread!!!

    func schemeHandlerRequestSaveFileDataToDisk(_ schemeHandler: SAWKURLSchemeHandler?, data: Data, fromURL: URL) -> URL?
        
    func schemeHandlerRequestSaveImageDataToDisk(_ schemeHandler: SAWKURLSchemeHandler?, data: Data, fromURL: URL) -> URL?
    
    func schemeHandlerRequestGetSavedImageData(_ schemeHandler: SAWKURLSchemeHandler?, fromURL: URL) -> Data?
}

@available(iOS 11.0, *)
class SAWKURLSchemeHandler: NSObject, WKURLSchemeHandler {
    weak var delegate: SAWKURLSchemeHandlerDelegate?
    private var urlSession: URLSession! = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(30)
        return URLSession.init(configuration: configuration, delegate: nil, delegateQueue: nil)
    } ()
    
    class func localFileURLFor(resourceURL: URL) -> URL? {
        let urlStr = resourceURL.absoluteString.lowercased()
        if urlStr == "http://images/back.gif" ||
            urlStr == "http://bbs.saraba1st.com/images/common/back.gif" {
            let url = Bundle.main.bundleURL.appendingPathComponent("static/image/common/back.gif")
            return url
        }
        
        guard let host = resourceURL.host else {
            return nil
        }
        
        let path = resourceURL.path
        let globalConfig = SAGlobalConfig()
        let mahjongDomain = globalConfig.mahjong_emoji_domain
        if host.caseInsensitiveCompare(mahjongDomain) == .orderedSame {
            if let range = path.range(of: "/image/smiley/"), range.lowerBound == path.startIndex {
                let component = path[range.upperBound ..< path.endIndex]
                let localFileURL = AppController.current.mahjongEmojiDirectory
                let localEmojiURL = localFileURL.appendingPathComponent(String(component))
                let fm = FileManager.default
                if fm.fileExists(atPath: localEmojiURL.path) {
                    return localEmojiURL
                }
            }
        }
        
        return nil
    }
    
    // We MUST assure that urlSchemeTask was released in main thread!!!
    // avoiding passing it as parameter to other functions.
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            makeTaskFail(task: urlSchemeTask)
            sa_log_v2("no url scheme request", log: .webView, type: .error)
            return
        }
        
        if url.host == SAURLSchemeHostType.image.rawValue {
            sa_log_v2("responds with image url", log: .webView, type: .debug, url as CVarArg)
            guard let imageKey = url.sa_queryString("url"), let resourceURL = URL(string: imageKey) else {
                makeTaskFail(task: urlSchemeTask)
                return
            }
            guard let data = delegate?.schemeHandlerRequestGetSavedImageData(self, fromURL: resourceURL) else {
                sa_log_v2("get downloaded image to disk failed url: %@", log: .webView, type: .error, url as CVarArg)
                makeTaskFail(task: urlSchemeTask)
                return
            }
            
            guard let _ = UIImage(data: data) else {
                let placeholderImageUrl = Bundle.main.url(forResource: "placeholder_format_not_supported", withExtension: "png")!
                responseTo(task: urlSchemeTask, withLocalFileURL: placeholderImageUrl, resourceURL: placeholderImageUrl)
                return
            }
            
            let mimeType = "image/\(resourceURL.pathExtension.lowercased())"
            let httpResponse = URLResponse.init(url: resourceURL, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: "UTF-8")
            urlSchemeTask.didReceive(httpResponse)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
            return
        }
        
        if url.host == SAURLSchemeHostType.failure.rawValue {
            sa_log_v2("responds with fail url", log: .webView, type: .error, url as CVarArg)
            let placeholderImageUrl = Bundle.main.url(forResource: "placeholderfail", withExtension: "png")!
            responseTo(task: urlSchemeTask, withLocalFileURL: placeholderImageUrl, resourceURL: placeholderImageUrl)
            return
        }
        
        if url.host == SAURLSchemeHostType.attachment.rawValue {
            sa_log_v2("responds with attachment url", log: .webView, type: .error, url as CVarArg)
            let placeholderImageUrl = Bundle.main.url(forResource: "placeholder_attachment", withExtension: "png")!
            responseTo(task: urlSchemeTask, withLocalFileURL: placeholderImageUrl, resourceURL: placeholderImageUrl)
            return
        }
        
        if url.host == SAURLSchemeHostType.imageFormatNotSupported.rawValue {
            sa_log_v2("responds with attachment url", log: .webView, type: .error, url as CVarArg)
            let placeholderImageUrl = Bundle.main.url(forResource: "placeholder_format_not_supported", withExtension: "png")!
            responseTo(task: urlSchemeTask, withLocalFileURL: placeholderImageUrl, resourceURL: placeholderImageUrl)
            return
        }
        
        // can only handle one of those host types
        if url.host != SAURLSchemeHostType.loading.rawValue {
            sa_log_v2("not loading or failure state. url: %@", log: .webView, type: .error, url as CVarArg)
            makeTaskFail(task: urlSchemeTask)
            return
        }
            
        guard let imgURLEncoded = url.sa_queryString("url")?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let resourceURL = URL.init(string: imgURLEncoded) else {
            makeTaskFail(task: urlSchemeTask)
            sa_log_v2("url scheme no url query. url is: %@", log: .webView, type: .error, url as CVarArg)
            return
        }
        
        if let localEmojiURL = SAWKURLSchemeHandler.localFileURLFor(resourceURL: resourceURL) {
            responseTo(task: urlSchemeTask, withLocalFileURL: localEmojiURL, resourceURL: resourceURL)
            return
        }
        
        guard let _ = resourceURL.host else {
            makeTaskFail(task: urlSchemeTask)
            sa_log_v2("url scheme no host. url is : %@", log: .webView, type: .error, resourceURL as CVarArg)
            return
        }
        
        if let cachedResponse = URLCache.shared.cachedResponse(for: URLRequest(url: resourceURL)) {
            if let mimetype = cachedResponse.response.mimeType, mimetype.contains("image") {
                sa_log_v2("hit image cache", log: .webView, type: .info)
                guard let _ = UIImage(data: cachedResponse.data) else {
                    let placeholderImageUrl = Bundle.main.url(forResource: "placeholder_format_not_supported", withExtension: "png")!
                    responseTo(task: urlSchemeTask, withLocalFileURL: placeholderImageUrl, resourceURL: placeholderImageUrl)
                    URLCache.shared.removeCachedResponse(for: URLRequest(url: resourceURL))
                    return
                }
                
                urlSchemeTask.didReceive(cachedResponse.response)
                urlSchemeTask.didReceive(cachedResponse.data)
                urlSchemeTask.didFinish()
                
                guard let _ = delegate?.schemeHandlerRequestSaveImageDataToDisk(self, data: cachedResponse.data, fromURL: resourceURL) else {
                    sa_log_v2("save downloaded file to disk failed url: %@", log: .webView, type: .error, url as CVarArg)
                    return
                }
                return
            }
        }
        
        // response with placeholder image first, and then download file
        let placeholderImageUrl = Bundle.main.url(forResource: "placeholder", withExtension: "png")!
        responseTo(task: urlSchemeTask, withLocalFileURL: placeholderImageUrl, resourceURL: resourceURL)
        
        var request = URLRequest.init(url: resourceURL)
        // Some site checks User-Agent string to prevent unpermitted image loading
        request.setValue(SAGlobalConfig().pc_useragent_string, forHTTPHeaderField: "User-Agent")
        let urlSessionTask = urlSession.dataTask(with: request, completionHandler: { [weak self] (data, response, error) in
            UIApplication.shared.hideNetworkIndicator()
            guard let delegate = self?.delegate else {
                sa_log_v2("delegate is nil", log: .webView, type: .info)
                return
            }
            
            let failureUrl = URL(string: "\(sa_wk_url_scheme)://\(SAURLSchemeHostType.failure.rawValue)?url=\(resourceURL.absoluteString.sa_formURLEncoded())")!
            guard let response = response as? HTTPURLResponse, let data = data else {
                sa_log_v2("failed to load: %@", log: .webView, type: .error, resourceURL as CVarArg)
                dispatch_async_main {
                    delegate.schemeHandlerRequestReloadHTMLPlaceholderImageTag(self, fromURL: url, toURL: failureUrl)
                }
                return
            }
            
            if response.statusCode < 200 || response.statusCode > 299 {
                sa_log_v2("failed to load: %@", log: .webView, type: .error, resourceURL as CVarArg)
                dispatch_async_main {
                    delegate.schemeHandlerRequestReloadHTMLPlaceholderImageTag(self, fromURL: url, toURL: failureUrl)
                }
                return
            }
            
            guard let _ = UIImage(data: data) else {
                let urlEncoded = resourceURL.absoluteString.sa_formURLEncoded()
                let attachmentURL = URL(string: "\(sa_wk_url_scheme)://\(SAURLSchemeHostType.imageFormatNotSupported.rawValue)?url=\(urlEncoded)")!
                dispatch_async_main {
                    delegate.schemeHandlerRequestReloadHTMLPlaceholderImageTag(self, fromURL: url, toURL: attachmentURL)
                }
                return
            }
            
            if let mimetype = response.mimeType, !mimetype.contains("image") {
                // not image file
                sa_log_v2("not image file url: %@", log: .webView, type: .error, resourceURL as CVarArg)
                let urlEncoded = resourceURL.absoluteString.sa_formURLEncoded()
                guard !urlEncoded.isEmpty else {
                    sa_log_v2("bad resourceURL: %@", log: .webView, type: .error, resourceURL as CVarArg)
                    return
                }
                
                guard let _ = delegate.schemeHandlerRequestSaveFileDataToDisk(self, data: data, fromURL: resourceURL) else {
                    sa_log_v2("save downloaded file to disk failed url: %@", log: .webView, type: .error, url as CVarArg)
                    return
                }
                
                // use attachment url, not `toURL`
                let attachmentURL = URL(string: "\(sa_wk_url_scheme)://\(SAURLSchemeHostType.attachment.rawValue)?url=\(urlEncoded)")!
                dispatch_async_main {
                    delegate.schemeHandlerRequestReloadHTMLPlaceholderImageTag(self, fromURL: url, toURL: attachmentURL)
                }
                return
            }
            
            // save image to cache directory
            guard let _ = delegate.schemeHandlerRequestSaveImageDataToDisk(self, data: data, fromURL: resourceURL) else {
                sa_log_v2("save downloaded image to disk failed url: %@", log: .webView, type: .error, url as CVarArg)
                return
            }
            
            sa_log_v2("saved downloaded image to disk image url: %@", log: .webView, type: .info, resourceURL as CVarArg)
            let urlQuery = resourceURL.absoluteString.sa_formURLEncoded()
            let imageUrl = URL.init(string: "\(sa_wk_url_scheme)://\(SAURLSchemeHostType.image.rawValue)?url=\(urlQuery)")!
            dispatch_async_main {
                delegate.schemeHandlerRequestReloadHTMLPlaceholderImageTag(self, fromURL: url, toURL: imageUrl)
            }
        })
        urlSessionTask.resume()
        UIApplication.shared.showNetworkIndicator()
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let url = urlSchemeTask.request.url?.absoluteString ?? ""
        sa_log_v2("url scheme task stopped request: %@", log: .webView, type: .info, url)
    }
    
    deinit {
        sa_log_v2("url scheme handler deinit", log: .webView, type: .info)
    }
    
    private func responseTo(task: WKURLSchemeTask, withLocalFileURL localEmojiURL: URL, resourceURL: URL) {
        sa_log_v2("url scheme task responded with local file: %@", localEmojiURL.lastPathComponent)
        guard let data = try? Data.init(contentsOf: localEmojiURL) else {
            let error = NSError.init(domain: SAGeneralErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"File Not Found at url: \(resourceURL.absoluteString)"])
            task.didFailWithError(error)
            return
        }
        
        let mimeType = "image/\(localEmojiURL.pathExtension.lowercased())"
        let httpResponse = URLResponse.init(url: resourceURL, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: "UTF-8")
        task.didReceive(httpResponse)
        task.didReceive(data)
        task.didFinish()
    }
    
    private func makeTaskFail(task: WKURLSchemeTask) {
        let error = NSError.init(domain: "Saralin", code: -1, userInfo: nil)
        task.didFailWithError(error)
    }
}
