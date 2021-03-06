//
//  SAHTMLAPI.swift
//  Saralin
//
//  Created by Junhui Zhang on 2020/5/19.
//  Copyright © 2020 zaczh. All rights reserved.
//

import UIKit

class SAHTMLAPI: NSObject {
    private var globalConfig: SAGlobalConfig {
        let config = SAGlobalConfig()
        return config
    }
    
    private var urlSession: URLSession {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        return session
    }
    
    @discardableResult
    func getTopicList(of fid: String, typeid: String?, page: Int, orderby:String?, completion: (([ThreadSummary]?, NSError?) -> Void)?) -> URLSessionTask? {
        if fid == "0" {
            // if fid is 0, then it's requesting the hot board data.
            let task = URLSession.saCustomized.getHotThreads { (data, error) in
                guard error == nil else {
                    completion?([], error)
                    return
                }
                
                guard data != nil, let variables = data!["Variables"] as? [String:AnyObject] else {
                    let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"数据为空，该板块可能需要登录才能查看。"])
                    completion?([], error)
                    return
                }
                
                guard let hotthreads = variables["data"] as? [[String:AnyObject]], !hotthreads.isEmpty else {
                    completion?([], nil)
                    return
                }
                
                var result = [ThreadSummary]()
                for data in hotthreads {
                    let model = ThreadSummary(tid: data["tid"] as! String, fid: data["fid"] as! String, subject: data["subject"] as! String, author: data["author"] as! String, authorid: data["authorid"] as! String, dbdateline: data["dbdateline"] as! String, dblastpost: data["dblastpost"] as! String, replies: Int(data["replies"] as! String)!, views: Int(data["replies"] as! String)!, readperm: Int(data["readperm"] as! String)!)
                    result.append(model)
                }
                completion?(result, nil)
            }
            task?.resume()
            return task
        }
        
        let url = globalConfig.forum_url + "?mod=forumdisplay&fid=\(fid)&page=\(page)&mobile=1"
        guard let aurl = URL(string: url) else {
            fatalError()
        }
        os_log("getTopicList url: %@", log: .network, type: .debug, aurl as CVarArg)
        
        var request = URLRequest(url: aurl)
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(globalConfig.mobile_useragent_string, forHTTPHeaderField: "User-Agent")
        let task = urlSession.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            guard let data = data else {
                completion?(nil, error as NSError?)
                return
            }
            guard let parser = try? HTMLParser(data: data) else {
                completion?(nil, error as NSError?)
                return
            }
            
            let items = parser.doc()?.findChildren(withAttribute: "class", matchingName: "bm_c", allowPartial: false) ?? []
            var list = [ThreadSummary]()
            for (_, _) in items.enumerated() {
                let model = ThreadSummary(tid: "", fid: fid, subject: "", author: "", authorid: "", dbdateline: "", dblastpost: "", replies: 0, views: 0, readperm: 0, attachment: 0, typeid: nil)
                list.append(model)
            }
            completion?(list, nil)
        })
        task.resume()
        return task
    }
    
    func handleHTMLResult(_ response:  URLResponse?, data: Data?, error: NSError?, completion: ((AnyObject?, NSError?) -> Void)?) -> Void {
       if error != nil {
           os_log("HTTP Request Error: %@", log: .network, type: .error, error! as CVarArg)
           completion?(nil, error!)
           return
       }
       
       var obj: String? = nil
       if data != nil {
           obj = String(data: data!, encoding: String.Encoding.utf8)
       }
       
       if obj == nil {
           let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Received bad response from server."])
           completion?(obj as AnyObject, error)
           return
       }
       
       completion?(obj as AnyObject, nil)
       return
   }
}
