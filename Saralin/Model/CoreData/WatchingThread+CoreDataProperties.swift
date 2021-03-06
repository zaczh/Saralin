//
//  WatchingThread+CoreDataProperties.swift
//  Saralin
//
//  Created by zhang on 2019/9/3.
//  Copyright © 2019 zaczh. All rights reserved.
//
//

import Foundation
import CoreData


extension WatchingThread {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WatchingThread> {
        return NSFetchRequest<WatchingThread>(entityName: "WatchingThread")
    }

    @NSManaged public var author: String?
    @NSManaged public var authorid: String?
    @NSManaged public var cachedcontent: String?
    @NSManaged public var createdeviceidentifier: String?
    @NSManaged public var createdevicename: String?
    @NSManaged public var fid: String?
    @NSManaged public var hasreplied: NSNumber?
    @NSManaged public var hotdegree: NSNumber?
    @NSManaged public var lastfetchreplycount: NSNumber?
    @NSManaged public var lastreplyupdatedtime: Date?
    @NSManaged public var lastviewreplycount: NSNumber?
    @NSManaged public var lastviewtime: Date?
    @NSManaged public var newreplycount: NSNumber?
    @NSManaged public var page: NSNumber?
    @NSManaged public var subject: String?
    @NSManaged public var tid: String?
    @NSManaged public var timeadded: Date?
    @NSManaged public var uid: String?

}
