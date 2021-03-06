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
    
    @objc static func runCommand(_ command: String, context: Any?) {
        return self.shared.runCommand(command)
    }
    
    func run() {
    }
    
    func runCommand(_ command: String) {
        if command == "ShowSettingsWindow" {
            showSettingsWindowController()
        }
    }
    
    private var settingsWindowController: NSWindowController?
    private func showSettingsWindowController() {
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
}
