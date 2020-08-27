//
//  SAReachability.swift
//  Saralin
//
//  Created by zhang on 2018/6/9.
//  Copyright © 2018 zaczh. All rights reserved.
//

import UIKit
import SystemConfiguration

func SAReachabilityCallback(_ reachability: SCNetworkReachability, _ flags: SCNetworkReachabilityFlags, _ context: UnsafeMutableRawPointer?) -> Void {
    guard let info = context else {
        return
    }
    
    let m = Unmanaged<SAReachability>.fromOpaque(info).takeUnretainedValue()
    m.updateStatus()
    sa_log_v2("reachability status changed. isWWAN? %@ isReachable: %@", module: .network, type: .info, m.isWWAN ? "1":"0", m.isReachable ? "1" : "0")
}

/// This class IS thread-safe.
class SAReachability: NSObject {
    var isReachable = false
    var isWWAN = false
    private var networkReachability: SCNetworkReachability!
    override init() {
        super.init()
        
        let sin_len = MemoryLayout<sockaddr_in>.size
        var s_add = sockaddr()
        s_add.sa_len = __uint8_t(sin_len)
        s_add.sa_family = sa_family_t(AF_INET)
        networkReachability = SCNetworkReachabilityCreateWithAddress(nil, &s_add)
        
        var context = SCNetworkReachabilityContext.init()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        SCNetworkReachabilitySetCallback(networkReachability, SAReachabilityCallback, &context)
        SCNetworkReachabilityScheduleWithRunLoop(networkReachability, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        updateStatus()
    }
    
    fileprivate func updateStatus() {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        
        var flags = SCNetworkReachabilityFlags.reachable
        isReachable = withUnsafeMutablePointer(to: &flags) { (pointer) -> Bool in
            SCNetworkReachabilityGetFlags(networkReachability, pointer)
            return pointer.pointee.contains(.reachable)
        }
        
        flags = SCNetworkReachabilityFlags.isWWAN
        isWWAN = withUnsafeMutablePointer(to: &flags) { (pointer) -> Bool in
            SCNetworkReachabilityGetFlags(networkReachability, pointer)
            return pointer.pointee.contains(.isWWAN)
        }
    }
    
    deinit {
        SCNetworkReachabilityUnscheduleFromRunLoop(networkReachability, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        SCNetworkReachabilitySetCallback(networkReachability, nil, nil)
    }
}
