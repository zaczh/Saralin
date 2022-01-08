//
//  SACoreDataManager.swift
//  Saralin
//
//  Created by zhang on 5/22/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

extension Notification.Name {
    public static let SABlockedUserListDidChange = Notification.Name.init("SABlockedUserListDidChange")
    public static let SABlockedThreadListDidChange = Notification.Name.init("SABlockedThreadListDidChange")
    public static let SACoreDataCacheDidChange = Notification.Name.init("SACoreDataCacheDidChange")
}

class SACoreDataManager {
    struct Cache {
        // cache
        let cacheKey: String
        var blockedUserIDs: [String]
        var viewedThreadIDs: [String]
        var blockedThreadIDs: [String]
    }
    var cache: Cache?
    var managedObjectModel: NSManagedObjectModel {
        return persistentContainer.managedObjectModel
    }
    
    private var cacheBuildingNotifyGroup: DispatchGroup?
    typealias CacheBuildingNotify = ((SACoreDataManager) -> ())
    
    private var persistentContainer: NSPersistentContainer!
    private var isReady = false
    
    private var onReadyQueue: [((SACoreDataManager) -> Void)] = []
    func onReady(_ job: @escaping ((SACoreDataManager) -> Void)) {
        onReadyQueue.append(job)
        
        var ready = false
        objc_sync_enter(self)
        ready = isReady
        objc_sync_exit(self)
        
        if ready {
            onReadyQueue.forEach { ($0)(self) }
            onReadyQueue.removeAll()
        } else {
            persistentContainer.loadPersistentStores { [weak self] (description, error) in
                guard error == nil else {
                    sa_log_v2("error occured when loadPersistentStores", log: .ui, type: .error)
                    return
                }
                
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
                objc_sync_enter(strongSelf)
                strongSelf.isReady = true
                objc_sync_exit(strongSelf)
                strongSelf.onReadyQueue.forEach { ($0)(strongSelf) }
                strongSelf.onReadyQueue.removeAll()
            }
        }
    }

    private var accountManager: SAAccountManager!
    init(accountManager: SAAccountManager) {
        self.accountManager = accountManager
        let url = AppController.current.coreDataDatebaseFileURL
        let config = NSPersistentStoreDescription.init(url: url)
        config.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        if #available(iOS 13.0, *) {
            persistentContainer = NSPersistentCloudKitContainer.init(name: "saralin")
            // initialize the CloudKit schema
            let id = "iCloud.me.zaczh.saralin"
            let options = NSPersistentCloudKitContainerOptions(containerIdentifier: id)
            config.cloudKitContainerOptions = options
        } else {
            // Fallback on earlier versions
            persistentContainer = NSPersistentContainer.init(name: "saralin")
        }
        
