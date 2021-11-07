//
//  SAFavouriteBoardsViewController.swift
//  Saralin
//
//  Created by zhang on 12/1/15.
//  Copyright © 2015 zaczh. All rights reserved.
//

import UIKit
import CoreData

class SAFavouriteBoardsViewController: SABaseTableViewController {
    override var showsSearchItem: Bool {return true}
    enum SegmentedControlIndex : Int {
        case recent = 0
        case thread = 1
        case watchList = 2
    }
    
    private var historyThreadsData: [ViewedThread] = []
    private var favoriteThreadsData: [OnlineFavoriteThread] = []
    private var watchingThreadsData: [WatchingThread] = []
    
    let segmentedControl = UISegmentedControl(items: [NSLocalizedString("RECENTLY_VIEWED", comment: "Recently Viewed"), NSLocalizedString("ONLINE_COLLECTION_TITLE", comment: "thread wording"), NSLocalizedString("FAVORITE_VC_WATCH_LIST", comment: "观察列表")])
    
    private var formhash: String = ""
    
    // MARK: Context Menu
    private var currentPreviewCellIndexPath: IndexPath?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // support Peek & Pop
        if #available(iOS 13.0, *) {
            let contextMenuInteraction = UIContextMenuInteraction(delegate: self)
            view.addInteraction(contextMenuInteraction)
        }
        
        if segmentedControl.selectedSegmentIndex == UISegmentedControl.noSegment {
            segmentedControl.selectedSegmentIndex = SegmentedControlIndex.recent.rawValue
        }
        segmentedControl.addTarget(self, action: #selector(SAFavouriteBoardsViewController.handleSegmentedControlValueChanged(_:)), for: .valueChanged)
        navigationItem.titleView = segmentedControl
        
        tableView.register(SABoardTableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.estimatedRowHeight = 100
        tableView.tableFooterView = UIView()

        updateTitleAfterSegmentedControlValueChange()
        
        loadInitialData()
    }
    
    #if targetEnvironment(macCatalyst)
    override func updateToolBar(_ viewAppeared: Bool) {
        super.updateToolBar(viewAppeared)
        guard let titlebar = view.window?.windowScene?.titlebar, let titleItems = titlebar.toolbar?.items else {
            return
        }
        
        for item in titleItems {
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierTitle.rawValue {
                break
            }
        }
    }
    #endif

    override func getTableView() -> UITableView {
        return UITableView(frame: .zero, style: .plain)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func createSearchController() -> SASearchController {
        let searchController = super.createSearchController()
        searchController.searchBar.placeholder = NSLocalizedString("SEARCH_BAR_PLACEHOLDER_SEARCH_HISTORY_RECORDS", comment: "")
        searchController.resultType = .localViewHistory
        return searchController
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //Loading data from coredata costs no time
        if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.recent.rawValue || segmentedControl.selectedSegmentIndex == SegmentedControlIndex.watchList.rawValue {
            refreshTableViewCompletion(nil)
        }
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        
        let textColor = UIColor.sa_colorFromHexString(Theme().globalTintColor)
        let placeholder = NSMutableAttributedString()
        placeholder.append(NSAttributedString(string: "无数据\n\n", attributes: [NSAttributedString.Key.font:UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline), NSAttributedString.Key.foregroundColor:textColor]))
        placeholder.append(NSAttributedString(string: "点击右上方分享箭头，可以将帖子加入收藏或者观察列表", attributes: [NSAttributedString.Key.font:UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.subheadline), NSAttributedString.Key.foregroundColor:textColor]))
        loadingController.emptyLabelAttributedTitle = placeholder
    }
    
    override func handleUserLoggedIn() {
        refreshTableViewCompletion(nil)
    }
    
    private func updateTitleAfterSegmentedControlValueChange() {
        if let title = segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex) {
            self.title = title
        }
    }
    
    func loadInitialData() {
        loadingController.setLoading()
        refreshTableViewCompletion { (success, error) in
            if success == .fail {
                self.loadingController.setFailed(with: error)
            }
        }
    }
    
    override func refreshTableViewCompletion(_ completion: ((SALoadingViewController.LoadingResult, NSError?) -> Void)?) {
        AppController.current.getService(of: SACoreDataManager.self)!.withMainContext { (context) in
            if self.segmentedControl.selectedSegmentIndex == SegmentedControlIndex.recent.rawValue {
                let fetch = NSFetchRequest<ViewedThread>(entityName: "ViewedThread")
                let sort = NSSortDescriptor(key: "lastviewtime", ascending: false)
                fetch.sortDescriptors = [sort]
                fetch.predicate = NSPredicate(format: "uid == %@", Account().uid)
                if let threads = try? context.fetch(fetch) {
                    self.historyThreadsData = threads
                }
                self.reloadData()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                    completion?(.newData, nil)
                }
            } else if self.segmentedControl.selectedSegmentIndex == SegmentedControlIndex.thread.rawValue {
                if Account().isGuest {
                    let error = NSError.init(domain: SAGeneralErrorDomain, code: -1, userInfo: ["msg":"Not logged in"])
                    completion?(.fail, error)
                    return
                }
                
                AppController.current.getService(of: SABackgroundTaskManager.self)!.fetchFavoriteThreadsInBackground({ (result) in
                    if result != .newData {
                        let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: ["msg":"no data"])
                        completion?(.fail, error)
                        return
                    }
                    
                    let sort = NSSortDescriptor(key: "favoriteddate", ascending: false)
                    let fetch = NSFetchRequest<OnlineFavoriteThread>(entityName: "OnlineFavoriteThread")
                    fetch.sortDescriptors = [sort]
                    fetch.predicate = NSPredicate(format: "uid == %@", Account().uid)
                    if let favorites = try? context.fetch(fetch) {
                        self.favoriteThreadsData.removeAll()
                        self.favoriteThreadsData.append(contentsOf: favorites)
                    }
                    self.reloadData()
                    completion?(self.favoriteThreadsData.count > 0 ? .newData : .emptyData, nil)
                })
            } else if self.segmentedControl.selectedSegmentIndex == SegmentedControlIndex.watchList.rawValue {
                let fetch = NSFetchRequest<WatchingThread>(entityName: "WatchingThread")
                let sort = NSSortDescriptor(key: "timeadded", ascending: false)
                fetch.sortDescriptors = [sort]
                fetch.predicate = NSPredicate(format: "uid == %@", Account().uid)
                if let threads = try? context.fetch(fetch) {
                    self.watchingThreadsData.removeAll()
                    self.watchingThreadsData.append(contentsOf: threads)
                }
                self.reloadData()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                    completion?(self.watchingThreadsData.count > 0 ? .newData : .emptyData, nil)
                }
            }
        }
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SABoardTableViewCell
        
        if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.recent.rawValue {
            guard !historyThreadsData.isEmpty else {
                return cell
            }
            
            let viewedThread = historyThreadsData[indexPath.row] as ViewedThread
            if let subject = viewedThread.subject {
                let attributedTitle = NSMutableAttributedString(string: subject.sa_stringByReplacingHTMLTags() as String, attributes:[NSAttributedString.Key.font: UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline),NSAttributedString.Key.foregroundColor: UIColor.sa_colorFromHexString(Theme().tableCellTextColor)])
                cell.customTitleLabel.attributedText = attributedTitle
            }
            if let date = viewedThread.lastviewtime {
                cell.customTimeLabel.text = "最后浏览于" + (date as Date).sa_prettyDate()
            }
            
            cell.customNameLabel.text = viewedThread.author
        } else if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.thread.rawValue {
            guard !favoriteThreadsData.isEmpty else {
                return cell
            }
            
            if let title = (favoriteThreadsData[indexPath.row].title)?.sa_stringByReplacingHTMLTags() as String? {
                let attributedTitle = NSMutableAttributedString(string: title, attributes:[NSAttributedString.Key.font: UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline),NSAttributedString.Key.foregroundColor: UIColor.sa_colorFromHexString(Theme().tableCellTextColor)])
                cell.customTitleLabel.attributedText = attributedTitle
            }
            
            let date = favoriteThreadsData[indexPath.row].favoriteddate as Date?
            cell.customTimeLabel.text = "收藏于" + (date ?? Date()).sa_prettyDate()
            cell.customNameLabel.text = favoriteThreadsData[indexPath.row].authorname
        } else if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.watchList.rawValue {
            let watchingThread = watchingThreadsData[indexPath.row]
            if let subject = watchingThread.subject {
                let attributedTitle = NSMutableAttributedString(string: subject.sa_stringByReplacingHTMLTags() as String, attributes:[NSAttributedString.Key.font: UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline),NSAttributedString.Key.foregroundColor: UIColor.sa_colorFromHexString(Theme().tableCellTextColor)])
                
                if let newReplies = watchingThread.newreplycount?.intValue {
                    if newReplies > 0 {
                        attributedTitle.append(NSAttributedString(string: "[\(newReplies)条新回复]", attributes: [NSAttributedString.Key.foregroundColor: UIColor.green]))
                    }
                }
                cell.customTitleLabel.attributedText = attributedTitle
            }
            if let date = watchingThread.timeadded {
                cell.customTimeLabel.text = "加入列表于" + (date as Date).sa_prettyDate()
            }
            cell.customNameLabel.text = watchingThread.author
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        
        let cell = cell as! SABoardTableViewCell
        cell.icloudIndicator.isHidden = true
        if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.recent.rawValue {
            guard !historyThreadsData.isEmpty else {
                return
            }
            
            cell.icloudIndicator.isHidden = historyThreadsData[indexPath.row].createdeviceidentifier == AppController.current.currentDeviceIdentifier
        } else if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.thread.rawValue {
            guard !favoriteThreadsData.isEmpty else {
                return
            }
            cell.icloudIndicator.isHidden = favoriteThreadsData[indexPath.row].createdeviceidentifier == AppController.current.currentDeviceIdentifier
        } else if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.watchList.rawValue {
            cell.icloudIndicator.isHidden = watchingThreadsData[indexPath.row].createdeviceidentifier == AppController.current.currentDeviceIdentifier
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.recent.rawValue {
            return historyThreadsData.count
        } else if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.thread.rawValue {
            return favoriteThreadsData.count
        } else if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.watchList.rawValue {
            return watchingThreadsData.count
        }
        
        return 0
    }
    
    private func detailViewControllerForCell(at indexPath: IndexPath) -> UIViewController? {
        if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.recent.rawValue {
            let object = historyThreadsData[indexPath.row] as ViewedThread
            guard object.tid != nil && object.page != nil else {
                return nil
            }
            
            let link = SAGlobalConfig().forum_base_url + "forum.php?mod=viewthread&tid=\(object.tid!)&fid=\(object.fid!)&page=1&mobile=1"
            if let url = URL(string: link) {
                return SAThreadContentViewController(url: url)
            }
        } else if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.thread.rawValue {
            guard let tid = favoriteThreadsData[indexPath.row].tid else {
                return nil
            }
            
            let url = SAGlobalConfig().forum_base_url + "forum.php?mod=viewthread&tid=\(tid)&page=1&mobile=1"
            
            os_log("url: %@", log: .ui, type: .debug, url)
            if let URL = URL(string: url) {
                return SAThreadContentViewController(url: URL)
            }
        } else if segmentedControl.selectedSegmentIndex == SegmentedControlIndex.watchList.rawValue {
            let object = watchingThreadsData[indexPath.row]
            guard object.tid != nil && object.page != nil else {
                return nil
            }
            
            let link = SAGlobalConfig().forum_base_url + "forum.php?mod=viewthread&tid=\(object.tid!)&page=1&mobile=1"
            if let url = URL(string: link) {
                return SAThreadContentViewController(url: url)
            }
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let thread = detailViewControllerForCell(at: indexPath) {
            if splitViewController!.isCollapsed {
                navigationController?.pushViewController(thread, animated: true)
            } else {
                // wrap with a navigation so that new secondary vc replacing old one.
                let navi = SANavigationController(rootViewController: thread)
                splitViewController?.setViewController(navi, for: .secondary)
            }
        }
    }
    
    @objc func handleSegmentedControlValueChanged(_ s: UISegmentedControl) {
        updateTitleAfterSegmentedControlValueChange()
        switch s.selectedSegmentIndex {
        case SegmentedControlIndex.recent.rawValue:
            if historyThreadsData.isEmpty {
                loadInitialData()
                return
            }
            reloadData()
            
            break
        case SegmentedControlIndex.thread.rawValue:
            if Account().isGuest {
                AppController.current.presentLoginAlert(sender: self, completion: nil)
                s.selectedSegmentIndex = SegmentedControlIndex.recent.rawValue
                return
            }
            
            if favoriteThreadsData.isEmpty {
                loadInitialData()
                return
            }
            reloadData()
            
            break
        case SegmentedControlIndex.watchList.rawValue:
            if watchingThreadsData.isEmpty {
                loadInitialData()
                return
            }
            reloadData()
            
            break
        default:
            break
        }
    }
}

