//
//  BlockedUser+CoreDataProperties.swift
//  Saralin
//
//  Created by zhang on 2019/9/3.
//  Copyright © 2019 zaczh. All rights reserved.
//
//

import Foundation
import CoreData


extension BlockedUser {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BlockedUser> {
        return NSFetchRequest<BlockedUser>(entityName: "BlockedUser")
    }

    @NSManaged public var blockreason: String?
    @NSManaged public var createdeviceidentifier: String?
    @NSManaged public var createdevicename: String?
    @NSManaged public var name: String?
    @NSManaged public var reporteruid: String?
    @NSManaged public var reportingtime: Date?
    @NSManaged public var uid: String?

}
