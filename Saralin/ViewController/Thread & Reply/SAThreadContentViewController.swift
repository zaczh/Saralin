//
//  SAThreadContentViewController.swift
//  Saralin
//
//  Created by zhang on 1/9/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import WebKit
import CoreData

class SAThreadContentViewController: SAContentViewController, SAReplyViewControllerDelegate {
    /// for paging
    private var currentPageUpper: Int = 1
    private var currentPageLower: Int = 1
    private var totalPage: Int = 1
    
    
    struct PollData {
        var polloptionid: Int
        var tid: Int
        var votes: Int
        var displayorder: Int
        var polloption: String
        var voterids: String
    }
    
    struct ThreadData {
        var author: String?
        var authorid: String?
        var dbdateline: String?
        var subject: String?
        var formhash: String!
        var tid: String!
        var fid: String!
        var typeid: String?
        var replies: Int = 0
        var pollData: [PollData] = []
    }
    
    // used in font configuration VC
    private var isDummy: Bool = false
    private var dummyHTMLFileURL: URL?
    class func createDummyInstanceWithHTMLFileAt(url: URL) -> SAThreadContentViewController {
        let dummyURL = URL.init(string: "http://dummy?tid=0&fid=0&page=0")!
        let viewController = SAThreadContentViewController.init(url: dummyURL)
        viewController.isDummy = true
        viewController.dummyHTMLFileURL = url
        return viewController
    }
    
    private var pageComposer: SAThreadHTMLComposer?
    private var pageLoadingFinishHandler: (((() -> Void)?) -> ())?
    
    private var fileURL: URL!
    private var fileDirectoryURL: URL!
    private let imageSavingSubDirName = "images"

    // thread json data
    private var threadData = ThreadData()

    // wkwebview javascript interaction
    var webData: [String:AnyObject]?
    