        persistentContainer.persistentStoreDescriptions = [config]
        onReady { [weak self] (_) in
            NotificationCenter.default.addObserver(forName: Notification.Name.SAUserLoggedOut, object: nil, queue: nil) { [weak self] (notification) in
                self?.cache = nil
            }
            NotificationCenter.default.addObserver(forName: Notification.Name.SAUserLoggedIn, object: nil, queue: nil, using: { [weak self] (notification) in
                self?.rebuildCache(completion: nil)
            })
            self?.rebuildCache(completion: nil)
        }
    }
    
    // MARK: - Core Data stack
    
    func withMainContext(_ completion:@escaping ((NSManagedObjectContext) -> Void)) {
        onReady { (_) in
            completion(self.persistentContainer.viewContext)
        }
    }
    
    // NOTE: This method executes on background thread
    func insertNewOrUpdateExist<Entity: NSManagedObject>(fetchPredicate: NSPredicate,
                                                         sortDescriptors:[NSSortDescriptor]?,
                                                         update:@escaping ((Entity) -> Void),
                                                         create:@escaping ((Entity) -> Void),
                                                         completion:(() -> Void)?) {
        let className = NSStringFromClass(Entity.self).components(separatedBy: ".").last! // remove module name
        if className == "NSManagedObject" {
            fatalError("Entity class must be supplied!")
        }
        
        withMainContext { (context) in
            context.perform {
                defer {
                    DispatchQueue.main.async {
                        completion?()
                    }
                }
                
                let fetch = NSFetchRequest<Entity>(entityName: className)
                fetch.predicate = fetchPredicate
                fetch.sortDescriptors = sortDescriptors
                let objects = try! context.fetch(fetch)
                if objects.count > 0 {
                    update(objects.first!)
                    // delete redundant objects
                    for object in objects {
                        if object != objects.first {
                            context.delete(object)
                            sa_log_v2("delete redundant object of %@", log: .ui, type: .error, className)
                        }
                    }
                    
                    self.save(context)
                    return
                }
                
                let entity = NSEntityDescription.insertNewObject(forEntityName: className, into: context) as! Entity
                create(entity)
                self.save(context)
            }
        }
    }
    
    func insertNew<Entity: NSManagedObject>(using create:@escaping ((Entity) -> Void),
                                                         completion:(() -> Void)?) {
        let className = NSStringFromClass(Entity.self).components(separatedBy: ".").last! // remove module name
        if className == "NSManagedObject" {
            fatalError("Entity class must be supplied!")
        }
        
        withMainContext { (context) in
            context.perform {
                defer {
                    DispatchQueue.main.async {
                        completion?()
                    }
                }
                
                let entity = NSEntityDescription.insertNewObject(forEntityName: className, into: context) as! Entity
                create(entity)
                self.save(context)
            }
        }
    }
    
    private func save(_ context: NSManagedObjectContext) {
        if !context.hasChanges {
            return
        }
        
        do {
            try context.save()
        } catch {
            let nserror = error as NSError
            sa_log_v2("Unresolved error %@", log: .ui, type: .fault, nserror)
        }
    }
    
    func fetch<Entity: NSManagedObject>(predicate: NSPredicate, sortDesscriptors:[NSSortDescriptor]?, completion:@escaping (([Entity]) -> Void)) {
        let className = NSStringFromClass(Entity.self).components(separatedBy: ".").last! // remove module name
        if className == "NSManagedObject" {
            fatalError()
        }
        
        withMainContext { (context) in
            let fetch = NSFetchRequest<Entity>(entityName: className)
            fetch.predicate = predicate
            fetch.sortDescriptors = sortDesscriptors
            context.perform {
                let objects = try! context.fetch(fetch)
                completion(objects)
            }
        }
    }
    
    func update<Entity: NSManagedObject>(predicate: NSPredicate, sortDescriptors:[NSSortDescriptor]?, update:@escaping ((Entity) -> Void), completion:@escaping ((Entity) -> Void)) {
        let className = NSStringFromClass(Entity.self).components(separatedBy: ".").last! // remove module name
        if className == "NSManagedObject" {
            fatalError()
        }
        
        withMainContext { (context) in
            context.perform {
                let fetch = NSFetchRequest<Entity>(entityName: className)
                fetch.predicate = predicate
                fetch.sortDescriptors = sortDescriptors
                let objects = try! context.fetch(fetch)
                if objects.isEmpty { return }
                
                update(objects.first!)
                // delete redundant objects
                for object in objects {
                    if object != objects.first {
                        context.delete(object)
                        sa_log_v2("delete redundant object of %@", log: .ui, type: .info, className)
                    }
                }
                
                self.save(context)
                DispatchQueue.main.async {
                    completion(objects.first!)
                }
            }
        }
    }
    
    // deleted entities will not returned
    func delete<Entity: NSManagedObject>(predicate: NSPredicate, completion:@escaping (([Entity]) -> Void)) {
        let className = NSStringFromClass(Entity.self).components(separatedBy: ".").last! // remove module name
        if className == "NSManagedObject" {
            fatalError()
        }
        
        withMainContext { (context) in
            let fetch = NSFetchRequest<Entity>(entityName: className)
            fetch.predicate = predicate
            context.perform {
                let objects = try! context.fetch(fetch)
                for object in objects {
                    context.delete(object)
                }
                self.save(context)
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    // MARK: - remove old records
    func cleanUp() {
        let uid = Account().uid
        withMainContext { (context) in
            let fetch = NSFetchRequest<ViewedThread>(entityName: "ViewedThread")
            fetch.predicate = NSPredicate(format: "(uid == %@) AND (lastviewtime < %@)", uid, Date().addingTimeInterval(-60*60*24*30*6) as CVarArg) // keep history of six months
            fetch.sortDescriptors = []
            context.perform {
                let objects = try! context.fetch(fetch)
                for object in objects {
                    context.delete(object as NSManagedObject)
                }
                sa_log_v2("core data cleaned up %@ records", log: .database, type: .info, "\(objects.count)")
            }
        }
    }
    
    // MARK: - Core Data Saving support
    
    func saveContext(completion: (() -> Void)?) {
        withMainContext { (context) in
            self.save(context)
        }
    }
    
    // MARK: - Business methods
    // completion block not on main thread
    private func fetchViewedThreads(completion: (([String]) -> ())?) {
        let uid = Account().uid
        guard !uid.isEmpty else {
            completion?([])
            return
        }
        
        withMainContext { (context) in
            context.perform {
                let fetch = NSFetchRequest<ViewedThread>(entityName: "ViewedThread")
                fetch.predicate = NSPredicate(format: "(uid == %@)", uid)
                fetch.sortDescriptors = []
                guard let objects = try? context.fetch(fetch) else {
                    sa_log_v2("no history of this thread", log: .ui, type: .debug)
                    DispatchQueue.main.async {
                        completion?([])
                    }
                    return
                }
                
                let ids = objects.reduce([String](), { (result, object) -> [String] in
                    if let tid = object.tid {
                        return result + [tid]
                    }
                    return result
                })
                
                DispatchQueue.main.async {
                    completion?(ids)
                }
            }
        }
    }
    
    private func fetchBlockedUserIDs(completion: (([String]) -> ())?) {
        let uid = Account().uid
        guard !uid.isEmpty else {
            completion?([])
            return
        }
        
        var blockedUsers: [BlockedUser] = []
        withMainContext { (context) in
            context.perform {
                let fetch = NSFetchRequest<BlockedUser>(entityName: "BlockedUser")
                fetch.predicate = NSPredicate(format: "reporteruid==%@", uid)
                fetch.sortDescriptors = []
                guard let objects = try? context.fetch(fetch) else {
                    sa_log_v2("error occured when fetching viewed threads", log: .ui, type: .debug)
                    DispatchQueue.main.async {
                        completion?([])
                    }
                    return
                }
                blockedUsers.append(contentsOf: objects)
                let ids = blockedUsers.reduce([String](), { (result, object) -> [String] in
                    if let uid = object.uid {
                        return result + [uid]
                    }
                    return result
                })
                DispatchQueue.main.async {
                    completion?(ids)
                }
            }
        }
    }
    
    private func fetchBlockedThreadIDs(completion: (([String]) -> ())?) {
        let uid = Account().uid
        guard !uid.isEmpty else {
            completion?([])
            return
        }
        
        var blockedThreads: [BlockedThread] = []
        withMainContext { (context) in
            context.perform {
                let fetch = NSFetchRequest<BlockedThread>(entityName: "BlockedThread")
                fetch.predicate = NSPredicate(format: "uid==%@", uid)
                fetch.sortDescriptors = []
                guard let objects = try? context.fetch(fetch) else {
                    sa_log_v2("error occured when fetching blocked threads", log: .ui, type: .debug)
                    DispatchQueue.main.async {
                        completion?([])
                    }
                    return
                }
                blockedThreads.append(contentsOf: objects)
                let ids = blockedThreads.reduce([String](), { (result, object) -> [String] in
                    if let tid = object.tid {
                        return result + [tid]
                    }
                    return result
                })
                DispatchQueue.main.async {
                    completion?(ids)
                }
            }
        }
    }
    
    func blockUser(uid: String, name: String, reason: String?) {
        let selfUid = Account().uid
        guard !selfUid.isEmpty else {
            return
        }
        
        withMainContext { (context) in
            context.perform {
                let fetch = NSFetchRequest<BlockedUser>(entityName: "BlockedUser")
                fetch.predicate = NSPredicate(format: "uid==%@ AND reporteruid==%@", uid, selfUid)
                fetch.sortDescriptors = []
                let objects = try! context.fetch(fetch)
                if objects.count > 0 {
                    return
                }
                
                let blockedUser = NSEntityDescription.insertNewObject(forEntityName: "BlockedUser", into: context) as! BlockedUser
                blockedUser.uid = uid
                blockedUser.createdevicename = UIDevice.current.name
                blockedUser.createdeviceidentifier = AppController.current.currentDeviceIdentifier
                blockedUser.reportingtime = Date()
                blockedUser.reporteruid = selfUid
                blockedUser.name = name
                blockedUser.blockreason = reason
                self.save(context)
            }
        }
        
        if !self.cache!.blockedUserIDs.contains(uid) {
            self.cache!.blockedUserIDs.append(uid)
        }
        NotificationCenter.default.post(name: NSNotification.Name.SABlockedUserListDidChange, object: self, userInfo: ["reportedUid":uid])
    }
    
    func undoBlockUser(uid: String) {
        let selfUid = Account().uid
        guard !selfUid.isEmpty else {
            return
        }
        
        withMainContext { (context) in
            let fetch = NSFetchRequest<NSManagedObject>(entityName: "BlockedUser")
            fetch.predicate = NSPredicate(format: "uid==%@ AND reporteruid==%@", uid, selfUid)
            fetch.sortDescriptors = []
            context.perform {
                if let objects = try? context.fetch(fetch) {
                    for object in objects {
                        context.delete(object)
                    }
                }
                
                self.save(context)
                
                DispatchQueue.main.async {
                    if let _ = self.cache {
                        if let index = self.cache!.blockedUserIDs.firstIndex(of: uid) {
                            self.cache!.blockedUserIDs.remove(at: index)
                        }
                    }
                    NotificationCenter.default.post(name: NSNotification.Name.SABlockedUserListDidChange, object: self, userInfo: ["reportedUid":uid])
                }
                sa_log_v2("delete BlockedUser")
            }
        }
    }
    
    func blockThread(tid: String, title: String, authorID: String, authorName: String, threadCreation: Date) {
        let selfUid = Account().uid
        guard !selfUid.isEmpty else {
            return
        }
        
        withMainContext { (context) in
            context.perform {
                let fetch = NSFetchRequest<BlockedThread>(entityName: "BlockedThread")
                fetch.predicate = NSPredicate(format: "tid==%@ AND uid==%@", tid, selfUid)
                fetch.sortDescriptors = []
                let objects = try! context.fetch(fetch)
                if objects.count > 0 {
                    // title may have changed
                    objects.first?.title = title
                    self.save(context)
                    return
                }
                
                let blockedThread = NSEntityDescription.insertNewObject(forEntityName: "BlockedThread", into: context) as! BlockedThread
                blockedThread.createdevicename = UIDevice.current.name
                blockedThread.createdeviceidentifier = AppController.current.currentDeviceIdentifier
                blockedThread.uid = selfUid
                blockedThread.tid = tid
                blockedThread.title = title
                blockedThread.authorid = authorID
                blockedThread.authorname = authorName
                blockedThread.dateofcreating = threadCreation
                blockedThread.dateofadding = Date()
                self.save(context)
            }
        }
        
        if !self.cache!.blockedThreadIDs.contains(tid) {
            self.cache!.blockedThreadIDs.append(tid)
        }
        NotificationCenter.default.post(name: NSNotification.Name.SABlockedThreadListDidChange, object: self, userInfo: ["tid":tid])
    }
    
    func undoBlockThread(tid: String) {
        let selfUid = Account().uid
        guard !selfUid.isEmpty else {
            return
        }
        
        withMainContext { (context) in
            let fetch = NSFetchRequest<BlockedThread>(entityName: "BlockedThread")
            fetch.predicate = NSPredicate(format: "tid==%@ AND uid==%@", tid, selfUid)
            fetch.sortDescriptors = []
            context.perform {
                if let objects = try? context.fetch(fetch) {
                    for object in objects {
                        context.delete(object)
                    }
                }
                
                self.save(context)
                
                DispatchQueue.main.async {
                    if let _ = self.cache {
                        if let index = self.cache!.blockedThreadIDs.firstIndex(of: tid) {
                            self.cache!.blockedThreadIDs.remove(at: index)
                        }
                    }
                    NotificationCenter.default.post(name: NSNotification.Name.SABlockedThreadListDidChange, object: self, userInfo: ["tid":tid])
                }
                sa_log_v2("delete BlockedThread")
            }
        }
    }
}

// Cache Management
extension SACoreDataManager {
    // call from main thread
    func rebuildCache(completion: CacheBuildingNotify?) {
        let uid = accountManager.activeAccount?.uid ?? "0"
        if let oldCache = self.cache {
            if oldCache.cacheKey == uid {
                completion?(self)
                return
            } else {
                self.cache = nil
            }
        }
        
        if let group = cacheBuildingNotifyGroup {
            group.notify(queue: .main) {
                completion?(self)
            }
            return
        }
        
        let group = DispatchGroup()
        cacheBuildingNotifyGroup = group
        
        var cache = Cache(cacheKey: uid, blockedUserIDs: [], viewedThreadIDs: [], blockedThreadIDs: [])
        group.enter()
        fetchViewedThreads { (viewed) in
            cache.viewedThreadIDs.append(contentsOf: viewed)
            group.leave()
        }
        
        group.enter()
        fetchBlockedUserIDs { (blocked) in
            cache.blockedUserIDs.append(contentsOf: blocked)
            group.leave()
        }
        
        group.enter()
        fetchBlockedThreadIDs { (blocked) in
            cache.blockedThreadIDs.append(contentsOf: blocked)
            group.leave()
        }
        
        group.notify(queue: DispatchQueue.main) {
            self.cache = cache
            completion?(self)
            self.cacheBuildingNotifyGroup = nil
        }
    }
    
    func appendViewedThreadIDsCache(tid: String) {
        assert(Thread.isMainThread, "This method must be called from main thread!")
        self.cache?.viewedThreadIDs.append(tid)
    }
}
