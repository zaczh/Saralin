//
//  SASettingViewController.swift
//  Saralin
//
//  Created by zhang on 10/21/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

class SASettingViewController: SABaseTableViewController {
    
    private var dataSource: [[String:Any]]! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = NSLocalizedString("SETTING_VC_TITLE", comment: "setting view title")
        
        tableView.tableFooterView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: view.frame.size.width, height: 20))
        tableView.estimatedRowHeight = 60
        tableView.estimatedSectionHeaderHeight = 40
        tableView.estimatedSectionFooterHeight = 40
        tableView.register(SAAccountCenterHeaderCell.self, forCellReuseIdentifier: "head")
        tableView.register(SAAccountCenterBodyCell.self, forCellReuseIdentifier: "cell")
        tableView.register(SAThemedTableHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "header")
        tableView.register(SAThemedTableHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "footer")
        
        dataSource = [
            
            ["summary":"",
             "items":[
                ["title":NSLocalizedString("OPTION_THREAD_VIEW_SHOWS_AVATAR", comment: "OPTION_THREAD_VIEW_SHOWS_AVATAR"), "detail":"", "bottom":"", "isSwitch":"1", "bindKey":SAAccount.Preference.thread_view_shows_avatar.rawValue, "eventId":"15"],
                ],
             "description":NSLocalizedString("OPTION_THREAD_VIEW_SHOWS_AVATAR_DESCRIPTION", comment: "OPTION_THREAD_VIEW_SHOWS_AVATAR_DESCRIPTION")
            ],
            
            ["summary":"",
             "items":[
                ["title":NSLocalizedString("OPTION_THREADS_DISPLAY_ORDER", comment: "帖子显示顺序"), "detail":"", "bindKey":SAAccount.Preference.new_threads_order.rawValue,  "bottom":"", "eventId":"10", "isSegmentedControl":"1"],
                ],
             "description":NSLocalizedString("OPTION_THREADS_DISPLAY_ORDER_DESCRIPTION", comment: "设置帖子列表的排序规则")
            ],
            
//            ["summary":"",
//             "items":[
//                ["title":NSLocalizedString("OPTION_HOT_TAB_SHOW_BOARD_FID", comment: "热门Tab显示子版块"), "detail":"", "bindKey":SAAccount.Preference.hot_tab_board_fid.rawValue,  "bottom":"", "clickable":"1", "eventId":"hot_tab_board_fid", "disclosure":"1"],
//                ],
//             "description":NSLocalizedString("OPTION_HOT_TAB_SHOW_BOARD_FID_DESCRIPTION", comment: "设置热门Tab显示子版块")
//            ],
            
            ["summary":"",
             "items":[
                ["title":NSLocalizedString("OPTION_ENABLE_PASTEBOARD_MONITORING", comment: "开启剪贴板监控"), "detail":"", "bindKey":SAAccount.Preference.enable_pasteboard_monitoring.rawValue, "bottom":"", "eventId":"enable_pasteboard_monitoring", "isSwitch":"1"],
                ],
             "description":NSLocalizedString("OPTION_ENABLE_PASTEBOARD_MONITORING_DESCRIPTION", comment: "")
            ],
            
            ["summary":"",
             "items":[
                ["title":NSLocalizedString("OPTION_THEME_SETTING", comment: "OPTION_THEME_SETTING"), "detail":"", "isSwitch":"0", "disclosure":"1", "clickable":"1","bindKey":SAAccount.Preference.theme_id.rawValue, "eventId":"3"],
                ["title":NSLocalizedString("OPTION_BOARD_SETTING", comment: "OPTION_BOARD_SETTING"), "detail":"", "isSwitch":"0", "disclosure":"1", "clickable":"1","bindKey":SAAccount.Preference.shown_boards_ids.rawValue, "eventId":"12"],
                ["title":NSLocalizedString("OPTION_FONT_SETTING", comment: "OPTION_FONT_SETTING"), "detail":"", "disclosure":"1", "bottom":"", "clickable":"1", "eventId":"13"],
                ],
             
             "description":""
            ],
            
            ["summary":"",
             "items":[
                ["title":NSLocalizedString("SETTINGS_OPTION_TURN_ON_NOTIFICATION", comment: "turn on notifications"), "detail":NSLocalizedString("SETTINGS_OPTION_TURN_ON_NOTIFICATION_DETAIL", comment: "Go To Settings"), "bottom":"", "clickable":"1", "disclosure":"1", "eventId":"notifications"],
                ],
             "description":NSLocalizedString("SETTINGS_OPTION_TURN_ON_NOTIFICATION_DESCRIPTION", comment: "turn on notifications description"),
             ],
            
            ["summary":"",
             "items":[
                ["title":NSLocalizedString("OPTION_CLEAR_CACHE", comment: "OPTION_CLEAR_CACHE"), "detail":"", "bottom":"", "clickable":"1", "eventId":"4"],
                ],
             "description":NSLocalizedString("OPTION_CLEAR_CACHE_DESCRIPTION", comment: "OPTION_CLEAR_CACHE_DESCRIPTION"),
            ],
        ]
        
        #if DEBUG
        let debugEntry: [String:Any] = ["summary":"",
         "items":[
            ["title":NSLocalizedString("DEBUG_ENTRY", comment: "DEBUG ENTRY"), "detail":"", "bottom":"", "clickable":"1", "eventId":"debug_entry", "disclosure":"1"],
            ],
         "description":"",
        ]
        dataSource.append(debugEntry)
        #endif
        
        updateNotificationSetting()
        
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil) { [weak self] (_) in
            self?.updateNotificationSetting()
        }
    }
    
    private func updateNotificationSetting() {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            if settings.authorizationStatus != .authorized { return }
            
            DispatchQueue.main.async {
                self.removeConfigSectionOf(firstItemEventId: "notifications")
                self.tableView.reloadData()
            }
        }
    }
    
    private func removeConfigSectionOf(firstItemEventId: String) {
        dataSource.removeAll(where: { (dict) -> Bool in
            let item = (dict["items"] as! [[String:String]]).first
            return item?["eventId"] == firstItemEventId
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: animated)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        #if targetEnvironment(macCatalyst)
        guard let titlebar = UIApplication.shared.windows.first?.windowScene?.titlebar, let titleItems = titlebar.toolbar?.items else {
            return
        }
        
        for item in titleItems {
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierTitle.rawValue {
                if let t = self.title {
                    item.title = t
                }
                break
            }
        }
        #endif
    }
    
    override var showsRefreshControl: Bool {
        return false
    }
    
    // MARK: - tableview
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let items = dataSource[indexPath.section]["items"] as! [[String:String]]
        let eventId = items[indexPath.row]["eventId"]!
        
        let cell = tableView.cellForRow(at: indexPath)
        cell?.isHighlighted = false
        
        return handleEvent(eventId, indexPath: indexPath)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if dataSource == nil {
            return 0
        }
        
        return dataSource.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as! SAThemedTableHeaderFooterView
        view.delegate = self
        if let summary = dataSource[section]["summary"] as? String {
            view.summaryTextView.text = summary
        }
        
        return view
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if dataSource == nil {
            return 0
        }
        
        let items = dataSource[section]["items"] as! [[String:String]]
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "footer") as! SAThemedTableHeaderFooterView
        view.delegate = self
        view.setTitleWith(description: dataSource[section]["description"] as? String,
                          link: dataSource[section]["description-link-title"] as? String,
                          url: dataSource[section]["description-link-target"] as? String)
        return view
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as? SAAccountCenterBodyCell
        cell?.accessoryView = nil
        
        let items = dataSource[indexPath.section]["items"] as! [[String:String]]
        
        let title = items[indexPath.row]["title"]
        let detail = items[indexPath.row]["detail"]
        let isSwitch = items[indexPath.row]["isSwitch"] != nil && items[indexPath.row]["isSwitch"]! == "1"
        let isSegmentedControl = items[indexPath.row]["isSegmentedControl"] != nil && items[indexPath.row]["isSegmentedControl"]! == "1"
        
        let disclosure = items[indexPath.row]["disclosure"] != nil && items[indexPath.row]["disclosure"]! == "1"
        let disabled = items[indexPath.row]["disabled"] != nil && items[indexPath.row]["disabled"]! == "1"
        let destructive = items[indexPath.row]["destructive"] != nil && items[indexPath.row]["destructive"]! == "1"
        var bindKey: SAAccount.Preference?
        if let keyRawValue = items[indexPath.row]["bindKey"] {
            bindKey = SAAccount.Preference.init(rawValue: keyRawValue)
        }
        
        if disclosure {
            cell!.accessoryType = .disclosureIndicator
        } else {
            cell!.accessoryType = .none
        }
        
        if isSwitch {
            let s = UISwitch()
            s.addTarget(self, action: #selector(handleSwitchValueChanged(_:)), for: .valueChanged)
            s.tintColor = Theme().tableCellGrayedTextColor.sa_toColor()
            cell!.accessoryView = s
            
            let status = (Account().preferenceForkey(bindKey!) as? Bool) ?? false
            s.isOn = status
            s.isEnabled = !disabled
        } else if isSegmentedControl {
            let optionNames = SAAccount.allOptionNamesForKey(bindKey!)
            let options = SAAccount.allOptionsForKey(bindKey!)
            let option = (Account().preferenceForkey(bindKey!) as? String) ?? ""
            let index = options.firstIndex(of: option) ?? 0
            let segmentedControl = UISegmentedControl(items: optionNames)
            segmentedControl.tintColor = cell!.tintColor
            segmentedControl.selectedSegmentIndex = index
            segmentedControl.addTarget(self, action:#selector(handleSegmentedControlValueChanged(_:)), for: .valueChanged)
            cell!.accessoryView = segmentedControl
        }
        
        if destructive {
            if let _ = title {
                cell!.textLabel?.attributedText = NSAttributedString(string: title!, attributes: [NSAttributedString.Key.foregroundColor:UIColor.red])
            }
        } else {
            cell!.textLabel?.text = title == nil ? "":title!
        }
        
        cell!.detailTextLabel!.text = detail == nil ? "": detail!
        
        return cell!
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let items = dataSource[indexPath.section]["items"] as! [[String:String]]
        let clickable = items[indexPath.row]["clickable"] != nil && items[indexPath.row]["clickable"]! == "1"
        
        return clickable
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    // MARK: event handling
    private func handleEvent(_ eventId: String, indexPath: IndexPath) -> IndexPath? {
        switch eventId {
        case "3":
            return pushThemeSelectPage(indexPath)
        case "4":
            return clearCache(indexPath)
        case "12":
            return openBoardSelectPage(indexPath)
        case "13":
            return openFontConfigurePage(indexPath)
        case "notifications":
            return openNotificationSettingPage(indexPath)
        case "debug_entry":
            return openDebugPage(indexPath)
        case "hot_tab_board_fid":
            return openHotTabBoardSelectPage(indexPath)
        default:
            break
        }
        
        return nil
    }
    
    private func openBoardSelectPage(_ indexPath: IndexPath?) -> IndexPath? {
        let about = SABoardArrangementViewController()
        navigationController?.pushViewController(about, animated: true)
        return indexPath
    }
    
    private func openHotTabBoardSelectPage(_ indexPath: IndexPath?) -> IndexPath? {
        let about = SAHotTabBoardSelectionViewController()
        navigationController?.pushViewController(about, animated: true)
        return indexPath
    }
    
    private func openFontConfigurePage(_ indexPath: IndexPath?) -> IndexPath? {
        let fontConfigureViewController = SAFontConfigureViewController()
        navigationController?.pushViewController(fontConfigureViewController, animated: true)
        return indexPath
    }
    
    private func openNotificationSettingPage(_ indexPath: IndexPath?) -> IndexPath? {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert], completionHandler: { (result, error) in
                    DispatchQueue.main.async { [weak self] in
                        self?.updateNotificationSetting()
                    }
                })
                return
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.open(URL.init(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
            }
        }
        
        return nil
    }
    
    private func openDebugPage(_ indexPath: IndexPath?) -> IndexPath? {
        let debug = SADebuggingViewController()
        navigationController?.pushViewController(debug, animated: true)
        return indexPath
    }
    
    private func pushThemeSelectPage(_ indexPath: IndexPath?) -> IndexPath? {
        let vc = SAThemeSelectViewController()
        navigationController?.pushViewController(vc, animated: true)
        return indexPath
    }
    
    private func clearCache(_ indexPath: IndexPath) -> IndexPath? {
        let alert = UIAlertController(title: nil, message: NSLocalizedString("CLEAR_APP_CACHE_CONFIRMATION", comment: "clear cache"), preferredStyle: .actionSheet)
        
        let rect = tableView.rectForRow(at: indexPath)
        alert.popoverPresentationController?.sourceView = tableView
        alert.popoverPresentationController?.sourceRect = rect
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel) { (action) in
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        alert.addAction(cancelAction)
        
        let threadAction = UIAlertAction(title: NSLocalizedString("SURE", comment: "Sure"), style: .destructive){ (action) in
            let activity = SAModalActivityViewController()
            self.present(activity, animated: true, completion: nil)
            AppController.current.getService(of: SABackgroundTaskManager.self)!.clearDiskCache(completion: { () in
                self.tableView.deselectRow(at: indexPath, animated: true)
                activity.hideAndShowResult(of: true, info: NSLocalizedString("HINT_CLEANED", comment: "已清理"), completion: nil)
            })
        }
        alert.addAction(threadAction)
        present(alert, animated: true, completion: nil)
        
        return indexPath
    }
    
    @objc func handleSwitchValueChanged(_ sender: UISwitch) {
        let visibleCells = self.tableView.visibleCells
        let cell = visibleCells.filter { (cell) -> Bool in
            if cell.accessoryView == sender {
                return true
            }
            
            return false
            }.first
        
        guard cell != nil else {
            fatalError("")
        }
        
        let indexPath = self.tableView.indexPath(for: cell!)
        guard indexPath != nil else {
            fatalError("Clicked an invalid cell?")
        }
        
        let items = dataSource[(indexPath! as NSIndexPath).section]["items"] as! [[String:String]]
        let bindKey = SAAccount.Preference.init(rawValue: items[(indexPath! as NSIndexPath).row]["bindKey"]!)
        guard bindKey != nil else {
            fatalError("bind key nil")
        }
        
        Account().savePreferenceValue(sender.isOn as AnyObject, forKey: bindKey!)
    }
    
    @objc func handleSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        let visibleCells = self.tableView.visibleCells
        let cell = visibleCells.filter { (cell) -> Bool in
            if cell.accessoryView == sender {
                return true
            }
            
            return false
            }.first
        
        guard cell != nil else {
            fatalError("")
        }
        
        let indexPath = self.tableView.indexPath(for: cell!)
        guard indexPath != nil else {
            fatalError("Clicked an invalid cell?")
        }
        
        let items = dataSource[(indexPath! as NSIndexPath).section]["items"] as! [[String:String]]
        let bindKey = SAAccount.Preference.init(rawValue: items[(indexPath! as NSIndexPath).row]["bindKey"]!)
        let options = SAAccount.allOptionsForKey(bindKey!)
        guard bindKey != nil else {
            fatalError("bind key nil")
        }
        
        Account().savePreferenceValue(options[sender.selectedSegmentIndex] as AnyObject, forKey: bindKey!)
    }
    
}

