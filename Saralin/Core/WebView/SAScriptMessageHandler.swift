//
//  SAWKScriptMessageHandler.swift
//  Saralin
//
//  Created by zhang on 12/6/15.
//  Copyright © 2015 zaczh. All rights reserved.
//

import UIKit
import WebKit

extension WKScriptMessageHandler {
    func insetFrameFromWebViewFrame(_ frame: CGRect, webView: WKWebView) -> CGRect {
        var frame = frame
        if #available(iOS 11.0, *) {
            frame.origin.x += webView.scrollView.adjustedContentInset.left
            frame.origin.y += webView.scrollView.adjustedContentInset.top
        } else {
            // Fallback on earlier versions
            frame.origin.x += webView.scrollView.contentInset.left
            frame.origin.y += webView.scrollView.contentInset.top
        }
        return frame
    }
}

class SABaseScriptLogHandler: NSObject, WKScriptMessageHandler {
    weak var viewController: UIViewController?
    init(viewController: UIViewController?) {
        super.init()
        self.viewController = viewController
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let log = message.body as? String {
            sa_log_v2("[ScriptHandler] %@", module: .webView, log)
        }
    }
}

class SAScriptWebDataHandler: NSObject, WKScriptMessageHandler {
    weak var viewController: UIViewController?
    init(viewController: UIViewController?) {
        super.init()
        self.viewController = viewController
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let data = message.body as? [String:AnyObject] else {
            sa_log_v2("[ScriptHandler] bad script message", type: .error)
            return
        }
        
        guard let content = self.viewController as? SAThreadContentViewController else {
            sa_log_v2("[ScriptHandler] SAScriptWebDataHandler can only be installed on a SAThreadContentViewController", type: .error)
            return
        }
        
        content.webData = data
    }
}

class SAScriptWebPageHandler: NSObject, WKScriptMessageHandler {
    weak var viewController: UIViewController?
    init(viewController: UIViewController?) {
        super.init()
        self.viewController = viewController
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let data = message.body as? [String:AnyObject] else {
            sa_log_v2("[ScriptHandler] bad script message", type: .error)
            return
        }
        
        guard let content = self.viewController as? SAThreadContentViewController else {
            sa_log_v2("[ScriptHandler] SAScriptWebDataHandler can only be installed on a SAThreadContentViewController", type: .error)
            return
        }
        
        guard let action = data["action"] as? String else {
            return
        }
        
        if action == "submit" {
            guard let actionData = data["data"] as? [String:AnyObject],
                let formDataString = actionData["formData"] as? String,
                let formDataStringData = formDataString.data(using: .utf8),
                let formAction = actionData["formAction"] as? String else {
                return
            }
            
            guard let formData = try? JSONSerialization.jsonObject(with: formDataStringData, options: []) as? [String:AnyObject] else {
                return
            }
            
            guard let formActionURL = URL(string: formAction) else {
                return
            }
            
            URLSession.saCustomized.submitForm(formData: formData, actionURL: formActionURL) { [weak content] (result, error) in
                guard error == nil else {
                    return
                }
                
                DispatchQueue.main.async {
                    content?.refreshWebPollForm()
                }
            }
        }
    }
}

class SAScriptImageLazyLoadHandler: SABaseScriptLogHandler {
    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let log = message.body as? String {
            sa_log_v2("[ScriptHandler] %@", module: .webView, log)
        }
    }
}

class SAScriptImageViewHandler: SABaseScriptLogHandler, UIDocumentInteractionControllerDelegate {
    var documentViewController: UIDocumentInteractionController?
    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        sa_log_v2("[SAScriptImageViewHandler]", module: .webView)
        guard let content = viewController as? SAThreadContentViewController else {
            return
        }
        
        guard let webView = message.webView else { return }
        guard let data = message.body as? [String:AnyObject] else {
            sa_log_v2("bad script content", module: .webView, type: .error)
            return
        }
        
        guard let rectDict = data["rect"] as? [String:Float] else { return }
        var frame = CGRect.init(x: CGFloat(rectDict["left"]!),
                                y: CGFloat(rectDict["top"]!),
                                width: CGFloat(rectDict["width"]!),
                                height: CGFloat(rectDict["height"]!))
        frame = insetFrameFromWebViewFrame(frame, webView: message.webView!)
        
        guard let selectedImageLink = data["url"] as? String, let _ = data["allimages"] as? [String] else {
            sa_log_v2("image data wrong!", module: .webView, type: .error)
            return
        }
        