    private var urlSession: URLSession! = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(30)
        return URLSession.init(configuration: configuration, delegate: nil, delegateQueue: nil)
    } ()
    
    // floor jumping related
    private var quoteFloorJumpView: QuoteFloorJumpView!
    private var quotedFloorPidStack: [String] = []

    required init(url: Foundation.URL) {
        super.init(url: url)
        commonInit()
    }
    
    override func config(url: Foundation.URL) {
        super.config(url: url)
        commonInit()
    }
    
    // must be called after set self.url
    private func commonInit() {
        showsLoadingProgressView = false
        
        let url = self.url!
        threadData.tid = url.sa_queryString("tid")
        
        // my notice view controller cell click goes here
        if threadData.tid == nil {
            threadData.tid = url.sa_queryString("ptid")
        }
        
        if let totalpage = url.sa_queryString("totalpage") {
            totalPage = Int(totalpage)!
        }
        
        guard threadData.tid != nil else {
            fatalError("wrong url parameter!")
        }
        
        automaticallyLoadsURL = false
        
        // this should be done early
        prepareDirectory()
        
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: nil) { [weak self] (notification) in
            self?.removeHTMLFiles()
        }
    }
    
    deinit {
        sa_log_v2("SAThreadContentViewController deinit", module: .ui, type: .debug)
        removeHTMLFiles()
        if let session = urlSession {
            session.invalidateAndCancel()
        }
        if let _ = kvoContext {
            webView.scrollView.removeObserver(self, forKeyPath: #keyPath(UIScrollView.contentSize))
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // MARK: - Restoration
    override func encodeRestorableState(with coder: NSCoder) {
        if let url = self.url {
            coder.encode(url, forKey: "url")
        }
        super.encodeRestorableState(with: coder)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        url = coder.decodeObject(forKey: "url") as? URL
        commonInit()
        loadPagePreserveHistory()
    }
    
    private var bottomRefreshStack = UIStackView()
    private let bottomRefreshContainerView = UIView()

    private var kvoContext: String!
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
        
        webView.scrollView.delegate = self
        webView.scrollView.addSubview(bottomRefreshContainerView)
        bottomRefreshContainerView.isHidden = true
        bottomRefreshStack.axis = .horizontal
        bottomRefreshStack.spacing = 10
        bottomRefreshStack.translatesAutoresizingMaskIntoConstraints = false
        bottomRefreshContainerView.addSubview(bottomRefreshStack)
        bottomRefreshStack.centerXAnchor.constraint(equalTo: bottomRefreshContainerView.centerXAnchor).isActive = true
        bottomRefreshStack.centerYAnchor.constraint(equalTo: bottomRefreshContainerView.centerYAnchor).isActive = true
        let loading = UIActivityIndicatorView(style: .gray)
        bottomRefreshStack.addArrangedSubview(loading)
        let label = UILabel()
        bottomRefreshStack.addArrangedSubview(label)
        kvoContext = ""
        webView.scrollView.addObserver(self, forKeyPath: #keyPath(UIScrollView.contentSize), options: [.new], context: &kvoContext)
        bottomRefresherDidRefresh() // reset state

        if isDummy {
            restorationIdentifier = nil
        } else {
            restorationIdentifier = SAViewControllerRestorationIdentifier.threadContent.rawValue
        }
        
        automaticallyShowsLoadingView = false
        
        loadingController.emptyLabelTitle = "当前帖子不存在、已被删除，或者你没有权限查看"
        
        if !isRestoredFromArchive {
            if isDummy {
                loadDummyHTMLFile()
            } else {
                loadDB { [weak self] in
                    if self?.favoriteRecordInDB != nil {
                        sa_log_v2("this thread also exist in online favorite list", module: .ui, type: .info)
                    }
                    self?.loadPagePreserveHistory()
                }
            }
        }
        
        #if targetEnvironment(macCatalyst)
            setupContextMenuAction()
        #endif
               
        if !isDummy {
            let moreItem: UIBarButtonItem = { () in
                if #available(iOS 13.0, *) {
                    return UIBarButtonItem(image: UIImage(systemName: "arrowshape.turn.up.left"), style: .plain, target: self, action: #selector(self.handleMoreButtonClick(_:)))
                } else {
                    // Fallback on earlier versions
                    return UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.reply, target: self, action: #selector(self.handleMoreButtonClick(_:)))
                }
            }()
            moreItem.isEnabled = false
            
            let shareItem: UIBarButtonItem = { () in
                if #available(iOS 13.0, *) {
                    return UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(self.handleShareButtonClick(_:)))
                } else {
                    // Fallback on earlier versions
                    return UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.action, target: self, action: #selector(self.handleShareButtonClick(_:)))
                }
            }()
            shareItem.isEnabled = false
            
            let nightModeItem = UIBarButtonItem(image: UIImage.imageWithSystemName("moon", fallbackName:"moon-56"), style: .plain, target: self, action: #selector(handleNightModeButtonClick(_:)))
            nightModeItem.isEnabled = false
            
            var items: [UIBarButtonItem] = [shareItem, moreItem, nightModeItem]
            let autoSwitchEnabled = (Account().preferenceForkey(.automatically_change_theme_to_match_system_appearance) as? Bool) ?? true
            if autoSwitchEnabled {
                items.removeAll { (item) -> Bool in
                    return item === nightModeItem
                }
            }
            navigationItem.rightBarButtonItems = items
        }
        
        quoteFloorJumpView = QuoteFloorJumpView.init(frame: .zero)
        view.addSubview(quoteFloorJumpView)
        quoteFloorJumpView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            quoteFloorJumpView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -20).isActive = true
            quoteFloorJumpView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
        } else {
            // Fallback on earlier versions
            quoteFloorJumpView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20).isActive = true
            quoteFloorJumpView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20).isActive = true
        }
        quoteFloorJumpView.isHidden = true
        
        let quoteFloorViewTap = UITapGestureRecognizer.init(target: self, action: #selector(handleJumpingButtonClick(_:)))
        quoteFloorJumpView.addGestureRecognizer(quoteFloorViewTap)
        
        if isDummy {
            loadingController.setFinished()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 13.0, *) {
            view.window?.windowScene?.userActivity = getUserActivity()
        } else {
            // Fallback on earlier versions
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &kvoContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        guard let change = change, let contentSize = change[.newKey] as? CGSize else {
            return
        }
        let frame = CGRect(x: 0 , y: contentSize.height, width: webView.scrollView.frame.size.width, height: 40)
        bottomRefreshContainerView.frame = frame
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
                    // append title
                    let prefix = item.title.components(separatedBy: " - ").first ?? ""
                    item.title = prefix + " - \(t)"
                }
            }
            
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierReply.rawValue {
                if viewAppeared {
                    item.target = self
                    item.action = #selector(self.handleMoreButtonClick(_:))
                    item.isEnabled = true
                } else {
                    item.target = nil
                    item.action = nil
                    item.isEnabled = false
                }
            }
            
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierShare.rawValue {
                if viewAppeared {
                    item.target = self
                    item.action = #selector(self.handleShareButtonClick(_:))
                } else {
                    item.target = nil
                    item.action = nil
                    item.isEnabled = false
                }
            }
        }
    }
    #endif
    
    private func getUserActivity() -> NSUserActivity? {
        guard let url = self.url else {
            return nil
        }
        
        let userActivity = NSUserActivity(activityType: SAActivityType.viewThread.rawValue)
        userActivity.isEligibleForHandoff = true
        userActivity.title = SAActivityType.viewThread.title()
        userActivity.userInfo = ["url":url]
        return userActivity
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isDummy { return }
        
        if loadingController.state == .finished {
            recordThreadViewHistory()
            updateWatchingListDB(createIfNotExist: false)
        }
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        quoteFloorJumpView.updateWith(theme: newTheme)
        if let loading = bottomRefreshStack.arrangedSubviews.first as? UIActivityIndicatorView {
            loading.style = newTheme.activityIndicatorStyle
        }
        if let label = bottomRefreshStack.arrangedSubviews[1] as? UILabel {
            label.textColor = newTheme.textColor.sa_toColor()
        }
        reloadPage()
    }
    
    override func viewFontDidChange(_ newTheme: SATheme) {
        super.viewFontDidChange(newTheme)
        reloadPage()
    }
    
    private func reloadPage() {
        guard let _ = webView.url else {
            sa_log_v2("no url was loaded", module: .ui, type: .info)
            return
        }
        
        updateCSSFile()
        
        if webView.isLoading {
            sa_log_v2("is loading, run later", module: .ui, type: .info)
            let handler: ValueChangeHandler = ("loading", { (webView) in
                webView.evaluateJavaScript("reloadCSS();") { (obj, error) in
                    sa_log_v2("reloadPage", module: .ui, type: .info)
                }
            })
            webviewKeyValueChangeRunOnceHandlers.append(handler)
        } else {
            sa_log_v2("not loading, run immediately", module: .ui, type: .info)
            webView.evaluateJavaScript("reloadCSS();") { (obj, error) in
                sa_log_v2("reloadPage", module: .ui, type: .info)
            }
        }
    }
    
    func refreshPage() {
        getWebPageCurrentFloor { [weak self] (floor) in
            guard let self = self else { return }
            
            guard floor > 0 else {
                self.loadDataForCurrentPage()
                return
            }
            
            self.refreshPageAndGoTo(floor: floor)
        }
    }
    
    func refreshWebPollForm() {
        var pollInfo: [String:AnyObject]?
        var pollOptions: [String:AnyObject]?

        let group = DispatchGroup()
        group.enter()
        urlSession.getPollInfo(of: threadData.tid) { [weak self] (obj, error) in
            defer {
                group.leave()
            }
            
            guard error == nil else {
                sa_log_v2("get poll error: %@", module: .ui, type: .error, error!)
                return
            }
                        
            guard let result = obj as? [String:AnyObject] else {
                let error = NSError(domain: NSPOSIXErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Bad response from server."])
                sa_log_v2("%@", module: .ui, type: .error, error.localizedDescription)
                return
            }
            
            guard let success = result["success"] as? Int, success == 1 else {
                sa_log_v2("%@", module: .ui, type: .info, "no poll in this thread")
                return
            }
            
            guard let self = self else {
                let error = NSError(domain: NSPOSIXErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Canceled."])
                sa_log_v2("%@", module: .ui, type: .error, error.localizedDescription)
                return
            }
            pollInfo = result
            
            group.enter()
            self.urlSession.getPollOptions(of: self.threadData.tid) { (obj, error) in
                defer {
                    group.leave()
                }
                
                guard error == nil else {
                    sa_log_v2("get poll error: %@", module: .ui, type: .error, error!)
                    return
                }
                
                sa_log_v2("get poll result: %@", module: .ui, type: .debug, obj?.description ?? "")
                
                guard let result = obj as? [String:AnyObject] else {
                    let error = NSError(domain: NSPOSIXErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Bad response from server.[GetPoolOption]"])
                    sa_log_v2("%@", module: .ui, type: .error, error.localizedDescription)
                    return
                }
                
                pollOptions = result
            }
        }
        
        group.notify(queue: .main) {
            self.pageComposer?.reloadPollForm(pollInfo: pollInfo, pollOptions: pollOptions)
        }
    }
    
    private func refreshPageAndGoTo(floor: Int) {
        let page = pageOfFloor(floor)
        currentPageUpper = page
        currentPageLower = page
        pageLoadingFinishHandler = { [weak self] (completion) in
            guard let self = self else { return }
            self.scrollWebPageTo(floor: floor, completion:{() in
                completion?()
            })
        }
        loadDataForCurrentPage()
    }
    
    private func pageOfFloor(_ floor: Int) -> Int {
        let ppp = SAGlobalConfig().number_of_replies_per_page
        return floor/ppp + 1
    }
    
    override func getWebViewConfiguration() -> WKWebViewConfiguration {
        let config = super.getWebViewConfiguration()
        
        config.userContentController.add(SAScriptImageLazyLoadHandler(viewController: self), name: "imagelazy")
        config.userContentController.add(SAScriptImageViewHandler(viewController: self), name: "imageview")
        config.userContentController.add(SAScriptThreadReplyHandler(viewController: self), name: "threadreply")
        config.userContentController.add(SAScriptReportAbuseHandler(viewController: self), name: "reportabuse")
        config.userContentController.add(SAScriptReportAbuseUserHandler(viewController: self), name: "reportabuseuser")
        config.userContentController.add(SAScriptUnblockAbuseUserHandler(viewController: self), name: "unblockabuseuser")
        config.userContentController.add(SAScriptThreadDeleteHandler(viewController: self), name: "threaddelete")
        config.userContentController.add(SAScriptThreadLoadMoreDataHandler(viewController: self), name: "threadloadmore")
        config.userContentController.add(SAScriptThreadActionHandler(viewController: self), name: "threadaction")
        config.userContentController.add(SAScriptWebDataHandler(viewController: self), name: "webdata")
        config.userContentController.add(SAScriptWebPageHandler(viewController: self), name: "page")

        if #available(iOS 11.0, *) {
            let schemeHandler = SAWKURLSchemeHandler()
            schemeHandler.delegate = self
            config.setURLSchemeHandler(schemeHandler, forURLScheme: sa_wk_url_scheme)
        } else {
            // Fallback on earlier versions
        }
        
        return config
    }
    
    
    private var historyRecordInDB: ViewedThread?
    private var watchlingListRecordInDB: WatchingThread?
    private var favoriteRecordInDB: OnlineFavoriteThread?

    private func loadDB(completion:(() -> Void)?) {
        
        guard let tid = threadData.tid else {
            sa_log_v2("save viewedthread tid is nil, not saved", module: .ui, type: .debug)
            completion?()
            return
        }
        
        let group = DispatchGroup()
        let uid = Account().uid
        group.enter()
        AppController.current.getService(of: SACoreDataManager.self)!.withMainContext { [weak self] (context) in
            defer {
                group.leave()
            }
            guard let self = self else { return }
            let fetch = NSFetchRequest<ViewedThread>(entityName: "ViewedThread")
            fetch.predicate = NSPredicate(format: "tid==%@ AND uid==%@", tid, uid)
            fetch.sortDescriptors = []
            let objects = try! context.fetch(fetch)
            self.historyRecordInDB = objects.first
            if objects.count > 1 {
                for i in 1 ..< objects.count {
                    context.delete(objects[i])
                }
            }
        }
        
        group.enter()
        AppController.current.getService(of: SACoreDataManager.self)!.withMainContext { [weak self] (context) in
            defer {
                group.leave()
            }
            guard let self = self else { return }
            let fetch = NSFetchRequest<WatchingThread>(entityName: "WatchingThread")
            fetch.predicate = NSPredicate(format: "tid==%@ AND uid==%@", tid, uid)
            fetch.sortDescriptors = []
            let objects = try! context.fetch(fetch)
            self.watchlingListRecordInDB = objects.first
            if objects.count > 1 {
                for i in 1 ..< objects.count {
                    context.delete(objects[i])
                }
            }
        }
        
        group.enter()
        AppController.current.getService(of: SACoreDataManager.self)!.withMainContext { [weak self] (context) in
            defer {
                group.leave()
            }
            guard let self = self else { return }
            let fetch = NSFetchRequest<OnlineFavoriteThread>(entityName: "OnlineFavoriteThread")
            fetch.predicate = NSPredicate(format: "tid==%@ AND uid==%@", tid, uid)
            fetch.sortDescriptors = []
            let objects = try! context.fetch(fetch)
            self.favoriteRecordInDB = objects.first
            if objects.count > 1 {
                for i in 1 ..< objects.count {
                    context.delete(objects[i])
                }
            }
        }
        
        group.notify(queue: .main) {
            completion?()
        }
    }
    
    private func loadPagePreserveHistory() {
        guard let obj = historyRecordInDB, let floor = obj.lastviewfloor?.intValue, floor > 1 else {
            sa_log_v2("load ThreadViewHistory floor number is zero", module: .ui, type: .debug)
             DispatchQueue.main.async {
                 self.loadDataForCurrentPage()
             }
            return
        }
        
        sa_log_v2("load ThreadViewHistory floor: %@", module: .ui, type: .info, NSNumber(value: floor))
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            let page = strongSelf.pageOfFloor(floor)
            strongSelf.currentPageUpper = page
            strongSelf.currentPageLower = page
            strongSelf.pageLoadingFinishHandler = { [weak self] (completion) in
                guard let self = self else { return }
                self.scrollWebPageTo(floor: floor, completion: {
                    completion?()
                })
            }
            strongSelf.loadDataForCurrentPage()
        }
    }
    
    // MARK: record history
    fileprivate func recordThreadViewHistory() {
        guard threadData.fid != nil && threadData.tid != nil else {
            sa_log_v2("save viewedthread fid is nil or tid is nil, not saved", module: .ui, type: .debug)
            return
        }
        
        let uid = Account().uid
        guard !uid.isEmpty else {
            return
        }
        
        getWebPageCurrentFloor { (floor) in
            guard floor > 0 else {return}
            
            sa_log_v2("record ThreadViewHistory floor: %@", module: .ui, type: .debug, NSNumber(value: floor))
            
            // because coredata saving could be in background thread
            let webviewYOffset = Float(self.webView!.scrollView.contentOffset.y)
            let lower = self.currentPageLower
            let replies = self.threadData.replies
            let subject = self.threadData.subject
            let author = self.threadData.author
            let authorID = self.threadData.authorid
            let tid = self.threadData.tid
            let fid = self.threadData.fid
            
            if let obj = self.historyRecordInDB {
                obj.managedObjectContext?.perform {
                    obj.lastviewtime = Date()
                    obj.subject = subject
                    obj.lastviewfloor = NSNumber(value: floor)
                    obj.lastviewpageisreverseloading = NSNumber(value: false)
                    obj.webviewyoffset = NSNumber(value: webviewYOffset)
                    obj.page = NSNumber(value: lower)
                    obj.lastviewreplycount = NSNumber(value: replies)
                    obj.createdevicename = UIDevice.current.name
                    obj.createdeviceidentifier = AppController.current.currentDeviceIdentifier
                }
            } else {
                AppController.current.getService(of: SACoreDataManager.self)!.insertNew(using: { [weak self] (viewedThread: ViewedThread) in
                    viewedThread.createdevicename = UIDevice.current.name
                    viewedThread.createdeviceidentifier = AppController.current.currentDeviceIdentifier
                    viewedThread.uid = uid
                    viewedThread.lastviewpageisreverseloading = NSNumber.init(value: false)
                    viewedThread.lastviewfloor = NSNumber(value: floor)
                    viewedThread.lastviewtime = Date()
                    viewedThread.author = author
                    viewedThread.authorid = authorID
                    viewedThread.subject = subject
                    viewedThread.tid = tid
                    viewedThread.fid = fid
                    viewedThread.page = NSNumber(value: lower)
                    viewedThread.webviewyoffset = NSNumber(value: webviewYOffset)
                    viewedThread.lastviewreplycount = NSNumber(value: replies)
                    self?.historyRecordInDB = viewedThread
                }, completion: nil)
                sa_log_v2("save viewedthread", module: .ui, type: .debug)
                
                if let _ = tid {
                    AppController.current.getService(of: SACoreDataManager.self)!.cache?.viewedThreadIDs.append(tid!)
                }
            }
        }
    }
    
    // this function is called from webpage
    func loadMoreDataAndInsertHTML(downward: Bool, callbackIndex: Int) {
        let noMoreDataScript = "runCallbackFuncAtIndex(\(callbackIndex),false,true,null);"
        let failedScript = "runCallbackFuncAtIndex(\(callbackIndex),true,false,null);"
        
        let allLoadedJob = { () in
            self.webView?.evaluateJavaScript(noMoreDataScript, completionHandler: nil)
            sa_log_v2("loadMoreDataAndInsertHTML: all loaded downward", module: .ui, type: .debug)
        }
        
        let allLoadedJobUpward = { () in
            self.webView?.evaluateJavaScript(noMoreDataScript, completionHandler: nil)
            sa_log_v2("loadMoreDataAndInsertHTML: all loaded upward", module: .ui, type: .debug)
        }
        
        let failedJob = { [weak self] () in
            guard let self = self else { return }
            
            // restore page
            if downward {
                self.currentPageLower = self.currentPageLower - 1
            } else {
                self.currentPageUpper = self.currentPageUpper + 1
            }
            self.webView?.evaluateJavaScript(failedScript, completionHandler: nil)
            sa_log_v2("loadMoreDataAndInsertHTML failed", module: .ui, type: .debug)
        }
        
        if downward {
            guard currentPageLower < totalPage else {
                allLoadedJob()
                return
            }
            currentPageLower = currentPageLower + 1
        } else {
            guard currentPageUpper > 1 else {
                allLoadedJobUpward()
                return
            }
            currentPageUpper = currentPageUpper - 1
        }
        
        urlSession.getTopicContent(of: threadData.tid, page: downward ? currentPageLower : currentPageUpper) { [weak self] (result, error) in
            guard let self = self else {
                return
            }
            
            guard error == nil,
                let resultDict = result as? [String:AnyObject],
                let variables = resultDict["Variables"] as? [String:Any],
                let thread = variables["thread"] as? [String:AnyObject],
                let replyCount = thread["replies"] as? String,
                let postlist = variables["postlist"] as? [[String:AnyObject]] else {
                    failedJob();
                    return
            }
            
            self.threadData.replies = Int(replyCount)!
            self.threadData.formhash = variables["formhash"] as? String
            self.threadData.fid = thread["fid"] as? String
            self.threadData.tid = thread["tid"] as? String
            self.threadData.subject = thread["subject"] as? String
            self.threadData.author = thread["author"] as? String
            self.threadData.authorid = thread["authorid"] as? String
            self.threadData.dbdateline = postlist.first?["dbdateline"] as? String
            
            guard self.threadData.tid != nil else {
                failedJob();
                return
            }
            
            let noMoreData = postlist.count < SAGlobalConfig().number_of_replies_per_page
            self.pageComposer?.append(threadInfo: thread, postList: postlist, completion: { (composer, content, parseError) in
                guard !content.isEmpty else {
                    failedJob();
                    return
                }
                
                let script = "runCallbackFuncAtIndex(\(callbackIndex),false,false,\"\(content.sa_escapedStringForJavaScriptInput())\");"
                self.webView?.evaluateJavaScript(script, completionHandler: { (result, error) in
                    if error == nil {
                        sa_log_v2("append html ok", module: .ui, type: .debug)
                    } else  {
                        sa_log_v2("append html error", module: .ui, type: .debug)
                    }
                })
                
                if noMoreData {
                    if downward {
                        allLoadedJob()
                    } else  {
                        allLoadedJobUpward()
                    }
                }
            })
        }
    }
    
    private func loadDataForCurrentPage() {
        guard threadData.tid != nil else {
            sa_log_v2("error: tid is nil!", module: .ui, type: .debug)
            return
        }
        
        //clear flags
        let script = "clearBeforeReloading();"
        webView?.evaluateJavaScript(script, completionHandler: nil)
        
        loadingController.setLoading()
        
        var threadResult: [String:AnyObject]?
        var pollInfo: [String:AnyObject]?
        var pollOptions: [String:AnyObject]?

        let group = DispatchGroup()
        group.enter()
        urlSession.getTopicContent(of: threadData.tid, page: currentPageLower) { [weak self] (result, error) in
            defer {
                group.leave()
            }
            guard let strongSelf = self else {
                return
            }
            
            guard error == nil,
            let resultDict = result as? [String:AnyObject] else {
                strongSelf.loadingController.setFailed(with: error)
                return
            }

            threadResult = resultDict
        }
        
        group.enter()
        urlSession.getPollInfo(of: threadData.tid) { [weak self] (obj, error) in
            defer {
                group.leave()
            }
            
            guard error == nil else {
                sa_log_v2("get poll error: %@", module: .ui, type: .error, error!)
                return
            }
                        
            guard let result = obj as? [String:AnyObject] else {
                let error = NSError(domain: NSPOSIXErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Bad response from server."])
                sa_log_v2("%@", module: .ui, type: .error, error.localizedDescription)
                return
            }
            
            guard let success = result["success"] as? Int, success == 1 else {
                sa_log_v2("%@", module: .ui, type: .info, "no poll in this thread")
                return
            }
            
            guard let self = self else {
                let error = NSError(domain: NSPOSIXErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Canceled."])
                sa_log_v2("%@", module: .ui, type: .error, error.localizedDescription)
                return
            }
            pollInfo = result
            
            group.enter()
            self.urlSession.getPollOptions(of: self.threadData.tid) { (obj, error) in
                defer {
                    group.leave()
                }
                
                guard error == nil else {
                    sa_log_v2("get poll error: %@", module: .ui, type: .error, error!)
                    return
                }
                
                sa_log_v2("get poll result: %@", module: .ui, type: .debug, obj?.description ?? "")
                
                guard let result = obj as? [String:AnyObject] else {
                    let error = NSError(domain: NSPOSIXErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Bad response from server.[GetPoolOption]"])
                    sa_log_v2("%@", module: .ui, type: .error, error.localizedDescription)
                    return
                }
                
                pollOptions = result
            }
        }
        
        group.notify(queue: DispatchQueue.main) { [weak self] in
            guard let strongSelf = self else {
                return
            }
            guard let resultDict = threadResult, let variables = resultDict["Variables"] as? [String:AnyObject] else {
                return
            }
                        
            if let message = resultDict["Message"] as? [String:AnyObject],
                let messagestr = message["messagestr"] as? String, !messagestr.isEmpty {
                strongSelf.loadingController.emptyLabelTitle = messagestr
            }
            
            guard let thread = variables["thread"] as? [String:Any],
            let postlist = variables["postlist"] as? [[String:Any]],
                !postlist.isEmpty else {
                strongSelf.loadingController.setEmpty()
                return
            }
            
            guard let replyCount = thread["replies"] as? String else {
                strongSelf.loadingController.setEmpty()
                return
            }
            
            strongSelf.threadData.replies = Int(replyCount)!
            strongSelf.threadData.formhash = variables["formhash"] as? String
            strongSelf.threadData.fid = thread["fid"] as? String
            strongSelf.threadData.tid = thread["tid"] as? String
            strongSelf.threadData.subject = thread["subject"] as? String
            strongSelf.threadData.author = thread["author"] as? String
            strongSelf.threadData.authorid = thread["authorid"] as? String
            strongSelf.threadData.dbdateline = postlist.first?["dbdateline"] as? String
            
            let allowperm = variables["allowperm"] as? [String:Any]
            if let uploadhash = allowperm?["uploadhash"] as? String {
               Account().uploadhash = uploadhash
            }
            guard strongSelf.threadData.fid != nil, strongSelf.threadData.tid != nil else {
               strongSelf.loadingController.setEmpty()
               return
            }

            #if targetEnvironment(macCatalyst)
            strongSelf.title = strongSelf.threadData.subject
            strongSelf.updateToolBar(true)
            #endif

            // NOTE: `loadDataForCurrentPage` may reset the composer
            strongSelf.pageComposer = SAThreadHTMLComposer(fid: strongSelf.threadData.fid, tid: strongSelf.threadData.tid, threadData: resultDict, pollInfo: pollInfo, pollOptions: pollOptions)
            strongSelf.pageComposer?.webView = strongSelf.webView
            strongSelf.pageComposer!.parse(isFirstPage: strongSelf.currentPageLower == 1, completion: { (composer, content, error) in
               if let ppp = variables["ppp"] as? String {
                   let postPerPage = Int(ppp)!
                   let replies = composer.replyCount + 1 // 主贴不算回复，所以加一
                   strongSelf.totalPage = Int(ceil(CGFloat(replies)/CGFloat(postPerPage)))
               }
               strongSelf.loadHTMLFile()
            })
        }
    }
    
    private func prepareDirectory() {
        let fm = FileManager.default
        let timeinterval = CFAbsoluteTimeGetCurrent()
        let htmlFileDirectory = AppController.current.threadHtmlFileDirectory.appendingPathComponent("\(timeinterval)_" + self.threadData.tid, isDirectory: true).path
        if !fm.fileExists(atPath: htmlFileDirectory) {
            try! fm.createDirectory(atPath: htmlFileDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        // some html elements
        let resourceMap: [String:String] = [
            htmlFileDirectory + "/Mahjong" : Bundle.main.path(forResource: "Mahjong", ofType: nil)!,
            htmlFileDirectory + "/static" : Bundle.main.path(forResource: "static", ofType: nil)!,
            htmlFileDirectory + "/noavatar_middle.png" : Bundle.main.path(forResource: "noavatar_middle", ofType: "png")!,
            htmlFileDirectory + "/thread_page_expand_arrow.png" : Bundle.main.path(forResource: "thread_page_expand_arrow", ofType: "png")!,
            htmlFileDirectory + "/loading.gif" : Bundle.main.path(forResource: "loading", ofType: "gif")!,
            htmlFileDirectory + "/placeholder.png" : Bundle.main.path(forResource: "placeholder", ofType: "png")!,
            htmlFileDirectory + "/placeholderfail.png" : Bundle.main.path(forResource: "placeholderfail", ofType: "png")!,
        ]
        for (k, v) in resourceMap {
            if !fm.fileExists(atPath: k) {
                try! fm.createSymbolicLink(atPath: k, withDestinationPath: v)
            }
        }
        
        // image saving dir
        let downloadedImageDir = htmlFileDirectory + "/\(imageSavingSubDirName)"
        if !fm.fileExists(atPath: downloadedImageDir) {
            try! fm.createDirectory(atPath: downloadedImageDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        let htmlFilePath = String.init(format: "%@/1.html", htmlFileDirectory)
        self.fileURL = Foundation.URL.init(fileURLWithPath: htmlFilePath)
        self.fileDirectoryURL = Foundation.URL.init(fileURLWithPath: htmlFileDirectory)
    }
    
    // replace css
    private func updateCSSFile() {
        let cssFilePath = Bundle.main.path(forResource: "base", ofType: "css")
        var css = try! String(contentsOfFile: cssFilePath!)
        
        // font and color
        let activeTheme = Theme()
        
        let avatarSize = ceil(UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body).pointSize * 2 + 8)
        let showsAvatar = Account().preferenceForkey(SAAccount.Preference.thread_view_shows_avatar) as! Bool
        css = css.replacingOccurrences(of: "${avatar-display-style}", with: showsAvatar ? "block":"none")
        css = css.replacingOccurrences(of: "${avatar-image-size}", with: "\(avatarSize)px")
        css = css.replacingOccurrences(of: "${background-color}", with: (activeTheme.backgroundColor))
        css = css.replacingOccurrences(of: "${foreground-color}", with: (activeTheme.foregroundColor))
        css = css.replacingOccurrences(of: "${normal-font-size}", with: String(describing: floor(UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body).pointSize/96 * 72)) + "pt")
        css = css.replacingOccurrences(of: "${small-font-size}", with: String(describing: floor(UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.subheadline).pointSize/96 * 72)) + "pt")
        css = css.replacingOccurrences(of: "${reply-header-height}", with: String(describing: floor(UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body).pointSize/96 * 72 * 2.5)) + "pt")

        // adapt icon color
        if activeTheme.colorScheme == 0 {
            css = css.replacingOccurrences(of: "${icon-invert-percent}", with: "50%")
        } else {
            css = css.replacingOccurrences(of: "${icon-invert-percent}", with: "100%")
        }

        css = css.replacingOccurrences(of: "${thread-title-color}", with: (activeTheme.tableHeaderTextColor))
        css = css.replacingOccurrences(of: "${thread-title-font-size}", with: String(describing: floor(UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline).pointSize/96 * 72)) + "pt")
        css = css.replacingOccurrences(of: "${text-color}", with: (activeTheme.textColor))
        css = css.replacingOccurrences(of: "${body-padding}", with: "15px")
        css = css.replacingOccurrences(of: "${link-color}", with: (activeTheme.htmlLinkColor))
        css = css.replacingOccurrences(of: "${header-background-color}", with: (activeTheme.tableCellHighlightColor))
        css = css.replacingOccurrences(of: "${block-quote-text-color}", with: (activeTheme.htmlBlockQuoteTextColor))
        css = css.replacingOccurrences(of: "${block-quote-background-color}", with: (activeTheme.htmlBlockQuoteBackgroundColor))
        
        css = css.replacingOccurrences(of: "${table-cell-seperator-color}", with: activeTheme.tableCellSeperatorColor.sa_toColor().sa_toHtmlCssColorFunction())
        css = css.replacingOccurrences(of: "${table-cell-grayed-text-color}", with: (activeTheme.tableCellGrayedTextColor))
        
        #if targetEnvironment(macCatalyst)
            css = css.replacingOccurrences(of: "${ipad-body-style}", with: "margin:0 auto;\n    max-width: \(SAContentViewControllerReadableAreaMaxWidth)px;")
            css = css.replacingOccurrences(of: "${img-max-width}", with: "\(SAContentViewControllerReadableAreaMaxWidth * 2/3)px")
        #else
            css = css.replacingOccurrences(of: "${ipad-body-style}", with: "")
            css = css.replacingOccurrences(of: "${img-max-width}", with: "100%")
        #endif
        
        try? FileManager.default.removeItem(at: fileDirectoryURL.appendingPathComponent("base.css"))
        FileManager.default.createFile(atPath: fileDirectoryURL.path.appending("/base.css"), contents: css.data(using: String.Encoding.utf8), attributes: nil)
    }
    
    private func loadDummyHTMLFile() {
        let content = try! String.init(contentsOf: dummyHTMLFileURL!)
        updateCSSFile()
        do {
            try content.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            sa_log_v2("write html to file failed error: %@", module: .ui, type: .error, error as CVarArg)
            return
        }
        _ = self.webView?.loadFileURL(fileURL, allowingReadAccessTo: fileDirectoryURL)
    }
    
    private func loadHTMLFile() {
        guard let content = pageComposer?.content else {
            sa_log_v2("load failed because content is nil", module: .ui, type: .error)
            return
        }
        updateCSSFile()
        do {
            try content.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            sa_log_v2("write html to file failed error: %@", module: .ui, type: .error, error as CVarArg)
            return
        }
        _ = self.webView?.loadFileURL(fileURL, allowingReadAccessTo: fileDirectoryURL)
    }
    
    private func scrollWebPageTo(floor: Int, completion: (() -> Void)?) {
        self.webView?.evaluateJavaScript("scrollToFloor('\(floor)')", completionHandler: { (result, error) in
            if error != nil {
                sa_log_v2("error when scroll to last postition: %@", module: .ui, type: .debug, error! as NSError)
            }
            completion?()
        })
    }
    
    private func removeHTMLFiles() {
        try? FileManager.default.removeItem(at: fileDirectoryURL)
    }
    
    override func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if isDummy { return }
        
        let finishing = {
            self.loadingController.setFinished()
            self.navigationItem.rightBarButtonItems?.forEach({ (item) in
                item.isEnabled = true
            })
            
        }
        
        if pageLoadingFinishHandler != nil {
            pageLoadingFinishHandler!{
                finishing()
            }
            pageLoadingFinishHandler = nil
        } else {
            finishing()
        }
    }
    
    override func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            super.webView(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
            return
        }
        
        guard let goto = url.sa_queryString("goto"), goto == "findpost" else {
            super.webView(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
            return
        }
        
        if let pid = url.sa_queryString("pid"), let ptid = url.sa_queryString("ptid"), ptid == threadData.tid {
            // jump to floor of this thread
            let jumpJs = "(function(){var oldFloor = getCurrentFloorTid();var jumpDiv = document.querySelector('div#pid\(pid)');if (jumpDiv != null) {return oldFloor;} else {return null;}})();"
            webView.evaluateJavaScript(jumpJs) { [weak self] (obj, error) in
                defer {
                    decisionHandler(.cancel)
                }
                
                guard let strongSelf = self else {
                    return
                }
                
                guard let oldFloor = obj as? String else {
                    return
                }
                
                strongSelf.quotedFloorPidStack.append(oldFloor)
                strongSelf.quoteFloorJumpView.inStackFloors = strongSelf.quotedFloorPidStack.count
                let flashJs = "(function(){var el = document.querySelector('div#pid\(pid)');el.scrollIntoView();flashElement(el);})();"
                strongSelf.webView.evaluateJavaScript(flashJs, completionHandler: nil)
            }
            return
        }
        
        super.webView(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
    }
    
    override func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        super.webViewWebContentProcessDidTerminate(webView)
        webView.reload()
    }
    
    func openDesktopPage() {
        let link = SAGlobalConfig().forum_base_url + "thread-\(self.threadData.tid!)-1-1.html"
        let desktopPage = SAContentViewController(url: Foundation.URL(string: link)!)
        desktopPage.shouldSetDesktopBrowserUserAgent = true
        desktopPage.shouldLoadAllRequestsWithin = true
        desktopPage.automaticallyShowsLoadingView = true
        desktopPage.title = NSLocalizedString("DESKTOP_PAGE", comment: "桌面版页面")
        navigationController?.pushViewController(desktopPage, animated: true)
    }
    
    // request review
    @objc func requestForAppReview() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(requestForAppReview), object: nil)
        AppController.current.promptForAppStoreReview()
    }
    
    // MARK: UIScrollViewDelegate
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        quoteFloorJumpView.isHidden = true
    }
        
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            // prompt immediately after scrolls conclues is not appropriate
            // so we delay it
            self.perform(#selector(requestForAppReview), with: nil, afterDelay: 2, inModes:[RunLoop.Mode.default])
        }
        quoteFloorJumpView.updateVisibility()
        
        if currentPageLower == totalPage {
            bottomRefreshContainerView.isHidden = false
            let offset =  webView.scrollView.contentOffset.y + webView.scrollView.frame.size.height - webView.scrollView.contentSize.height - webView.scrollView.adjustedContentInset.bottom
            if offset > bottomRefreshContainerView.frame.size.height {
                bottomRefresherIsRefreshing()
                doBottomRefreshing()
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isDragging else {
            return
        }
        
        guard currentPageLower == totalPage else {
            return
        }
        
        bottomRefreshContainerView.isHidden = false
        let offset =  webView.scrollView.contentOffset.y + webView.scrollView.frame.size.height - webView.scrollView.contentSize.height - webView.scrollView.adjustedContentInset.bottom
        if offset > bottomRefreshContainerView.frame.size.height {
            bottomRefresherWillRefresh()
        } else {
            bottomRefresherDidRefresh()
        }
    }
    
    private func bottomRefresherIsRefreshing() {
        if let loading = bottomRefreshStack.arrangedSubviews.first as? UIActivityIndicatorView {
            loading.startAnimating()
        }
        if let label = bottomRefreshStack.arrangedSubviews[1] as? UILabel {
            label.text = NSLocalizedString("REFRESHING_TITLE", comment: "Refreshing")
        }
        var inset = webView.scrollView.contentInset
        inset.bottom = bottomRefreshContainerView.frame.size.height
        webView.scrollView.contentInset = inset
    }
    
    private func bottomRefresherWillRefresh() {
        if let label = bottomRefreshStack.arrangedSubviews[1] as? UILabel {
            label.text = NSLocalizedString("THREAD_BOTTOM_REFRESHER_TITLE_RELEASE_TO_REFRESH", comment: "Release to refresh")
        }
    }
    
    private func doBottomRefreshing() {
        urlSession.getTopicContent(of: threadData.tid, page: currentPageLower) { [weak self] (result, error) in
            guard let self = self else {
                return
            }
            
            guard error == nil,
                let resultDict = result as? [String:AnyObject],
                let variables = resultDict["Variables"] as? [String:Any],
                let ppp = variables["ppp"] as? String,
                let thread = variables["thread"] as? [String:AnyObject],
                let replyCount = thread["replies"] as? String,
                let postlist = variables["postlist"] as? [[String:AnyObject]] else {
                    self.bottomRefresherDidRefresh()
                    return
            }
            
            guard let composer = self.pageComposer else {
                self.bottomRefresherDidRefresh()
                return
            }
            
            var newPostList: [[String:AnyObject]] = []
            postlist.forEach { (reply) in
                guard let floorNumber = Int(reply["number"] as! String) else {
                    return
                }
                if floorNumber > composer.maxFloor {
                    newPostList.append(reply)
                }
            }
            
            guard !newPostList.isEmpty else {
                let newReplyCount = Int(replyCount)!
                if newReplyCount > self.threadData.replies {
                    // new page
                    let postPerPage = Int(ppp)!
                    self.totalPage = Int(ceil(CGFloat(newReplyCount)/CGFloat(postPerPage)))
                    guard self.totalPage > self.currentPageLower else {
                        sa_log_v2("reloading on page boundary", module: .ui, type: .info)
                        self.bottomRefresherDidRefresh()
                        return
                    }
                    self.currentPageLower = self.totalPage
                    self.doBottomRefreshing() // recursive
                    sa_log_v2("recursive bottom refreshing", module: .ui, type: .info)
                    return
                }
                
                self.bottomRefresherDidRefresh()
                return
            }
            
            self.threadData.replies = Int(replyCount)!
            self.threadData.formhash = variables["formhash"] as? String
            self.threadData.fid = thread["fid"] as? String
            self.threadData.tid = thread["tid"] as? String
            self.threadData.subject = thread["subject"] as? String
            self.threadData.author = thread["author"] as? String
            self.threadData.authorid = thread["authorid"] as? String
            self.threadData.dbdateline = postlist.first?["dbdateline"] as? String
            
            guard self.threadData.tid != nil else {
                self.bottomRefresherDidRefresh()
                return
            }
            
            composer.append(threadInfo: thread, postList: newPostList, completion: { (composer, content, parseError) in
                guard !content.isEmpty else {
                    self.bottomRefresherDidRefresh()
                    return
                }
                let script = "appendPostListContent(\"\(content.sa_escapedStringForJavaScriptInput())\");"
                self.webView?.evaluateJavaScript(script, completionHandler: { [weak self] (result, error) in
                    if error == nil {
                        sa_log_v2("append postlist ok", module: .ui, type: .info)
                    } else  {
                        sa_log_v2("append postlist error", module: .ui, type: .info)
                    }
                    self?.bottomRefresherDidRefresh()
                })
            })
        }
    }
    
    private func bottomRefresherDidRefresh() {
        if let loading = bottomRefreshStack.arrangedSubviews.first as? UIActivityIndicatorView {
            loading.stopAnimating()
        }
        if let label = bottomRefreshStack.arrangedSubviews[1] as? UILabel {
            label.text = NSLocalizedString("THREAD_BOTTOM_REFRESHER_TITLE_DRAG_UP_TO_REFRESH", comment: "Drag up to refresh")
        }
        var inset = webView.scrollView.contentInset
        if inset.bottom == 0 {
            return
        }
        inset.bottom = 0
        webView.scrollView.contentInset = inset
    }
    
    private func getWebPageCurrentFloor(completion: ((Int) -> Void)?) {
        if let s = webData?["floor"] as? String, let d = Int(s) {
            completion?(d)
            return
        }
        
        completion?(-1)
    }
    
    override func loadingControllerDidRetry(_ controller: SALoadingViewController) {
        super.loadingControllerDidRetry(controller)
        loadPagePreserveHistory()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func showShareActivity() {
        sa_log_v2("clicked share button", module: .ui, type: .debug)
        guard threadData.tid != nil else {
            sa_log_v2("error: tid is nil!")
            return
        }
        
        let url = Foundation.URL(string: SAGlobalConfig().forum_base_url + "thread-\(self.threadData.tid!)-\(self.currentPageLower)-1.html")!

        let sharePageItem = SAActivityItem()
        sharePageItem.url = url
        sharePageItem.viewController = self
        
        var items: [AnyObject] = [sharePageItem]
        items.append(url as AnyObject)
        
        // insert an app icon
        let appIcon = #imageLiteral(resourceName: "logo")
        items.append(appIcon as AnyObject)

        let applications: [UIActivity] = [SAOpenInSafariActivity() /* , SASnapshotWebPageActivity() */]
        let activityController = UIActivityViewController(activityItems: items, applicationActivities: applications)
        activityController.excludedActivityTypes = [.saveToCameraRoll, .addToReadingList,.assignToContact, .print]
        activityController.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
            sa_log_v2("share completed returned: %@", returnedItems ?? "")
        }
        activityController.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activityController, animated: true, completion: nil)
    }
    
    func replyToMainThread() {
        if !self.checkLoginWithHint("登录以后才能回复帖子") {
            return
        }
        
        var info = [String : AnyObject]()
        info["fid"] = self.threadData.fid as AnyObject?
        info["tid"] = self.threadData.tid as AnyObject?
        info["formhash"] = self.threadData.formhash as AnyObject?
        info["subject"] = self.threadData.subject as AnyObject?
        info["quote_textcontent"] = self.threadData.subject as AnyObject?
        info["author"] = self.threadData.author as AnyObject?
        
        if #available(iOS 13.0, *) {
            if UIApplication.shared.supportsMultipleScenes && ((Account().preferenceForkey(.enable_multi_windows) as? Bool) ?? false) {
                let userActivity = NSUserActivity(activityType: SAActivityType.replyThread.rawValue)
                userActivity.isEligibleForHandoff = true
                userActivity.title = SAActivityType.replyThread.title()
                userActivity.userInfo = ["quoteInfo":info]
                let options = UIScene.ActivationRequestOptions()
                options.requestingScene = view.window?.windowScene
                UIApplication.shared.requestSceneSessionActivation(AppController.current.findSceneSession(), userActivity: userActivity, options: options) { (error) in
                    sa_log_v2("request new scene returned: %@", error.localizedDescription)
                }
            } else {
                // Fallback on earlier versions
                let navi = UIStoryboard(name: "ReplyThread", bundle: nil).instantiateInitialViewController() as! UINavigationController
                let reply = navi.topViewController! as! SAReplyViewController
                reply.config(quoteInfo: info)
                reply.delegate = self
                navi.modalPresentationStyle = .pageSheet
                self.present(navi, animated: true, completion: nil)
            }
        } else {
            // Fallback on earlier versions
            let navi = UIStoryboard(name: "ReplyThread", bundle: nil).instantiateInitialViewController() as! UINavigationController
            let reply = navi.topViewController! as! SAReplyViewController
            reply.config(quoteInfo: info)
            reply.delegate = self
            navi.modalPresentationStyle = .pageSheet
            self.present(navi, animated: true, completion: nil)
        }
    }
    
    func checkLoginWithHint(_ hint: String) -> Bool {
        if Account().isGuest {
            let alert = UIAlertController(title: "提示", message: hint, preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            
            let threadAction = UIAlertAction(title: "现在登录", style: .default){ (action) in
                AppController.current.presentLoginViewController(sender: self, completion: nil)
            }
            alert.addAction(threadAction)
            present(alert, animated: true, completion: nil)
            
            return false
        }
        
        return true
    }
    
    private func favoriteThread() {
        if !checkLoginWithHint("登录以后才能收藏帖子") {
            return
        }
        
        guard threadData.tid != nil && !threadData.tid.isEmpty else {
            return
        }
        
        let activity = SAModalActivityViewController()
        present(activity, animated: true, completion: nil)
        
        urlSession.favorite(thread: threadData.tid!, formhash: threadData.formhash!) { (object, error) in
            activity.hideAndShowResult(of: true, info: "已收藏") { () in
                let viewController = self.navigationController!.presentingViewController
                viewController?.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    private func addToWatchList() {
        if !checkLoginWithHint("登录以后才能将帖子加入观察列表") {
            return
        }
        
        let addWatchingListAction = { () in
            guard self.threadData.tid != nil && !self.threadData.tid.isEmpty else {
                return
            }
            
            let activity = SAModalActivityViewController(style: .resultSuccess, caption: "已加入")
            self.present(activity, animated: true, completion: nil)
            self.updateWatchingListDB(createIfNotExist: true)
            activity.hide(completion: { [weak self] in
                let notificationManager = AppController.current.getService(of: SANotificationManager.self)!
                notificationManager.checkIfNeedPrompt({ (shouldPrompt, shouldOpenInSettings) in
                    if !shouldPrompt { return }
                    
                    let alert = UIAlertController(title: "是否开启通知？", message: "开启后App在后台能通过静默通知的方式刷新观察列表里面的帖子。", preferredStyle: .alert)
                    let action = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default) { (action) in
                        AppController.current.getService(of: SANotificationManager.self)!.registerNotifications()
                    }
                    alert.addAction(action)
                    alert.addAction(UIAlertAction.init(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel) { [weak self] (action) in
                        let alert = UIAlertController(title: NSLocalizedString("HINT", comment: "提示"), message: "后续如果需要，可以在设置页面开启通知。", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: nil))
                        self?.present(alert, animated: true, completion: nil)
                    })
                    self?.present(alert, animated: true, completion: nil)
                })
            })
        }
        
        if let _ = UserDefaults.standard.value(forKey: SAUserDefaultsKey.lastDateWatchingListIntroductionBeenShown.rawValue) {
            addWatchingListAction()
            return
        }
        
        UserDefaults.standard.set(Date(), forKey: SAUserDefaultsKey.lastDateWatchingListIntroductionBeenShown.rawValue)
        let alert = UIAlertController(title: NSLocalizedString("HINT", comment: "Hint"), message: "加入观察列表的帖子会定时在后台检查更新，列表最多支持30个帖子。", preferredStyle: .alert)
        let action = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default) { (action) in
            addWatchingListAction()
        }
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
        return
    }
    
    func updateWatchingListDB(createIfNotExist: Bool) {
        guard let tid = self.threadData.tid else {
            sa_log_v2("addToWatchingList fid is nil or tid is nil, not add", module: .ui, type: .debug)
            return
        }
        
        let uid = Account().uid
        let fid = self.threadData.fid
        let replyCount = self.threadData.replies
        let subject = self.threadData.subject
        let author = self.threadData.author
        let authorid = self.threadData.authorid
        let currentPageLower = self.currentPageLower
        
        if let obj = watchlingListRecordInDB {
            obj.managedObjectContext?.perform {
                obj.lastviewtime = Date()
                obj.subject = subject
                obj.page = NSNumber(value: currentPageLower)
                obj.lastviewreplycount = NSNumber(value: replyCount)
                obj.newreplycount = NSNumber(value: 0)
                obj.createdevicename = UIDevice.current.name
                obj.createdeviceidentifier = AppController.current.currentDeviceIdentifier
            }
        } else if createIfNotExist {
            AppController.current.getService(of: SACoreDataManager.self)!.insertNew(using: { [weak self] (watchingThread: WatchingThread) in
                watchingThread.createdevicename = UIDevice.current.name
                watchingThread.createdeviceidentifier = AppController.current.currentDeviceIdentifier
                watchingThread.uid = uid
                watchingThread.lastviewtime = Date()
                watchingThread.author = author
                watchingThread.authorid = authorid
                watchingThread.subject = subject
                watchingThread.tid = tid
                watchingThread.fid = fid
                watchingThread.page = NSNumber(value: currentPageLower)
                watchingThread.lastviewreplycount = NSNumber(value: replyCount)
                watchingThread.timeadded = Date()
                watchingThread.newreplycount = NSNumber(value: 0)
                watchingThread.lastfetchreplycount = NSNumber(value: replyCount)
                self?.watchlingListRecordInDB = watchingThread
            }, completion: nil)
        }
    }
    
    func removeFromWatchingList() {
        guard let record = watchlingListRecordInDB, let context = record.managedObjectContext else { return }
        context.perform {
            context.delete(record)
            let activity = SAModalActivityViewController(style: .resultSuccess, caption: "已移除")
            self.watchlingListRecordInDB = nil
            self.present(activity, animated: true, completion: nil)
            activity.hide(completion: nil)
        }
    }
    
    @objc func handleJumpingButtonClick(_ sender: UIButton) {
        if let floor = quotedFloorPidStack.popLast() {
            webView.evaluateJavaScript("(function(){var el = document.querySelector('div#pid\(floor)');el.scrollIntoView();})();", completionHandler: nil)
        }
        quoteFloorJumpView.inStackFloors = quotedFloorPidStack.count
    }
    
    @objc func handleShareButtonClick(_ sender: AnyObject) {
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
        popoverContentController.addAction(UIAlertAction.init(title: "分享", style: UIAlertAction.Style.default, handler: { (action) in
            self.showShareActivity()
        }))
        popoverContentController.addAction(UIAlertAction.init(title: "查看桌面版页面", style: UIAlertAction.Style.default, handler: { (action) in
            self.openDesktopPage()
        }))
        popoverContentController.addAction(UIAlertAction.init(title: "加入收藏夹", style: UIAlertAction.Style.default, handler: { (action) in
            self.favoriteThread()
        }))
        
        if watchlingListRecordInDB == nil {
            popoverContentController.addAction(UIAlertAction.init(title: "加入观察列表", style: UIAlertAction.Style.default, handler: { (action) in
                self.addToWatchList()
            }))
        } else {
            popoverContentController.addAction(UIAlertAction.init(title: "移除出观察列表", style: UIAlertAction.Style.default, handler: { (action) in
                self.removeFromWatchingList()
            }))
        }
        popoverContentController.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))

        targetViewController.present(popoverContentController, animated: true, completion: nil)
    }
    
    @objc func handleNightModeButtonClick(_ sender: UIBarButtonItem) {
        let doSwitch = { () in
            Account().savePreferenceValue(false as AnyObject, forKey: .automatically_change_theme_to_match_system_appearance)
            let themeManager = AppController.current.getService(of: SAThemeManager.self)!
            themeManager.switchTheme()
        }
        
        if #available(iOS 13.0, *) {
            let autoSwitchEnabled = (Account().preferenceForkey(.automatically_change_theme_to_match_system_appearance) as? Bool) ?? true
            if autoSwitchEnabled {
                let alert = UIAlertController(title: "提示", message: "这将关闭自动跟随系统主题切换，改成手动切换模式，是否继续？", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: NSLocalizedString("继续", comment: "OK"), style: .destructive) { (action) in
                    doSwitch()
                })
                present(alert, animated: true, completion: nil)
                return
            }
            doSwitch()
            return
        } else {
            doSwitch()
            return
        }
    }
    
    @objc func handleMoreButtonClick(_ sender: AnyObject) {
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
        popoverContentController.addAction(UIAlertAction.init(title: "跳转分页", style: UIAlertAction.Style.default, handler: { (action) in
            self.jumpBetweenPages()
        }))
        popoverContentController.addAction(UIAlertAction.init(title: "刷新", style: UIAlertAction.Style.default, handler: { (action) in
            self.refreshPage()
        }))
        popoverContentController.addAction(UIAlertAction.init(title: "回复", style: UIAlertAction.Style.default, handler: { (action) in
            self.replyToMainThread()
        }))
        
        popoverContentController.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))
        targetViewController.present(popoverContentController, animated: true, completion: nil)
    }
    
    
    func jumpBetweenPages() {
        let alert = UIAlertController(title: "输入页码：", message: nil, preferredStyle: .alert)
        alert.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil)
        alert.addAction(cancelAction)

        let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default){ (action) in
            let textField = alert.textFields![0]
            guard textField.text != nil else {
                return
            }
            guard let page = Int(textField.text!) else {
                return
            }
            
            if page <= self.totalPage && page > 0 {
                self.currentPageLower = page
                self.currentPageUpper = self.currentPageLower
                self.loadDataForCurrentPage()
            }
        }
        alert.addAction(okAction)

        alert.addTextField { (textField) in
            textField.text = String.init(format: "%d", self.currentPageLower)
            textField.keyboardType = .numberPad
            textField.keyboardAppearance = Theme().keyboardAppearence
            
            let pageLabel = UILabel()
            pageLabel.font = textField.font
            pageLabel.textColor = Theme().tableCellGrayedTextColor.sa_toColor()
            pageLabel.text = "/共\(self.totalPage)页"
            pageLabel.sizeToFit()
            textField.rightView = pageLabel
            textField.rightViewMode = .always
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: Preview action items.
    lazy var previewActions: [UIPreviewActionItem] = {
        let action1 = UIPreviewAction(title: "隐藏帖子", style: .default, handler: { (action, viewController) in
            guard let threadContent = viewController as? SAThreadContentViewController else {return}
            
            guard let tid = threadContent.threadData.tid,
                let threadTitle = threadContent.threadData.subject,
                let threadAuthorUid = threadContent.threadData.authorid,
                let threadAuthorName = threadContent.threadData.author,
                let interval = threadContent.threadData.dbdateline else {
                    return
            }
            
            AppController.current.getService(of: SACoreDataManager.self)!.blockThread(tid: tid, title: threadTitle, authorID: threadAuthorUid, authorName: threadAuthorName, threadCreation: Date.init(timeIntervalSince1970: TimeInterval(interval) ?? 0))
            
        })
        
        let action2 = UIPreviewAction(title: "屏蔽作者", style: .destructive, handler: { (action, viewController) in
            guard let threadContent = viewController as? SAThreadContentViewController else {return}
            guard let threadAuthorUid = threadContent.threadData.authorid,
                let threadAuthorName = threadContent.threadData.author else {
                    return
            }
            
            AppController.current.getService(of: SACoreDataManager.self)!.blockUser(uid: threadAuthorUid, name: threadAuthorName, reason: nil)
        })
        
        return [action1, action2]
    }()
    
    override var previewActionItems : [UIPreviewActionItem] {
        return previewActions
    }
}

