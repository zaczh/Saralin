//
//  ForumThread+CoreDataProperties.swift
//  Saralin
//
//  Created by zhang on 2019/9/3.
//  Copyright © 2019 zaczh. All rights reserved.
//
//

import Foundation
import CoreData


extension ForumThread {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ForumThread> {
        return NSFetchRequest<ForumThread>(entityName: "ForumThread")
    }

    @NSManaged public var authorid: String?
    @NSManaged public var authorname: String?
    @NSManaged public var containedimagescount: NSNumber?
    @NSManaged public var createdate: Date?
    @NSManaged public var createdeviceidentifier: String?
    @NSManaged public var createdevicename: String?
    @NSManaged public var fid: String?
    @NSManaged public var isnew: NSNumber?
    @NSManaged public var issettop: NSNumber?
    @NSManaged public var lastreplydate: Date?
    @NSManaged public var lasttimeviewed: Date?
    @NSManaged public var newreplycount: NSNumber?
    @NSManaged public var readlevel: NSNumber?
    @NSManaged public var replycount: NSNumber?
    @NSManaged public var tid: String?
    @NSManaged public var timemodified: Date?
    @NSManaged public var title: String?
    @NSManaged public var viewcount: NSNumber?

}
