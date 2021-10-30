//
//  CatalystExtensionLoader.swift
//  CatalystExtension
//
//  Created by Junhui Zhang on 2020/11/15.
//  Copyright © 2020 zaczh. All rights reserved.
//

import Cocoa

class CatalystExtensionLoader: NSObject {
    static let shared = CatalystExtensionLoader()
    
    @objc static func run() {
        return self.shared.run()
    }
    
    @objc static func runCommand(_ command: String, object: AnyObject?) {
        return self.shared.runCommand(command, object: object)
    }
    
    func run() {
    }
    
    func runCommand(_ command: String, object: AnyObject?) {
        if command == "ShowSettingsWindow" {
            showSettingsWindowController(object: object)
            return
        }
        
        if command == "ViewImage" {
            viewImage(object: object)
            return
        }
    }
    
    private var settingsWindowController: NSWindowController?
    private func showSettingsWindowController(object: AnyObject?) {
        if settingsWindowController == nil {
            let extensionMainWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                                               styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            let settingsViewController = MacSettingsViewController(nibName: nil, bundle: Bundle(for: CatalystExtensionLoader.self))
            extensionMainWindow.contentViewController = settingsViewController
            settingsWindowController = NSWindowController(window: extensionMainWindow)
        }
        if let window = NSApp.keyWindow != nil ? NSApp.keyWindow : NSApp.mainWindow {
            let selfWindow = settingsWindowController!.window!
            let centerPosition = window.convertPoint(toScreen: CGPoint(x: window.frame.size.width * 0.5, y: window.frame.size.height * 0.5))
            selfWindow.setFrameOrigin(CGPoint(x: centerPosition.x - selfWindow.frame.size.width * 0.5,
                                              y: centerPosition.y - selfWindow.frame.size.height * 0.5))
        }
        settingsWindowController!.window?.makeKeyAndOrderFront(nil)
    }
    
    
    private func viewImage(object: AnyObject?) {
        guard let param = object as? [String:AnyObject] else {
            return
        }
        
        // let url = param["url"] as! URL
        
        guard let fileUrl = param["fileUrl"] as? URL else {
            return
        }
        
        NSWorkspace.shared.open(fileUrl)
    }
}
