//
//  DirectMessage+CoreDataProperties.swift
//  Saralin
//
//  Created by zhang on 2019/9/3.
//  Copyright © 2019 zaczh. All rights reserved.
//
//

import Foundation
import CoreData


extension DirectMessage {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DirectMessage> {
        return NSFetchRequest<DirectMessage>(entityName: "DirectMessage")
    }

    @NSManaged public var authorid: NSNumber?
    @NSManaged public var createdeviceidentifier: String?
    @NSManaged public var createdevicename: String?
    @NSManaged public var dateline: Date?
    @NSManaged public var isnew: NSNumber?
    @NSManaged public var lastauthor: String?
    @NSManaged public var lastauthorid: NSNumber?
    @NSManaged public var lastdateline: Date?
    @NSManaged public var lastsummary: String?
    @NSManaged public var lastupdate: Date?
    @NSManaged public var members: NSNumber?
    @NSManaged public var message: String?
    @NSManaged public var msgfrom: String?
    @NSManaged public var msgfromid: NSNumber?
    @NSManaged public var msgtoid: NSNumber?
    @NSManaged public var plid: NSNumber?
    @NSManaged public var pmnum: NSNumber?
    @NSManaged public var pmtype: NSNumber?
    @NSManaged public var sa_isread: NSNumber?
    @NSManaged public var subject: String?
    @NSManaged public var touid: String?
    @NSManaged public var tousername: String?
    @NSManaged public var uid: String?

}
