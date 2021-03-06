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
            os_log("[ScriptHandler] %@", log: .webView, log)
        }
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
            os_log("[ScriptHandler] bad script message", type: .error)
            return
        }
        
        guard let _ = self.viewController as? SAThreadContentViewController else {
            os_log("[ScriptHandler] SAScriptWebPageHandler can only be installed on a SAThreadContentViewController", type: .error)
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
            
            URLSession.saCustomized.submitForm(formData: formData, actionURL: formActionURL) { (result, error) in
                guard error == nil else {
                    return
                }
                
                DispatchQueue.main.async {
                    message.webView?.evaluateJavaScript("reloadPoll();", completionHandler: nil)
                }
            }
        }
    }
}

class SAScriptImageLazyLoadHandler: SABaseScriptLogHandler {
    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let log = message.body as? String {
            os_log("[ScriptHandler] %@", log: .webView, log)
        }
    }
}

class SAScriptImageViewHandler: SABaseScriptLogHandler, UIDocumentInteractionControllerDelegate {
    var documentViewController: UIDocumentInteractionController?
    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        os_log("[SAScriptImageViewHandler]", log: .webView)
        guard let content = viewController as? SAThreadContentViewController else {
            return
        }
        
        guard let webView = message.webView else { return }
        guard let data = message.body as? [String:AnyObject] else {
            os_log("bad script content", log: .webView, type: .error)
            return
        }
        
        guard let rectDict = data["rect"] as? [String:Float] else { return }
        var frame = CGRect.init(x: CGFloat(rectDict["left"]!),
                                y: CGFloat(rectDict["top"]!),
                                width: CGFloat(rectDict["width"]!),
                                height: CGFloat(rectDict["height"]!))
        frame = insetFrameFromWebViewFrame(frame, webView: message.webView!)
        
        guard let selectedImageLink = data["url"] as? String, let _ = data["allimages"] as? [String] else {
            os_log("image data wrong!", log: .webView, type: .error)
            return
        }
        
        guard let originalUrl = URL.init(string: selectedImageLink) else {
            os_log("image url bad!", log: .webView, type: .error)
            return
        }
        
        let snapshot = webView.resizableSnapshotView(from: frame, afterScreenUpdates: false, withCapInsets: .zero)!
        snapshot.frame = webView.convert(frame, to: nil)
        
        if #available(iOS 11, *) {
            guard originalUrl.scheme == sa_wk_url_scheme else {
                os_log("unknown script message from sa custom url scheme url: %@", log: .webView, type: .error, originalUrl as CVarArg)
                return
            }
            
            guard let realUrlStr = originalUrl.sa_queryString("url"), let realUrl = URL.init(string: realUrlStr) else {
                os_log("image url bad! %@", log: .webView, type: .error, originalUrl as CVarArg)
                return
            }
            
