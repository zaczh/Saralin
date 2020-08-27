//
//  SABoardViewController.swift
//  Saralin
//
//  Created by zhang on 1/10/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import WebKit
import CoreData

class SABoardViewController: SABaseTableViewController, SABoardFilterDelegate {
    
    class OperationModel: NSObject {
        var tid: String?
        var operation: Operation?
        var result: ViewModel?
    }
    
    struct ViewModel {
        var attributedTitle: NSAttributedString?
        var authorName: NSAttributedString?
        var createTimeText: NSAttributedString?
        var replyStatusText: NSAttributedString?
        var viewStatusText: NSAttributedString?
    }
    override var showsSearchItem: Bool {return true}
    var showsComposeBarItem: Bool {return true}
    var showsSubBoardBarItem: Bool {return true}

    private var fid: String?
    private var name: String?
    private var typeid: String?
    private var formhash: String?
    private var uploadhash: String?
    private var forumInfo: [String:Any]?
    private var types: [String:String]?
    
    var unfilteredDataSource: [[String:AnyObject]] = []
    var dataSource: [[String:AnyObject]] = []
    private var lastReplyCountDataSource: [String:Int] = [:]
    
    private var ignoreNextBlockUserListChangeNotification = false
    private var ignoreNextBlockThreadListChangeNotification = false
    
    private var subBoardList: [[String:AnyObject]]?
    private var currentPage = 1
    private var totalPage = 1
    
    private var boardData:[String:AnyObject]?
    var URL: Foundation.URL?
    override var showsBottomRefreshView: Bool {return true}
    
    private var currentPreviewCellIndexPath: IndexPath?
    