@available(iOS 13.0, *)
extension SAFavouriteBoardsViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        let tableLocation = interaction.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: tableLocation) else {
            return nil
        }
        currentPreviewCellIndexPath = indexPath
        
        let actionProvider: UIContextMenuActionProvider = { (menu) in
            let deleteAction = UIAction.init(title: NSLocalizedString("DELETE", comment: "Delete"), image: UIImage(systemName: "delete.right"), identifier: SAContextActionTitleDelete, discoverabilityTitle: nil, attributes: UIMenuElement.Attributes.destructive, state: .off) { [weak self] (action) in
                guard let self = self else {
                    return
                }
                
                if self.segmentedControl.selectedSegmentIndex == SegmentedControlIndex.recent.rawValue {
                    guard !self.historyThreadsData.isEmpty else {
                        return
                    }
                    
                    AppController.current.getService(of: SACoreDataManager.self)!.withMainContext { (context) in
                        let object = self.historyThreadsData[indexPath.row]
                        context.delete(object)
                        self.tableView.beginUpdates()
                        self.historyThreadsData.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        self.tableView.endUpdates()
                    }
                    return
                } else if self.segmentedControl.selectedSegmentIndex == SegmentedControlIndex.thread.rawValue {
                    guard let favid = self.favoriteThreadsData[indexPath.row].favid else {
                        return
                    }
                    
                    let activity = SAModalActivityViewController()
                    self.present(activity, animated: true, completion: nil)
                    URLSession.saCustomized.unfavorite(favid: favid, formhash: Account().formhash, completion: { [weak self] (object, error) in
                        guard let self = self else {
                            return
                        }
                        
                        if error == nil {
                            os_log("已取消收藏")
                            self.tableView.beginUpdates()
                            self.favoriteThreadsData.remove(at: indexPath.row)
                            self.tableView.deleteRows(at: [indexPath], with: .automatic)
                            self.tableView.endUpdates()
                            activity.hideAndShowResult(of: true, info: NSLocalizedString("OPERATION_SUCCEEDED", comment: ""), completion: nil)
                        } else {
                            os_log("取消收藏失败 error: %@", type: .error, error! as CVarArg)
                            activity.hideAndShowResult(of: false, info: NSLocalizedString("OPERATION_FAILED", comment: ""), completion: nil)
                        }
                    })
                } else if self.segmentedControl.selectedSegmentIndex == SegmentedControlIndex.watchList.rawValue {
                    AppController.current.getService(of: SACoreDataManager.self)!.withMainContext { (context) in
                        let object = self.watchingThreadsData[indexPath.row]
                        context.delete(object)
                        self.tableView.beginUpdates()
                        self.watchingThreadsData.remove(at: indexPath.row)
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        self.tableView.endUpdates()
                    }
                }
            }
            
            let iCloudAction = UIAction.init(title: "查看iCloud同步信息", image: UIImage(systemName: "icloud.fill"), identifier: SAContextActionTitleICloudInfo, discoverabilityTitle: nil, attributes: [], state: .off) { (action) in
                let showDataDevice:((String?, String?, Date?) -> Void) = { (device, id, date) in
                    guard let d = device, let i = id, let t = date else {
                        return
                    }
                    
                    let alert = UIAlertController(title: "iCloud同步信息", message: "设备名：\(d)\n设备ID：\(i)\n时间：\(t.description)", preferredStyle: .alert)
                    alert.popoverPresentationController?.sourceView = self.tableView
                    alert.popoverPresentationController?.sourceRect = self.tableView.bounds
                    let openAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: { (action) in
                        
                    })
                    alert.addAction(openAction)
                    self.present(alert, animated: true, completion: nil)
                }
                
                if self.segmentedControl.selectedSegmentIndex == SegmentedControlIndex.recent.rawValue {
                    guard !self.historyThreadsData.isEmpty else {
                        return
                    }
                    
                    let data = self.historyThreadsData[indexPath.row]
                    showDataDevice(data.createdevicename, data.createdeviceidentifier, data.lastviewtime)
                } else if self.segmentedControl.selectedSegmentIndex == SegmentedControlIndex.thread.rawValue {
                    guard !self.favoriteThreadsData.isEmpty else {
                        return
                    }
                    let data = self.favoriteThreadsData[indexPath.row]
                    showDataDevice(data.createdevicename, data.createdeviceidentifier, data.favoriteddate)
                } else if self.segmentedControl.selectedSegmentIndex == SegmentedControlIndex.watchList.rawValue {
                    let data = self.watchingThreadsData[indexPath.row]
                    showDataDevice(data.createdevicename, data.createdeviceidentifier, data.lastviewtime)
                }
            }
            
            let amenu = UIMenu(title: "可选操作", image: nil, identifier: nil, options: [], children: [iCloudAction, deleteAction])
            return amenu
        }
        
        let contextMenuConfiguration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: actionProvider)
        return contextMenuConfiguration
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        
        guard let indexPath = self.currentPreviewCellIndexPath, let cell = self.tableView.cellForRow(at: indexPath) else {
            return nil
        }
        
        let preview = UITargetedPreview(view: cell)
        return preview
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let contentViewer = animator.previewViewController else {
            return
        }
        
        animator.addCompletion {
            self.navigationController?.show(contentViewer, sender: self)
        }
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willEndFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        guard let _ = self.currentPreviewCellIndexPath else {
            return
        }
        currentPreviewCellIndexPath = nil
    }
}

