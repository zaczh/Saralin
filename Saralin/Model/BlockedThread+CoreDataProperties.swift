//
//  BlockedThread+CoreDataProperties.swift
//  Saralin
//
//  Created by zhang on 2019/9/3.
//  Copyright © 2019 zaczh. All rights reserved.
//
//

import Foundation
import CoreData


extension BlockedThread {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BlockedThread> {
        return NSFetchRequest<BlockedThread>(entityName: "BlockedThread")
    }

    @NSManaged public var authorid: String?
    @NSManaged public var authorname: String?
    @NSManaged public var createdeviceidentifier: String?
    @NSManaged public var createdevicename: String?
    @NSManaged public var dateofadding: Date?
    @NSManaged public var dateofcreating: Date?
    @NSManaged public var fid: String?
    @NSManaged public var tid: String?
    @NSManaged public var title: String?
    @NSManaged public var uid: String?

}
