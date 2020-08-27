//
//  SALogger.swift
//  Saralin
//
//  Created by zhang on 10/29/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import os.log

enum SALogType : Int {
    case `default` = 0
    case debug = 1
    case info = 2
    case error = 3
    case fault = 4
    
    func toString() -> String {
        switch self {
        case .`default`:
            return "Default"
        case .debug:
            return "Debug"
        case .info:
            return "Info"
        case .error:
            return "Error"
        case .fault:
            return "Fault"
        }
    }
    
    @available(iOS 10.0, *)
    func toOSLogType() -> OSLogType {
        switch self {
        case .`default`:
            return OSLogType.default
        case .debug:
            return OSLogType.debug
        case .info:
            return OSLogType.info
        case .error:
            return OSLogType.error
        case .fault:
            return OSLogType.fault
        }
    }
    
    static var allTypes: [SALogType] {
        return [.default, .debug, .info, .error, .fault]
    }
}

enum SALogModule : String {
    case `default`  = "Default"
    case ui         = "UI"
    case utility    = "Utility"
    case network    = "Network"
    case database   = "Database"
    case webView    = "WebView"
    case account    = "Account"
    case cookie     = "Cookie"
    case keychain   = "keychain"
    case search     = "Search"
    case config     = "Config"
    case cloudkit   = "Cloudkit"
}

@available(iOS 10.0, *)
private var _logs: [String:OSLog] = [:]
@available(iOS 10.0, *)
private func getOSLog(for module: String) -> OSLog {
    if let log = _logs[module] {
        return log
    }
    
    let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: module)
    _logs[module] = log
    return log
}

private var _savingLogTypes: [SALogType] = [.info, .error, .fault]
/// Set log types to be saved in file.
/// - Parameter types: The types of log to be saved in file.
func setSavingLogTypes(_ types: [SALogType]) {
    _logQueue.async {
        _savingLogTypes = types
    }
}

// make this public
let sa_log_file_directoy = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.path + "/Data/Log/"
func sa_current_log_file_path() -> String {
    let date = Date()
    let dateComponents = NSCalendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond, .timeZone], from: date)
    let year = String.init(format: "%4d", dateComponents.year ?? 0)
    let month = String.init(format: "%02d", dateComponents.month ?? 0)
    let day = String.init(format: "%02d", dateComponents.day ?? 0)
    return sa_log_file_directoy + "\(year)\(month)\(day).log"
}

private(set) var logFileMaximumCharactersCount = Int(1024 * 1024 * 6)
private let _logQueue = DispatchQueue.init(label: Bundle.main.bundleIdentifier! + ".queue.log")
private let _pid = ProcessInfo.processInfo.processIdentifier


/// The New Log API
///
/// - Parameters:
///   - message: the log message
///   - file: file name of source code
///   - line: line of source code
///   - column: column of source code
///   - function: calling function of source code
///   - module: the log module
///   - type: the log type
///   - args: the args
func sa_log_v2(_ message: StaticString, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function, module: SALogModule = .default, type: SALogType = .debug, _ args: CVarArg...) {
    let date = Date()
    var tid: __uint64_t = 0
    pthread_threadid_np(pthread_self(), &tid)
    let logContent = String.init(format: message.description, arguments: args)
    _logQueue.async {
        let dateComponents = NSCalendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond, .timeZone], from: date)
        
        let year = String.init(format: "%4d", dateComponents.year ?? 0)
        let month = String.init(format: "%02d", dateComponents.month ?? 0)
        let day = String.init(format: "%02d", dateComponents.day ?? 0)
        let hour = String.init(format: "%02d", dateComponents.hour ?? 0)
        let minute = String.init(format: "%02d", dateComponents.minute ?? 0)
        let second = String.init(format: "%09.6f", Double(dateComponents.second ?? 0) + Double(dateComponents.nanosecond ?? 0)/Double(1e9))
        let timeZone = "\(dateComponents.timeZone?.abbreviation() ?? "")"
        
        let logFilePath = sa_log_file_directoy + "\(year)\(month)\(day).log"
        let dateStr = "\(year)-\(month)-\(day) \(hour):\(minute):\(second)\(timeZone)"
        let printLog = String.init(format: "|[%@]|%@:%d|%@:%d|%@\n", type.toString(), (file as NSString).lastPathComponent, line, function, column, logContent)
        if #available(iOS 10.0, *) {
            let log = getOSLog(for: module.rawValue)
            os_log("%@", log: log, type: type.toOSLogType(), printLog)
        } else {
            // Fallback on earlier versions
            NSLog("%@", printLog)
        }
        
        if !_savingLogTypes.contains(type) {
            return
        }
        
        let logSaveInfo = String.init(format: "%@|[%d:%d]|[%@]%@", dateStr, _pid, tid, module.rawValue, printLog)
        guard let logSaveInfoData = logSaveInfo.data(using: .utf8) else {
            os_log("log content illegal")
            return
        }
        
        let fm = FileManager.default
        let fileURL = URL.init(fileURLWithPath: logFilePath)
        let dirURL = fileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: dirURL.path) {
            try! fm.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
        }
        if !fm.fileExists(atPath: logFilePath) {
            fm.createFile(atPath: logFilePath, contents: nil, attributes: nil)
        }
                
        guard let outputStream = OutputStream.init(toFileAtPath: logFilePath, append: true) else {
            os_log("fail to open file at: %@", logFilePath)
            return
        }
        outputStream.open()
        defer {
            outputStream.close()
        }
        
        let bytesWritten = logSaveInfoData.withUnsafeBytes { (pointer) -> Int in
            guard let base = pointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return outputStream.write(base, maxLength: pointer.count)
        }
        guard bytesWritten > 0 else {
            os_log("write to file failed")
            return
        }
    }
}
