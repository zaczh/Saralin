//
//  Models.swift
//  Saralin
//
//  Created by Junhui Zhang on 2020/5/20.
//  Copyright © 2020 zaczh. All rights reserved.
//

import Foundation

struct ThreadSummary {
    var tid: String
    var fid: String
    var subject: String
    var author: String
    var authorid: String
    var dbdateline: String
    var dblastpost: String
    var replies: Int
    var views: Int
    var readperm: Int
    
    var attachment:Int = 0
    
    // optional
    var typeid: String? = nil
    var floor: Int = 1
    var formhash: String? = nil
    
    var hasRead = false
}

struct PrivateMessageSummary {
    var lastupdate: String
    var isnew: Int
    var tousername: String
    var touid: String
    var message: String
    var pmnum: Int
}

struct ThreadPollDetail {
    var polloptionid: Int
    var tid: Int
    var votes: Int
    var displayorder: Int
    var polloption: String
    var voterids: String
}
