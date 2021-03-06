//
//  ViewedBoard+CoreDataProperties.swift
//  Saralin
//
//  Created by zhang on 2019/9/3.
//  Copyright © 2019 zaczh. All rights reserved.
//
//

import Foundation
import CoreData


extension ViewedBoard {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ViewedBoard> {
        return NSFetchRequest<ViewedBoard>(entityName: "ViewedBoard")
    }

    @NSManaged public var createdeviceidentifier: String?
    @NSManaged public var createdevicename: String?
    @NSManaged public var fid: String?
    @NSManaged public var lastfetchedtid: String?
    @NSManaged public var lastviewtime: Date?
    @NSManaged public var name: String?
    @NSManaged public var typeid: String?
    @NSManaged public var uid: String?

}