        guard let originalUrl = URL.init(string: selectedImageLink) else {
            sa_log_v2("image url bad!", module: .webView, type: .error)
            return
        }
        
        let snapshot = webView.resizableSnapshotView(from: frame, afterScreenUpdates: false, withCapInsets: .zero)!
        snapshot.frame = webView.convert(frame, to: nil)
        
        if #available(iOS 11, *) {
            guard originalUrl.scheme == sa_wk_url_scheme else {
                sa_log_v2("unknown script message from sa custom url scheme url: %@", module: .webView, type: .error, originalUrl as CVarArg)
                return
            }
            
            guard let realUrlStr = originalUrl.sa_queryString("url"), let realUrl = URL.init(string: realUrlStr) else {
                sa_log_v2("image url bad! %@", module: .webView, type: .error, originalUrl as CVarArg)
                return
            }
            
            if originalUrl.host == SAURLSchemeHostType.attachment.rawValue {
                guard let attachmentURL = content.getSavedFilePath(of: realUrl) else {
                    sa_log_v2("attachment not found %@", module: .webView, type: .error, realUrl as CVarArg)
                    return
                }
                
                let action = UIAlertController(title: NSLocalizedString("HINT", comment: "HINT"), message: NSLocalizedString("OPEN_ATTACHMENT_HINT_TEXT", comment: ""), preferredStyle: .actionSheet)
                let fileName = attachmentURL.lastPathComponent
                if !fileName.isEmpty {
                    action.message = action.message! + " " + NSLocalizedString("FILE_NAME", comment: "") + ": \(fileName)"
                }
                action.popoverPresentationController?.sourceView = content.webView
                action.popoverPresentationController?.sourceRect = frame
                action.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))
                action.addAction(UIAlertAction(title: NSLocalizedString("OPEN", comment: ""), style: .default, handler: { [weak self] (action) in
                    // copy file to temp first
                    let tempFileName = NSTemporaryDirectory() + "/\(attachmentURL.lastPathComponent)"
                    let tempFileURL = URL.init(fileURLWithPath: tempFileName, isDirectory: false)
                    try? FileManager.default.removeItem(atPath: tempFileURL.path)
                    do {
                        try FileManager.default.copyItem(atPath: attachmentURL.path, toPath: tempFileName)
                    } catch {
                        sa_log_v2("can not copy log file", type: .error)
                        return
                    }
                    let documentViewController = UIDocumentInteractionController.init(url: tempFileURL)
                    documentViewController.delegate = self
                    documentViewController.presentOpenInMenu(from: frame, in: content.webView, animated: true)
                    self?.documentViewController = documentViewController
                }))
                viewController?.present(action, animated: true, completion: nil)
                return
            } else if originalUrl.host == SAURLSchemeHostType.failure.rawValue {
                sa_log_v2("tap an image that fails to load, image url is %@", module: .webView, type: .error, originalUrl as CVarArg)
                // loading and failure url state only differs in their scheme.
                var loadingUrlComponents = URLComponents.init(url: originalUrl, resolvingAgainstBaseURL: false)
                loadingUrlComponents?.host = SAURLSchemeHostType.loading.rawValue
                if let loadingUrl = loadingUrlComponents?.url {
                    content.reloadHTMLPlaceholderImageTag(fromURL: originalUrl, toURL: loadingUrl)
                } else {
                    sa_log_v2("can not create loading url from image url: %@", module:.webView, type: .error, originalUrl as CVarArg)
                }
                return
            }
            
            var fullSize: UIImage?
            if let data = content.getSavedImageData(fromURL: realUrl) {
                fullSize = UIImage.init(data: data)
            }
            
            if #available(iOS 13.0, *) {
                if UIApplication.shared.supportsMultipleScenes && ((Account().preferenceForkey(.enable_multi_windows) as? Bool) ?? false) {
                    var userInfo:[String:AnyObject] = [:]
                    userInfo["url"] = realUrl as AnyObject
                    userInfo["fullSizeImageData"] = data as AnyObject

                    let userActivity = NSUserActivity(activityType: SAActivityType.viewImage.rawValue)
                    userActivity.isEligibleForHandoff = true
                    userActivity.title = SAActivityType.viewImage.title()
                    userActivity.userInfo = userInfo
                    let options = UIScene.ActivationRequestOptions()
                    options.requestingScene = webView.window?.windowScene
                    UIApplication.shared.requestSceneSessionActivation(AppController.current.findSceneSession(), userActivity: userActivity, options: options) { (error) in
                        sa_log_v2("request new scene returned: %@", error.localizedDescription)
                    }
                } else {
                    // Fallback on earlier versions
                    let imageViewer = ImageViewController()
                    imageViewer.config(imageURL: realUrl, thumbnailImage: nil, fullSizeImage: fullSize, transitioningView: snapshot)
                    viewController?.present(imageViewer, animated: true, completion: nil)
                }
            } else {
                // Fallback on earlier versions
                let imageViewer = ImageViewController()
                imageViewer.config(imageURL: realUrl, thumbnailImage: nil, fullSizeImage: fullSize, transitioningView: snapshot)
                viewController?.present(imageViewer, animated: true, completion: nil)
            }
            
        } else {
            // does not support wk url scheme
            var fullSize: UIImage?
            if let data = URLCache.shared.cachedResponse(for: URLRequest.init(url: originalUrl))?.data {
                fullSize = UIImage.init(data: data)
            }
            let imageViewer = ImageViewController()
            imageViewer.config(imageURL: originalUrl, thumbnailImage: nil, fullSizeImage: fullSize, transitioningView: snapshot)
            viewController?.present(imageViewer, animated: true, completion: nil)
        }
    }
    
    // Document View
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return viewController!
    }
}

