//
//  ViewedThread+CoreDataProperties.swift
//  Saralin
//
//  Created by zhang on 2019/9/3.
//  Copyright © 2019 zaczh. All rights reserved.
//
//

import Foundation
import CoreData


extension ViewedThread {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ViewedThread> {
        return NSFetchRequest<ViewedThread>(entityName: "ViewedThread")
    }

    @NSManaged public var author: String?
    @NSManaged public var authorid: String?
    @NSManaged public var createdeviceidentifier: String?
    @NSManaged public var createdevicename: String?
    @NSManaged public var fid: String?
    @NSManaged public var lastviewfloor: NSNumber?
    @NSManaged public var lastviewpageisreverseloading: NSNumber?
    @NSManaged public var lastviewreplycount: NSNumber?
    @NSManaged public var lastviewreplyid: NSNumber?
    @NSManaged public var lastviewtime: Date?
    @NSManaged public var page: NSNumber?
    @NSManaged public var subject: String?
    @NSManaged public var tid: String?
    @NSManaged public var uid: String?
    @NSManaged public var webviewyoffset: NSNumber?

}