            if originalUrl.host == SAURLSchemeHostType.attachment.rawValue {
                guard let attachmentURL = content.getSavedFilePath(of: realUrl) else {
                    os_log("attachment not found %@", log: .webView, type: .error, realUrl as CVarArg)
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
                        os_log("can not copy log file", type: .error)
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
                os_log("tap an image that fails to load, image url is %@", log: .webView, type: .error, originalUrl as CVarArg)
                // loading and failure url state only differs in their scheme.
                var loadingUrlComponents = URLComponents.init(url: originalUrl, resolvingAgainstBaseURL: false)
                loadingUrlComponents?.host = SAURLSchemeHostType.loading.rawValue
                if let loadingUrl = loadingUrlComponents?.url {
                    content.reloadHTMLPlaceholderImageTag(fromURL: originalUrl, toURL: loadingUrl)
                } else {
                    os_log("can not create loading url from image url: %@", log:.webView, type: .error, originalUrl as CVarArg)
                }
                return
            } else if originalUrl.host == SAURLSchemeHostType.imageFormatNotSupported.rawValue {
                os_log("tap an image that not supported, image url is %@", log: .webView, type: .error, originalUrl as CVarArg)
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
                        os_log("request new scene returned: %@", error.localizedDescription)
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
        os_log("[SAScriptImageViewHandler] report abuse", log: .webView)
        guard let info = message.body as? [String : String] else {
            os_log("bad script message", type: .error)
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
        os_log("[SAScriptImageViewHandler] report abuse user", log: .webView)
        guard let info = message.body as? [String : String] else {
            os_log("bad script message", type: .error)
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
        os_log("[SAScriptImageViewHandler] report abuse user", log: .webView)
        guard let info = message.body as? [String : String] else {
            os_log("bad script message", type: .error)
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
        os_log("[SAScriptThreadActionHandler] message", log: .webView)
        guard let info = message.body as? [String:String] else {
            return
        }
        
        guard let scriptAction = info["action"] else {
            return
        }
        
        guard let thread = self.viewController as? SAThreadContentViewController else {
            return
        }
        
        if scriptAction == "trigger_bottom_refreshing" {
            thread.enableBottomRefreshing = true
            os_log("[SAScriptImageViewHandler] enabled bottom refreshing", type: .info)
            return
        }
        
        if scriptAction == "quote_reply" {
            guard let replyID = info["replyID"],
                let rect = info["rect"],
                let replyTime = info["replyTime"],
                let replyAuthorName = info["replyAuthorName"] else {
                os_log("[SAScriptImageViewHandler] bad reply format!", type: .error)
                return
            }
            // add contentInset
            var frame = NSCoder.cgRect(for: rect)
            frame = insetFrameFromWebViewFrame(frame, webView: message.webView!)
            
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
            return
        }
        
        if scriptAction == "block_user" {
            guard let authorID = info["authorID"],
                let rect = info["rect"],
                let replyAuthorName = info["replyAuthorName"] else {
                os_log("[SAScriptImageViewHandler] bad reply format!", type: .error)
                return
            }
            // add contentInset
            var frame = NSCoder.cgRect(for: rect)
            frame = insetFrameFromWebViewFrame(frame, webView: message.webView!)
            
            thread.reportAbuseUser(authorID, name: replyAuthorName, fromElementAtFrame: frame)
            return
        }
        
        if scriptAction == "report_abuse" {
            guard let replyID = info["replyID"],
                let rect = info["rect"] else {
                os_log("[SAScriptImageViewHandler] bad reply format!", type: .error)
                return
            }
            // add contentInset
            var frame = NSCoder.cgRect(for: rect)
            frame = insetFrameFromWebViewFrame(frame, webView: message.webView!)
            
            thread.reportAbuse(replyID, fromElementAtFrame: frame)
            return
        }
    }
}


class SAScriptThreadReplyHandler: SABaseScriptLogHandler {
    override func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        os_log("[SAScriptThreadReplyHandler] reply", log: .webView)
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
            os_log("[SAScriptImageViewHandler] bad reply format!", type: .error)
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
        os_log("[SAScriptThreadDeleteHandler] reply", log: .webView, type: .debug)
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
        os_log("delete reply")
    }
}

class SAScriptThreadLoadMoreDataHandler: NSObject, WKScriptMessageHandlerWithReply {
    weak var viewController: UIViewController?
    init(viewController: UIViewController?) {
        super.init()
        self.viewController = viewController
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let body = message.body as? [String:Any] else {
            replyHandler(nil, "message contains no body")
            return
        }
        
        guard let page = body["page"] as? Int else {
            replyHandler(nil, "message contains no page parameter")
            return
        }
        
        guard let webview = message.webView else {
            replyHandler(nil, "no webview")
            return
        }
        
        guard let tid = webview.url?.sa_queryString("tid") else {
            os_log("thread page url tid is nil", log: .webView, type: .error)
            replyHandler(nil, "thread page url tid is nil")
            return
        }
        
        URLSession.saCustomized.getTopicContent(of: tid, page: page) { (result, error) in
            guard error == nil else {
                let errorMsg = error!.localizedDescription
                let result: [Any] = [errorMsg, false, NSNull(), NSNull(), NSNull()]
                replyHandler(result, nil)
                os_log("loadMoreDataAndInsertHTML failed", log: .webView, type: .error)
                return
            }

            guard let resultDict = result as? [String:AnyObject],
                let variables = resultDict["Variables"] as? [String:Any],
                var thread = variables["thread"] as? [String:AnyObject],
                let _ = thread["replies"] as? String,
                let postlist = variables["postlist"] as? [[String:AnyObject]],
                !postlist.isEmpty else {
                    var errorMsg = "当前帖子不存在、已被删除，或者你没有权限查看"
                    if let resultDict = result as? [String:AnyObject],
                        let message = resultDict["Message"] as? [String:AnyObject],
                        let messagestr = message["messagestr"] as? String, !messagestr.isEmpty {
                        errorMsg = messagestr
                    }
                let result: [Any] = [errorMsg, false, NSNull(), NSNull(), NSNull()]
                replyHandler(result, nil)
                os_log("loadMoreDataAndInsertHTML failed", log: .ui, type: .error)
                return
            }
            
            thread["formhash"] = variables["formhash"] as AnyObject
            let formhash = ((thread["formhash"] as? String) ?? "").sa_escapedStringForJavaScriptInput()
            
            SAThreadHTMLComposer.prepare(threadInfo: thread, postList: postlist, completion: { (content, parseError) in
                guard !content.isEmpty else {
                    let result: [Any] = [NSNull(), false, NSNull(), thread, formhash]
                    replyHandler(result, nil)
                    os_log("loadMoreDataAndInsertHTML failed", log: .webView, type: .error)
                    return
                }
                
                let result: [Any] = [NSNull(), false, content, thread, formhash]
                replyHandler(result, nil)
            })
        }
    }
}

class SAScriptThreadPollHandler: NSObject, WKScriptMessageHandlerWithReply {
    weak var viewController: UIViewController?
    init(viewController: UIViewController?) {
        super.init()
        self.viewController = viewController
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        guard let body = message.body as? [String:Any] else {
            replyHandler(nil, "message contains no body")
            return
        }
        
        guard let fid = body["fid"] as? String else {
            replyHandler(nil, "message body no fid")
            return
        }
         
        guard let tid = body["tid"] as? String else {
            replyHandler(nil, "message body no tid")
            return
        }

        var pollInfo: [String:AnyObject]?
        var pollOptions: [String:AnyObject]?
        let group = DispatchGroup()
        group.enter()
        URLSession.saCustomized.getPollInfo(of: tid) { (obj, error) in
            defer {
                group.leave()
            }
            
            guard error == nil else {
                os_log("get poll error: %@", log: .ui, type: .error, error!)
                return
            }
                        
            guard let result = obj as? [String:AnyObject] else {
                let error = NSError(domain: NSPOSIXErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Bad response from server."])
                os_log("%@", log: .ui, type: .error, error.localizedDescription)
                return
            }
            
            guard let success = result["success"] as? Int, success == 1 else {
                os_log("%@", log: .ui, type: .info, "no poll in this thread")
                return
            }
            pollInfo = result
            
            group.enter()
            URLSession.saCustomized.getPollOptions(of: tid) { (obj, error) in
                defer {
                    group.leave()
                }
                
                guard error == nil else {
                    os_log("get poll error: %@", log: .ui, type: .error, error!)
                    return
                }
                
                os_log("get poll result: %@", log: .ui, type: .debug, obj?.description ?? "")
                
                guard let result = obj as? [String:AnyObject] else {
                    let error = NSError(domain: NSPOSIXErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Bad response from server.[GetPoolOption]"])
                    os_log("%@", log: .ui, type: .error, error.localizedDescription)
                    return
                }
                
                pollOptions = result
            }
        }
        
        group.notify(queue: .main) {
            
            guard let pollInfoO = pollInfo, let pollOptionsO = pollOptions else {
                replyHandler(nil, "fail to fetch poll info")
                return
            }
            
            let pollContent = SAThreadHTMLComposer.createPollHTML(fid: fid, tid: tid, pollInfo: pollInfoO, pollOptions: pollOptionsO)
            if pollContent.isEmpty {
                replyHandler(nil, "fail to create poll html from data")
                return
            }
            
            replyHandler(pollContent, nil)
            os_log("reload poll finished", type: .info)
        }
    }
}
