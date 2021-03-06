//
//  MacSettingsViewController.swift
//  CatalystExtension
//
//  Created by Junhui Zhang on 2020/11/15.
//  Copyright © 2020 zaczh. All rights reserved.
//

import Cocoa

class MacSettingsViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    @IBAction func handleDoneButtonClick(_ sender: AnyObject) {
        view.window?.windowController?.close()
    }
}
