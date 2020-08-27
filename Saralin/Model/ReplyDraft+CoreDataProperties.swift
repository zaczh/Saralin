//
//  ReplyDraft+CoreDataProperties.swift
//  Saralin
//
//  Created by zhang on 2019/9/3.
//  Copyright © 2019 zaczh. All rights reserved.
//
//

import Foundation
import CoreData


extension ReplyDraft {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReplyDraft> {
        return NSFetchRequest<ReplyDraft>(entityName: "ReplyDraft")
    }

    @NSManaged public var attachedimagedata: Data?
    @NSManaged public var createdate: Date?
    @NSManaged public var createdeviceidentifier: String?
    @NSManaged public var createdevicename: String?
    @NSManaged public var draftcontent: String?
    @NSManaged public var draftcontentdata: Data?
    @NSManaged public var fid: String?
    @NSManaged public var quote_author: String?
    @NSManaged public var quote_content_urlencoded: String?
    @NSManaged public var quote_id: String?
    @NSManaged public var quote_name: String?
    @NSManaged public var quote_textcontent: String?
    @NSManaged public var tid: String?
    @NSManaged public var uid: String?

}
