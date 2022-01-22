//
//  SAAccountCenterViewController.swift
//  Saralin
//
//  Created by zhang on 12/5/15.
//  Copyright © 2015 zaczh. All rights reserved.
//

import UIKit
import WebKit

class SAAccountCenterViewController: SABaseTableViewController {
    struct TableCell {
        var title: String
        var detail: String
        var description: String
        var icon: String
        var clickable: Bool
        var disclousure: Bool
        var cellIdentifier: String
        var onDisplay: ((UITableViewCell) -> Void)
        var handler: ((IndexPath) -> IndexPath?)
    }
    
    struct TableSection {
        var summary: String
        var description: String
        var linkTitle: String
        var linkTarget: String
        var items: [TableCell]
    }

    var dataSource: [TableSection]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let barItem = UIBarButtonItem(image: UIImage.imageWithSystemName("gear", fallbackName: "Settings-44"), style: .plain, target: self, action: #selector(handleSettingsBarButtonClick(_:)))
        navigationItem.rightBarButtonItem = barItem
        
        tableView.tableHeaderView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: view.frame.size.width, height: 20))
        tableView.estimatedRowHeight = 100
        tableView.register(SAAccountCenterHeaderCell.self, forCellReuseIdentifier: "head")
        tableView.register(SAAccountCenterBodyCell.self, forCellReuseIdentifier: "cell")
        tableView.register(SAThemedTableHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "SAThemedTableHeaderFooterView")
        
        title = NSLocalizedString("ACCOUNT_CENTER_VC_TITLE", comment: "account center view title")
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserLoggedOut(_:)), name: Notification.Name.SAUserLoggedOut, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserLoggedIn(_:)), name: Notification.Name.SAUserLoggedIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleBackgroundTaskRefreshNotification(_:)), name: Notification.Name.SABackgroundTaskDidFinish, object: nil)
        
        refreshTableViewCompletion(nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.SAUserLoggedOut, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.SAUserLoggedIn, object: nil)
    }
    
    override func refreshTableViewCompletion(_ completion: ((SALoadingViewController.LoadingResult, NSError?) -> Void)?) {
        dataSource = [
            TableSection(summary: "", description: "", linkTitle: "", linkTarget: "", items: [
                TableCell(title: NSLocalizedString("ACCOUNT_VC_ACCOUNT_DETAIL", comment: "Account Detail"),
                          detail: "", description: "", icon: "", clickable: true, disclousure: true, cellIdentifier: "head", onDisplay: { tableCell in
                              
                              let cell = tableCell as! SAAccountCenterHeaderCell
                              cell.textLabel?.text = nil
                              cell.detailTextLabel!.text = nil
                              
                              cell.customImageView.image = UIImage(named:"noavatar_middle")
                              cell.checkInHandler = { [weak self] () in
                                  self?.dailyCheckIn(cell)
                              }
                              
                              if Account().isGuest {
                                  cell.checkInButton.isHidden = true
                                  cell.name.text = Account().name
                                  cell.uin.text = NSLocalizedString("ACCOUNT_VC_CLICK_HERE_TO_LOG_IN", comment: "点击此处登录")
                              } else {
                                  cell.checkInButton.isHidden = false
                                  cell.uin.text = Account().uid
                                  cell.name.text = Account().name
                              }
                              
                              cell.hasCheckedIn = Account().hasCheckedInToday
                              
                              guard let url = Account().avatarImageURL else {
                                  return
                              }
                              
                              UIApplication.shared.showNetworkIndicator()
                              URLSession.saCustomized.dataTask(with: url, completionHandler: { (data, response, error) in
                                  UIApplication.shared.hideNetworkIndicator()
                                  guard error == nil && data != nil else {
                                      sa_log_v2("image download failed", log: .ui, type: .error)
                                      return
                                  }
                                  
                                  if let image = UIImage(data: data!) {
                                      DispatchQueue.main.async(execute: {
                                          cell.customImageView.image = image
                                      })
                                  }
                              }).resume()
                          }, handler: { [weak self] (indexPath) in
                              if Account().isGuest {
                                  AppController.current.presentLoginViewController(sender: self, completion: nil)
                                  return nil
                              }
                              return self?.pushAccountInfoPage(indexPath)
                          })
            ]),
            
            TableSection(summary: "", description: "", linkTitle: "", linkTarget: "", items: [
                TableCell(title: NSLocalizedString("ACCOUNT_VC_MY_MESSAGES", comment: "我的私信"),
                          detail: "", description: "", icon: "text.bubble", clickable: true, disclousure: true, cellIdentifier: "cell", onDisplay: { [weak self] (cell) in
                              self?.refreshTabAndCellBadgeValue(cell)
                          }, handler: { [weak self] (indexPath) in
                                  if Account().isGuest {
                                      AppController.current.presentLoginAlert(sender: self, completion: nil)
                                      return nil
                                  }
                                  
                              return self?.openDMPage(indexPath)
                          }),
                TableCell(title: NSLocalizedString("ACCOUNT_VC_MY_THREADS", comment: "My Threads"),
                          detail: "", description: "", icon: "doc.text", clickable: true, disclousure: true, cellIdentifier: "cell", onDisplay: {_ in }, handler: { [weak self] (indexPath) in
                                  if Account().isGuest {
                                      AppController.current.presentLoginAlert(sender: self, completion: nil)
                                      return nil
                                  }
                                  
                              return self?.openMyThreadsPage(indexPath)
                          }),
                TableCell(title: NSLocalizedString("ACCOUNT_VC_MY_NOTICES", comment: "My Notices"),
                          detail: "", description: "", icon: "alarm", clickable: true, disclousure: true, cellIdentifier: "cell", onDisplay: {_ in }, handler: { [weak self] (indexPath) in
                                  if Account().isGuest {
                                      AppController.current.presentLoginAlert(sender: self, completion: nil)
                                      return nil
                                  }
                                  
                              return self?.openMyNoticesPage(indexPath)
                          }),
                TableCell(title: NSLocalizedString("ACCOUNT_VC_BLACKLIST", comment: "Block List"),
                          detail: "", description: "", icon: "shield.lefthalf.fill", clickable: true, disclousure: true, cellIdentifier: "cell", onDisplay: {_ in }, handler: { [weak self] (indexPath) in
                              return self?.openBlacklistConfigurePage(indexPath)
                          }),
                
            ]),
            
            TableSection(summary: "", description: "", linkTitle: "", linkTarget: "", items: [
                TableCell(title: NSLocalizedString("ACCOUNT_VC_ABOUT", comment: "About"), detail: "", description: "", icon: "info.circle", clickable: true, disclousure: true, cellIdentifier: "cell", onDisplay: {_ in }, handler: { [weak self] (indexPath) in
                    return self?.openAboutPage(indexPath)
                })
            ])
        ]
        
        if Account().isGuest {
            reloadData()
            completion?(.newData, nil)
            return
        }

        Account().checkSmsBindingState { (binded, error) in
            guard error == nil else {
                completion?(.fail, error)
                return
            }

            DispatchQueue.main.async {
                defer {
                    completion?(.newData, nil)
                }

                if binded { return }
                
                let bindingEntry = TableSection(summary: "",
                                                description: NSLocalizedString("ACCOUNT_VC_BIND_SMS", comment: "Bind"),
                                                linkTitle: "点击绑定",
                                                linkTarget: "salink://open?target=bindsms",
                                                items: self.dataSource[0].items)

                self.dataSource[0] = bindingEntry
                self.reloadData()
            }
        }
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
        
        if !Account().hasCheckedInToday {
            if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? SAAccountCenterHeaderCell {
                cell.hasCheckedIn = Account().hasCheckedInToday
            }
        }
        reloadData()
    }
    
    override func viewDidBecomeActive() {
        super.viewDidBecomeActive()
        reloadData()
    }
    
    override var showsRefreshControl: Bool {
        return false
    }

    // MARK: - tableview
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {        
        let items = dataSource[indexPath.section].items
        let handler = items[indexPath.row].handler
        if handler(indexPath) == nil {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if dataSource == nil {
            return 0
        }
        
        return dataSource.count
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SAThemedTableHeaderFooterView") as! SAThemedTableHeaderFooterView
        view.delegate = self
        view.summaryTextView.text = dataSource[section].summary
        return view
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if dataSource == nil {
            return 0
        }
        
        let items = dataSource[section].items
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let items = dataSource[indexPath.section].items
        let title = items[indexPath.row].title
        let cell = tableView.dequeueReusableCell(withIdentifier: items[indexPath.row].cellIdentifier, for: indexPath)
        cell.accessoryView = nil
        
        let systemIcon = items[indexPath.row].icon
        if !systemIcon.isEmpty {
            cell.imageView?.image = UIImage(systemName: systemIcon)
        }
        
        cell.accessoryType = .disclosureIndicator

        let detail = items[indexPath.row].detail
        cell.textLabel?.text = title
        cell.detailTextLabel!.text = detail
        
        items[indexPath.row].onDisplay(cell)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        #if targetEnvironment(macCatalyst)
        if indexPath.section == 0 && indexPath.row == 0 {
            return 0
        }
        #endif
        
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let items = dataSource[indexPath.section].items
        let clickable = items[indexPath.row].clickable

        return clickable
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SAThemedTableHeaderFooterView") as! SAThemedTableHeaderFooterView
        view.delegate = self
        view.setTitleWith(description: dataSource[section].description,
                          link: dataSource[section].linkTitle,
                          url: dataSource[section].linkTarget)
        return view
    }
    
    func dailyCheckIn(_ cell: SAAccountCenterHeaderCell?) {
        let activity = SAModalActivityViewController()
        present(activity, animated: true, completion: nil)
        AppController.current.getService(of: SABackgroundTaskManager.self)!.dailyCheckIn { (succeeded) in
            if succeeded {
                activity.hideAndShowResult(of: true, info: NSLocalizedString("HAVE_PUNCHED_IN_TODAY", comment: "已签到")) { () in
                    cell?.hasCheckedIn = true
                }
            } else {
                activity.hideAndShowResult(of: false, info: NSLocalizedString("OPERATION_FAILED", comment: "操作失败")) { () in
                    cell?.hasCheckedIn = true
                }
            }
        }
    }
    
    func openBlacklistConfigurePage(_ indexPath: IndexPath?) -> IndexPath? {
        let vc = SABlockedListConfigureViewController()
        if splitViewController!.isCollapsed {
            navigationController?.pushViewController(vc, animated: true)
        } else {
            // wrap with a navigation so that new secondary vc replacing old one.
            let navi = SANavigationController(rootViewController: vc)
            splitViewController?.setViewController(navi, for: .secondary)
        }
        return indexPath
    }
    
    func bindSMSNumber(_ indexPath: IndexPath?) -> IndexPath? {
        AppController.current.bindSMSNumber(sender: self)
        return indexPath
    }
    
    func openDMPage(_ indexPath: IndexPath?) -> IndexPath? {
        let vc = SAMessageInboxViewController()
        if splitViewController!.isCollapsed {
            navigationController?.pushViewController(vc, animated: true)
        } else {
            // wrap with a navigation so that new secondary vc replacing old one.
            let navi = SANavigationController(rootViewController: vc)
            splitViewController?.setViewController(navi, for: .secondary)
        }
        return indexPath
    }
    
    func openMyThreadsPage(_ indexPath: IndexPath?) -> IndexPath? {
        let myThreads = AppController.current.createMyThreadsPage()
        if splitViewController!.isCollapsed {
            navigationController?.pushViewController(myThreads, animated: true)
        } else {
            // wrap with a navigation so that new secondary vc replacing old one.
            let navi = SANavigationController(rootViewController: myThreads)
            splitViewController?.setViewController(navi, for: .secondary)
        }
        return indexPath
    }
    
    func openMyNoticesPage(_ indexPath: IndexPath?) -> IndexPath? {
        let vc = SAUserNoticeViewController()
        if splitViewController!.isCollapsed {
            navigationController?.pushViewController(vc, animated: true)
        } else {
            // wrap with a navigation so that new secondary vc replacing old one.
            let navi = SANavigationController(rootViewController: vc)
            splitViewController?.setViewController(navi, for: .secondary)
        }
        return indexPath
    }
    
    func openAboutPage(_ indexPath: IndexPath?) -> IndexPath? {
        let about = SAAboutViewController()
        if splitViewController!.isCollapsed {
            navigationController?.pushViewController(about, animated: true)
        } else {
            // wrap with a navigation so that new secondary vc replacing old one.
            let navi = SANavigationController(rootViewController: about)
            splitViewController?.setViewController(navi, for: .secondary)
        }
        return indexPath
    }
    
    func pushAccountInfoPage(_ indexPath: IndexPath?) -> IndexPath? {
        guard !Account().isGuest else {
            return indexPath
        }
        
        let url = SAGlobalConfig().profile_url_template.replacingOccurrences(of: "%{UID}", with: Account().uid)
        let vc = SAAccountInfoViewController(url: URL(string: url)!)
        vc.isAccountManager = true
        if splitViewController!.isCollapsed {
            navigationController?.pushViewController(vc, animated: true)
        } else {
            // wrap with a navigation so that new secondary vc replacing old one.
            let navi = SANavigationController(rootViewController: vc)
            splitViewController?.setViewController(navi, for: .secondary)
        }
        return indexPath
    }
    
    private func refreshTabAndCellBadgeValue(_ cell: UITableViewCell?) {
        // currently only new direct messages show badge
        let newMsgCount = AppController.current.getService(of: SABackgroundTaskManager.self)!.unreadDirectMessageCount
        if !Account().isGuest && newMsgCount > 0 {
            tabBarItem.badgeValue = "\(newMsgCount)"
            parent?.tabBarItem.badgeValue = "\(newMsgCount)"
            let buttonDemension = CGFloat(24)
            let button = UIButton(frame: CGRect(x: 0, y: 0, width: buttonDemension, height: buttonDemension))
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .systemRed
            button.setTitle("\(newMsgCount)", for: .normal)
            button.clipsToBounds = true
            button.layer.cornerRadius = buttonDemension/2.0
            cell?.accessoryView = button
        } else {
            tabBarItem.badgeValue = nil
            parent?.tabBarItem.badgeValue = nil
            cell?.accessoryView = nil
        }
    }
    
    // MARK: - UI events handlling
    @objc func handleSettingsBarButtonClick(_ sender:AnyObject) {
        AppController.current.presentSettingsViewController(self)
    }

    @objc func handleUserLoggedOut(_ notification: NSNotification) {
        refreshTableViewCompletion(nil)
    }
    
    @objc func handleUserLoggedIn(_ notification: NSNotification) {
        refreshTableViewCompletion(nil)
    }
    
    @objc func handleBackgroundTaskRefreshNotification(_ notification: NSNotification) {
        reloadData()
        refreshTabAndCellBadgeValue(nil)
    }
}