// MARK: - SAReplyViewControllerDelegate
extension SAThreadContentViewController {
    func replyDidSucceed(_ replyViewController: SAReplyViewController) {
        refreshPageAndGoTo(floor: threadData.replies + 1)
    }

    func replyDidFail(_ replyViewController: SAReplyViewController) {
        
    }
}

// MARK: - Script Handler Interfaces
extension SAThreadContentViewController {
    func reportAbuseUser(_ reportedUid: String, name: String, fromElementAtFrame frame: CGRect) {
        let alert = UIAlertController(title: "屏蔽[\(name)]", message: "请选择屏蔽原因", preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = webView
        alert.popoverPresentationController?.sourceRect = frame
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        
        let reportAction: ((_ reason: String) -> Void) = { (reason) in
            let alert = SAModalActivityViewController()
            self.present(alert, animated: true, completion: nil)
            AppController.current.getService(of: SACoreDataManager.self)!.blockUser(uid: reportedUid, name: name, reason: reason)
            
            let tagID = "posterid_\(reportedUid)"
            self.webView?.evaluateJavaScript("Array.prototype.forEach.call(document.getElementsByClassName('\(tagID)'), function(e){e.parentNode.style.height='80px';e.style.display=\"flex\";});", completionHandler: nil)
            alert.dismiss(animated: true, completion: nil)
        }
        
        let threadAction = UIAlertAction(title: "发布广告", style: .default){ (action) in
            reportAction("发布广告")
        }
        alert.addAction(threadAction)
        
        let trollAction = UIAlertAction(title: "恶意灌水", style: .default){ (action) in
            reportAction("恶意灌水")
        }
        alert.addAction(trollAction)
        
        let illegalAction = UIAlertAction(title: "发布不适当内容", style: .default){ (action) in
            reportAction("发布不适当内容")
        }
        alert.addAction(illegalAction)
        
        let othersAction = UIAlertAction(title: "其他原因", style: .default){ (action) in
            reportAction("其他原因")
        }
        alert.addAction(othersAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    func sendDM(to touid: String, name: String) {
        let tousername = name.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? "未知昵称"
        let pmnum = "0"
        let url = Foundation.URL(string: SAGlobalConfig().forum_base_url + "home.php?mod=spacecp&ac=pm&touid=\(touid)&mobile=1&tousername=\(tousername)&pmnum=\(pmnum)")!
        let dm = SAMessageCompositionViewController(url: url)
        navigationController?.pushViewController(dm, animated: true)
    }
    
    func unblockAbuseUser(_ reportedUid: String, name: String, fromElementAtFrame frame: CGRect) {
        AppController.current.getService(of: SACoreDataManager.self)!.undoBlockUser(uid: reportedUid)
        let tagID = "posterid_\(reportedUid)"
        self.webView?.evaluateJavaScript("Array.prototype.forEach.call(document.getElementsByClassName('\(tagID)'), function(e){e.parentNode.style=null;e.style.display=\"none\";});", completionHandler: nil)
    }
    
    func reportAbuse(_ rid: String, fromElementAtFrame frame: CGRect) {
        let alert = UIAlertController(title: NSLocalizedString("REPORT_ABUSE", comment: "Report Abuse"), message: NSLocalizedString("PLEASE_CHOOSE_TYPE_OF_ABUSE", comment: "Which Type Of Abuse Have You Encountered?"), preferredStyle: .actionSheet)
        
        alert.popoverPresentationController?.sourceView = webView
        alert.popoverPresentationController?.sourceRect = frame
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        let reportAction: ((_ reason: String) -> Void) = { (reason) in
            let alert = SAModalActivityViewController()
            self.present(alert, animated: true, completion: nil)
            self.urlSession.reportAbuse(of: self.threadData.fid, tid: self.threadData.tid, rid: rid, reason: "广告/SPAM", formhash: self.threadData.formhash!, completion: { (obj, error) in
                if error == nil {
                    alert.hideAndShowResult(of: true, info: "已举报") { () in
                        let viewController = self.navigationController!.presentingViewController
                        viewController?.dismiss(animated: true, completion: nil)
                    }
                } else  {
                    alert.hideAndShowResult(of: true, info: "失败") { () in
                        let viewController = self.navigationController!.presentingViewController
                        viewController?.dismiss(animated: true, completion: nil)
                    }
                }
            })
        }
        
        let threadAction = UIAlertAction(title: NSLocalizedString("SPAM", comment: "Spam"), style: .default){ (action) in
            reportAction("广告/SPAM")
        }
        alert.addAction(threadAction)
        
        let trollAction = UIAlertAction(title: NSLocalizedString("TROLL", comment: "Troll"), style: .default){ (action) in
            reportAction("恶意灌水")
        }
        alert.addAction(trollAction)
        
        let illegalAction = UIAlertAction(title: NSLocalizedString("OFFENDING", comment: "Offending"), style: .default){ (action) in
            reportAction("内容不适当")
        }
        alert.addAction(illegalAction)
        
        let othersAction = UIAlertAction(title: NSLocalizedString("OTHERS", comment: "Others"), style: .default){ (action) in
            reportAction("其他")
        }
        alert.addAction(othersAction)
        
        
        present(alert, animated: true, completion: nil)
    }
    
    func replyByQuoteReplyOfID(_ replyID: String, time: String, authorName: String, replyContent: String) {
        if !checkLoginWithHint("登录以后才能回复帖子") {
            return
        }
        
        var trimmedContent = replyContent as NSString
        if trimmedContent.length > 200 {
            trimmedContent = trimmedContent.substring(to: 200) as NSString
        }
        
        var info = [String : AnyObject]()
        info["fid"] = self.threadData.fid as AnyObject?
        info["formhash"] = self.threadData.formhash as AnyObject?
        info["tid"] = self.threadData.tid as AnyObject?
        info["subject"] = self.threadData.subject as AnyObject?
        info["quote_id"] = replyID as AnyObject?
        info["quote_name"] = authorName as AnyObject?
        
        let repliedOnLocalized = NSLocalizedString("TEXT_REPLIED_ON", comment: "Replied on")
        
        let quoteContent = "[quote][size=2][url=forum.php?mod=redirect&goto=findpost&pid=\(replyID)&ptid=\(self.threadData.tid!)][color=#999999] \(authorName) \(repliedOnLocalized) \(time)[/color][/url][/size] \((trimmedContent as String)) [/quote]"
        info["quote_content_raw"] = quoteContent as AnyObject?

        info["quote_textcontent"] = replyContent as AnyObject?
        
        if #available(iOS 13.0, *) {
            if UIApplication.shared.supportsMultipleScenes && ((Account().preferenceForkey(.enable_multi_windows) as? Bool) ?? false) {
                let userActivity = NSUserActivity(activityType: SAActivityType.replyThread.rawValue)
                userActivity.isEligibleForHandoff = true
                userActivity.title = SAActivityType.replyThread.title()
                userActivity.userInfo = ["quoteInfo":info]
                let options = UIScene.ActivationRequestOptions()
                options.requestingScene = view.window?.windowScene
                UIApplication.shared.requestSceneSessionActivation(AppController.current.findSceneSession(), userActivity: userActivity, options: options) { (error) in
                    sa_log_v2("request new scene returned: %@", error.localizedDescription)
                }
                return
            }
        }
        
        let navi = UIStoryboard(name: "ReplyThread", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let reply = navi.topViewController! as! SAReplyViewController
        reply.config(quoteInfo: info)
        reply.delegate = self
        navi.modalPresentationStyle = .pageSheet
        present(navi, animated: true, completion: nil)
    }
    
    func reloadHTMLPlaceholderImageTag(fromURL: URL, toURL: URL) {
        assert(Thread.isMainThread)
        assert(toURL.scheme == sa_wk_url_scheme)
        let str = fromURL.absoluteString.sa_escapedStringForJavaScriptInput()
        let toParam = "\"\(toURL.absoluteString.sa_escapedStringForJavaScriptInput())\""
        sa_log_v2("from: %@ to: %@", module: .ui, type: .info, fromURL as CVarArg, toURL as CVarArg)
        webView.evaluateJavaScript("reloadHTMLImgTags(\"\(str)\", \(toParam));", completionHandler: nil)
    }
    
    func getSavedImageData(fromURL: URL) -> Data? {
        let fm = FileManager.default
        guard let dir = fileDirectoryURL else {
            return nil
        }
        
        let downloadedImageDir = dir.appendingPathComponent(imageSavingSubDirName)
        if !fm.fileExists(atPath: downloadedImageDir.path) {
            return nil
        }
        
        guard let base64Name = fromURL.absoluteString.data(using: .utf8)?.base64EncodedString().replacingOccurrences(of: "/", with: "") else {
            return nil
        }
        
        let filePath = downloadedImageDir.appendingPathComponent(base64Name)
        if !fm.fileExists(atPath: filePath.path) {
            return nil
        }
        
        let data = try? Data.init(contentsOf: filePath)
        return data
    }
}

// MARK: - Caching Images
extension SAThreadContentViewController: SAWKURLSchemeHandlerDelegate {
    
    // after downloading the image, tell page to reload img tag to which this image belongs.
    // if toURL is nil, mark this image loading failure
    func schemeHandlerRequestReloadHTMLPlaceholderImageTag(_ schemeHandler: SAWKURLSchemeHandler?, fromURL: URL, toURL: URL) {
        reloadHTMLPlaceholderImageTag(fromURL: fromURL, toURL: toURL)
    }
    
    // NOTE: methods below may be called from non-main thread!!!
    
    func schemeHandlerRequestSaveFileDataToDisk(_ schemeHandler: SAWKURLSchemeHandler?, data: Data, fromURL: URL) -> URL? {
        guard let dir = fileDirectoryURL else {
            return nil
        }
        let fm = FileManager.default
        let downloadedImageDir = dir.appendingPathComponent(imageSavingSubDirName)
        if !fm.fileExists(atPath: downloadedImageDir.path) {
            // maybe this page was removed
            sa_log_v2("will not save because dir not found", module: .ui, type: .error)
            return nil
        }
        
        let fileName = fromURL.lastPathComponent
        let filePath = downloadedImageDir.appendingPathComponent(fileName)
        let succeeded = fm.createFile(atPath: filePath.path, contents: data, attributes: nil)
        return succeeded ? filePath : nil
    }
    
    func getSavedFilePath(of aurl: URL) -> URL? {
        let fm = FileManager.default
        guard let dir = fileDirectoryURL else {
            return nil
        }
        
        let downloadedImageDir = dir.appendingPathComponent(imageSavingSubDirName)
        if !fm.fileExists(atPath: downloadedImageDir.path) {
            return nil
        }
        
        let fileName = aurl.lastPathComponent
        let filePath = downloadedImageDir.appendingPathComponent(fileName)
        if !fm.fileExists(atPath: filePath.path) {
            return nil
        }
        
        return filePath
    }
    
    func schemeHandlerRequestSaveImageDataToDisk(_ schemeHandler: SAWKURLSchemeHandler?, data: Data, fromURL: URL) -> URL? {
        guard let dir = fileDirectoryURL else {
            return nil
        }
        let fm = FileManager.default
        let downloadedImageDir = dir.appendingPathComponent(imageSavingSubDirName)
        if !fm.fileExists(atPath: downloadedImageDir.path) {
            // maybe this page was removed
            sa_log_v2("will not save because dir not found", module: .ui, type: .error)
            return nil
        }
        
        guard let base64Name = fromURL.absoluteString.data(using: .utf8)?.base64EncodedString().replacingOccurrences(of: "/", with: "") else {
            return nil
        }
        
        let filePath = downloadedImageDir.appendingPathComponent(base64Name)
        let succeeded = fm.createFile(atPath: filePath.path, contents: data, attributes: nil)
        return succeeded ? filePath : nil
    }
    
    func schemeHandlerRequestGetSavedImageData(_ schemeHandler: SAWKURLSchemeHandler?, fromURL: URL) -> Data? {
        return getSavedImageData(fromURL: fromURL)
    }
}

@available(iOS 13.0, *)
extension SAThreadContentViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        let actionProvider: ([UIMenuElement]) -> UIMenu? = { _ in
            let action0 = UIAction(title: "切换主题") { [weak self] _ in
                let doSwitch = { () in
                    Account().savePreferenceValue(false as AnyObject, forKey: .automatically_change_theme_to_match_system_appearance)
                    let themeManager = AppController.current.getService(of: SAThemeManager.self)!
                    themeManager.switchTheme()
                }
               
                let autoSwitchEnabled = (Account().preferenceForkey(.automatically_change_theme_to_match_system_appearance) as? Bool) ?? true
                if autoSwitchEnabled {
                    let alert = UIAlertController(title: "提示", message: "这将关闭自动跟随系统主题切换，改成手动切换模式，是否继续？", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))
                    alert.addAction(UIAlertAction(title: NSLocalizedString("继续", comment: "OK"), style: .destructive) { (action) in
                        doSwitch()
                    })
                    self?.present(alert, animated: true, completion: nil)
                    return
                }
                doSwitch()
            }
            
            let action1 = UIAction(title: "跳转分页") { [weak self] _ in
                self?.jumpBetweenPages()
            }
            
            let action2 = UIAction(title: "刷新") { [weak self] _ in
                self?.refreshPage()
            }
            
            let action3 = UIAction(title: "回复主贴") { [weak self] _ in
                self?.replyToMainThread()
            }
    
            return UIMenu(title: "Actions", image: nil, identifier: nil, children: [action0, action1, action2, action3])
        }

        // A context menu can have a `identifier`, a `previewProvider`,
        // and, finally, the `actionProvider that creates the menu
        return UIContextMenuConfiguration(identifier: nil,
                                         previewProvider: nil,
                                         actionProvider: actionProvider)
    }
    
    func setupContextMenuAction() {
        view.addInteraction(UIContextMenuInteraction(delegate: self))
    }
}
