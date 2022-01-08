//
//  SAThreadHTMLComposer.swift
//  Saralin
//
//  Created by zhang on 3/20/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import CoreData
import WebKit

let sa_wk_url_scheme = "sa-src"

private let reply_template = try! String(contentsOf: Bundle.main.url(forResource: "reply_template", withExtension: "html")!)

private let imgTagClickHandler = " referrerpolicy =\"no-referrer\" onclick=\"var postmessage = this; while(postmessage && postmessage.className != 'postmessage'){postmessage = postmessage.parentNode;}console.log(postmessage);var images = postmessage.getElementsByTagName('img');var srcList = [];for(var i = 0; i < images.length; i++) {var image = images[i]; if(image.width>50 && image.height>50) {srcList.push(images[i].src);}};if(srcList.length==0){srcList.push(this.src);};var rect = JSON.parse(JSON.stringify(this.getBoundingClientRect()));window.webkit.messageHandlers.imageview.postMessage({'rect':rect,'url':this.src,'allimages':srcList});return false;\" "

class SAThreadHTMLComposer {
    
    class func createPollHTML(fid: String, tid: String, pollInfo: [String:AnyObject], pollOptions:[String:AnyObject]) -> String {
        guard ((pollInfo["success"] as? Int) ?? 0) == 1,
            ((pollOptions["success"] as? Int) ?? 0) == 1,
            let pollInfoData = pollInfo["data"] as? [String:AnyObject],
            let pollOptionsData = pollOptions["data"] as? [[String:AnyObject]] else {
                return ""
        }
        
        let isMultipleChoice = ((pollInfoData["multiple"] as? Int) ?? 0) == 1
        let maxChoices = (pollInfoData["maxchoices"] as? Int) ?? 1
        let totalVotesCount = pollInfoData["voters"] as? Int ?? 0
        let voted = pollInfoData["voted"] as? Bool ?? false
        let expired = pollInfoData["expired"] as? Bool ?? false
        
        var pollHtmlContent = "<form id=\"poll\" method=\"post\" autocomplete=\"off\" onsubmit=\"submitPollForm(event);\" action=\"\(SAGlobalConfig().forum_base_url)forum.php?mod=misc&action=votepoll&fid=\(fid)&tid=\(tid)&pollsubmit=yes&quickforward=yes\">\n"
        pollHtmlContent.append("<legend name=\"\(maxChoices)\">投票信息(最多可选\(maxChoices)项)：</legend>\n")
        
        if voted {
            pollHtmlContent.append("<ul>\n")
        }
        
        for (n, d) in pollOptionsData.enumerated() {
            let votes = d["votes"] as? Int ?? 0
            let formattedPercentInfo = (voted || expired) ? String(format: "<br/><progress class='poll' max=\"%d\" value=\"%d\"> %.1f%% </progress> %d(%.1f%%)", totalVotesCount, votes, Float(votes)/Float(totalVotesCount) * 100, votes, Float(votes)/Float(totalVotesCount) * 100) : ""
            if isMultipleChoice {
                if voted || expired {
                    let checkbox = "<li>\(d["polloption"] as! String) \(formattedPercentInfo)</li>\n"
                    pollHtmlContent.append(checkbox)
                } else {
                    let checkbox = "<div><label><input type=\"checkbox\" name=\"pollanswers[]\" id=\"option_\(n + 1)\" value=\"\(d["polloptionid"] as! Int)\" onchange=\"handleRadioStateChange(event);\">\(d["polloption"] as! String) \(formattedPercentInfo) </label></div>\n"
                    pollHtmlContent.append(checkbox)
                }
            } else {
                if voted || expired {
                    let radio = "<li>\(d["polloption"] as! String) \(formattedPercentInfo) </li>\n"
                    pollHtmlContent.append(radio)
                } else {
                    let radio = "<div><label><input type=\"radio\" name=\"pollanswers[]\" id=\"option_\(n + 1)\" value=\"\(d["polloptionid"] as! Int)\" onchange=\"handleRadioStateChange(event);\">\(d["polloption"] as! String) \(formattedPercentInfo) </label></div>\n"
                    pollHtmlContent.append(radio)
                }
            }
        }
        
        if voted {
            pollHtmlContent.append("</ul>\n")
        }
                
        if voted {
            pollHtmlContent.append("<div><label>你已投票，共有\(totalVotesCount)人投票。</label></div>\n")
        } else if expired {
            pollHtmlContent.append("<div><label>投票已过期。</label></div>\n")
        } else {
            pollHtmlContent.append("<div><button type=\"submit\" disabled=\"true\">提交</button></div>\n")
        }
        pollHtmlContent.append("</form>")
        return pollHtmlContent
    }
    
    class func appendTail(threadInfo:[String:AnyObject], postList: [[String:AnyObject]], completion: ((String, NSError?) -> Void)?) {
        guard !postList.isEmpty else {
            sa_log_v2("empty post list", log: .webView, type: .error)
            DispatchQueue.main.async {
                completion?("", nil)
            }
            return
        }
        
        self.prepare(threadInfo: threadInfo, postList: postList) { (content, error) in
            guard error == nil else {
                completion?("", error!)
                return
            }
            
            completion?(content, nil)
        }
    }
    
