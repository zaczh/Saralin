//
//  SACronJobManager.swift
//  Saralin
//
//  Created by zhang on 4/30/17.
//  Copyright © 2017 zaczh. All rights reserved.
//

import UIKit
import WebKit
import CoreData

class SABackgroundTaskManager {
    private var timer: Timer!
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    private var currentBackgroundFetchResult: UIBackgroundFetchResult = .noData
    private var backgroundTaskCompletion: ((UIBackgroundFetchResult) -> Void)?
    var unreadDirectMessageCount = 0
    
    private var globalConfig: SAGlobalConfig! = {
        return SAGlobalConfig()
    } ()
    private var coreDataManager: SACoreDataManager!
    private var urlSession: URLSession! = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(30)
        return URLSession.init(configuration: configuration, delegate: nil, delegateQueue: nil)
    } ()
    
    init(coreDataManager: SACoreDataManager) {
        self.coreDataManager = coreDataManager
    }
    
    func start() {
        if let timer = timer {
            timer.invalidate()
        }
        
        // setup timer. Timer will not fire when app is in background
        timer = Timer.scheduledTimer(timeInterval: globalConfig.background_fetch_interval, target: self, selector: #selector(handleTimerEvent(_:)), userInfo: nil, repeats: true)
    }
    
    func stop() {
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
    }
    
    @objc func handleTimerEvent(_: Timer) {
        if Account().isGuest {
            return
        }
        
        os_log("app bg fetch timer fires", log: .ui, type: .info)
        startBackgroundTask { (result) in
            
        }
    }
    
    func startBackgroundTask(with completionHandler: @escaping ((UIBackgroundFetchResult) -> Void)) {
        if backgroundTaskIdentifier != UIBackgroundTaskIdentifier.invalid {
            os_log("app bg fetch: a job is already running", log: .ui, type: .info)
            completionHandler(.noData)
            return
        }
        
        // perform background fetch
        let application = UIApplication.shared
        backgroundTaskIdentifier = application.beginBackgroundTask {
            self.finish()
        }
        backgroundTaskCompletion = completionHandler
        
        let group = DispatchGroup()
        group.enter()
        self.fetchWatchingListThreadsInBackground { (result) in
            self.currentBackgroundFetchResult = result
            group.leave()
        }
        
        group.enter()
        self.fetchFavoriteThreadsInBackground { (result) in
            self.currentBackgroundFetchResult = result
            group.leave()
        }
        
        group.enter()
        self.fetchDirectMessageInBackground { (list, error) in
            if error == nil {
                self.currentBackgroundFetchResult = UIBackgroundFetchResult.failed
            } else if list.count > 0 {
                self.currentBackgroundFetchResult = UIBackgroundFetchResult.newData
            } else {
                self.currentBackgroundFetchResult = UIBackgroundFetchResult.noData
            }
            group.leave()
        }
        
        group.notify(qos: DispatchQoS.default, flags: [], queue: DispatchQueue.main) {
            self.finish()
        }
    }
    
    private func finish() {
        let application = UIApplication.shared
        application.endBackgroundTask(self.backgroundTaskIdentifier)
        self.backgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
        self.backgroundTaskCompletion?(self.currentBackgroundFetchResult)
        self.backgroundTaskCompletion = nil
        self.currentBackgroundFetchResult = .noData
        os_log("app bg fetch finished", log: .network, type: .info)
    }
    
    func clearDiskCache(completion: (() -> Void)?) {
        coreDataManager.cleanUp()
        URLCache.shared.removeAllCachedResponses()
        var set = WKWebsiteDataStore.allWebsiteDataTypes()
        // keep cookies
        set.remove(WKWebsiteDataTypeCookies)
        WKWebsiteDataStore.default().removeData(ofTypes: set, modifiedSince: Date.distantPast, completionHandler: {
            completion?()
        })
    }
    
    func fetchFavoriteThreadsInBackground(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Account().isGuest {
            dispatch_async_main {
                completionHandler(.noData)
            }
            return
        }
        
        // count pages
        urlSession.getFavoriteThreads(page: 1, completion: { (object, error) in
            guard error == nil else {
                os_log("parsing favorite threads data error: %@", log: .network, type: .error, error!)
                dispatch_async_main {
                    completionHandler(.failed)
                }
                return
            }
            
            guard let object = object as? [String:Any] else {
                os_log("parsing favorite threads data error bad response", log: .network, type: .error)
                dispatch_async_main {
                    completionHandler(.failed)
                }
                return
            }
            
            guard let variables = object["Variables"] as? [String:Any] else {
                os_log("parsing favorite threads data error variables is nil", log: .network, type: .error)
                dispatch_async_main {
                    completionHandler(.failed)
                }
                return
            }
            
            guard let perpageStr = variables["perpage"] as? String, let countStr = variables["count"] as? String else {
                os_log("parsing favorite threads data error no page info", log: .network, type: .error)
                dispatch_async_main {
                    completionHandler(.failed)
                }
                return
            }

            let perpage = Int(perpageStr)!
            let count = Int(countStr)!
            let totalPage = count/perpage + 1
            
            let group = DispatchGroup()
            // do actual fetching
            for i in 0 ..< totalPage {
                group.enter()
                self.urlSession.getFavoriteThreads(page: i + 1, completion: { (obj, error) in
                    guard error == nil, let object = obj as? [String:Any], let variables = object["Variables"] as? [String:Any] else {
                        os_log("parsing favorite threads data error no page info", log: .network, type: .error)
                        group.leave()
                        return
                    }
                    
                    self.handleFavoritesResponse(data: variables) {
                        group.leave()
                    }
                })
            }
            
            group.notify(queue: DispatchQueue.main, execute: {
                completionHandler(.newData)
            })
        })
    }
    
    private func handleFavoritesResponse(data: [String:Any], completion:(() -> Void)?) {
        let variables = data
        guard let list = variables["list"] as? [[String:Any]] else {
            os_log("parsing favorite threads data error: not array type", log: .network, type: .error)
            completion?()
            return
        }
        
        let uid = Account().uid
        let group = DispatchGroup()
        for item in list {
            group.enter()
            let favid = item["favid"] as? String
            let replies = item["replies"] as? String
            guard let replyCount = Int(replies ?? "0") else {
                os_log("replies is bad or nil", log: .network, type: .error)
                group.leave()
                continue
            }
            let title = item["title"] as? String
            let author = item["author"] as? String
            let dateline = item["dateline"] as? String
            guard let datelineInt = Int(dateline ?? "0") else {
                os_log("dateline is bad or nil", log: .network, type: .error)
                group.leave()
                continue
            }
            let id = item["id"] as? String
            let idtype = item["idtype"] as? String
            var tid: String?
            if idtype == "tid" {
                tid = id
            }
            let icon = item["icon"] as? String
            
            let predicate = NSPredicate(format: "favid==%@ AND tid==%@ AND uid==%@", favid ?? NSNull(), tid ?? NSNull(), uid)
            
            coreDataManager.insertNewOrUpdateExist(fetchPredicate: predicate, sortDescriptors: nil, update: { (entity: OnlineFavoriteThread) in
                entity.replycount = NSNumber(value: replyCount)
                entity.title = title
                entity.createdevicename = UIDevice.current.name
                entity.createdeviceidentifier = AppController.current.currentDeviceIdentifier
            }, create: { (entity: OnlineFavoriteThread) in
                entity.createdevicename = UIDevice.current.name
                entity.createdeviceidentifier = AppController.current.currentDeviceIdentifier
                entity.uid = uid
                entity.title = title
                entity.authorname = author
                entity.favoriteddate = Date(timeIntervalSince1970: TimeInterval(datelineInt))
                entity.replycount = NSNumber(value: replyCount)
                entity.tid = tid
                entity.icon = icon
                entity.favid = favid
            }, completion: {
                group.leave()
            })
        }
        
        group.notify(queue: .global()) {
            completion?()
        }
    }
    
    // the completionHandler MUST BE executed before return
    // TODO: filter older thread in this list
    fileprivate func fetchWatchingListThreadsInBackground(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        os_log("begin fetching watching list in background", log: .ui, type: .info)
        
        if Account().isGuest {
            completionHandler(.noData)
            return
        }
        
        // 30 seconds time limit
        coreDataManager.withMainContext { (context) in
            let fetch = NSFetchRequest<WatchingThread>(entityName: "WatchingThread")
            fetch.fetchLimit = 30
            let sort = NSSortDescriptor(key: "timeadded", ascending: false)
            fetch.sortDescriptors = [sort]
            guard let objects = try? context.fetch(fetch) else {
                os_log("fetching watching list in background failed", log: .ui, type: .error)
                completionHandler(.noData)
                return
            }
            
            var backgroundFetchResultUpdated = 0
            var workingJobs = objects.count
            let oneJobCompleted = { () in
                guard workingJobs == 0 else {
                    return
                }
                
                completionHandler(backgroundFetchResultUpdated > 0 ? .newData : .noData)
                
                if UIApplication.shared.applicationState != .active && backgroundFetchResultUpdated > 0 {
                    if #available(iOS 10.0, *) {
                        let notificationContent = UNMutableNotificationContent()
                        notificationContent.title = "观察列表已更新"
                        notificationContent.body = "观察列表中有\(backgroundFetchResultUpdated)个帖子已更新，快去看看吧"
                        notificationContent.sound = UNNotificationSound.default
                        let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
                        let notificationRequest = UNNotificationRequest(identifier: SANotificationManager.SANotificationRequestIdentifier.viewWatchList.rawValue, content: notificationContent, trigger: notificationTrigger)
                        UNUserNotificationCenter.current().add(notificationRequest) { (error : Error?) in
                            if let error = error {
                                // Handle any errors
                                os_log("error presenting local notification: %@", log: .ui, type: .error, error as NSError)
                                return
                            }
                        }
                    } else {
                        // Fallback on earlier versions
                        let notification = UILocalNotification()
                        notification.soundName = UILocalNotificationDefaultSoundName
                        notification.fireDate = Date()
                        notification.alertTitle = "观察列表已更新"
                        notification.alertBody = "观察列表中有\(backgroundFetchResultUpdated)个帖子已更新，快去看看吧"
                        UIApplication.shared.presentLocalNotificationNow(notification)
                    }
                }
            }
            
            if workingJobs == 0 {
                oneJobCompleted()
                return
            }
            
            for obj in objects {
                guard let tid = obj.tid else {
                    workingJobs = workingJobs - 1
                    continue
                }
                
                self.urlSession.getTopicContent(of: tid, page: 0) { (result, error) in
                    workingJobs = workingJobs - 1
                    guard error == nil,
                    let resultDict = result as? [String:AnyObject],
                    let variables = resultDict["Variables"] as? [String:Any],
                    let thread = variables["thread"] as? [String:Any],
                    let replyCount = thread["replies"] as? String else {
                        oneJobCompleted()
                        return
                    }
                    
                    let fetch = NSFetchRequest<WatchingThread>(entityName: "WatchingThread")
                    fetch.predicate = NSPredicate(format: "tid==%@ AND uid==%@", tid, Account().uid)
                    guard let objects = try? context.fetch(fetch),
                    let obj = objects.first,
                    let nowReply = Int(replyCount),
                    let lastReply = obj.lastviewreplycount?.intValue else {
                        oneJobCompleted()
                        return
                    }
                    
                    // notify only updated replies
                    if let lastFetchReplyCount = obj.lastfetchreplycount?.intValue {
                        if lastFetchReplyCount >= nowReply {
                            oneJobCompleted()
                            return
                        }
                    }
                    
                    guard nowReply > lastReply else {
                        oneJobCompleted()
                        return
                    }
                    
                    backgroundFetchResultUpdated = backgroundFetchResultUpdated + 1
                    obj.newreplycount = NSNumber.init(value: nowReply - lastReply)
                    obj.lastfetchreplycount = NSNumber.init(value: nowReply)
                    
                    if let lastDate = obj.lastreplyupdatedtime {
                        if NSDate().timeIntervalSince(lastDate as Date) < self.globalConfig.background_fetch_interval {
                            var hotDegree = 0
                            if let degree = obj.hotdegree?.intValue {
                                hotDegree = degree
                            }
                            
                            hotDegree = hotDegree + 1
                            if hotDegree > 5 {
                                hotDegree = 5
                            }
                            
                            obj.hotdegree = NSNumber.init(value: hotDegree)
                        }
                    }
                    obj.lastreplyupdatedtime = Date()
                    oneJobCompleted()
                    return
                }
            }
        }
    }
    
    func fetchDirectMessageInBackground(completion: (([PrivateMessageSummary], Error?) -> Void)?) {
        os_log("begin fetching direct message list in background", log: .ui, type: .info)
        // get all messages at once
        DispatchQueue.global().async {
            var allMessages: [PrivateMessageSummary] = []
            var page = 1
            var finished = false
            
            repeat {
                let group = DispatchGroup()
                group.enter()
                self.urlSession.getMessageList(page: page) { (result, error) in
                    defer {
                        group.leave()
                    }
                    
                    guard error == nil,
                        let resultDict = result as? [String:AnyObject],
                        let variables = resultDict["Variables"] as? [String:AnyObject],
                        let list = variables["list"] as? [[String:AnyObject]] else {
                        return
                    }
                    
                    if list.count == 0 {
                        finished = true
                        return
                    }
                    
                    var results: [PrivateMessageSummary] = []
                    for item in list {
                        guard let lastupdate = item["lastupdate"] as? String,
                              let isnewStr = item["isnew"] as? String,
                              let isnew = Int(isnewStr),
                              let touid = item["touid"] as? String,
                              let message = item["message"] as? String,
                              let pmnumstr = item["pmnum"] as? String,
                              let pmnum = Int(pmnumstr)
                        else {
                            continue
                        }
                        
                        let tousername = (item["tousername"] as? String) ?? (item["msgfrom"] as? String) ?? ""
                        results.append(PrivateMessageSummary(lastupdate: lastupdate,
                                                             isnew: isnew,
                                                             tousername: tousername,
                                                             touid: touid,
                                                             message: message,
                                                             pmnum: pmnum))
                    }
                    
                    allMessages.append(contentsOf: results)
                    
                    guard let countStr = variables["count"] as? String,
                        let count = Int(countStr),
                        let perpageStr = variables["perpage"] as? String,
                        let perpage = Int(perpageStr) else {
                        return
                    }
                    let maxPage = count/perpage + 1
                    if page >= maxPage {
                        finished = true
                    }
                }
                _ = group.wait(timeout: .distantFuture)
                page = page + 1
            } while (!finished && page <= 10)
            
            DispatchQueue.main.async {
                self.saveMessagesToDb(messages: allMessages)
                completion?(allMessages, nil)
            }
        }
    }
    
    // MARK: - Core Data
    private func saveMessagesToDb(messages: [PrivateMessageSummary]) {
        let group = DispatchGroup()
        var numberOfNewMessages = 0
        messages.forEach({ (dict) in
            let touid = dict.touid
            guard !touid.isEmpty else {
                return
            }
            
            if dict.isnew != 0 {
                numberOfNewMessages = numberOfNewMessages + 1
            }
            
            group.enter()
            let predicate = NSPredicate(format: "uid==%@ AND touid==%@", Account().uid, touid)
            coreDataManager.insertNewOrUpdateExist(fetchPredicate: predicate, sortDescriptors: nil, update: { (obj: DirectMessage) in
                obj.createdevicename = UIDevice.current.name
                obj.createdeviceidentifier = AppController.current.currentDeviceIdentifier
                obj.pmnum = NSNumber(value: dict.pmnum)
                obj.isnew = NSNumber(value: dict.isnew)
                obj.touid = dict.touid
                obj.lastupdate = dict.lastupdate.sa_toDateFrom1970SecondsDate()
                obj.message = dict.message
                obj.tousername = dict.tousername
                os_log("update existing record DirectMessage", log: .database, type: .debug)
                group.leave()
            }, create: { (obj) in
                obj.uid = Account().uid
                obj.createdevicename = UIDevice.current.name
                obj.createdeviceidentifier = AppController.current.currentDeviceIdentifier
                
                obj.pmnum = NSNumber(value: dict.pmnum)
                obj.isnew = NSNumber(value: dict.isnew)
                obj.touid = dict.touid
                obj.lastupdate = dict.lastupdate.sa_toDateFrom1970SecondsDate()
                obj.message = dict.message
                obj.tousername = dict.tousername
                
                group.leave()
                os_log("insert new record DirectMessage", log: .database, type: .debug)
            }, completion: nil)
        })
        
        group.notify(queue: DispatchQueue.main) {
            self.unreadDirectMessageCount = numberOfNewMessages
            if self.unreadDirectMessageCount > 0 {
                self.showNewDirectMessagesNotification(messageCount: self.unreadDirectMessageCount)
            }
        }
    }
    
    private func showNewDirectMessagesNotification(messageCount: Int) {
        if #available(iOS 10.0, *) {
            let notificationContent = UNMutableNotificationContent()
            notificationContent.title = "收到新私信🆕"
            notificationContent.body = "你收到了\(messageCount)条新私信，快去收件箱📥看看吧"
            notificationContent.sound = UNNotificationSound.default
            let notificationTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let notificationRequest = UNNotificationRequest(identifier: SANotificationManager.SANotificationRequestIdentifier.viewDirectMessageList.rawValue,
                                                            content: notificationContent,
                                                            trigger: notificationTrigger)
            UNUserNotificationCenter.current().add(notificationRequest) { (error : Error?) in
                if let error = error {
                    // Handle any errors
                    os_log("error presenting local notification: %@", log: .ui, type: .error, error as NSError)
                    return
                }
            }
        } else {
            // Fallback on earlier versions
            let notification = UILocalNotification()
            notification.soundName = UILocalNotificationDefaultSoundName
            notification.fireDate = Date()
            notification.alertTitle = "收到新私信"
            notification.alertBody = "你收到了\(messageCount)条新私信，快去收件箱看看吧"
            UIApplication.shared.presentLocalNotificationNow(notification)
        }
    }
    
    func dailyCheckIn(completion: ((Bool) -> Void)?) {
        guard !Account().isGuest else {
            dispatch_async_main {
                completion?(false)
            }
            return
        }
        
        let homeUrl = URL.init(string: globalConfig.forum_url)!
        var homeRequest = URLRequest.init(url: homeUrl)
        homeRequest.setValue(globalConfig.pc_useragent_string, forHTTPHeaderField: "User-Agent")
        UIApplication.shared.showNetworkIndicator()
        urlSession.dataTask(with: homeRequest) { [weak self] (data, response, error) in
            UIApplication.shared.hideNetworkIndicator()
            guard let self = self else {
                dispatch_async_main {
                    completion?(false)
                }
                return
            }
            
            guard error == nil else {
                os_log("dailyCheckIn error: %@", error! as CVarArg)
                dispatch_async_main {
                    completion?(false)
                }
                return
            }
            
            guard let data = data else {
                os_log("dailyCheckIn empty data")
                dispatch_async_main {
                    completion?(false)
                }
                return
            }
            
            let str = String(data: data, encoding: String.Encoding.utf8)!
            guard let parser = try? HTMLParser.init(string: str) else {
                os_log("dailyCheckIn parser initializing failed")
                dispatch_async_main {
                    completion?(false)
                }
                return
            }
            guard let elements = parser.body()?.findChildren(withAttribute: "style", matchingName: "color:red;", allowPartial: false) else {
                // no url when already checked in today
                Account().lastDayCheckIn = Date()
                dispatch_async_main {
                    completion?(true)
                }
                return
            }
            
            for el in elements {
                let parent = el.parent()
                if parent.nodetype() == HTMLHrefNode {
                    guard let checkInUrl = parent.getAttributeNamed("href") else {
                        os_log("dailyCheckIn empty data")
                        dispatch_async_main {
                            completion?(false)
                        }
                        return
                    }
                    
                    guard let url = URL.init(string: self.globalConfig.forum_base_url + checkInUrl) else {
                        os_log("dailyCheckIn bad url")
                        dispatch_async_main {
                            completion?(false)
                        }
                        return
                    }
                    
                    // handle daily check in url
                    
                    self.urlSession.dataTask(with: url) { (data, response, error) in
                        guard error == nil else {
                            os_log("dailyCheckIn error: %@", error! as CVarArg)
                            dispatch_async_main {
                                completion?(false)
                            }
                            return
                        }
                        
                        guard let data = data else {
                            os_log("dailyCheckIn empty data")
                            dispatch_async_main {
                                completion?(false)
                            }
                            return
                        }
                        
                        let str = String(data: data, encoding: String.Encoding.utf8)!
                        guard let parser = try? HTMLParser.init(string: str) else {
                            os_log("dailyCheckIn parser initializing failed")
                            dispatch_async_main {
                                completion?(false)
                            }
                            return
                        }
                        
                        if let element = parser.body()?.findChild(withAttribute: "id", matchingName: "messagetext", allowPartial: true) {
                            if element.children().count > 1 {
                                let messagetext = element.children()[1]
                                if let content = messagetext.contents() {
                                    // <p>已签到,请不要重新签到！</p>
                                    // 成功签到
                                    if content.contains("成功") || content.contains("已签到") {
                                        os_log("dailyCheckIn succeeded")
                                        dispatch_async_main {
                                            Account().lastDayCheckIn = Date()
                                            completion?(true)
                                        }
                                        return
                                    }
                                }
                            }
                        }
                        
                        os_log("dailyCheckIn failed")
                        dispatch_async_main {
                            completion?(false)
                        }
                    }.resume()
                    return
                }
            }
            
            dispatch_async_main {
                Account().lastDayCheckIn = Date()
                completion?(true)
            }
        }.resume()
    }
    
    func clearDiskCacheIfNeeded() {
        let userDefaults = UserDefaults.standard
        let key = SAUserDefaultsKey.lastDateClearedDiskCache.rawValue
        if let date = userDefaults.value(forKey: key) as? Date, date.timeIntervalSinceNow < -5 * 24 * 60 * 60 {
            userDefaults.set(Date() as AnyObject, forKey: key)
            clearDiskCache(completion: nil)
            os_log("cleared disk cache", log: .ui, type: .info)
        }
    }
    
    func removeLogFilesIfNeeded() {
        let fm = FileManager.default
        guard let dirEnu = fm.enumerator(atPath: sa_log_file_directoy) else {
            os_log("fail to enumerate at log file dir", log: .ui, type: .info)
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = .current
        
        let today = dateFormatter.date(from: dateFormatter.string(from: Date()))!
        let logFileDaysToKeep = SAGlobalConfig().log_file_days_to_keep
        var deletedFiles: [NSString] = []
        for (_, file) in dirEnu.enumerated() {
            if let f = file as? NSString,
                let savedFileDate = dateFormatter.date(from: (f.lastPathComponent as NSString).deletingPathExtension),
                savedFileDate.timeIntervalSince(today) < -Double(logFileDaysToKeep - 1) * 24 * 60 * 60 {
                let filePath = sa_log_file_directoy + "/\(f)"
                deletedFiles.append(filePath as NSString)
            }
        }
        
        for dir in deletedFiles {
            try? fm.removeItem(atPath: dir as String)
            os_log("delete log file at: %@", log: .ui, type: .info, dir)
        }
    }
}
