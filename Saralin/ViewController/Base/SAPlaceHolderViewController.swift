//
//  SAPlaceHolderViewController.swift
//  Saralin
//
//  Created by Junhui Zhang on 2020/2/18.
//  Copyright © 2020 zaczh. All rights reserved.
//

import UIKit

class SAPlaceHolderViewController: SABaseViewController {
    @IBOutlet var infoLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        infoLabel.text = NSLocalizedString("PLACEHOLDER_VC_INFO_TEXT", comment: "Swipe Right")
        
        splitViewController?.show(.primary)
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        infoLabel.textColor = Theme().textColor.sa_toColor()
        view.backgroundColor = Theme().backgroundColor.sa_toColor()
    }
}