    class func prepare(threadInfo: [String:AnyObject], postList: [[String:AnyObject]], completion: ((String, NSError?) -> Void)?) {
        guard !postList.isEmpty else {
            sa_log_v2("empty post list", log: .webView, type: .error)
            DispatchQueue.main.async {
                completion?("", nil)
            }
            return
        }
        
        let globalConfig = SAGlobalConfig()
        let account = Account()
        let coreDataManager = AppController.current.getService(of: SACoreDataManager.self)!
        let blockedUserIDs = coreDataManager.cache?.blockedUserIDs ?? []
        if blockedUserIDs.isEmpty {
            // FIXME: This maybe empty
            sa_log_v2("blocked user ids is empty", type: .info)
        }
        
        let url = AppController.current.userGroupInfoConfigFileURL
        let groupInfoDict = NSDictionary(contentsOf: url) as! [String:AnyObject]
        let groupInfo = groupInfoDict["items"] as! [[String:AnyObject]]
        
        let forumID = threadInfo["fid"] as! String
        let threadID = threadInfo["tid"] as! String
        let posterID = threadInfo["authorid"] as! String

        var content = ""
        postList.forEach { (reply) in
            var author = reply["author"] as! String
            let authorID = reply["authorid"] as! String
            let time = reply["dateline"] as! String
            
            if author.isEmpty {
                author = "匿名"
            }
            
            var message = ""
            if let msg = reply["message"] as? String {
                message = msg
            }
            
            guard let floorNumber = Int(reply["number"] as! String) else {
                return
            }
            
//            if floorNumber == 1 {
//                let pollContent = self.createPollHTML()
//                if !pollContent.isEmpty {
//                    message.append("<fieldset class='poll'>" + pollContent + "</fieldset>\n")
//                }
//            }
            
            let replyID = reply["pid"] as! String
            var groupID = reply["groupid"] as? String
            if groupID != nil {
                groupInfo.forEach({ (obj) in
                    if (obj["gid"] as! String) == groupID! {
                        groupID = obj["name"] as? String
                    }
                })
            }
            
            let adminID = reply["adminid"] as? String
            
            // There is a bug here: the server returns wrong <img> tag
            let goodBody = (message as NSString).mutableCopy() as! NSMutableString
            let re = try? NSRegularExpression(pattern: "<imgwidth=\"[0-9]*\"(\\s*height=\"[0-9]*\")?", options: [.anchorsMatchLines])
            let range = NSMakeRange(0, goodBody.length)
            re?.replaceMatches(in: goodBody, options: [], range: range, withTemplate: "<img")
            message = goodBody as String
            
            if let attachments = reply["attachments"] as? [String:[String:AnyObject]], attachments.count > 0 {
                message = message + "<div class=\"attachmenttitle\"><p>附件：</p></div>"
                attachments.forEach({ (attach) in
                    if let aUrl = attach.1["url"] as? String, let aAttach = attach.1["attachment"] as? String {
                        let picID = attach.0
                        let picUrl = aUrl + aAttach
                        if let range = message.range(of: "[attach]\(picID)[/attach]") {
                            message = message.replacingCharacters(in: range, with: "<img src='\(picUrl)' alt='' >")
                        }
                        else {
                            message = message + "<img src='\(picUrl)' alt='' >"
                        }
                    }
                })
            }
            
            var body = reply_template.replacingOccurrences(of: "${POST_BODY}", with: message)
            body = body.replacingOccurrences(of: "${GROUP_ID}", with: groupID != nil ? groupID! : "0")
            body = body.replacingOccurrences(of: "${ADMIN_ID}", with: adminID != nil ? adminID! : "0")
            
            body = body.replacingOccurrences(of: "${FLOOR_ID}", with: String(floorNumber))
            
            body = body.replacingOccurrences(of: "${AUTHOR_NAME}", with: author)
            
            if posterID == authorID {
                body = body.replacingOccurrences(of: "${POSTER_TITLE_DISPLAY}", with: "inline")
            } else {
                body = body.replacingOccurrences(of: "${POSTER_TITLE_DISPLAY}", with: "none")
            }
            body = body.replacingOccurrences(of: "${POST_TIME}", with: time)
            body = body.replacingOccurrences(of: "${FORUM_ID}", with: forumID)
            body = body.replacingOccurrences(of: "${REPLY_ID}", with: replyID)
            body = body.replacingOccurrences(of: "${THREAD_ID}", with: threadID)
            body = body.replacingOccurrences(of: "${AUTHOR_ID}", with: authorID)
            body = body.replacingOccurrences(of: "${REPLY_TIME}", with: time)
            body = body.replacingOccurrences(of: "${POLL_FORM_ACTION_URL}", with: "\(SAGlobalConfig().forum_base_url)forum.php?mod=misc&action=votepoll&fid=\(forumID)&tid=\(threadID)&pollsubmit=yes&quickforward=yes")

            //block
            var isBlocked = false
            for blockedUserID in blockedUserIDs {
                if blockedUserID == authorID {
                    isBlocked = true
                    break
                }
            }
            
            if isBlocked {
                body = body.replacingOccurrences(of: "${BLOCK_OVERLAY_DISPLAY_STYLE}", with: "flex")
                body = body.replacingOccurrences(of: "${BLOCK_WRAPPER_INLINE_STYLE}", with:"style='height: 80px;'")
            } else {
                body = body.replacingOccurrences(of: "${BLOCK_OVERLAY_DISPLAY_STYLE}", with: "none")
                body = body.replacingOccurrences(of: "${BLOCK_WRAPPER_INLINE_STYLE}", with:"")
            }
            
            //TODO: implement thread delete function
            body = body.replacingOccurrences(of: "${DELETE_DISPLAY_STYLE}", with: "none")
            
            if !account.isGuest {
                if account.uid == authorID {
                    body = body.replacingOccurrences(of: "${SEND_MESSAGE_DISPLAY_STYLE}", with: "none")
                } else  {
                    body = body.replacingOccurrences(of: "${SEND_MESSAGE_DISPLAY_STYLE}", with: "inline")
                }
            } else {
                body = body.replacingOccurrences(of: "${SEND_MESSAGE_DISPLAY_STYLE}", with: "none")
            }
            
            if !authorID.isEmpty {
                let avatarUrl =  globalConfig.avatar_base_url + "avatar.php?uid=\(authorID)&size=middle"
                body = body.replacingOccurrences(of: "${POSTER_AVATAR_URL}", with: avatarUrl)
            } else {
                body = body.replacingOccurrences(of: "${POSTER_AVATAR_URL}", with: globalConfig.avatar_base_url + "images/noavatar_middle.gif")
            }

            let authorLink = globalConfig.forum_base_url + "space-uid-\(authorID).html"
            body = body.replacingOccurrences(of: "${AUTHOR_PROFILE_HREF}", with: authorLink)
            body = body.replacingOccurrences(of: "${SEND_AUTHOR_MESSAGE_HREF}", with: globalConfig.forum_base_url + "home.php?mod=spacecp&ac=pm&touid=\(authorID)&pmid=0&daterange=2&pid=\(replyID)&mobile=1")
            
            // search for images & replace them
            let imageRE = try! NSRegularExpression(pattern: "<img src=['\"]([hH]ttps?://.*?)['\"].*?>", options: [])
            repeat {
                guard let result = imageRE.firstMatch(in: body as String, options: [], range: NSMakeRange(0, (body as NSString).length)) else {
                    break
                }
                
                guard result.numberOfRanges >= 2 else {
                    continue
                }
                
                let imgTagRange = result.range(at: 0)
                let imgSrcRange = result.range(at: 1)
                guard imgTagRange.location != NSNotFound, imgSrcRange.location != NSNotFound else {
                    continue
                }
                
                let imgSrcUrl = (body as NSString).substring(with: imgSrcRange).sa_stringByReplacingHTMLTags() as String
                let imgTagContent = (body as NSString).substring(with: imgTagRange)
                let isMahjongImage = imgTagContent.contains("smilieid=")
                let imgAttributes = isMahjongImage ? " smilieid=\"0\"" : imgTagClickHandler
                let saSchemedUrl = "\(sa_wk_url_scheme)://\(SAURLSchemeHostType.loading.rawValue)?url=\(imgSrcUrl.sa_formURLEncoded())"
                
                let range = Range.init(imgTagRange, in: body)!
                
                if isMahjongImage {
                    // do not show the placeholder image
                    if #available(iOS 11, *) {
                        var redirectedImageURL = isMahjongImage ? imgSrcUrl : saSchemedUrl
                        if let resourceURL = URL.init(string: imgSrcUrl),
                            let _ = SAWKURLSchemeHandler.localFileURLFor(resourceURL: resourceURL) {
                            redirectedImageURL = saSchemedUrl
                        }
                        body.replaceSubrange(range, with: "<img\(imgAttributes) data-src='\(redirectedImageURL)' src='mahjong_placeholder.png' alt='\(imgSrcUrl)' />")
                    } else {
                        body.replaceSubrange(range, with: "<img\(imgAttributes) data-src='\(imgSrcUrl)' src='mahjong_placeholder.png' alt='\(imgSrcUrl)' />")
                    }
                } else {
                    if #available(iOS 11, *) {
                        var redirectedImageURL = isMahjongImage ? imgSrcUrl : saSchemedUrl
                        if let resourceURL = URL.init(string: imgSrcUrl),
                            let _ = SAWKURLSchemeHandler.localFileURLFor(resourceURL: resourceURL) {
                            redirectedImageURL = saSchemedUrl
                        }
                        body.replaceSubrange(range, with: "<img\(imgAttributes) data-src='\(redirectedImageURL)' src = 'placeholder.png' alt='\(imgSrcUrl)' />")
                    } else {
                        body.replaceSubrange(range, with: "<img\(imgAttributes) data-src='\(imgSrcUrl)' src = 'placeholder.png' alt='\(imgSrcUrl)' />")
                    }
                }
                
            } while true
            
            content = content + body
        }
        
        DispatchQueue.main.async {
            completion?(content, nil)
        }
    }
}
