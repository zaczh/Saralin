//
//  SACatalystSidebarController.swift
//  Saralin
//
//  Created by junhui zhang on 2019/10/13.
//  Copyright © 2019 zaczh. All rights reserved.
//

import UIKit


enum CatelystSidebarSectionID: Int {
    case forums
    case others
    case max
}

class SACatalystSidebarController: SABaseViewController, UITableViewDataSource, UITableViewDelegate {

    class SidebarCell: UITableViewCell {
        
        private func doUpdateForTheme(_ newTheme: SATheme) {
            imageView?.tintColor = newTheme.textColor.sa_toColor()
            textLabel?.textColor = newTheme.textColor.sa_toColor()
        }
        
        override func themeDidUpdate(_ newTheme: SATheme) {
            super.themeDidUpdate(newTheme)
            doUpdateForTheme(newTheme)
        }
        
        override func fontDidUpdate(_ newTheme: SATheme) {
            super.fontDidUpdate(newTheme)
            textLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        }
    }
    
    class AvatarView: UIView {
        let contentView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        let customImageView = UIButton(type: .custom)
        let uin = UILabel()
        let name = UILabel()
        let settingsButton = UIButton(type: .custom)
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            addSubview(contentView)
            customImageView.layer.masksToBounds = true
            contentView.translatesAutoresizingMaskIntoConstraints = false
            contentView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
            contentView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
            contentView.topAnchor.constraint(equalTo: topAnchor).isActive = true
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
            
            customImageView.translatesAutoresizingMaskIntoConstraints = false
            contentView.contentView.addSubview(customImageView)
            
            // contentview height constraint here
            customImageView.setBackgroundImage(UIImage(named: "noavatar_middle"), for: .normal)
            customImageView.leftAnchor.constraint(equalTo: contentView.contentView.leftAnchor, constant: 10).isActive = true
            customImageView.heightAnchor.constraint(equalToConstant: 40).isActive = true
            customImageView.widthAnchor.constraint(equalTo: customImageView.heightAnchor, multiplier: 1).isActive = true
            customImageView.centerYAnchor.constraint(equalTo: contentView.contentView.centerYAnchor, constant: 0).isActive = true
            customImageView.layer.cornerRadius = 40/2.0

            
            uin.text = Account().uid
            name.text = Account().name
            let stack = UIStackView(arrangedSubviews: [name, uin])
            stack.axis = .vertical
            contentView.contentView.addSubview(stack)
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.leftAnchor.constraint(equalTo: customImageView.rightAnchor, constant: 16).isActive = true
            stack.centerYAnchor.constraint(equalTo: contentView.contentView.centerYAnchor).isActive = true
            
            contentView.contentView.addSubview(settingsButton)
            if #available(iOS 13.0, *) {
                settingsButton.setBackgroundImage(UIImage(systemName: "gear"), for: .normal)
            } else {
                // Fallback on earlier versions
                settingsButton.setBackgroundImage(UIImage(named: "Settings-44"), for: .normal)
            }
            settingsButton.translatesAutoresizingMaskIntoConstraints = false
            settingsButton.rightAnchor.constraint(equalTo: contentView.contentView.rightAnchor, constant: -8).isActive = true
            settingsButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
            settingsButton.widthAnchor.constraint(equalTo: settingsButton.heightAnchor, multiplier: 1).isActive = true
            settingsButton.centerYAnchor.constraint(equalTo: contentView.contentView.centerYAnchor).isActive = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func themeDidUpdate(_ newTheme: SATheme) {
            super.themeDidUpdate(newTheme)
            uin.textColor = newTheme.tableCellGrayedTextColor.sa_toColor()
            name.textColor = newTheme.textColor.sa_toColor()
            settingsButton.tintColor = newTheme.textColor.sa_toColor()
        }
        