    var urlSession: URLSession! = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(30)
        return URLSession.init(configuration: configuration, delegate: nil, delegateQueue: nil)
    } ()
    
    required init(url: Foundation.URL) {
        super.init(nibName: nil, bundle: nil)

        self.URL = url
        self.fid = url.sa_queryString("fid")
        
        if let pageStr = url.sa_queryString("page") {
            if let page = Int(pageStr) {
                self.currentPage = page
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // MARK: - restoration
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(title, forKey: "title")

        coder.encode(fid, forKey: "fid")
        coder.encode(name, forKey: "name")
        coder.encode(typeid, forKey: "typeid")
        coder.encode(formhash, forKey: "formhash")
        coder.encode(uploadhash, forKey: "uploadhash")
        coder.encode(forumInfo, forKey: "forumInfo")
        coder.encode(types, forKey: "types")
        
        coder.encode(unfilteredDataSource, forKey: "unfilteredDataSource")
        coder.encode(dataSource, forKey: "dataSource")
        coder.encode(lastReplyCountDataSource, forKey: "lastReplyCountDataSource")
        coder.encode(ignoreNextBlockUserListChangeNotification, forKey: "ignoreNextBlockUserListChangeNotification")
        coder.encode(ignoreNextBlockThreadListChangeNotification, forKey: "ignoreNextBlockThreadListChangeNotification")

        coder.encode(subBoardList, forKey: "subBoardList")
        coder.encode(currentPage, forKey: "currentPage")
        coder.encode(totalPage, forKey: "totalPage")
        coder.encode(URL, forKey: "URL")
        
        if let table = tableView {
            #if !targetEnvironment(macCatalyst)
            coder.encode(table.contentOffset, forKey: "tableView.contentOffset")
            #endif
        }
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        if let title = coder.decodeObject(forKey: "title") as? String {
            self.title = title
        }
        
        fid = coder.decodeObject(forKey: "fid") as? String
        name = coder.decodeObject(forKey: "name") as? String
        typeid = coder.decodeObject(forKey: "typeid") as? String
        formhash = coder.decodeObject(forKey: "formhash") as? String
        uploadhash = coder.decodeObject(forKey: "uploadhash") as? String
        forumInfo = coder.decodeObject(forKey: "forumInfo") as? [String:Any]
        types = coder.decodeObject(forKey: "types") as? [String:String]
        
        unfilteredDataSource = coder.decodeObject(forKey: "unfilteredDataSource") as! [[String:AnyObject]]
        dataSource = coder.decodeObject(forKey: "dataSource") as! [[String:AnyObject]]
        lastReplyCountDataSource = coder.decodeObject(forKey: "lastReplyCountDataSource") as! [String:Int]
        ignoreNextBlockUserListChangeNotification = coder.decodeBool(forKey: "ignoreNextBlockUserListChangeNotification")
        ignoreNextBlockThreadListChangeNotification = coder.decodeBool(forKey: "ignoreNextBlockThreadListChangeNotification")
        
        subBoardList = coder.decodeObject(forKey: "subBoardList") as? [[String:AnyObject]]
        currentPage = Int(coder.decodeInt64(forKey: "currentPage"))
        totalPage = Int(coder.decodeInt64(forKey: "totalPage"))
        URL = coder.decodeObject(forKey: "URL") as? Foundation.URL
        
        if let table = tableView {
            #if !targetEnvironment(macCatalyst)
            table.contentOffset = coder.decodeCGPoint(forKey: "tableView.contentOffset")
            #endif
        }
        
        // check for bad saving state
        if dataSource.isEmpty {
            sa_log_v2("awake from archive, last saving state data empty, now reloading", module: .ui, type: .info)
            loadInitialData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        if #available(iOS 13.0, *) {
            let contextMenuInteraction = UIContextMenuInteraction(delegate: self)
            view.addInteraction(contextMenuInteraction)
        } else {
            // Fallback on earlier versions
            registerForPreviewing(with: self, sourceView: view)
        }
        
        restorationIdentifier = SAViewControllerRestorationIdentifier.board.rawValue
        
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .automatic
        } else {
            // Fallback on earlier versions
        }
        
        loadingController.emptyLabelTitle = "你没有权限查看当前板块或者其内容为空。"
        
        #if !targetEnvironment(macCatalyst)
        let changeOrderItem = UIBarButtonItem(image: UIImage.imageWithSystemName("arrow.up.arrow.down", fallbackName: "Descending-Sorting"), style: .plain, target: self, action: #selector(handleChangeOrderItemClick(_:)))
        if showsSubBoardBarItem {
            let subForumBarButtonItem = UIBarButtonItem(image: UIImage.imageWithSystemName("square.grid.2x2", fallbackName:"Menu"),
                                                        style: .plain,
                                                        target: self,
                                                        action: #selector(handleSubForumButtonClick(_:)))
            navigationItem.rightBarButtonItems = [changeOrderItem, subForumBarButtonItem]
        } else {
            navigationItem.rightBarButtonItems = [changeOrderItem]
        }
        
        if showsComposeBarItem {
            var items = navigationItem.rightBarButtonItems ?? []
            let composeItem = UIBarButtonItem.init(image: UIImage.imageWithSystemName("plus", fallbackName: "icons8-plus-math-48"),
                                                   style: .plain,
                                                   target: self,
                                                   action: #selector(handleComposeItemClick(_:)))
            items.insert(composeItem, at: 0)
            navigationItem.rightBarButtonItems = items
        }
        #endif
        
        tableView.register(SABoardTableViewCell.self, forCellReuseIdentifier: "cell")
        
        fetchingMoreCompleted()
        
        // get last refresh time before loading data,
        // so that we can know if a thread is new
        fetchForumLastReloadingDate()
        
        if isRestoredFromArchive {
            sa_log_v2("awake from archive", module: .ui, type: .info)
            AppController.current.getService(of: SACoreDataManager.self)!.rebuildCache { [weak self] (manager) in
                guard let self = self else { return }
                self.tableView.reloadData()
                self.registerNotifications()
            }
            return
        }
        
        loadInitialData()
    }
    
    override func getTableView() -> UITableView {
        return UITableView(frame: .zero, style: .plain)
    }
    
    #if targetEnvironment(macCatalyst)
    override func updateToolBar(_ viewAppeared: Bool) {
        super.updateToolBar(viewAppeared)
        guard let titlebar = UIApplication.shared.windows.first?.windowScene?.titlebar, let titleItems = titlebar.toolbar?.items else {
            return
        }
        
        for item in titleItems {
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierTitle.rawValue {
                if let t = self.title {
                    item.title = t
                }
            }
            
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierAddButton.rawValue {
                item.isEnabled = showsComposeBarItem && isBarButtonItemsEnabled
                item.action = #selector(handleComposeItemClick(_:))
                item.target = self
                
                if self.forumInfo == nil || self.fid == nil {
                    item.isEnabled = false
                }
            }
        }
    }
    #endif
    
    deinit {
        sa_log_v2("SABoardViewController deinit")
    }
    
    override func createSearchController() -> SASearchController {
        let searchController = super.createSearchController()
        searchController.resultType = .onlineGlobalSearch
        searchController.searchBar.placeholder = NSLocalizedString("SEARCH_BAR_PLACEHOLDER_SEARCH_FORUM_THREADS", comment: "Search Forum Threads")
        return searchController
    }
    
    func showSearchController() {
        let searchController = SASearchController()
        navigationController?.pushViewController(searchController, animated: false)
    }
    
    private func loadInitialData() {
        self.isBarButtonItemsEnabled = false
        loadingController.setLoading()
        waitForPrerequisite { [weak self] in
            self?.refreshTableAndBarButtonItems()
            self?.registerNotifications()
        }
    }
    
    private func waitForPrerequisite(_ completion: @escaping (() -> Void)) {
        let group = DispatchGroup()

        group.enter()
        AppController.current.getService(of: SAAccountManager.self)!.waitForAccountState(using: { (state) -> Bool in
            return state != .notValidated
        }) {
            group.leave()
        }
        
        group.enter()
        AppController.current.getService(of: SACoreDataManager.self)!.rebuildCache { (manager) in
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion()
        }
    }
    
    private func refreshTableAndBarButtonItems() {
        refreshTableViewCompletion { [weak self] (finished, error) in
            self?.handleTableLoadingResult(finished, error: error)
            self?.isBarButtonItemsEnabled = finished == .newData
        }
    }
    
    private func registerNotifications() {
        _ = NotificationCenter.default.addObserver(forName: .SABlockedUserListDidChange, object: nil, queue: nil, using: { [weak self] (notification) in
            guard let strongSelf = self else {return}
            
            if strongSelf.ignoreNextBlockUserListChangeNotification {
                strongSelf.ignoreNextBlockUserListChangeNotification = false
                return
            }
            strongSelf.filterDataSourceAndReloadData()
        })
    
        _ = NotificationCenter.default.addObserver(forName: .SABlockedThreadListDidChange, object: nil, queue: nil, using: { [weak self] (notification) in
            guard let strongSelf = self else {return}
            
            if strongSelf.ignoreNextBlockThreadListChangeNotification {
                strongSelf.ignoreNextBlockThreadListChangeNotification = false
                return
            }
            strongSelf.filterDataSourceAndReloadData()
        })
        
        _ = NotificationCenter.default.addObserver(forName: .SAUserLoggedInNotification, object: nil, queue: nil, using: { [weak self] (notification) in
            AppController.current.getService(of: SACoreDataManager.self)!.rebuildCache { [weak self] (manager) in
                guard let self = self else { return }
                self.tableView.reloadData()
                self.registerNotifications()
            }
        })
    }
    
    private func filterDataSourceAndReloadData() {
        self.dataSource = self.filterDataSource(self.unfilteredDataSource)
        self.reloadData()
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        prefetchOperations.removeAll()
        tableView.reloadData()
    }
    
    override func viewFontDidChange(_ newTheme: SATheme) {
        super.viewFontDidChange(newTheme)
        prefetchOperations.removeAll()
        tableView.reloadData()
    }
    
    private var isBarButtonItemsEnabled: Bool = false {
        didSet {
            if isBarButtonItemsEnabled {
                navigationItem.rightBarButtonItems?.forEach({ (item) in
                    item.isEnabled = true
                })
            } else {
                navigationItem.rightBarButtonItems?.forEach({ (item) in
                    item.isEnabled = false
                })
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func cleanUpBeforeReload() {
        super.cleanUpBeforeReload()
        formhash = nil
        subBoardList = nil
        types = nil
        totalPage = 1
        currentPage = 1
        prefetchOperations.removeAll()
    }
    
    fileprivate func fetchForumLastReloadingDate() {
        guard let fid = self.fid else {
            sa_log_v2("fetchForumLastViewedDate fid is nil, not save", module: .ui, type: .debug)
            return
        }
        
        AppController.current.getService(of: SACoreDataManager.self)!.withMainContext { [weak self] (context) in
            context.perform {
                let fetch = NSFetchRequest<ViewedBoard>(entityName: "ViewedBoard")
                fetch.predicate = NSPredicate(format: "fid==%@", fid)
                
                // We do not care about which account this records belong to, we
                // just want to get the last time this board was loaded.
                let sortDescriptor = NSSortDescriptor(key: "lastviewtime", ascending: false)
                fetch.sortDescriptors = [sortDescriptor]
                let objects = try! context.fetch(fetch)
                if objects.isEmpty { return}
                
                let date = objects.first!.lastviewtime
                DispatchQueue.main.async {
                    self?.lastTimeReloadingDate = date as Date?
                }
            }
        }
    }
    
    //MARK: - save thread viewing history
    fileprivate func recordBoardViewingHistory() {
        guard let fid = self.fid else {
            sa_log_v2("recordBoardViewingHistory fid is nil, not save", module: .ui, type: .debug)
            return
        }
        let name = self.name
        let typeid = self.typeid
        
        // Keep guest viewing history
        let uid = Account().uid
        
        var lastfetchedtid: String?
        if currentPage == 1 {
            if let thread = dataSource.first {
                lastfetchedtid = thread["tid"] as? String
            }
        }
        if lastfetchedtid == nil {
            sa_log_v2("no threads fetched, not save", module: .ui, type: .debug)
            return
        }
        
        AppController.current.getService(of: SACoreDataManager.self)!.withMainContext { (context) in
            context.perform {
                let fetch = NSFetchRequest<ViewedBoard>(entityName: "ViewedBoard")
                fetch.predicate = NSPredicate(format: "fid==%@ AND uid==%@", fid, uid)
                let objects = try! context.fetch(fetch)
                if objects.count > 0 {
                    let obj = objects.first!
                    obj.name = name
                    obj.lastviewtime = Date()
                    obj.lastfetchedtid = lastfetchedtid
                    obj.typeid = typeid
                    return
                }
                
                let viewedBoard = NSEntityDescription.insertNewObject(forEntityName: "ViewedBoard", into: context) as! ViewedBoard
                viewedBoard.createdevicename = UIDevice.current.name
                viewedBoard.createdeviceidentifier = AppController.current.currentDeviceIdentifier
                viewedBoard.uid = uid
                viewedBoard.lastviewtime = Date()
                viewedBoard.fid = fid
                viewedBoard.typeid = typeid
                viewedBoard.name = name
                viewedBoard.lastfetchedtid = lastfetchedtid
                sa_log_v2("save viewed board %@", module: .ui, type: .error, viewedBoard)
            }
        }
    }
    
    // completion block calls not on main thread
    fileprivate func queryLastViewReplyCountOfThread(_ tid: String, completion:((Int) -> ())?) {
        let uid = Account().uid
        guard !uid.isEmpty else {
            completion?(0)
            return
        }
        
        AppController.current.getService(of: SACoreDataManager.self)!.withMainContext { (context) in
            context.perform {
                let fetch = NSFetchRequest<ViewedThread>(entityName: "ViewedThread")
                fetch.predicate = NSPredicate(format: "(uid == %@ AND tid == %@)", uid, tid)
                fetch.sortDescriptors = []
                guard let objects = try? context.fetch(fetch) else {
                    sa_log_v2("error occured when fetching viewed threads", module: .ui, type: .debug)
                    completion?(0)
                    return
                }
                
                if let replies = objects.first?.lastviewreplycount?.intValue {
                    completion?(replies)
                    return
                }
                
                completion?(0)
                return
            }
        }
    }
    
    //TODO: filter threads
    fileprivate func fetchMoreThreadsCompletion(_ completion: (([[String:AnyObject]]?) -> Void)?) {
        guard currentPage < totalPage else {
            completion?(nil)
            return
        }
        
        currentPage = currentPage + 1
        
        guard fid != nil else {
            completion?(nil)
            return
        }
        
        let order = Account().preferenceForkey(SAAccount.Preference.new_threads_order) as! String
        urlSession.getTopicList(of: fid!, typeid: typeid, page: currentPage, orderby: order) { [weak self] (data, error) -> Void in
            guard let self = self else {
                completion?(nil)
                return
            }
            
            guard error == nil, let dataDict = data as? [String:AnyObject] else {
                //rollback
                self.currentPage = self.currentPage - 1
                completion?(nil)
                return
            }
            
            if dataDict.count == 0 {
                //The end, no more data
                self.currentPage = self.currentPage - 1
                completion?([])
                return
            }
            
            let variables = dataDict["Variables"] as? [String:AnyObject]
            guard variables != nil else {
                completion?(nil)
                return
            }
            
            let list = variables!["forum_threadlist"] as? [[String:AnyObject]]
            completion?(list)
            return
        }
    }
    
    override func refreshTableViewCompletion(_ completion: ((SALoadingViewController.LoadingResult, NSError?) -> Void)?) {
        cleanUpBeforeReload()
        fetchTopListOfCurrentPage { [weak self] (error) in
            guard let strongSelf = self else {
                return
            }
            if let error = error {
                completion?(.fail, error)
                return
            }
            strongSelf.reloadData()
            let count = strongSelf.dataSource.count
            strongSelf.isBarButtonItemsEnabled = count > 0
            completion?(count > 0 ? .newData : .emptyData, nil)
        }
    }
    
    func filterDataSource(_ inData: [[String:AnyObject]]) -> [[String:AnyObject]] {
        if inData.isEmpty {
            return inData
        }
        
        var outData = inData
        var removed: [Int] = []
        for i in 0 ..< inData.count {
            let obj = inData[i]
            if shouldDataBeFilled(data: obj) {
                removed.append(i)
            }
        }
        
        for offset in 0 ..< removed.count {
            let originalIndex = removed[offset]
            outData.remove(at: originalIndex - offset)
        }
        
        return outData
    }
    
    private func shouldDataBeFilled(data: [String:AnyObject]) -> Bool {
        guard let cache = AppController.current.getService(of: SACoreDataManager.self)!.cache else {
            return false
        }
        
        if let authorid = data["authorid"] as? String {
            if cache.blockedUserIDs.contains(authorid) {
                return true
            }
        }
        
        if let tid = data["tid"] as? String {
            if cache.blockedThreadIDs.contains(tid) {
                return true
            }
        }
        
        return false
    }
    
    func fetchTopListOfCurrentPage(completion: ((NSError?) -> ())?) {
        guard fid != nil else {
            let error = NSError.init(domain: SAGeneralErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"内部错误: fid为空。"])
            completion?(error)
            return
        }
        
        let currentRequestFid = fid!
        let currentRequestTypeID = typeid
        let currentReqeustPage = currentPage
        
        let order = Account().preferenceForkey(SAAccount.Preference.new_threads_order) as! String
        urlSession.getTopicList(of: currentRequestFid, typeid: currentRequestTypeID, page: currentReqeustPage, orderby: order) { [weak self] (data, error) -> Void in
            guard let strongSelf = self, error == nil,
            let dataDict = data as? [String:AnyObject],
            let variables = dataDict["Variables"] as? [String:AnyObject] else {
                let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"帖子列表为空，该板块可能需要登录才能查看。"])
                completion?(error)
                return
            }
            
            //update this var before reloading tableview
            if strongSelf.thisTimeReloadingDate != nil {
                strongSelf.lastTimeReloadingDate = strongSelf.thisTimeReloadingDate
            }
            strongSelf.thisTimeReloadingDate = Date()
            
            if let ra = variables["readaccess"] as? String, let ira = Int(ra) {
                Account().readaccess = ira
            }
            
            let allowperm = variables["allowperm"]
            strongSelf.uploadhash = allowperm?["uploadhash"] as? String
            strongSelf.forumInfo = variables["forum"] as? [String:Any]
            strongSelf.formhash = variables["formhash"] as? String
            strongSelf.subBoardList = variables["sublist"] as? [[String:AnyObject]]
            
            if let data = variables["forum_threadlist"] as? [[String:AnyObject]] {
                strongSelf.unfilteredDataSource = data
                strongSelf.dataSource = strongSelf.filterDataSource(data)
            }
            
            let unfilteredDataSource = strongSelf.unfilteredDataSource
            if unfilteredDataSource.count == 0 {
                let error = NSError.init(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"帖子列表为空，该板块可能需要登录才能查看。"])
                completion?(error)
                return
            }
            
            if let threadtypes = variables["threadtypes"] as? [String:AnyObject] {
                strongSelf.types = threadtypes["types"] as? [String:String]
            }
            let forum = variables["forum"]! as! [String:AnyObject]
            let threads = Float(forum["threads"] as! String)!
            let tpp = Float(variables["tpp"] as! String)!
            let totalPage = ceil(threads/tpp)
            
            strongSelf.totalPage =  Int(totalPage)
            
            let title = forum["name"] as? String ?? ""
            strongSelf.name = title
            
            var extendedTitle = title
            if strongSelf.types != nil, strongSelf.typeid != nil, let category = strongSelf.types![strongSelf.typeid!] {
                let categoryInfo = "(\(category))"
                extendedTitle.append(categoryInfo)
            } else {
                extendedTitle.append("(全部)")
            }
            strongSelf.title = extendedTitle
            #if targetEnvironment(macCatalyst)
            strongSelf.updateToolBar(true)
            #endif
            strongSelf.recordBoardViewingHistory() // record view history here because sometimes loading fails
            strongSelf.fetchingMoreCompleted()
            strongSelf.updateLastReplyCountOf(dataSource: unfilteredDataSource, completion: {
                completion?(nil)
            })
        }
    }
    
    func updateLastReplyCountOf(dataSource: [[String:AnyObject]], completion: (()->())?) {
        let group = DispatchGroup()
        var replyCountDict = [String:Int]()
        let dictLock = NSLock()
        for data in dataSource {
            guard let topicID = data["tid"] as? String else {
                continue
            }
            group.enter()
            self.queryLastViewReplyCountOfThread(topicID, completion: { (replies) in
                dictLock.lock()
                replyCountDict[topicID] = replies
                dictLock.unlock()
                group.leave()
            })
        }
        group.notify(queue: DispatchQueue.main) {
            self.lastReplyCountDataSource.merge(replyCountDict) { (_, new) in new }
            completion?()
        }
    }
    
    // MARK: - SASubBoardViewControllerDelegate
    func boardFilterViewController(_: SABoardFilterViewController, didChooseSubBoardID fid: String, categoryID cid: String) {
        self.fid = fid
        self.typeid = nil
        self.currentPage = 1
        if cid == "0" {
            self.typeid = nil
        } else {
            self.typeid = cid
        }
        currentPage = 1
        loadingController.setLoading()
        self.isBarButtonItemsEnabled = false
        refreshTableViewCompletion { (success, error) in
            if success != .fail {
                if self.tableView.numberOfRows(inSection: 0) > 0 {
                    self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
                }
                self.loadingController.setFinished()
                self.isBarButtonItemsEnabled = true
            } else {
                self.loadingController.setFailed(with: error)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = self.dataSource.count
        return count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SABoardTableViewCell
        let fillCellWithModel: ((ViewModel, SABoardTableViewCell) -> Void) = { (viewModel, cell) in
            cell.customTitleLabel.attributedText = viewModel.attributedTitle
            cell.customNameLabel.attributedText = viewModel.authorName
            cell.customTimeLabel.attributedText = viewModel.createTimeText
            cell.customReplyLabel.attributedText = viewModel.replyStatusText
            cell.customViewLabel.attributedText = viewModel.viewStatusText
        }
        
        let fillWithEmptyData: ((SABoardTableViewCell) -> Void) = { (cell) in
            let viewModel = ViewModel()
            cell.customTitleLabel.attributedText = viewModel.attributedTitle
            cell.customNameLabel.attributedText = viewModel.authorName
            cell.customTimeLabel.attributedText = viewModel.createTimeText
            cell.customReplyLabel.attributedText = viewModel.replyStatusText
            cell.customViewLabel.attributedText = viewModel.viewStatusText
        }
        
        guard indexPath.row < dataSource.count else {
            sa_log_v2("index out of range", type: .fault)
            fillWithEmptyData(cell)
            return cell
        }

        let thread = dataSource[(indexPath as NSIndexPath).row]
        let tid = thread["tid"] as? String
        for op in prefetchOperations {
            if tid == op.tid {
                if let viewModel = op.result {
                    fillCellWithModel(viewModel, cell)
                    return cell
                }
                sa_log_v2("prefetching not finished yet", type: .info)
                break
            }
        }
        
        if let viewModel = fetchDataForRow(of: thread) {
            fillCellWithModel(viewModel, cell)
            return cell
        }
        
        fillWithEmptyData(cell)
        return cell
    }
    
    override func doFetchingMore() {
        if isFetchingMoreThreads {
            return
        }
        isFetchingMoreThreads = true
        fetchingMoreBegan()
        
        fetchMoreThreadsCompletion { [weak self] (data) in
            sa_log_v2("fetch %@ items", module: .ui, type: .debug, "\(data?.count ?? 0)")
            guard let strongSelf = self else {
                return
            }
            
            guard let unfilteredData = data else {
                strongSelf.isFetchingMoreFailed = true
                strongSelf.isFetchingMoreThreads = false
                strongSelf.fetchingMoreFailed()
                return
            }
            
            //if currentPage is 1, tableview may have been reloaded
            guard strongSelf.currentPage > 1 else {
                strongSelf.isFetchingMoreFailed = false
                strongSelf.isFetchingMoreThreads = false
                strongSelf.fetchingMoreCompleted()
                return
            }
            
            var isLastPage = false
            if unfilteredData.count < SAGlobalConfig().number_of_threads_per_page {
                isLastPage = true
            }
            
            let filteredData = strongSelf.filterDataSource(unfilteredData)
            strongSelf.fetchingMoreAction = { [weak strongSelf] () in
                guard let strongSelf = strongSelf else {
                    return
                }
                
                strongSelf.updateLastReplyCountOf(dataSource: unfilteredData, completion: {
                    var rows: [IndexPath] = []
                    for i in strongSelf.dataSource.count ..< strongSelf.dataSource.count + filteredData.count {
                        let indexPath = IndexPath(row: i, section: 0)
                        rows.append(indexPath)
                    }
                    strongSelf.unfilteredDataSource.append(contentsOf: unfilteredData)
                    if !filteredData.isEmpty {
                        strongSelf.dataSource.append(contentsOf: filteredData)
                        strongSelf.tableView.insertRows(at: rows, with: .bottom)
                    }
                    strongSelf.isFetchingMoreFailed = false
                    strongSelf.isFetchingMoreThreads = false
                    if isLastPage {
                        strongSelf.isFetchingMoreNoMoreData = true
                        strongSelf.fetchingMoreCompletedNoMoreData()
                    } else {
                        strongSelf.fetchingMoreCompleted()
                    }
                })
            }
            
            if !strongSelf.tableView.isDragging && !self!.tableView.isDecelerating {
                strongSelf.fetchingMoreAction!()
                strongSelf.fetchingMoreAction = nil
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if tableView.indexPathForSelectedRow == indexPath {
            return nil
        }
        return indexPath
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let threadInfo = dataSource[indexPath.row]
        guard let threadAuthorUid = threadInfo["authorid"] as? String,
            let threadAuthorName = threadInfo["author"] as? String,
            let tid = threadInfo["tid"] as? String,
            let threadTitle = (threadInfo["subject"] as? String)?.sa_stringByReplacingHTMLTags() as String?,
            let dbdateline = threadInfo["dbdateline"] as? String,
            let interval = Int(dbdateline) else {
                return nil
        }
        
        let blockAction = UIContextualAction.init(style: .normal, title: NSLocalizedString("TABLE_CONTEXTUAL_ACTION_BLOCK_USER", comment: "Block User")) { [weak self] (action, cell, completionHandler) in
            self?.showAlert(sender: cell, title: NSLocalizedString("BOARD_VC_BLOCK_USER_CONFIRM", comment: "Block User"), message: nil, actionTitle: NSLocalizedString("SURE", comment: "SURE"), actionHandler: {
                guard let strongSelf = self else {
                    completionHandler(false)
                    return
                }
                
                strongSelf.ignoreNextBlockUserListChangeNotification = true
                AppController.current.getService(of: SACoreDataManager.self)!.blockUser(uid: threadAuthorUid, name: threadAuthorName, reason: nil)
                strongSelf.tableView.beginUpdates()
                for i in (0 ..< strongSelf.dataSource.count).reversed() {
                    let data = strongSelf.dataSource[i]
                    if strongSelf.shouldDataBeFilled(data: data) {
                        let ip = IndexPath.init(row: i, section: indexPath.section)
                        strongSelf.dataSource.remove(at: i)
                        strongSelf.tableView.deleteRows(at: [ip], with: .middle)
                    }
                }
                strongSelf.tableView.endUpdates()
                completionHandler(true)
            }, cancelHandler: {
                completionHandler(false)
            })
        }
        blockAction.backgroundColor = UIColor.red

        let hideAction = UIContextualAction.init(style: .normal, title: NSLocalizedString("TABLE_CONTEXTUAL_ACTION_HIDE_THREAD", comment: "Hide")) { [weak self] (action, cell, completionHandler) in
            self?.showAlert(sender: cell, title: NSLocalizedString("BOARD_VC_HIDE_THREAD_CONFIRM", comment: "Hide Thread"), message: nil, actionTitle: NSLocalizedString("SURE", comment: "SURE"), actionHandler: {
                guard let self = self else {
                    completionHandler(false)
                    return
                }
                
                self.ignoreNextBlockThreadListChangeNotification = true
                AppController.current.getService(of: SACoreDataManager.self)!.blockThread(tid: tid, title: threadTitle, authorID: threadAuthorUid, authorName: threadAuthorName, threadCreation: Date.init(timeIntervalSince1970: TimeInterval(interval)))
                self.tableView.beginUpdates()
                self.dataSource.remove(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .middle)
                self.tableView.endUpdates()
                completionHandler(true)
            }, cancelHandler: {
                completionHandler(false)
            })
        }
        hideAction.backgroundColor = UIColor.blue
        
        let config = UISwipeActionsConfiguration(actions: [hideAction, blockAction])
        return config
    }
    
    private func showAlert(sender: UIView, title: String?, message: String?, actionTitle:String, actionHandler:(() -> Void)?, cancelHandler:(() -> Void)?) {
        let sheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        sheet.popoverPresentationController?.sourceView = sender
        sheet.popoverPresentationController?.sourceRect = sender.bounds

        sheet.addAction(UIAlertAction(title: actionTitle, style: .default) { (action) in
            actionHandler?()
        })
        
        sheet.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel) { (action) in
            cancelHandler?()
        })
        present(sheet, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard dataSource.count > indexPath.row else {
            sa_log_v2("fatal error dataSource index out of range", module: .ui, type: .error)
            return
        }
        let thread = dataSource[indexPath.row] as [String:AnyObject]
        let readPermission = Int(thread["readperm"] as! String)!
        
        let currentReadAccess = Account().readaccess
        if readPermission > 0 && currentReadAccess < readPermission {
            let message = String(format: NSLocalizedString("NOT_QUALIFIED_TO_VIEW_THREAD_FORMATTED", comment: "Not qualified to view thread"), String(currentReadAccess), String(readPermission))
            let alert = UIAlertController(title: NSLocalizedString("HINT", comment: "Hint"), message: message, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: { (action) in
                tableView.deselectRow(at: indexPath, animated: false)
            })
            alert.addAction(cancelAction)
            present(alert, animated: true, completion: nil)
            return
        }
        
        guard let contentViewer = threadContentViewControllerForCell(at: indexPath) else { return }
        splitViewController?.showDetailViewController(contentViewer, sender: self)
        updateReadStatusForCell(at: indexPath, reloadCell: true)
    }
    
    private func threadContentViewControllerForCell(at indexPath: IndexPath) -> SAThreadContentViewController? {
        guard dataSource.count > indexPath.row else {
            sa_log_v2("fatal error dataSource index out of range", module: .ui, type: .error)
            return nil
        }
        
        let thread = dataSource[indexPath.row] as [String:AnyObject]
        let readPermission = Int((thread["readperm"] as? String) ?? "0") ?? 0
        let currentReadAccess = Account().readaccess
        if readPermission > 0 && currentReadAccess < readPermission {
            return nil
        }
        
        let topicID = thread["tid"] as! String
        var totalPage = 1
        if let replies = thread["replies"] as? String, let repliesFloat = Float(replies) {
            totalPage = Int(ceil(repliesFloat/Float(SAGlobalConfig().number_of_replies_per_page)))
        }
        
        let urlString = SAGlobalConfig().forum_base_url + "forum.php?mod=viewthread&tid=\(topicID)&totalpage=\(totalPage)&extra=page%3D1&page=1&mobile=1&simpletype=no"
        let url = Foundation.URL(string: urlString)!
        return SAThreadContentViewController(url: url)
    }
    
    private func updateReadStatusForCell(at indexPath: IndexPath, reloadCell: Bool) {
        guard dataSource.count > indexPath.row else {
            sa_log_v2("fatal error dataSource index out of range", module: .ui, type: .error)
            return
        }
        var thread = dataSource[indexPath.row] as [String:AnyObject]
        let topicID = thread["tid"] as! String
        
        prefetchOperations.removeAll { (op) -> Bool in
            return topicID == op.tid
        }
        thread["hasRead"] = NSNumber.init(value: true)
        self.dataSource[indexPath.row] = thread
        AppController.current.getService(of: SACoreDataManager.self)!.appendViewedThreadIDsCache(tid: topicID)
        if reloadCell {
            self.tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
    
    // MARK: - private methods
    
    @objc func handleComposeItemClick(_ sender: AnyObject) {
        var targetViewController: UIViewController = self
        
        let popoverContentController = UIAlertController.init(title: NSLocalizedString("THREAD_ACTION_CHOOSE", comment: "Please choose an action"), message: nil, preferredStyle: .actionSheet)
        #if targetEnvironment(macCatalyst)
        
        guard let root = view.window?.rootViewController else {
            return
        }
        targetViewController = root
        
        let toolbarItem = sender as! NSToolbarItem
        let visibleItems = toolbarItem.toolbar!.visibleItems!
        let index = visibleItems.firstIndex(where: {$0 == toolbarItem})!
        let offset = index.distance(to: visibleItems.count)
        popoverContentController.popoverPresentationController?.sourceView = targetViewController.view
        popoverContentController.popoverPresentationController?.sourceRect = CGRect(x: targetViewController.view.frame.size.width - CGFloat(offset) * 60, y: 20, width: 40, height: 40)
        #else
        popoverContentController.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
        #endif
        popoverContentController.addAction(UIAlertAction.init(title: NSLocalizedString("ALERT_VIEW_CONTROLLER_VIEW_BOARD_REGULATION_TITLE", comment: ""), style: UIAlertAction.Style.default, handler: { (action) in
            self.showForumRulesInfo()
        }))
        
        popoverContentController.addAction(UIAlertAction.init(title: NSLocalizedString("ALERT_VIEW_CONTROLLER_POST_NEW_THREAD_TITLE", comment: ""), style: UIAlertAction.Style.default, handler: { (action) in
            self.makeNewThread()
        }))
        popoverContentController.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))

        targetViewController.present(popoverContentController, animated: true, completion: nil)
    }
    
    private func makeNewThread() {
        if Account().isGuest {
            let alert = UIAlertController(title: NSLocalizedString("HINT", comment: "Hint"), message: NSLocalizedString("ALERT_VIEW_CONTROLLER_REQUIRE_LOGIN_TITLE", comment: ""), preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            
            let threadAction = UIAlertAction(title: "现在登录", style: .default){ (action) in
                AppController.current.presentLoginViewController(sender: self, completion: nil)
            }
            alert.addAction(threadAction)
            present(alert, animated: true, completion: nil)
            
            return
        }
        
        guard let fid = self.fid else {
            return
        }
        
        if #available(iOS 13.0, *) {
            if UIApplication.shared.supportsMultipleScenes && ((Account().preferenceForkey(.enable_multi_windows) as? Bool) ?? false) {
                var userInfo:[String:AnyObject] = [:]
                userInfo["fid"] = fid  as AnyObject
                let userActivity = NSUserActivity(activityType: SAActivityType.composeThread.rawValue)
                userActivity.isEligibleForHandoff = true
                userActivity.title = SAActivityType.composeThread.title()
                userActivity.userInfo = userInfo
                let options = UIScene.ActivationRequestOptions()
                options.requestingScene = view.window?.windowScene
                UIApplication.shared.requestSceneSessionActivation(AppController.current.findSceneSession(), userActivity: userActivity, options: options) { (error) in
                    sa_log_v2("request new scene returned: %@", error.localizedDescription)
                }
                return
            }
        }
        
        let post = SAThreadCompositionViewController()
        post.config(fid: fid)
        let navi = SANavigationController(rootViewController: post)
        navi.modalPresentationStyle = .formSheet
        present(navi, animated: true, completion: nil)
    }
    
    private func showForumRulesInfo() {
        guard let info = forumInfo else {
            return
        }
        
        let templateHtmlFileURL = Bundle.main.url(forResource: "forum_rules_template", withExtension: "html")!
        let targetHtmlFileURL = AppController.current.appTemporaryDirectory.appendingPathComponent("forum_rules_template.html", isDirectory: false)
        var content = try! String.init(contentsOf: templateHtmlFileURL)
        
        if let name = info["name"] as? String {
            content = content.replacingOccurrences(of: "${FORUM_TITLE}", with: name)
        }
        
        if let threads = info["threads"] as? String {
            content = content.replacingOccurrences(of: "${THREAD_COUNT}", with: threads)
        }
        
        if let posts = info["posts"] as? String {
            content = content.replacingOccurrences(of: "${REPLY_COUNT}", with: posts)
        }
        
        if let rules = info["rules"] as? String {
            content = content.replacingOccurrences(of: "${FORUM_RULES}", with: rules)
        } else {
            content = content.replacingOccurrences(of: "${FORUM_RULES}", with: "无")
        }
        
        try! content.write(to: targetHtmlFileURL, atomically: false, encoding: String.Encoding.utf8)
        let webView = SAThreadContentViewController.createDummyInstanceWithHTMLFileAt(url: targetHtmlFileURL)
        webView.automaticallySetTitleWhenFinishLoading = true
        #if targetEnvironment(macCatalyst)
        guard splitViewController?.viewControllers.count ?? 0 > 1, let navi = splitViewController!.viewControllers[1] as? UINavigationController else {
            return
        }
        navi.pushViewController(webView, animated: true)
        #else
        splitViewController?.showDetailViewController(webView, sender: self)
        #endif
    }
    
    @objc func handleChangeOrderItemClick(_ sender: UIBarButtonItem) {
        let account = Account()
        let order = account.preferenceForkey(SAAccount.Preference.new_threads_order) as! String
        
        var allOrderTitles: [String] = [NSLocalizedString("OPTION_THREADS_DISPLAY_ORDER_REPLY_TIME", comment: ""), NSLocalizedString("OPTION_THREADS_DISPLAY_ORDER_CREATE_TIME", comment: "")]
        if order == "lastpost" {
            allOrderTitles[0] = allOrderTitles[0] + NSLocalizedString("OPTION_THREADS_DISPLAY_ORDER_CURRENT_OPTION_SUFFIX", comment: "")
        } else {
            allOrderTitles[1] = allOrderTitles[1] + NSLocalizedString("OPTION_THREADS_DISPLAY_ORDER_CURRENT_OPTION_SUFFIX", comment: "")
        }
        
        let selectOrderAtIndex: (Int) -> () = { (index) in
            if index == 0 {
                account.savePreferenceValue("lastpost" as AnyObject, forKey: .new_threads_order)
            } else {
                account.savePreferenceValue("dateline" as AnyObject, forKey: .new_threads_order)
            }
            self.isBarButtonItemsEnabled = false
            let activty = SAModalActivityViewController(style: .loadingWithCaption, caption: NSLocalizedString("LOADING_INDICATOR_TITLE_PROCESSING", comment: "Processing"))
            self.present(activty, animated: true, completion: nil)
            self.refreshTableViewCompletion { [weak self] (finished, error) in
                self?.handleTableLoadingResult(finished, error: error)
                self?.isBarButtonItemsEnabled = finished == .newData
                activty.presentingViewController?.dismiss(animated: true, completion: nil)
            }
        }
        
        let alert = UIAlertController(title: NSLocalizedString("CHANGE_THREAD_LIST_ORDER_ALERT_TITLE", comment: "Change Thread List Order"), message: nil, preferredStyle: .actionSheet)
        alert.popoverPresentationController?.barButtonItem = sender
        alert.addAction(UIAlertAction(title: allOrderTitles[0], style: .default, handler: { (action) in
            selectOrderAtIndex(0)
        }))
        alert.addAction(UIAlertAction(title: allOrderTitles[1], style: .default, handler: { (action) in
            selectOrderAtIndex(1)
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
        

        
    }
    
    @objc func handleSubForumButtonClick(_ sender: UIBarButtonItem) {
        guard fid != nil && name != nil else {
            sa_log_v2("fid or name is nil", module: .ui, type: .debug)
            return
        }
        
        var childBoard = [(String,String)]()
        
        //Add main board first
        childBoard.append((fid!, name!))
        
        var forum: NSDictionary! = nil
        let forumInfo = NSDictionary(contentsOf: AppController.current.forumInfoConfigFileURL)! as! [String:AnyObject]
        let forumList = forumInfo["items"] as! [[String:AnyObject]]
        for obj in forumList {
            let aFid = obj["fid"] as! String
            if aFid == fid {
                forum = obj as NSDictionary
                break
            }
        }
        
        guard forum != nil else {
            sa_log_v2("fatal error forum is nil", module: .ui, type: .debug)
            return
        }
        
        var sublist = forum["sublist"] as? [[String:String]]
        if sublist == nil {
            sublist = [[String:String]]()
        }
        
        let categorylist = forum["types"] as! [[String:String]]
        
        sublist!.forEach { (sub) in
           let b = (sub["fid"]!, sub["name"]!)
            childBoard.append(b)
        }
        
        //Add empty filter option
        var categoryData = [("0", "全部")]
        categorylist.forEach { (c) in
            let b = (c["typeid"]!, c["typename"]!)
            categoryData.append(b)
        }
        
        let childBoardController = SABoardFilterViewController(boards: childBoard, selectedBoard: fid!, categories: categoryData, selectedCategory: typeid != nil ? typeid! : "0")
        childBoardController.title = NSLocalizedString("CHOOSE_CHILD_BOARD_AND_CATEGORY", comment: "选择子板和分类")
        childBoardController.delegate = self
        childBoardController.navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .plain, target: self, action: #selector(SABoardViewController.handleChildBoardCancel))
        let navigation = SANavigationController(rootViewController: childBoardController)
        navigation.modalPresentationStyle = .popover
        navigation.popoverPresentationController?.barButtonItem = sender
        present(navigation, animated: true, completion: nil)
    }
    
    @objc func handleChildBoardCancel() {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Prefetching
    private var prefetchOperations: [OperationModel] = []
    private var prefetchOperationQueue = OperationQueue.init()
    override func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            guard dataSource.count > indexPath.row else {
                sa_log_v2("fatal error dataSource index out of range", module: .ui, type: .error)
                continue
            }
            let thread = dataSource[indexPath.row] as [String:AnyObject]
            let topicID = thread["tid"] as! String
            
            if prefetchOperations.contains(where: { (op) -> Bool in
                return topicID == op.tid
            }) {
                continue
            }
            
            let result = OperationModel()
            
            let newOperation = BlockOperation.init { [weak self, weak result] in
                if let viewModel = self?.fetchDataForRow(of: thread) {
                    result?.result = viewModel
                }
            }
            result.tid = topicID
            result.operation = newOperation
            prefetchOperations.append(result)
            prefetchOperationQueue.addOperation(newOperation)
        }
    }
    
    override func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            guard dataSource.count > indexPath.row else {
                sa_log_v2("fatal error dataSource index out of range", module: .ui, type: .error)
                continue
            }
            let thread = dataSource[indexPath.row] as [String:AnyObject]
            let topicID = thread["tid"] as! String
            
            prefetchOperations.removeAll(where: { (op) -> Bool in
                return topicID == op.tid
            })
        }
    }
    
    // This method runs on background thread!!!
    // Keep thread-safety in mind.
    private func fetchDataForRow(of thread: [String : AnyObject]) -> ViewModel? {
        let lastTimeReloadingDate = self.lastTimeReloadingDate
        guard let replyCount = thread["replies"] as? String,
            let readperm = thread["readperm"] as? String,
            let readPermission = Int(readperm),
            let views = thread["views"] as? String,
            let tid = thread["tid"] as? String,
            let dbdateline = thread["dbdateline"] as? String,
            let interval = Int(dbdateline) else {
                return nil
        }
        let dateCreated = Date(timeIntervalSince1970: TimeInterval(interval))
        
        //        let lastPostInterval = Int(thread["dblastpost"] as! String)
        //        let lastPostDate = Date(timeIntervalSince1970: TimeInterval(lastPostInterval!))
        
        let attachmentCount = thread["attachment"] as? String
        
        //        let heats = thread["heats"] as? String
        
        let fid = thread["fid"] as? String
        let typeid = thread["typeid"] as? String
        
        var boardName: String?
        var categoryName: String?
        
        let forumInfo = NSDictionary(contentsOf: AppController.current.forumInfoConfigFileURL)! as! [String:AnyObject]
        let forumList = forumInfo["items"] as! [[String:AnyObject]]
        for forum in forumList {
            let ffid = forum["fid"] as! String
            if ffid == fid {
                boardName = forum["name"] as? String
                let ttypes = forum["types"] as! [[String:String]]
                for type in ttypes {
                    let atype = type["typeid"]
                    if atype == typeid {
                        categoryName = type["typename"]! as String
                    }
                }
                break
            }
        }
        
        var isInHistory: Bool = false
        if let cache = AppController.current.getService(of: SACoreDataManager.self)!.cache {
            isInHistory = cache.viewedThreadIDs.contains(tid)
        }
        
        var hasRead = false
        if let _ = thread["hasRead"]?.boolValue {
            hasRead = true
        }
        let attributedTitle = NSMutableAttributedString()
        if !isInHistory && lastTimeReloadingDate != nil && dateCreated.compare(lastTimeReloadingDate!) == .orderedDescending {
            let attachment = NSTextAttachment()
            if #available(iOS 13.0, *) {
                attachment.image = UIImage(systemName: "burst.fill")?.withTintColor(Theme().globalTintColor.sa_toColor())
            } else {
                // Fallback on earlier versions
                attachment.image = UIImage.init(named: "icons8-new")
            }
            let imageSize = attachment.image!.size
            let font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline)
            attachment.bounds = CGRect(x: 0, y: font.descender, width: imageSize.width * font.pointSize / imageSize.height, height: font.pointSize)
            let attributedString = NSAttributedString.init(attachment: attachment)
            attributedTitle.append(attributedString)
        }
        
        let threadTitle = (thread["subject"] as? String)?.sa_stringByReplacingHTMLTags() as String?
        if threadTitle != nil && !threadTitle!.isEmpty {
            if readPermission > 0 {
                attributedTitle.append(NSAttributedString(string: "[" + NSLocalizedString("READ_QUALIFICATION", comment: "Read Qualification") + " \(readPermission)] ", attributes: [NSAttributedString.Key.foregroundColor: UIColor.red]))
            }
            
            if isInHistory {
                attributedTitle.append(NSAttributedString(string: threadTitle!, attributes: [NSAttributedString.Key.foregroundColor: UIColor.sa_colorFromHexString(Theme().tableCellGrayedTextColor)]))
            } else {
                attributedTitle.append(NSAttributedString(string: threadTitle!, attributes: [NSAttributedString.Key.foregroundColor: UIColor.sa_colorFromHexString(Theme().tableCellTextColor)]))
            }
        }
        
        if attachmentCount != nil && Int(attachmentCount!)! > 0 {
            let attachment = NSTextAttachment()
            if #available(iOS 13.0, *) {
                attachment.image = UIImage(systemName: "photo.fill")?.withTintColor(Theme().globalTintColor.sa_toColor())
            } else {
                // Fallback on earlier versions
                attachment.image = UIImage.init(named: "icons8-picture")
            }
            
            let imageSize = attachment.image!.size
            let font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline)
            attachment.bounds = CGRect(x: 0, y: font.descender, width: imageSize.width * font.pointSize / imageSize.height, height: font.pointSize)
            let attributedString = NSAttributedString.init(attachment: attachment)
            attributedTitle.append(attributedString)
        }
        
        let lastReplyCount = self.lastReplyCountDataSource[tid] ?? 0
        let newReplies = (Int(replyCount) ?? lastReplyCount) - lastReplyCount
        //database updated, so `lastReplyCount` may be 0, this should be avoided
        if !hasRead && isInHistory && newReplies > 0 && lastReplyCount > 0 {
            let color = UIColor.init(red: 0xfd/255.0, green: 0xac/255.0, blue: 0x61/255.0, alpha: 1)
            attributedTitle.append(NSAttributedString(string: String(format: "[" + NSLocalizedString("FORMATTED_NEW_REPLY_COUNT", comment: "") + "]", "\(newReplies)"), attributes: [NSAttributedString.Key.foregroundColor: color]))
        }
        
        var viewModel = ViewModel()
        attributedTitle.addAttributes([NSAttributedString.Key.font: UIFont.sa_preferredFont(forTextStyle: .headline)], range: NSMakeRange(0, (attributedTitle.string as NSString).length))
        
        let order = Account().preferenceForkey(.new_threads_order) as! String
        
        var timeText = ""
        if boardName != nil {
            timeText = timeText + boardName! + "|"
        }
        if categoryName != nil {
            timeText = timeText + categoryName! + "|"
        }
        
        if order == "dateline" {
            timeText = timeText + NSLocalizedString("POST_ON", comment: "") + " " + dateCreated.sa_prettyDate()
        } else {
            timeText = timeText + NSLocalizedString("UPDATE_ON", comment: "") + " " + dateCreated.sa_prettyDate()
        }
        
        if isInHistory {
            let attributes: [NSAttributedString.Key:Any] = [.foregroundColor: Theme().tableCellGrayedTextColor.sa_toColor()]
            viewModel.attributedTitle = attributedTitle
            viewModel.authorName = NSAttributedString.init(string: (thread["author"] as? String) ?? "", attributes: attributes)
            viewModel.createTimeText = NSAttributedString.init(string: timeText, attributes: attributes)
            viewModel.replyStatusText = NSAttributedString.init(string: String(format: NSLocalizedString("FORMATTED_REPLY_COUNT", comment: ""), replyCount), attributes: attributes)
            viewModel.viewStatusText = NSAttributedString.init(string: String(format: NSLocalizedString("FORMATTED_VIEW_COUNT", comment: ""), views), attributes:attributes)
        } else {
            let attributes: [NSAttributedString.Key:Any] = [.foregroundColor: Theme().tableCellGrayedTextColor.sa_toColor()]
            viewModel.attributedTitle = attributedTitle
            viewModel.authorName = NSAttributedString.init(string: (thread["author"] as? String) ?? "", attributes: attributes)
            viewModel.createTimeText = NSAttributedString.init(string: timeText, attributes: attributes)
            viewModel.replyStatusText = NSAttributedString.init(string: String(format: NSLocalizedString("FORMATTED_REPLY_COUNT", comment: ""), replyCount), attributes: attributes)
            viewModel.viewStatusText = NSAttributedString.init(string: String(format: NSLocalizedString("FORMATTED_VIEW_COUNT", comment: ""), views), attributes:attributes)
        }
        
        return viewModel
    }
}

extension SABoardViewController: UIViewControllerPreviewingDelegate {
    // MARK: UIViewControllerPreviewingDelegate
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        let tableLocation = previewingContext.sourceView.convert(location, to: tableView)
        let sourceView = previewingContext.sourceView
        
        guard let indexPath = tableView.indexPathForRow(at: tableLocation), let cell = tableView.cellForRow(at: indexPath) else {
            return nil
        }
        
        guard let contentViewer = threadContentViewControllerForCell(at: indexPath) else {
            return nil
        }
        currentPreviewCellIndexPath = indexPath
        // Set the source rect to the cell frame, so surrounding elements are blurred.
        previewingContext.sourceRect = cell.convert(cell.bounds, to: sourceView)
        return contentViewer
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        if let indexPath = currentPreviewCellIndexPath {
            updateReadStatusForCell(at: indexPath, reloadCell: true)
        }
        navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}

@available(iOS 13.0, *)
extension SABoardViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        let tableLocation = interaction.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: tableLocation) else {
            return nil
        }
        currentPreviewCellIndexPath = indexPath

        let provider: UIContextMenuContentPreviewProvider = { [weak self] () in
            guard let self = self else { return nil }
            
            guard let indexPath = self.currentPreviewCellIndexPath else {
                return nil
            }
            
            guard let contentViewer = self.threadContentViewControllerForCell(at: indexPath) else {
                return nil
            }
            return contentViewer
        }
        
        let action: UIContextMenuActionProvider = { (menu) in
            let action1 = UIAction(title: "隐藏帖子", image: UIImage.imageWithSystemName("eye.slash", fallbackName: ""), identifier: nil, discoverabilityTitle: nil, attributes: .init(rawValue: 0), state: .off) { [weak self] (action) in
                guard let self = self else { return }
                
                guard let indexPath = self.currentPreviewCellIndexPath else {
                    return
                }
                
                let thread = self.dataSource[indexPath.row] as [String:AnyObject]
                
                guard let tid = thread["tid"] as? String,
                    let threadTitle = thread["subject"]  as? String,
                    let threadAuthorUid = thread["authorid"] as? String,
                    let threadAuthorName = thread["author"] as? String,
                    let dbdateline = thread["dbdateline"] as? String,
                    let interval = Double(dbdateline) else {
                        return
                }
                
                let cordataManager = AppController.current.getService(of: SACoreDataManager.self)!
                cordataManager.blockThread(tid: tid,
                                           title: threadTitle,
                                           authorID: threadAuthorUid,
                                           authorName: threadAuthorName,
                                           threadCreation: Date(timeIntervalSince1970: TimeInterval(interval)))
            }
            
            let action2 = UIAction(title: "屏蔽作者", image: UIImage.imageWithSystemName("hand.raised", fallbackName: ""), identifier: nil, discoverabilityTitle: nil, attributes: .init(rawValue: 0), state: .off) { [weak self] (action) in
                guard let self = self else { return }
                
                guard let indexPath = self.currentPreviewCellIndexPath else {
                    return
                }
                
                let thread = self.dataSource[indexPath.row] as [String:AnyObject]
                guard let threadAuthorUid = thread["authorid"] as? String,
                    let threadAuthorName = thread["author"] as? String else {
                        return
                }
                
                let cordataManager = AppController.current.getService(of: SACoreDataManager.self)!
                cordataManager.blockUser(uid: threadAuthorUid, name: threadAuthorName, reason: nil)
            }
            
            let amenu = UIMenu(title: "可选操作", image: nil, identifier: nil, options: .init(rawValue: 0), children: [action1, action2])
            return amenu
        }
        
        let contextMenuConfiguration = UIContextMenuConfiguration(identifier: nil, previewProvider: provider, actionProvider: action)
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
            self.splitViewController?.showDetailViewController(contentViewer, sender: self)
        }
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willEndFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        guard let indexPath = self.currentPreviewCellIndexPath else {
            return
        }
        updateReadStatusForCell(at: indexPath, reloadCell: false)
        currentPreviewCellIndexPath = nil
    }
}
