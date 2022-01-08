//
//  SALogger.swift
//  Saralin
//
//  Created by zhang on 10/29/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import os.log

extension OSLogType {
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
        default:
            return "Default"
        }
    }
    
    static let allTypes: [OSLogType] = [.default, .debug, .info, .error, .fault]
}

enum SALogger {
    case `default`// = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Default")
    case ui // Logger(subsystem: Bundle.main.bundleIdentifier!, category: "UI")
    case debugging // Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Debugging")
    case utility // Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Utility")
    case network // Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Network")
    case database // Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Database")
    case webView // Logger(subsystem: Bundle.main.bundleIdentifier!, category: "WebView")
    case account // Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Account")
    case cookie // Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Cookie")
    case keychain // Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Keychain")
    case search // Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Search")
    case config // Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Config")
    case cloudkit // Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Cloudkit")

    func getCategory() -> String {
        switch self {
        case .ui:
            return "UI"
        case .utility:
            return "Utility"
        case .network:
            return "Network"
        case .database:
            return "Database"
        case .webView:
            return "WebView"
        case .account:
            return "Account"
        case .cookie:
            return "Cookie"
        case .keychain:
            return "Keychain"
        case .search:
            return "Search"
        case .config:
            return "Config"
        case .cloudkit:
            return "Cloudkit"
        default:
            return "Default"
        }
    }
    
    func getLogger() -> Logger {
        switch self {
        case .ui:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "UI")
        case .debugging:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Debugging")
        case .utility:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Utility")
        case .network:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Network")
        case .database:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Database")
        case .webView:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "WebView")
        case .account:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Account")
        case .cookie:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Cookie")
        case .keychain:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Keychain")
        case .search:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Search")
        case .config:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Config")
        case .cloudkit:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Cloudkit")
        default:
            return Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Default")
        }
    }
}

private var _savingLogTypes: [OSLogType] = [.info, .error, .fault]
/// Set log types to be saved in file.
/// - Parameter types: The types of log to be saved in file.
func setSavingLogTypes(_ types: [OSLogType]) {
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
///   - log: the os log object
///   - type: the log type
///   - args: the args
func sa_log_v2(_ message: StaticString, file: String = #file, line: Int = #line, column: Int = #column, function: String = #function, log: SALogger = .default, type: OSLogType = .debug, _ args: CVarArg...) {
    let date = Date()
    var tid: __uint64_t = 0
    pthread_threadid_np(pthread_self(), &tid)
    let logContent = String.init(format: message.description, arguments: args)
    log.getLogger().log(level: type, "\(logContent)")
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
        if !_savingLogTypes.contains(type) {
            return
        }
        
        let logSaveInfo = String.init(format: "%@|[%d:%d]|[%@]%@", dateStr, _pid, tid, log.getCategory(), printLog)
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