        func refreshView() {
            uin.text = Account().uid
            name.text = Account().name
            
            customImageView.setBackgroundImage(UIImage(named: "noavatar_middle"), for: .normal)
            if let avatarURL = Account().avatarImageURL {
                URLSession.saCustomized.dataTask(with: avatarURL) { [weak self] (data, rsp, error) in
                    guard error == nil, let data = data else {
                        return
                    }
                    
                    guard let image = UIImage(data: data) else {
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self?.customImageView.setBackgroundImage(image, for: .normal)
                    }
                }.resume()
            }
        }
    }
    
    private let upperTableView = UITableView(frame: .zero, style: .grouped)
    private var dataSource: [[String:AnyObject]] = []
    private var boardsSummaryData: [[String:AnyObject]]?
    private let avatarView = AvatarView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.

        view.addSubview(avatarView)
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 4).isActive = true
        avatarView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -4).isActive = true
        avatarView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        avatarView.heightAnchor.constraint(equalToConstant: 50).isActive = true
        avatarView.customImageView.addTarget(self, action: #selector(handleAvatarViewTap(_:)), for: .touchUpInside)
        avatarView.settingsButton.addTarget(self, action: #selector(handleAvatarViewSettingsGearClick(_:)), for: .touchUpInside)

        view.insertSubview(upperTableView, belowSubview: avatarView)
        
        upperTableView.showsVerticalScrollIndicator = false
        upperTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        upperTableView.showsHorizontalScrollIndicator = false
        upperTableView.separatorStyle = .none
        upperTableView.rowHeight = 40
        upperTableView.estimatedRowHeight = 40
        upperTableView.backgroundColor = .clear
        upperTableView.dataSource = self
        upperTableView.delegate = self
        upperTableView.register(SidebarCell.self, forCellReuseIdentifier: "SidebarCell")
        upperTableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            upperTableView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 4),
            upperTableView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -4),
            upperTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
            upperTableView.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 0)
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserLoggedIn(_:)), name: .SAUserLoggedInNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserLoggedOut(_:)), name: .SAUserLoggedOutNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserPreferenceChange(_:)), name: .SAUserPreferenceChangedNotification, object: nil)

        let searchBar = UISearchBar(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        searchBar.delegate = self
        if UIDevice.current.userInterfaceIdiom == .mac {
            upperTableView.tableHeaderView = searchBar
        }
        refreshTableViewCompletion(nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(handleMacKeyCommandPreferences(_:)), name: .macKeyCommandPreferencesPanel, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .macKeyCommandPreferencesPanel, object: nil)
    }
    
    @objc func handleMacKeyCommandPreferences(_ sender: AnyObject) {
        let userActivity = NSUserActivity(activityType: SAActivityType.settings.rawValue)
        userActivity.isEligibleForHandoff = true
        userActivity.title = SAActivityType.settings.title()
        userActivity.userInfo = nil
        let options = UIScene.ActivationRequestOptions()
        options.requestingScene = view.window?.windowScene
        UIApplication.shared.requestSceneSessionActivation(AppController.current.findSceneSession(activityType: SAActivityType.settings.rawValue), userActivity: userActivity, options: options) { (error) in
            os_log("request new scene returned: %@", error.localizedDescription)
        }
    }
    
    func refreshTableViewCompletion(_ completion: ((SALoadingViewController.LoadingResult, NSError?) -> Void)?) {
        guard let boards = Account().preferenceForkey(SAAccount.Preference.shown_boards_ids) as? [Int] else {
            completion?(.emptyData, nil)
            return
        }
        
        var newDataSource = [[String:AnyObject]]()
        for board in boards {
            let forumInfo = NSDictionary(contentsOf: AppController.current.forumInfoConfigFileURL)! as! [String:AnyObject]
            let forumList = forumInfo["items"] as! [[String:AnyObject]]
            guard let foundBoard = forumList.first(where: { (obj) -> Bool in
                if let fids = obj["fid"] as? String, let fid = Int(fids) {
                    return fid == board
                }
                return false
            }) else {
                continue
            }
            newDataSource.append(foundBoard)
        }
        self.dataSource.removeAll()
        self.dataSource.append(contentsOf: newDataSource)
        self.upperTableView.reloadData()
        
        avatarView.refreshView()
        
        URLSession.saCustomized.getBoardsSummary { (obj, error) in
            guard error == nil else {
                return
            }
            
            guard let json = obj as? [String:AnyObject] else {
                return
            }
            
            guard let data = json["data"] as? [[String:AnyObject]] else {
                return
            }
                        
            DispatchQueue.main.async {
                self.boardsSummaryData = data
                self.upperTableView.reloadData()
                completion?(.newData, nil)
            }
        }
    }
    
    override func viewThemeDidChange(_ newTheme: SATheme) {
        super.viewThemeDidChange(newTheme)
        view.backgroundColor = newTheme.foregroundColor.sa_toColor()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return CatelystSidebarSectionID.max.rawValue
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == CatelystSidebarSectionID.forums.rawValue {
            return dataSource.count
        } else {
            return 3
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SidebarCell", for: indexPath) as! SidebarCell
        
        if indexPath.section == CatelystSidebarSectionID.forums.rawValue {
            cell.textLabel?.text = dataSource[indexPath.row]["name"] as? String
            if let forumIDStr = dataSource[indexPath.row]["fid"] as? String,
                let forumID = Int(forumIDStr),
                let boardSummary = getSummaryDataOfBoard(forumID),
                let todayPosts = boardSummary["todayposts"] as? String {
                cell.textLabel?.text = (cell.textLabel?.text ?? "") + " (\(todayPosts))"
            }
        } else {
            if indexPath.row == 0 {
                cell.textLabel?.text = NSLocalizedString("RECENTLY_VIEWED", comment: "Recently viewed")
            } else if indexPath.row == 1 {
                cell.textLabel?.text = NSLocalizedString("ONLINE_COLLECTION_TITLE", comment: "Online collection")
            } else if indexPath.row == 2 {
                cell.textLabel?.text = NSLocalizedString("FAVORITE_VC_WATCH_LIST", comment: "Watch list")
            }
            
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == CatelystSidebarSectionID.forums.rawValue {
            return NSLocalizedString("FORUM_VC_TITLE", comment: "Forum")
        } else {
            return NSLocalizedString("OTHERS", comment: "Others")
        }
    }
    
    func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == CatelystSidebarSectionID.forums.rawValue {
            let fid = dataSource[indexPath.row]["fid"] as! String
            let url = URL(string: SAGlobalConfig().forum_base_url + "forum.php?mod=forumdisplay&fid=\(fid)&mobile=1")!
            let board = SABoardViewController(url: url)
            let navi = SANavigationController(rootViewController: board)
            splitViewController?.setViewController(navi, for: .supplementary)
        } else if indexPath.section == CatelystSidebarSectionID.others.rawValue {
            if indexPath.row == 0 {
                let vc = SAFavouriteBoardsViewController()
                vc.segmentedControl.selectedSegmentIndex = SAFavouriteBoardsViewController.SegmentedControlIndex.recent.rawValue
                let navi = SANavigationController(rootViewController: vc)
                splitViewController?.setViewController(navi, for: .supplementary)
            } else if indexPath.row == 1 {
                let vc = SAFavouriteBoardsViewController()
                vc.segmentedControl.selectedSegmentIndex = SAFavouriteBoardsViewController.SegmentedControlIndex.thread.rawValue
                let navi = SANavigationController(rootViewController: vc)
                splitViewController?.setViewController(navi, for: .supplementary)
            } else if indexPath.row == 2 {
                let vc = SAFavouriteBoardsViewController()
                vc.segmentedControl.selectedSegmentIndex = SAFavouriteBoardsViewController.SegmentedControlIndex.watchList.rawValue
                let navi = SANavigationController(rootViewController: vc)
                splitViewController?.setViewController(navi, for: .supplementary)
            }
        }
    }
    
    private func getSummaryDataOfBoard(_ boardID : Int) -> [String:AnyObject]? {
        if boardsSummaryData == nil {
            return nil
        }
        
        for sub in boardsSummaryData! {
            if let child = sub["child"] as? [[String:AnyObject]] {
                for childForum in child {
                    if let fid = childForum["fid"] as? Int, fid == boardID {
                        return childForum
                    }
                }
            }
        }
        
        return nil
    }
    
    @objc func handleAvatarViewTap(_ sender: UIButton) {
        if Account().isGuest {
            AppController.current.presentLoginViewController(sender: self, completion: nil)
            return
        }
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("SURE", comment: "Sure"), style: .cancel, handler: nil))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("ACCOUNT_CENTER_VC_TITLE", comment: "Account"), style: .default, handler: { (action) in
            guard !Account().isGuest else {
                return
            }
            
            let url = SAGlobalConfig().profile_url_template.replacingOccurrences(of: "%{UID}", with: Account().uid)
            let page = SAAccountInfoViewController(url: URL(string: url)!)
            page.isAccountManager = true
            let navi = SANavigationController(rootViewController: page)
            self.splitViewController?.setViewController(navi, for: .secondary)
        }))
        
        if !Account().hasCheckedInToday {
            alert.addAction(UIAlertAction(title: NSLocalizedString("CLICK_TO_PUNCH_IN_TODAY", comment: "点击签到"), style: .default, handler: { (action) in
                let activity = SAModalActivityViewController()
                self.present(activity, animated: true, completion: nil)
                AppController.current.getService(of: SABackgroundTaskManager.self)!.dailyCheckIn { (succeeded) in
                    if succeeded {
                        activity.hideAndShowResult(of: true, info: NSLocalizedString("HAVE_PUNCHED_IN_TODAY", comment: "已签到")) { () in
                        }
                    } else {
                        activity.hideAndShowResult(of: false, info: NSLocalizedString("OPERATION_FAILED", comment: "操作失败")) { () in
                        }
                    }
                }
            }))
        }
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("ACCOUNT_VC_MY_MESSAGES", comment: "Messages"), style: .default, handler: { (action) in
            if Account().isGuest {
                AppController.current.presentLoginAlert(sender: self, completion: nil)
                return
            }
            let vc = SAMessageInboxViewController()
            let navi = SANavigationController(rootViewController: vc)
            self.splitViewController?.setViewController(navi, for: .secondary)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("ACCOUNT_VC_MY_THREADS", comment: "Threads"), style: .default, handler: { (action) in
            if Account().isGuest {
                AppController.current.presentLoginAlert(sender: self, completion: nil)
                return
            }
            let vc = AppController.current.createMyThreadsPage()
            let navi = SANavigationController(rootViewController: vc)
            self.splitViewController?.setViewController(navi, for: .secondary)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("ACCOUNT_VC_MY_NOTICES", comment: "Notices"), style: .default, handler: { (action) in
            if Account().isGuest {
                AppController.current.presentLoginAlert(sender: self, completion: nil)
                return
            }
            let vc = SAUserNoticeViewController()
            let navi = SANavigationController(rootViewController: vc)
            self.splitViewController?.setViewController(navi, for: .secondary)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("ACCOUNT_VC_BLACKLIST", comment: "Blocked"), style: .default, handler: { (action) in
            let vc = SABlockedListConfigureViewController()
            let navi = SANavigationController(rootViewController: vc)
            self.splitViewController?.setViewController(navi, for: .secondary)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("ACCOUNT_VC_ABOUT", comment: "Abount"), style: .default, handler: { (action) in
            let vc = SAAboutViewController()
            let navi = SANavigationController(rootViewController: vc)
            self.splitViewController?.setViewController(navi, for: .secondary)
        }))
        
        alert.addAction(UIAlertAction(title: NSLocalizedString("ACCOUNT_VC_LOG_OUT", comment: "Log out"), style: .destructive, handler: { (action) in
            AppController.current.getService(of: SAAccountManager.self)?.logoutCurrentActiveAccount(nil)
        }))
        
        alert.popoverPresentationController?.sourceView = sender
        alert.popoverPresentationController?.sourceRect = sender.bounds
        present(alert, animated: true, completion: nil)
    }
    
    @objc func handleAvatarViewSettingsGearClick(_ sender: UIButton) {
        if UIDevice.current.userInterfaceIdiom == .mac {
            let macCatalystExtensionBundlePath = Bundle.main.builtInPlugInsPath! + "/CatalystExtension.bundle"
            let bundle = Bundle.init(path: macCatalystExtensionBundlePath)!
            if let cls = bundle.principalClass as? NSObject.Type {
                cls.perform(NSSelectorFromString("runCommand:object:"), with: "ShowSettingsWindow", with: nil)
            }
            return
        }
        
        if #available(iOS 13.0, *) {
            if UIApplication.shared.supportsMultipleScenes && (Account().preferenceForkey(.enable_multi_windows, defaultValue: false as AnyObject) as! Bool) {
                let userActivity = NSUserActivity(activityType: SAActivityType.settings.rawValue)
                userActivity.isEligibleForHandoff = true
                userActivity.title = SAActivityType.viewImage.title()
                userActivity.userInfo = nil
                let options = UIScene.ActivationRequestOptions()
                options.requestingScene = view.window?.windowScene
                UIApplication.shared.requestSceneSessionActivation(AppController.current.findSceneSession(), userActivity: userActivity, options: options) { (error) in
                    os_log("request new scene returned: %@", error.localizedDescription)
                }
            } else {
                let split = AppController.current.instantiateInitialViewController(for: .settings) as! UISplitViewController
                let navi = split.viewControllers.first as! UINavigationController
                let settings = navi.topViewController! as! SASettingViewController
                settings.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("CLOSE", comment: "Close"), style: .plain, target: self, action: #selector(handleSettingsClose(_:)))
                present(navi, animated: true, completion: nil)
            }
        } else {
            // Fallback on earlier versions
            let split = AppController.current.instantiateInitialViewController(for: .settings) as! UISplitViewController
            let navi = split.viewControllers.first as! UINavigationController
            split.modalPresentationStyle = .formSheet
            let settings = navi.topViewController! as! SASettingViewController
            settings.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("CLOSE", comment: "Close"), style: .plain, target: self, action: #selector(handleSettingsClose(_:)))
            present(split, animated: true, completion: nil)
        }
    }
    
    @objc func handleSettingsClose(_ sender: AnyObject) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Notification handling
    @objc func handleUserLoggedIn(_ notification: Notification) {
        refreshTableViewCompletion(nil)
    }
    
    @objc func handleUserLoggedOut(_ notification: Notification) {
        refreshTableViewCompletion(nil)
    }
    
    @objc func handleUserPreferenceChange(_ notification: Notification) {
        let userInfo = notification.userInfo
        guard let key = userInfo?[SAAccount.Preference.changedPreferenceNameKey] as? SAAccount.Preference else {
            return
        }
        if key == SAAccount.Preference.shown_boards_ids {
            refreshTableViewCompletion(nil)
        }
    }
}

@available(iOS 13.0, *)
extension SACatalystSidebarController: UISearchBarDelegate {
    
}