class SAScriptReportAbuseHandler: SABaseScriptLogHandler {
    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        sa_log_v2("[SAScriptImageViewHandler] report abuse", module: .webView)
        guard let info = message.body as? [String : String] else {
            sa_log_v2("bad script message", type: .error)
            return
        }
        let rid = info["replyID"]
        
        let left = info["left"]!
        let top = info["top"]!
        let width = info["width"]!
        let height = info["height"]!
        
        var frame = NSCoder.cgRect(for: "{{\(left),\(top)},{\(width),\(height)}}")
        frame = insetFrameFromWebViewFrame(frame, webView: message.webView!)
        
        if let threadViewer = viewController as? SAThreadContentViewController {
            threadViewer.reportAbuse(rid!, fromElementAtFrame: frame)
        }
    }
}

class SAScriptReportAbuseUserHandler: SABaseScriptLogHandler {
    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        sa_log_v2("[SAScriptImageViewHandler] report abuse user", module: .webView)
        guard let info = message.body as? [String : String] else {
            sa_log_v2("bad script message", type: .error)
            return
        }
        let rid = info["authorID"]
        let replierName = info["replyAuthorName"]
        
        let left = info["left"]!
        let top = info["top"]!
        let width = info["width"]!
        let height = info["height"]!
        
        var frame = NSCoder.cgRect(for: "{{\(left),\(top)},{\(width),\(height)}}")
        frame = insetFrameFromWebViewFrame(frame, webView: message.webView!)
        
        if let threadViewer = viewController as? SAThreadContentViewController {
            threadViewer.reportAbuseUser(rid!, name: replierName!, fromElementAtFrame: frame)
        }
    }
}

class SAScriptUnblockAbuseUserHandler: SABaseScriptLogHandler {
    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        sa_log_v2("[SAScriptImageViewHandler] report abuse user", module: .webView)
        guard let info = message.body as? [String : String] else {
            sa_log_v2("bad script message", type: .error)
            return
        }
        let rid = info["authorID"]
        let replierName = info["replyAuthorName"]
        
        let left = info["left"]!
        let top = info["top"]!
        let width = info["width"]!
        let height = info["height"]!
        
        // add contentInset
        var frame = NSCoder.cgRect(for: "{{\(left),\(top)},{\(width),\(height)}}")
        frame = insetFrameFromWebViewFrame(frame, webView: message.webView!)
        
        if let threadViewer = viewController as? SAThreadContentViewController {
            threadViewer.unblockAbuseUser(rid!, name: replierName!, fromElementAtFrame: frame)
        }
    }
}

class SAScriptThreadActionHandler: SABaseScriptLogHandler {
    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        sa_log_v2("[SAScriptThreadActionHandler] message", module: .webView)
        guard let info = message.body as? [String:String] else {
            return
        }
        
        guard let replyID = info["replyID"],
            let authorID = info["authorID"],
            let rect = info["rect"],
            let replyTime = info["replyTime"],
            let replyAuthorName = info["replyAuthorName"] else {
            sa_log_v2("[SAScriptImageViewHandler] bad reply format!", type: .error)
            return
        }
        
