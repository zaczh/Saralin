//
//  SABaseViewController.swift
//  Saralin
//
//  Created by zhang on 9/25/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import ObjectiveC

class SABaseViewController: UIViewController {
    override func decodeRestorableState(with coder: NSCoder) {
        isRestoredFromArchive = true
        super.decodeRestorableState(with: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        addChild(loadingController)
        loadingController.didMove(toParent: self)
        
        loadingController.loadViewIfNeeded()
        view.addSubview(loadingController.view)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        #if targetEnvironment(macCatalyst)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        #endif
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if targetEnvironment(macCatalyst)
        updateToolBar(true)
        #endif
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        #if targetEnvironment(macCatalyst)
        updateToolBar(false)
        #endif
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let webView = view.subviews.first else {
            loadingController.view.frame = view.bounds
            return
        }
        loadingController.view.frame = webView.frame
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme().statusBarStyle
    }
    
    // MARK: theming
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        viewIfLoaded?.backgroundColor = newTheme.backgroundColor.sa_toColor()
        viewIfLoaded?.themeDidUpdate(newTheme)
        for vc in children {
            vc.viewThemeDidChange(newTheme)
        }
    }
    
    override func viewFontDidChange(_ newTheme: SATheme) {
        super.viewFontDidChange(newTheme)
        viewIfLoaded?.fontDidUpdate(newTheme)
        
        for vc in children {
            vc.viewThemeDidChange(newTheme)
        }
    }
    
    open func updateToolBar(_ viewAppeared: Bool) {
        
    }
}
