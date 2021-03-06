//
//  SearchKeyword+CoreDataProperties.swift
//  Saralin
//
//  Created by zhang on 2019/9/3.
//  Copyright © 2019 zaczh. All rights reserved.
//
//

import Foundation
import CoreData


extension SearchKeyword {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SearchKeyword> {
        return NSFetchRequest<SearchKeyword>(entityName: "SearchKeyword")
    }

    @NSManaged public var category: String?
    @NSManaged public var count: NSNumber?
    @NSManaged public var createdeviceidentifier: String?
    @NSManaged public var createdevicename: String?
    @NSManaged public var date: Date?
    @NSManaged public var keyword: String?
    @NSManaged public var uid: String?

}
