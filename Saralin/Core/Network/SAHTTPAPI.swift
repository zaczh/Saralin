//
//  SAHTTPAPI.swift
//  Saralin
//
//  Created by zhang on 3/19/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

extension URLSession {
    static var kGlobalConfig = ""
    private var globalConfig: SAGlobalConfig! {
        if let config = objc_getAssociatedObject(self, &URLSession.kGlobalConfig) as? SAGlobalConfig {
            return config
        }
        
        let config = SAGlobalConfig()
        objc_setAssociatedObject(self, &URLSession.kGlobalConfig, config, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return config
    }
    
    /// The system `shared` session has problems that in some cases, the completion block not been called.
    /// We need to create our own session.
    static var saCustomized: URLSession {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        let urlSession = URLSession.init(configuration: sessionConfig)
        return urlSession
    }
    
    private func getFormHash(url: URL?, completion: @escaping (String?) -> Void) -> URLSessionTask? {
        let aurl = url ?? URL(string: globalConfig.forum_base_url)!
        let task = dataTask(with: aurl) { (data, response, error) in
            guard error == nil, data != nil,
                let str = String(data: data!, encoding: String.Encoding.utf8),
                let parser = try? HTMLParser.init(string: str) else {
                    completion(nil)
                    return
            }
            
            if let formhashElement = parser.body()?.findChild(withAttribute: "name", matchingName: "formhash", allowPartial: false), let formhash = formhashElement.getAttributeNamed("value") {
                completion(formhash)
                return
            }
            completion(nil)
        }
        task.resume()
        return task
    }
    
    /// The login API
    /// - Parameter username: <#username description#>
    /// - Parameter password: <#password description#>
    /// - Parameter completion: <#completion description#>
    /// - Parameter questionid: 0: 安全提问(未设置请忽略) 1: 母亲的名字 2: 爷爷的名字 3: 父亲出生的城市 4: 您其中一位老师的名字 5: 您个人计算机的型号 6: 您最喜欢的餐馆名称 7: 驾驶执照最后四位数字
    /// - Parameter answer: <#answer description#>
    /// - Returns: <#description#>
    
    /*
     Demo:
     Query String Parameters
     mod: logging
     action: login
     loginsubmit: yes
     handlekey: login
     loginhash: Lbygs
     inajax: 1

     Request Data
     MIME Type: application/x-www-form-urlencoded
     formhash: ac9f22c9
     referer: https://bbs.saraba1st.com/2b/thread-1956764-1-1.html
     loginfield: username
     username: xxxxxx
     password: xxxxxx
     questionid: 3
     answer: xxxx
     loginsubmit: true

     */
    @discardableResult
    func login(username: String, password: String, questionid: String?, answer: String?, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let refererUrl = URL(string: globalConfig.forum_base_url + "thread-1956764-1-1.html")!
        let formHashUrl = URL(string: globalConfig.forum_base_url + "member.php?mod=logging&action=login&infloat=yes&handlekey=login&inajax=1&ajaxtarget=fwin_content_login")!
        return getFormHash(url: formHashUrl) { [weak self] (formhash) in
            guard let self = self else {
                return
            }
            
            guard let formhash = formhash, !formhash.isEmpty else {
                let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"bad response from server"])
                self.handleObjectResult(nil, error: error, completion: completion)
                return
            }
            
            let url = "member.php?mod=logging&action=login&loginsubmit=yes&handlekey=login&loginhash=Lbygs&inajax=1"
            guard let aurl = URL(string: url, relativeTo: URL(string: self.globalConfig.forum_base_url)!) else {
                fatalError()
            }
            sa_log_v2("login url: %@", log: .network, type: .debug, aurl as CVarArg)
            
            var request = URLRequest(url: aurl)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue(self.globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
            request.setValue(refererUrl.absoluteString, forHTTPHeaderField: "Referer")

            let parameters:[(String, String)] = [
                ("formhash", formhash),
                ("referer", refererUrl.absoluteString),
                ("loginfield", "username"),
                ("username", username),
                ("password", password),
                ("questionid", questionid ?? ""),
                ("answer", answer ?? ""),
                ("loginsubmit", "1"),
                ("cookietime", "2592000"),
            ]
            
            let queries = NSMutableArray()
            for (key, value) in parameters {
                queries.add("\(key.sa_formURLEncoded())=\(value.sa_formURLEncoded())")
            }
            let query = queries.componentsJoined(by: "&")
            let queryData = query.data(using: String.Encoding.utf8, allowLossyConversion: false)! as NSData
            request.httpBody = queryData as Data
            request.setValue("\(queryData.length)", forHTTPHeaderField: "Content-Length")

            UIApplication.shared.showNetworkIndicator()
            let task = self.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
                self.handleHTMLResult(response, data: data, error: error as NSError?, completion: completion)
                UIApplication.shared.hideNetworkIndicator()
            })
            task.resume()
        }
    }
    
    /*
     
     {
       "success" : true,
       "message" : "登录成功",
       "code" : 200,
       "data" : {
         "uid" : "228812",
         "username" : "everfly",
         "sid" : "E8TMd2"
       }
     }
     
     */
    //returns a json object
    @discardableResult
    func loginV2(username: String, password: String, questionid: String, answer: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let aurl = URL(string: globalConfig.forum_app_api_domain + "/user/login")!
        sa_log_v2("loginV2 url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        let boundary = "---------------------------\(request.hashValue)"
         request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
         request.setValue("application/json", forHTTPHeaderField: "Accept")
         request.httpMethod = "POST"
         
         let data = NSMutableData()
         let parameters = [("placeholder", "\n"), ("username", username), ("password", password), ("questionid", questionid), ("answer", answer)]
         for (name, value) in parameters {
             data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
             data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: String.Encoding.utf8)!)
             data.append("\(value)\r\n".data(using: String.Encoding.utf8)!)
         }
         data.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)
         request.httpBody = data as Data
         request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
            UIApplication.shared.hideNetworkIndicator()
        })
        task.resume()
        return task
    }
    
    //returns a json object
    @discardableResult
    func auth(_ completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let url = "api/mobile/index.php?module=login"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("auth url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
            UIApplication.shared.hideNetworkIndicator()
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func getTopicList(of fid: String, typeid: String?, page: Int, orderby:String?, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        var url = "api/mobile/index.php?module=forumdisplay&version=1&tpp=\(globalConfig.number_of_threads_per_page)&submodule=checkpost&mobile=no&page=\(page)&fid=\(fid)&orderby=\(orderby ?? "dateline")"
        if typeid != nil {
            url += "&filter=typeid&typeid=\(typeid!)"
        }
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("getTopicList url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
            UIApplication.shared.hideNetworkIndicator()
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func getPollInfo(of tid: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let aurl = URL(string: globalConfig.forum_app_api_domain + "/poll/poll")!
        sa_log_v2("getPoll url: %@", log: .network, type: .debug, aurl as CVarArg)
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        let boundary = "---------------------------\(request.hashValue)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let auth = Account().sid
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        
        let data = NSMutableData()
        let parameters = [("placeholder", "\n"), ("sid", auth), ("tid", tid)]
        for (name, value) in parameters {
            data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: String.Encoding.utf8)!)
            data.append("\(value)\r\n".data(using: String.Encoding.utf8)!)
        }
        data.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)
        request.httpBody = data as Data
        request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
            UIApplication.shared.hideNetworkIndicator()
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func getPollOptions(of tid: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let aurl = URL(string: globalConfig.forum_app_api_domain + "/poll/options")!
        sa_log_v2("getPoll url: %@", log: .network, type: .debug, aurl as CVarArg)
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        let boundary = "---------------------------\(request.hashValue)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let auth = Account().sid
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        
        let data = NSMutableData()
        let parameters = [("placeholder", "\n"), ("sid", auth), ("tid", tid)]
        for (name, value) in parameters {
            data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: String.Encoding.utf8)!)
            data.append("\(value)\r\n".data(using: String.Encoding.utf8)!)
        }
        data.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)
        request.httpBody = data as Data
        request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
            UIApplication.shared.hideNetworkIndicator()
        })
        task.resume()
        return task
    }
    
    func sendPollOption(of tid: String, options: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let aurl = URL(string: globalConfig.forum_app_api_domain + "/poll/vote")!
        sa_log_v2("sendPollOption url: %@", log: .network, type: .debug, aurl as CVarArg)
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        let boundary = "---------------------------\(request.hashValue)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let auth = Account().sid
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        
        let data = NSMutableData()
        let parameters = [("placeholder", "\n"), ("sid", auth), ("tid", tid), ("options", options)]
        for (name, value) in parameters {
            data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: String.Encoding.utf8)!)
            data.append("\(value)\r\n".data(using: String.Encoding.utf8)!)
        }
        data.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)
        request.httpBody = data as Data
        request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
            UIApplication.shared.hideNetworkIndicator()
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func getBoardsSummary(completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let aurl = URL(string: globalConfig.forum_app_api_domain + "/forum/all")!
        sa_log_v2("getTopicList url: %@", log: .network, type: .debug, aurl as CVarArg)
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        let boundary = "---------------------------\(request.hashValue)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        
        let data = NSMutableData()
        let parameters = [("placeholder", "")]
        for (name, value) in parameters {
            data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: String.Encoding.utf8)!)
            data.append("\(value)\r\n".data(using: String.Encoding.utf8)!)
        }
        data.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)
        request.httpBody = data as Data
        request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
            UIApplication.shared.hideNetworkIndicator()
        })
        task.resume()
        return task
    }
    
    ///
    /// - Parameter uid: <#uid description#>
    /// - Parameter completion: <#completion description#>
    @discardableResult
    func getThreadsOf(uid: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        sa_log_v2("getThreadsOf uid: %@", log: .network, type: .debug, uid as CVarArg)
        guard !uid.isEmpty else {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Need login."])
            self.handleObjectResult(nil, error: error, completion: completion)
            return nil
        }
        
        let url = URL(string: globalConfig.user_threads_url_template.replacingOccurrences(of: "%{UID}", with: uid))!
        var request = URLRequest.init(url: url)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue(globalConfig.forum_url, forHTTPHeaderField: "Referer")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) in
            UIApplication.shared.hideNetworkIndicator()
            self.handleHTMLResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    /// Get User Infomation
    ///
    ///
    /// - Parameters:
    ///   - uid: uid of user to query
    ///   - completion: the body of html, or error if error occured (completion handler was not called on main thread)
    @discardableResult
    func getUserInfoOf(uid: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        sa_log_v2("getUserInfoOf uid: %@", log: .network, type: .debug, uid as CVarArg)
        guard !uid.isEmpty else {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Need login."])
            self.handleObjectResult(nil, error: error, completion: completion)
            return nil
        }
        
        let url = URL(string: globalConfig.profile_url_template.replacingOccurrences(of: "%{UID}", with: uid))!
        var request = URLRequest.init(url: url)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue(globalConfig.forum_url, forHTTPHeaderField: "Referer")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) in
            UIApplication.shared.hideNetworkIndicator()
            self.handleHTMLResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    
    /// The forum searching API
    /// Two-step, Need Log-in
    /// - Parameter keywords: <#keywords description#>
    /// - Parameter previousResult: <#previousResult description#>
    /// - Parameter completion: <#completion description#>
    @discardableResult
    func searchThreads(with keywords: String, previousResult: AnyObject?, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        guard !Account().isGuest else {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"you need to log in before searching"])
            self.handleObjectResult(nil, error: error, completion: completion)
            return nil
        }
        
        let url = "search.php?mod=forum"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("searchThreads url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        return getFormHash(url: aurl) { (formhash) in
            if let formhash = formhash, !formhash.isEmpty {
                _ = self.doSearchThreads(with: keywords, formhash: formhash, previousResult: previousResult, completion: completion)
                return
            }
            
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"bad response from server"])
            self.handleObjectResult(nil, error: error, completion: completion)
        }
    }
    
    /// Search API step two
    private func doSearchThreads(with keywords: String, formhash: String, previousResult: AnyObject?, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let url = "search.php?mod=forum"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        if previousResult != nil {
            if let previousPageInfo = previousResult?["pageInfo"] as? [String:String], let url = previousPageInfo["nextPageUrl"] {
                guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
                    fatalError()
                }
                sa_log_v2("searchThreads load more url: %@", log: .network, type: .debug, aurl as CVarArg)
                request.url = aurl
            } else {
                sa_log_v2("searchThreads no more data", log: .network, type: .debug)
                let obj = ["results":[] as [[String:String]]] as AnyObject
                self.handleObjectResult(obj, error: nil, completion: completion)
                return nil
            }
        } else {
            if keywords.isEmpty {
                let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"empty search text"])
                self.handleObjectResult(nil, error: error, completion: completion)
                return nil
            }
            
            request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            let data = NSMutableData()
            data.append("searchsubmit=yes&srchtxt=\(keywords.sa_formURLEncoded())&formhash=\(formhash)".data(using: .utf8)!)
            request.httpBody = data as Data
            request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        }
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            guard error == nil, data != nil,
                let str = String(data: data!, encoding: String.Encoding.utf8),
                let parser = try? HTMLParser.init(string: str) else {
                    let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Bad response from server, not html string."])
                    self.handleObjectResult(nil, error: error, completion: completion)
                    return
            }
            
            var data: [[String:String]] = []
            parser.body()?.findChild(withAttribute: "id", matchingName: "threadlist", allowPartial: true)?.findChildTags("li").forEach({ (dl) in
                var adata: [String:String] = [:]
                
                let children = dl.children()
                guard children.count > 7 else {
                    return
                }
                
                let xs3 = children[1]
                let xs3_a = xs3.findChildTag("a")
                let xs3_a_href = xs3_a?.getAttributeNamed("href") // thread-1648214-1-1.html
                let xs3_a_content = xs3_a?.allContents() // 程一起就够了
                adata["thread-title"] = xs3_a_content ?? ""
                adata["thread-link"] = xs3_a_href ?? ""
                
                let xg1 = children[3]
                let xg1_content = xg1.allContents() //35 个回复 - 2928 次查看
                guard let xg1_content_components = xg1_content?.components(separatedBy: " "), xg1_content_components.count > 3 else {
                    return
                }
                let xg1_content_reply = xg1_content_components.first
                let xg1_content_view = xg1_content_components[3]
                adata["view-count"] = xg1_content_view
                adata["reply-count"] = xg1_content_reply ?? ""
                
                let p0 = children[5]
                let p0_content = p0.contents() //如题 上油管看各类评测，基本上2560*1440都是叫1440p或者QuadHD...
                let p1 = children[7]
                let p1_children = p1.children()
                guard p1_children.count > 5 else {
                    return
                }
                let p1_span0 = p1_children[1]
                let p1_span0_time = p1_span0.contents() // 2017-12-3 20:14
                adata["thread-abstract"] = p0_content ?? ""
                adata["date"] = p1_span0_time ?? ""
                
                let p1_span1 = p1_children[3]
                if p1_span1.children().count > 1 {
                    let p1_span1_a = p1_span1.children()[1]
                    let p1_span1_a_href = p1_span1_a.getAttributeNamed("href") // space-uid-202207.html
                    let p1_span1_a_content = p1_span1_a.contents() // kiyu
                    adata["author-link"] = p1_span1_a_href ?? ""
                    adata["author-name"] = p1_span1_a_content ?? ""
                } else  {
                    // anonymous thread
                }
                
                let p1_span2 = p1_children[5]
                guard p1_span2.children().count > 0 else {
                    return
                }
                let p1_span2_a = p1_span2.children()[0]
                let p1_span2_a_href = p1_span2_a.getAttributeNamed("href")
                let p1_span2_a_content = p1_span2_a.contents() // PC数码
                adata["category-name"] = p1_span2_a_content ?? ""
                adata["category-link"] = p1_span2_a_href ?? ""
                data.append(adata)
            })
            
            var pageInfo = [String:String]()
            if let e_nxt = parser.body()?.findChild(withAttribute: "class", matchingName: "nxt", allowPartial: true) {
                pageInfo["nextPageUrl"] = e_nxt.getAttributeNamed("href")
            }
            
            let dict: [String:AnyObject] = ["results": data as AnyObject, "pageInfo": pageInfo as AnyObject]
            self.handleObjectResult(dict as AnyObject, error: nil, completion: completion)
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func getTopicContent(of topicID: String, page: Int, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let url = "api/mobile/index.php?module=viewthread&version=1&ppp=\(globalConfig.number_of_replies_per_page)&submodule=checkpost&mobile=no&tid=\(topicID)&page=\(page)"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("getTopicContent url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func favorite(forum: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        // TODO: implementation needed!!!
        return nil
    }
    
    @discardableResult
    func getHistoryMessage(with uid: String, page: Int, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        guard !Account().isGuest else {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Need login."])
            self.handleObjectResult(nil, error: error, completion: completion)
            return nil
        }
        
        let url = "api/mobile/index.php?module=mypm&version=1&subop=view&touid=\(uid)&page=\(page)&mobile=no"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("getHistoryMessage url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func getComposedThreads(page: Int, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        guard !Account().isGuest else {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Need login."])
            self.handleObjectResult(nil, error: error, completion: completion)
            return nil
        }
        
        let url = "api/mobile/index.php?module=mythread&version=1&page=\(page)&mobile=no"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("getComposedThreads url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
            UIApplication.shared.hideNetworkIndicator()
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func getMessageList(page: Int, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        guard !Account().isGuest else {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Need login."])
            self.handleObjectResult(nil, error: error, completion: completion)
            return nil
        }
        
        let url = "api/mobile/index.php?module=mypm&version=1&page=\(page)&mobile=no"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("getMessageList url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func sendMessageToUid(uid: String, message: String, formHash: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        guard !Account().isGuest else {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Need login."])
            self.handleObjectResult(nil, error: error, completion: completion)
            return nil
        }
        
        let url = "home.php?mod=spacecp&ac=pm&op=send&touid=\(uid)&pmid=0&mobile=yes"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("sendMessageToUid url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        
        let data = NSMutableData()
        data.append("referer=\(globalConfig.forum_base_url.sa_formURLEncoded())./&pmsubmit=true&message=\(message.sa_formURLEncoded())&formhash=\(formHash.sa_formURLEncoded())".data(using: .utf8)!)
        
        request.httpBody = data as Data
        request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleHTMLResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func sendMessage(to pmid: String, message: String, formHash: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        guard !Account().isGuest else {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Need login."])
            self.handleObjectResult(nil, error: error, completion: completion)
            return nil
        }
        
        let url = "api/mobile/index.php?module=sendpm&version=1&pmid=\(pmid)&pmsubmit=yes&mobile=no"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("sendMessage url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
       
        let data = NSMutableData()
        data.append("message=\(message.sa_formURLEncoded())&formhash=\(formHash.sa_formURLEncoded())".data(using: .utf8)!)
        
        request.httpBody = data as Data
        request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    
    //param:
    /*
     <li>广告/SPAM</li><li>恶意灌水</li><li>违规内容</li><li>文不对题</li><li>重复发帖</li><li>--------</li><li>我很赞同</li><li>精品文章</li><li>原创内容</li></ul>
     
     <name="message" value="">
     <button type="submit" value="true" class="pn pnc"><strong>确定</strong></button>
     </p>
     <input type="hidden" name="referer" value="http://bbs.saraba1st.com/2b/thread-1274618-1-1.html">
     <input type="hidden" name="reportsubmit" value="true">
     <input type="hidden" name="rtype" value="post">
     <input type="hidden" name="rid" value="32346358">
     <input type="hidden" name="fid" value="75">
     <input type="hidden" name="url" value="">
     <input type="hidden" name="inajax" value="1">
     <input type="hidden" name="handlekey" value="miscreport32346358"><input type="hidden" name="formhash" value="4d0850bb">
     
     let referer = forum_base_url + "thread-\(tid)-1-1.html"

     */
    

    @discardableResult
    func reportAbuse(of fid: String, tid: String, rid: String, reason: String?, formhash: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let url = globalConfig.forum_base_url + "misc.php?mod=report"
        let referer = globalConfig.forum_base_url + "thread-\(rid)-1-1.html"
        
        let parameters : [String:String] = ["message": reason ?? "其他",
                                            "referer": referer,
                                            "reportsubmit": "true",
                                            "rtype": "post",
                                            "rid": rid,
                                            "fid": fid,
                                            "url": "",
                                            "inajax": "1",
                                            "handlekey": "miscreport\(rid)",
                                            "formhash": formhash]
        
        
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("reportAbuse url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.httpMethod = "POST"
        
        let boundary = "---------------------------\(request.hashValue)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(globalConfig.forum_base_url, forHTTPHeaderField: "Origin")
        
        let data = NSMutableData()
        for (name, value) in parameters {
            data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: String.Encoding.utf8)!)
            data.append("\(value)\r\n".data(using: String.Encoding.utf8)!)
        }
        data.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)
        
        request.httpBody = data as Data
        request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleHTMLResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func getHotThreads(_ completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let url = globalConfig.forum_base_url + "api/mobile/index.php?module=hotthread&version=1&mobile=no"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("getHotThreads url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func getForumBoardInfo(_ completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let url = globalConfig.forum_base_url + "api/mobile/index.php?module=forumnav&version=1&mobile=no"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("getForumBoardInfo url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    // this API can not be used any longer
    @discardableResult
    func getAccountInfo(of uid: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let url = globalConfig.forum_base_url + "api/mobile/index.php?module=profile&version=1&uid=\(uid)&mobile=no"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("getAccountInfo url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue(globalConfig.forum_base_url, forHTTPHeaderField: "Referer")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
            UIApplication.shared.hideNetworkIndicator()
        })
        task.resume()
        return task
    }
    
    /// Get the html form before creating a composing thread request.
    /// The completion block will be invoked with an html string if no error.
    /// Use an html parser to parse the form query parameters.
    /// Usage in Saralin:
    /*
        URLSession.saCustomized.getComposingThreadHTTPForm(of: fid!) { [weak self] (html, error) in
            guard error == nil, let str = html as? String, let parser = try? HTMLParser.init(string: str) else {
                DispatchQueue.main.async {
                    let error = NSError(domain: NSPOSIXErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"数据异常"])
                    self?.loadingController.setFailed(with: error)
                }
                return
            }
     
            guard let formhash = parser.body()?.findChild(withAttribute: "name", matchingName: "formhash", allowPartial: false)?.getAttributeNamed("value"),
                let posttime = parser.body()?.findChild(withAttribute: "name", matchingName: "posttime", allowPartial: false)?.getAttributeNamed("value"),
                let hash = parser.body()?.findChild(withAttribute: "name", matchingName: "hash", allowPartial: false)?.getAttributeNamed("value"),
                let uid = parser.body()?.findChild(withAttribute: "name", matchingName: "uid", allowPartial: false)?.getAttributeNamed("value") else {
                    DispatchQueue.main.async {
                        let error = NSError(domain: NSPOSIXErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"无法解析服务器数据"])
                        self?.loadingController.setFailed(with: error)
                    }
                    return
            }
     
            var typeIDArr: [[String:String]] = []
            parser.body()?.findChild(withAttribute: "id", matchingName: "typeid", allowPartial: false)?.children().forEach({ (node) in
                if let value = node.getAttributeNamed("value"), let name = node.contents() {
                    typeIDArr.append(["name": name, "value": value])
                }
            })
     
            DispatchQueue.main.async {
                self?.typeIDList.removeAll()
                self?.formData.removeAll()
                self?.typeIDList.append(contentsOf: typeIDArr)
                self?.formData["formhash"] = formhash as AnyObject
                self?.formData["hash"] = hash as AnyObject
                self?.formData["posttime"] = posttime as AnyObject
                self?.formData["uid"] = uid as AnyObject
                self?.tableView.reloadData()
                self?.typePickerView.reloadComponent(0)
                self?.loadingController.setFinished()
                let titleCell = self?.tableViewCells[0] as! TitleCell
                titleCell.textField.becomeFirstResponder()
            }
        }
     */
    ///
    /// - Parameters:
    ///   - fid: the forum ID
    ///   - completion:
    @discardableResult
    func getComposingThreadHTTPForm(of fid: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        guard let url = Foundation.URL(string: SAGlobalConfig().forum_base_url + "forum.php?mod=post&action=newthread&fid=\(fid)&mobile=2") else {
            fatalError()
        }
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: url) { (data, response, error) in
            UIApplication.shared.hideNetworkIndicator()
            self.handleHTMLResult(response, data: data, error: error as NSError?, completion: completion)
        }
        task.resume()
        return task
    }
    
    /// Submit the thread composing HTML form.
    /// The form parameters should be fetched from previous call.
    ///
    /// - Parameters:
    ///   - fid: forum ID
    ///   - uid: user ID
    ///   - subject: subject of this new thread
    ///   - message: content of this new thread
    ///   - typeid: user selected typeid
    ///   - type: unknown, use the default value
    ///   - formhash: formhash
    ///   - hash: hash
    ///   - posttime: posttime
    ///   - attachment: the attached image if user selected
    ///   - completion: completion handler
    /// - Returns: The cancelable request object
    @discardableResult
    func submitComposingThreadForm(to fid: String, queryParam: [String:String], attachment: UIImage?, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let url = Foundation.URL(string: globalConfig.forum_base_url + "forum.php?mod=post&action=newthread&fid=\(fid)&extra=&topicsubmit=yes&mobile=yes")!
        sa_log_v2("uploadImage url: %@", log: .network, type: .debug, url as CVarArg)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(globalConfig.mobile_useragent_string, forHTTPHeaderField: "User-Agent")
        
        let uuid = CFUUIDCreate(nil);
        let boundary = CFUUIDCreateString(nil, uuid) as String
        request.setValue("multipart/form-data; charset=utf-8; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let data = NSMutableData()
        for (key, value) in queryParam {
            data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: String.Encoding.utf8)!)
            data.append("\(value)\r\n".data(using: String.Encoding.utf8)!)
        }
        
        if let image = attachment {
            var imageSize = image.size
            if imageSize.width > 800 {
                imageSize.width = 800
                imageSize.height = ceil(800.0/image.size.width * image.size.height)
            }
            let imageData = image.scaledToSize(imageSize).jpegData(compressionQuality: 0.3)!
            //image
            data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
            data.append("Content-Disposition: form-data; name=\"Filedata\"; filename=\"image.jpg\"\r\n".data(using: String.Encoding.utf8)!)
            data.append("Content-Type: image/jpeg\r\n\r\n".data(using: String.Encoding.utf8)!)
            data.append(imageData)
            data.append("\r\n".data(using: String.Encoding.utf8)!)
        }
        
        data.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)
        request.httpBody = data as Data
        request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleHTMLResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    
    /// Upload Task With Progress Handler
    ///
    /// - Parameters:
    ///   - forum:
    ///   - image:
    ///   - progress:
    ///   - completion:
    @discardableResult
    func uploadImage(to fid: String, tid: String, image: UIImage, progress: ((Float, NSError?) -> Void)?, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        guard !Account().isGuest else {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Need login."])
            self.handleObjectResult(nil, error: error, completion: completion)
            return nil
        }
        let url = "misc.php?mod=swfupload&action=swfupload&operation=upload&fid=\(fid)"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("uploadImage url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.httpMethod = "POST"
        request.setValue(globalConfig.mobile_useragent_string, forHTTPHeaderField: "User-Agent")
        
        let uuid = CFUUIDCreate(nil);
        let boundary = CFUUIDCreateString(nil, uuid) as String
        request.setValue("multipart/form-data; charset=utf-8; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let refererStr = globalConfig.forum_base_url + "forum.php?mod=post&action=reply&fid=\(fid)&extra=&tid=\(tid)"
        request.setValue(refererStr, forHTTPHeaderField: "Referer")
        request.setValue(globalConfig.mobile_useragent_string, forHTTPHeaderField: "User-Agent")

        let data = NSMutableData()
        
        //uid
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"uid\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(Account().uid)\r\n".data(using: String.Encoding.utf8)!)
        
        //hash
        var imageSize = image.size
        if imageSize.width > 800 {
            imageSize.width = 800
            imageSize.height = ceil(800.0/image.size.width * image.size.height)
        }
        let imageData = image.scaledToSize(imageSize).jpegData(compressionQuality: 0.3)!
        let hash = Account().uploadhash
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"hash\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(hash)\r\n".data(using: String.Encoding.utf8)!)
        
        //image
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"Filedata\"; filename=\"image.jpg\"\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Type: image/jpeg\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append(imageData)
        data.append("\r\n".data(using: String.Encoding.utf8)!)
        data.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)
        
        request.httpBody = data as Data
        request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            guard let data = data else {
                let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"No network."])
                self.handleObjectResult(nil, error: error, completion: completion)
                return
            }
            
            guard let result = String.init(data: data, encoding: .utf8) else {
                let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Bad response from server, not utf-8 string."])
                self.handleObjectResult(nil, error: error, completion: completion)
                return
            }
            let components = result.components(separatedBy: "|")
            if components.count < 3 {
                let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Bad response from server, not utf-8 string."])
                self.handleObjectResult(nil, error: error, completion: completion)
                return
            }
            
            let attachmentID = components[2] as AnyObject
            self.handleObjectResult(attachmentID, error: nil, completion: completion)
        })
        task.resume()
        return task
    }
    
    @discardableResult
    func favorite(thread: String, formhash: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let url = "api/mobile/index.php?module=favthread&version=1&id=\(thread)&favoritesubmit=true&mobile=no"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("favorite url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.httpMethod = "POST"
        request.setValue(globalConfig.mobile_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        let body = "formhash=\(formhash.sa_formURLEncoded())"
        let data = body.data(using: .utf8)!
        request.httpBody = data
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    /// unfavorite a thread.
    /// Example:
    /// <?xml version="1.0" encoding="utf-8"?>
    /// <root><![CDATA[<script type="text/javascript" reload="1">if(typeof succeedhandle_a_delete_1057231=='function') {succeedhandle_a_delete_1057231('home.php?mod=space&uid=445568&do=favorite&view=me&type=all&quickforward=1', '操作成功 ', {'favid':'1057231','id':'1596614'});}hideWindow('a_delete_1057231');showDialog('操作成功 ', 'right', null, function () { window.location.href ='home.php?mod=space&uid=445568&do=favorite&view=me&type=all&quickforward=1'; }, 0, null, null, null, null, 3, 3);</script>]]></root>
    /// Test URL:
    /// https://bbs.saraba1st.com/2b/home.php?mod=spacecp&ac=favorite&op=delete&favid=1057231&type=all&inajax=1
    /// referer: https://bbs.saraba1st.com/2b/home.php?mod=spacecp&ac=favorite&op=delete&favid=1057231&type=all&inajax=1
    ///
    /// - Parameter favid: <#favid description#>
    /// - Parameter formhash: <#formhash description#>
    /// - Parameter completion: <#completion description#>
    @discardableResult
    func unfavorite(favid: String, formhash: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let url = "home.php?mod=spacecp&ac=favorite&op=delete&favid=\(favid)&type=all&inajax=1"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("favorite url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        let uid = Account().uid
        
        let getFormUrl = URL.init(string: "\(globalConfig.forum_base_url)home.php?mod=spacecp&ac=favorite&op=delete&favid=\(favid)&infloat=yes&handlekey=a_delete_\(favid)&inajax=1&ajaxtarget=fwin_content_a_delete_\(favid)")!
        let task = dataTask(with: getFormUrl) { (data1, response, error) in
            guard let data1 = data1 else {
                let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Can not connect to server."])
                self.handleHTMLResult(response, data: nil, error: error as NSError?, completion: completion)
                return
            }
            
            guard let str = NSString.init(data: data1, encoding: String.Encoding.utf8.rawValue) else {
                let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Invalid response from server."])
                self.handleHTMLResult(response, data: data1, error: error as NSError?, completion: completion)
                return
            }
            
            let reg = try? NSRegularExpression.init(pattern: ".* name=\"formhash\" value=\"(.*)\" ", options: [])
            let range = NSRange.init(location: 0, length: (str as NSString).length)
            let result = reg?.matches(in: str as String, options: [], range: range).first
            guard let r = result, r.numberOfRanges > 1 else {
                let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Invalid response from server."])
                self.handleHTMLResult(response, data: data1, error: error as NSError?, completion: completion)
                return
            }
            
            let strRange = r.range(at: 1)
            let formHash = (str as NSString).substring(with: strRange)
            
            // now do POST request
            
            var request = URLRequest(url: aurl)
            request.httpMethod = "POST"
            request.setValue(self.globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let referer = "\(self.globalConfig.forum_base_url)home.php?mod=space&uid=\(uid)&do=favorite&type=all&page=1"
            request.setValue(referer, forHTTPHeaderField: "Referer")
            
            let body = "referer=\(referer.sa_formURLEncoded())&deletesubmit=true&formhash=\(formHash.sa_formURLEncoded())&handlekey=a_delete_\(favid.sa_formURLEncoded())"
            let data = body.data(using: .utf8)!
            request.httpBody = data
            request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
            
            UIApplication.shared.showNetworkIndicator()
            self.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
                UIApplication.shared.hideNetworkIndicator()
                
                guard let data = data else {
                    let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Can not connect to server."])
                    self.handleHTMLResult(response, data: nil, error: error as NSError?, completion: completion)
                    return
                }
                
                guard let str = String.init(data: data, encoding: .utf8) else {
                    let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Invalid response from server."])
                    self.handleHTMLResult(response, data: data, error: error as NSError?, completion: completion)
                    return
                }
                
                if let _ = str.range(of: "操作成功") {
                    self.handleHTMLResult(response, data: data, error: nil, completion: completion)
                } else {
                    let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Operation failed."])
                    self.handleHTMLResult(response, data: data, error: error as NSError?, completion: completion)
                    return
                }
            }).resume()
        }
        task.resume()
        return task
    }
    
    @discardableResult
    func getFavoriteThreads(page: Int, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        let url = "api/mobile/index.php?module=myfavthread&version=1&page=\(page)&mobile=no"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("getFavoriteThreads url: %@", log: .network, type: .debug, aurl as CVarArg)

        var request = URLRequest(url: aurl)
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(globalConfig.mobile_useragent_string, forHTTPHeaderField: "User-Agent")
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    // NOTE: `quoteMessage` is not url encoded
    @discardableResult
    func reply(quoteId: String?, quoteMessage: String?, tid: String, message: String, attachid: String?, formhash: String, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        guard !Account().isGuest else {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Need login."])
            self.handleObjectResult(nil, error: error, completion: completion)
            return nil
        }
        
        let url = "api/mobile/index.php?module=sendreply&version=1&tid=\(tid)&replysubmit=yes&mobile=no"
        
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("reply url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.httpMethod = "POST"
        request.setValue(globalConfig.mobile_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        var body = "mobiletype=1&formhash=\(formhash.sa_formURLEncoded())&allowphoto=1&message=\(message.sa_formURLEncoded())&allownoticeauthor=1"
        if quoteId != nil && quoteMessage != nil {
            body = body + "&reppid=\(quoteId!.sa_formURLEncoded())&noticetrimstr=\(quoteMessage!.sa_formURLEncoded())"
        }
        
        if attachid != nil && !attachid!.isEmpty {
            body = body + "&attachnew%5B\(attachid!.sa_formURLEncoded())%5D%5Bdescription%5D="
        }
        
        let data = body.data(using: .utf8)!
        request.httpBody = data
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleJsonResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
    
    // NOTE: `quoteMessage` is not url encoded
    @discardableResult
    func submitForm(formData: [String:AnyObject], actionURL: URL, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        guard !Account().isGuest else {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Need login."])
            self.handleObjectResult(nil, error: error, completion: completion)
            return nil
        }
        
        sa_log_v2("submitForm url: %@", log: .network, type: .debug, actionURL as CVarArg)
        
        var request = URLRequest(url: actionURL)
        request.httpMethod = "POST"
        let auth = Account().sid
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.setValue(globalConfig.mobile_useragent_string, forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        let uuid = CFUUIDCreate(nil);
        let boundary = CFUUIDCreateString(nil, uuid) as String
        request.setValue("multipart/form-data; charset=utf-8; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let data = NSMutableData()
        
        for (key, value) in formData {
            data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: String.Encoding.utf8)!)
            data.append("\(value)\r\n".data(using: String.Encoding.utf8)!)
        }
        
        data.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)
        request.httpBody = data as Data
        request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            self.handleHTMLResult(response, data: data, error: error as NSError?, completion: completion)
        })
        task.resume()
        return task
    }
        /// Edit a thread
    ///
    /// - Parameters:
    ///   - editType: 0 delete thread 1 delete thread attachments 2 update thread 3 update read permission
    ///   - formhash:
    ///   - posttime:
    ///   - fid:
    ///   - tid:
    ///   - pid:
    ///   - typeid:
    ///   - subject: new thread subject
    ///   - message: new thread content
    ///   - completion: completion handler
    @discardableResult
    func editThread(editType: Int, formhash: String, posttime: Int, fid: String, tid: String, pid: String, typeid: String, subject: String, message: String, readperm: Int, completion: ((AnyObject?, NSError?) -> Void)?) -> URLSessionTask? {
        guard !Account().isGuest else {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Need login."])
            self.handleObjectResult(nil, error: error, completion: completion)
            return nil
        }
        
        let url = "forum.php?mod=post&action=edit&extra=&editsubmit=yes"
        guard let aurl = URL(string: url, relativeTo: URL(string: globalConfig.forum_base_url)!) else {
            fatalError()
        }
        sa_log_v2("editThread url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.httpMethod = "POST"
        request.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        
        let uuid = CFUUIDCreate(nil);
        let boundary = CFUUIDCreateString(nil, uuid) as String
        request.setValue("multipart/form-data; charset=utf-8; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let data = NSMutableData()
        
        //formhash
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"formhash\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(formhash)\r\n".data(using: String.Encoding.utf8)!)
        
        //posttime
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"posttime\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(posttime)\r\n".data(using: String.Encoding.utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"delattachop\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(editType == 1 ? "1" : "0")\r\n".data(using: String.Encoding.utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"wysiwyg\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("1\r\n".data(using: String.Encoding.utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"fid\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(fid)\r\n".data(using: String.Encoding.utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"tid\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(tid)\r\n".data(using: String.Encoding.utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"pid\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(pid)\r\n".data(using: String.Encoding.utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"page\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("1\r\n".data(using: String.Encoding.utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"typeid\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(typeid)\r\n".data(using: String.Encoding.utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"subject\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(subject)\r\n".data(using: String.Encoding.utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"message\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(message)\r\n".data(using: String.Encoding.utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"readperm\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(editType == 3 ? String(readperm) : "")\r\n".data(using: String.Encoding.utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"delete\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(editType == 0 ? "1" : "")\r\n".data(using: String.Encoding.utf8)!)
        
        data.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
        data.append("Content-Disposition: form-data; name=\"save\"\r\n\r\n".data(using: String.Encoding.utf8)!)
        data.append("\(editType == 2 ? "1" : "")\r\n".data(using: String.Encoding.utf8)!)
        
        // form tail
        data.append("\r\n".data(using: String.Encoding.utf8)!)
        data.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)
        
        request.httpBody = data as Data
        request.setValue("\(data.length)", forHTTPHeaderField: "Content-Length")
        
        UIApplication.shared.showNetworkIndicator()
        let task = dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            UIApplication.shared.hideNetworkIndicator()
            guard let data = data else {
                let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"No netowrk."])
                self.handleObjectResult(nil, error: error, completion: completion)
                return
            }
            
            guard let result = String.init(data: data, encoding: .utf8) else {
                let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Bad response from server, not utf-8 string."])
                self.handleObjectResult(nil, error: error, completion: completion)
                return
            }
            
            let components = result.components(separatedBy: "|")
            if components.count < 3 {
                let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Bad response from server, not recognized."])
                self.handleObjectResult(nil, error: error, completion: completion)
                return
            }
            
            let attachmentID = components[2] as AnyObject
            self.handleObjectResult(attachmentID, error: nil, completion: completion)
        })
        task.resume()
        return task
    }
}

// MARK: - Result Handler
extension URLSession {
    class CallbackObject: NSObject {
        var callback:((AnyObject?, NSError?) -> Void)?
        var object: AnyObject?
        var error: NSError?
        
        init(callback: ((AnyObject?, NSError?) -> Void)?, object: AnyObject?, error: NSError?) {
            super.init()
            self.callback = callback
            self.object = object
            self.error = error
        }
    }
    
    @objc func executeCallback(_ callbackObject: CallbackObject) {
        guard let callback = callbackObject.callback else {
            return
        }
        
        callback(callbackObject.object as AnyObject, callbackObject.error)
    }
    
    // data is json
    fileprivate func handleJsonResult(_ response:  URLResponse?, data: Data?, error: NSError?, completion: ((AnyObject?, NSError?) -> Void)?) -> Void {
        if let error = error {
            sa_log_v2("HTTP Request Error: %@", log: .network, type: .error, error as CVarArg)
            if error.code == -1202 {
                sa_log_v2("invalid cert error: %@", log: .network, type: .error, error as CVarArg)
            }
            
            let callbackObj = CallbackObject.init(callback: completion, object: nil, error: error)
            RunLoop.main.perform(#selector(executeCallback(_:)), target: self, argument: callbackObj, order: 0, modes: [RunLoop.Mode.default])
            return
        }
        
        let obj = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
        if obj == nil {
            let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"parse json failed"])
            let callbackObj = CallbackObject.init(callback: completion, object: nil, error: error)
            RunLoop.main.perform(#selector(executeCallback(_:)), target: self, argument: callbackObj, order: 0, modes: [RunLoop.Mode.default])
            return
        }
        
        let callbackObj = CallbackObject.init(callback: completion, object: obj as AnyObject, error: nil)
        RunLoop.main.perform(#selector(executeCallback(_:)), target: self, argument: callbackObj, order: 0, modes: [RunLoop.Mode.default])
        return
    }
    
    // data is HTML
    fileprivate func handleHTMLResult(_ response:  URLResponse?, data: Data?, error: NSError?, completion: ((AnyObject?, NSError?) -> Void)?) -> Void {
        if error != nil {
            sa_log_v2("HTTP Request Error: %@", log: .network, type: .error, error! as CVarArg)
            let callbackObj = CallbackObject.init(callback: completion, object: nil, error: error)
            RunLoop.main.perform(#selector(executeCallback(_:)), target: self, argument: callbackObj, order: 0, modes: [RunLoop.Mode.default])
            return
        }
        
        var obj: String? = nil
        if data != nil {
            obj = String(data: data!, encoding: String.Encoding.utf8)
        }
        
        if obj == nil {
            let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Received bad response from server."])
            let callbackObj = CallbackObject.init(callback: completion, object: obj as AnyObject, error: error)
            RunLoop.main.perform(#selector(executeCallback(_:)), target: self, argument: callbackObj, order: 0, modes: [RunLoop.Mode.default])
            return
        }
        
        let callbackObj = CallbackObject.init(callback: completion, object: obj as AnyObject, error: nil)
        RunLoop.main.perform(#selector(executeCallback(_:)), target: self, argument: callbackObj, order: 0, modes: [RunLoop.Mode.default])
        return
    }
    
    // data is a user defined object
    fileprivate func handleObjectResult(_ object: AnyObject?, error: NSError?, completion: ((AnyObject?, NSError?) -> Void)?) -> Void {
        if error != nil {
            sa_log_v2("HTTP Request Error: %@", log: .network, type: .error, error! as CVarArg)
            let callbackObj = CallbackObject.init(callback: completion, object: nil, error: error)
            RunLoop.main.perform(#selector(executeCallback(_:)), target: self, argument: callbackObj, order: 0, modes: [RunLoop.Mode.default])
            return
        }
        
        let callbackObj = CallbackObject.init(callback: completion, object: object, error: nil)
        RunLoop.main.perform(#selector(executeCallback(_:)), target: self, argument: callbackObj, order: 0, modes: [RunLoop.Mode.default])
    }
}