        guard let thread = self.viewController as? SAThreadContentViewController else {
            return
        }
        
        // add contentInset
        var frame = NSCoder.cgRect(for: rect)
        frame = insetFrameFromWebViewFrame(frame, webView: message.webView!)
        
        let action = UIAlertController(title: NSLocalizedString("THREAD_ACTION_CHOOSE", comment: "Please choose an action"), message: nil, preferredStyle: .actionSheet)
        action.popoverPresentationController?.sourceView = thread.webView
        action.popoverPresentationController?.sourceRect = frame
        action.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))
        action.addAction(UIAlertAction(title: NSLocalizedString("THREAD_ACTION_REPLY", comment: "Reply"), style: .default, handler: { (action) in
            thread.webView?.evaluateJavaScript("(function(){var a = document.getElementById('postmessage_' + \(replyID));return(a.textContent);})();", completionHandler: { (result, error) in
                guard error == nil else {
                    return
                }
                
                guard var content = result as? String else {
                    return
                }
                content = content.replacingOccurrences(of: "\n", with: " ")
                
                thread.replyByQuoteReplyOfID(replyID, time: replyTime, authorName: replyAuthorName, replyContent: content)
            })
        }))
        
        action.addAction(UIAlertAction(title: NSLocalizedString("THREAD_ACTION_SEND_DM", comment: "THREAD_ACTION_SEND_DM"), style: .default, handler: { (action) in
            thread.sendDM(to: authorID, name: replyAuthorName)
        }))
        
        action.addAction(UIAlertAction(title: NSLocalizedString("THREAD_ACTION_BLOCK", comment: "THREAD_ACTION_BLOCK"), style: .destructive, handler: { (action) in
            thread.reportAbuseUser(authorID, name: replyAuthorName, fromElementAtFrame: frame)
        }))
        action.addAction(UIAlertAction(title: NSLocalizedString("THREAD_ACTION_REPORT", comment: "THREAD_ACTION_REPORT"), style: .destructive, handler: { (action) in
            thread.reportAbuse(replyID, fromElementAtFrame: frame)
        }))
        viewController?.present(action, animated: true, completion: nil)
    }
}


class SAScriptThreadReplyHandler: SABaseScriptLogHandler {
    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        sa_log_v2("[SAScriptThreadReplyHandler] reply", module: .webView)
        guard var info = message.body as? [String:String] else {
            return
        }
        
        let replyID = info["replyID"]
        let replyTime = info["replyTime"]
        
        //reply to post owner
        if replyID == nil {
            return
        }
        //reply to replier
        let authorName = info["replyAuthorName"]
        guard replyID != nil && authorName != nil else {
            sa_log_v2("[SAScriptImageViewHandler] bad reply format!", type: .error)
            return;
        }
        
        let thread = viewController as? SAThreadContentViewController
        thread?.webView?.evaluateJavaScript("(function(){var a = document.getElementById('postmessage_' + \(replyID!));return(a.textContent);})();", completionHandler: { (result, error) in
            guard error == nil else {
                return
            }
            
            guard var content = result as? String else {
                return
            }
            content = content.replacingOccurrences(of: "\n", with: " ")
            info["quote_textcontent"] = content
            
            thread?.replyByQuoteReplyOfID(replyID!, time: replyTime!, authorName: authorName!, replyContent: content)
        })
    }
}

class SAScriptThreadDeleteHandler: SABaseScriptLogHandler {
    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        sa_log_v2("[SAScriptThreadDeleteHandler] reply", module: .webView, type: .debug)
        guard message.body is [String:String] else {
            return
        }
        
        //'replyID':'${REPLY_ID}','threadID':'${THREAD_ID}','floorID':'${FLOOR_ID}','forumID':'${FORUM_ID}
//        guard let replyID = info["replyID"] else {
//            return
//        }
//        
//        let threadID = info["threadID"]
//        let forumID = info["forumID"]

        //TODO: DELETE REPLY
        sa_log_v2("delete reply")
    }
}

class SAScriptThreadLoadMoreDataHandler: SABaseScriptLogHandler {
    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String:Any] else {
            return
        }
        
        guard let downward = body["downward"] as? Bool else {
            return
        }
        
        guard let callbackIndex = body["callbackIndex"] as? Int else {
            return
        }
        
        if let thread = viewController as? SAThreadContentViewController {
            thread.loadMoreDataAndInsertHTML(downward: downward, callbackIndex: callbackIndex)
        }
        
    }
}
