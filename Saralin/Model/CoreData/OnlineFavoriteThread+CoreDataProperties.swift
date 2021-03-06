//
//  OnlineFavoriteThread+CoreDataProperties.swift
//  Saralin
//
//  Created by zhang on 2019/9/3.
//  Copyright © 2019 zaczh. All rights reserved.
//
//

import Foundation
import CoreData


extension OnlineFavoriteThread {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<OnlineFavoriteThread> {
        return NSFetchRequest<OnlineFavoriteThread>(entityName: "OnlineFavoriteThread")
    }

    @NSManaged public var authorname: String?
    @NSManaged public var createdeviceidentifier: String?
    @NSManaged public var createdevicename: String?
    @NSManaged public var favid: String?
    @NSManaged public var favoriteddate: Date?
    @NSManaged public var icon: String?
    @NSManaged public var replycount: NSNumber?
    @NSManaged public var tid: String?
    @NSManaged public var title: String?
    @NSManaged public var uid: String?

}
