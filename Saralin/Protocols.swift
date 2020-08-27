//
//  Protocols.swift
//  Saralin
//
//  Created by zhang on 2019/9/26.
//  Copyright © 2019 zaczh. All rights reserved.
//

import UIKit

protocol SAViewControllerTheming {
    func viewThemeDidChange(_ newTheme:SATheme)
    func viewFontDidChange(_ newTheme:SATheme)
}

protocol SAViewTheming {
    func themeDidUpdate(_ newTheme: SATheme)
    func fontDidUpdate(_ newTheme: SATheme)
}

protocol SAViewControllerActiveStateChanging {
    func viewWillResignActive()
    func viewDidBecomeActive()
}

protocol SAViewControllerLoading {
    var loadingView: UIView {get}
    var loadingController: SALoadingViewController {get}
    func loadingControllerDidRetry(_ controller: SALoadingViewController)
}

protocol SAViewControllerRestore {
    var isRestoredFromArchive: Bool {get set}
}

protocol SAViewControllerVisibility {
    var isViewVisible: Bool {get set}
}
