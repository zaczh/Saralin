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
        
        infoLabel.text = "请从左侧打开一个帖子"
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        
        NSLayoutConstraint(item: infoLabel!, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: infoLabel!, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.0, constant: 0).isActive = true
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        infoLabel.textColor = Theme().textColor.sa_toColor()
        view.backgroundColor = Theme().backgroundColor.sa_toColor()
    }
}
