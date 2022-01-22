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
    
    // used in font configuration VC
    private var isDummy: Bool = false
    private var dummyHTMLFileURL: URL?
    class func createDummyInstanceWithHTMLFileAt(url: URL) -> SAThreadContentViewController {
        let dummyURL = URL.init(string: "http://dummy?tid=0&fid=0&tid=0&page=0")!
        let viewController = SAThreadContentViewController.init(url: dummyURL)
        viewController.isDummy = true
        viewController.dummyHTMLFileURL = url
        return viewController
    }
        
    private var fileURL: URL!
    private var fileDirectoryURL: URL!
    private let imageSavingSubDirName = "images"
    private let bottomRefreshDraggingTriggerDistance = CGFloat(40)
    var enableBottomRefreshing = false

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
        
        automaticallyLoadsURL = false
        
        guard let _ = url?.sa_queryString("tid") else {
            fatalError("tid must be set.")
        }
        
        // this should be done early
        prepareDirectory()
        
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: nil) { [weak self] (notification) in
            self?.removeHTMLFiles()
        }
    }
    
    
    // the bridging js methods
    private func getThreadInfo(completion: @escaping((ThreadSummary?) -> Void)) {
        webView.evaluateJavaScript("threadInfo;") { (object, error) in
            guard error == nil else {
                sa_log_v2("webview javascript error: %@", type: .error, error!.localizedDescription)
                completion(nil)
                return
            }
            
            guard let thread = object as? [String:AnyObject] else {
                sa_log_v2("webview thread info bad", type: .error)
                completion(nil)
                return
            }
            
            var threadData = ThreadSummary(tid: thread["tid"] as? String ?? "",
                                           fid: thread["fid"] as? String ?? "",
                                           subject: thread["subject"] as? String ?? "",
                                           author: thread["author"] as? String ?? "",
                                           authorid: thread["authorid"] as? String ?? "",
                                           dbdateline: thread["dbdateline"] as? String ?? "",
                                           dblastpost: thread["dblastpost"] as? String ?? "",
                                           replies: Int((thread["replies"] as? String) ?? "0") ?? 0,
                                           views: Int(thread["views"] as! String)!, readperm: 0)
            threadData.formhash = thread["formhash"] as? String
            threadData.floor = thread["floor"] as? Int ?? 1
            completion(threadData)
        }
    }
    
    deinit {
        sa_log_v2("SAThreadContentViewController deinit", log: .ui, type: .debug)
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
        loadHTMLFile()
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
        if #available(iOS 13.0, *) {
            let loading = UIActivityIndicatorView(style: .medium)
            bottomRefreshStack.addArrangedSubview(loading)
        } else {
            // Fallback on earlier versions
            let loading = UIActivityIndicatorView(style: .gray)
            bottomRefreshStack.addArrangedSubview(loading)
        }
        let label = UILabel()
        bottomRefreshStack.addArrangedSubview(label)
        kvoContext = ""
        webView.scrollView.addObserver(self, forKeyPath: #keyPath(UIScrollView.contentSize), options: [.new], context: &kvoContext)
        #if !targetEnvironment(macCatalyst)
        bottomRefresherDidRefresh() // reset state
        #endif
        
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
                        sa_log_v2("this thread also exist in online favorite list", log: .ui, type: .info)
                    }
                    self?.loadHTMLFile()
                }
            }
        }
        
        setupContextMenuAction()
               
        if !isDummy {
            let moreItem: UIBarButtonItem = { [weak self] () in
                let menu = UIMenu(title: NSLocalizedString("THREAD_ACTION_CHOOSE", comment: "Please choose an action"), identifier: UIMenu.Identifier(SAToolbarItemIdentifierReply.rawValue), children: [
                    UIAction.init(title: "跳转分页", handler: { (action) in
                        self?.jumpTo(page: 0)
                    }),
                    UIAction.init(title: "跳到首页", image: UIImage(systemName: "backward"), handler: { (action) in
                        self?.jumpTo(page: -1)
                    }),
                    UIAction.init(title: "跳到末页", image: UIImage(systemName: "forward"), handler: { (action) in
                        self?.jumpTo(page: -2)
                    }),
                    UIAction.init(title: "刷新", image: UIImage(systemName: "arrow.clockwise"), handler: { (action) in
                        self?.loadHTMLFile()
                    }),
                    UIAction.init(title: "回复", image: UIImage(systemName: "arrowshape.turn.up.left"), handler: { (action) in
                        self?.replyToMainThread()
                    })
                ])
                return UIBarButtonItem(title: nil, image: UIImage(systemName: "arrowshape.turn.up.left"), primaryAction: nil, menu: menu)
            }()
            moreItem.isEnabled = false
            
            let shareItem: UIBarButtonItem = { () in
                var children: [UIAction] = [
                    UIAction.init(title: "分享", handler: { [weak self] (action) in
                        self?.showShareActivity(action)
                    }),
                    
                    UIAction.init(title: "查看桌面版页面", handler: { [weak self] (action) in
                        self?.openDesktopPage(action)
                    }),
                    
                    UIAction.init(title: "加入收藏夹", handler: { [weak self] (action) in
                        self?.favoriteThread(action)
                    }),
                ]
                
                if self.watchlingListRecordInDB == nil {
                    children.append(
                        UIAction.init(title: "加入观察列表", handler: { [weak self] (action) in
                            self?.addToWatchList(action)
                        })
                    )
                } else {
                    children.append(
                        UIAction.init(title: "移除出观察列表", handler: { [weak self] (action) in
                            self?.removeFromWatchingList(action)
                        })
                    )
                }
                let menu = UIMenu(title: NSLocalizedString("THREAD_ACTION_CHOOSE", comment: "Please choose an action"), identifier: UIMenu.Identifier(SAToolbarItemIdentifierShare.rawValue), children: children)
                return UIBarButtonItem(title: nil, image: UIImage(systemName: "square.and.arrow.up"), primaryAction: nil, menu: menu)
            }()
            shareItem.isEnabled = false
            
            let nightModeItem = UIBarButtonItem(title: nil, image: UIImage(systemName: "moon"), primaryAction: UIAction(handler: { action in
                self.handleNightModeButtonClick(action)
            }), menu: nil)
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
        guard let titlebar = view.window?.windowScene?.titlebar, let titleItems = titlebar.toolbar?.items else {
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
            
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierShare.rawValue {
                item.target = self
                item.action = #selector(share(_:))
            }
            
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierViewDeskTopPage.rawValue {
                item.target = self
                item.action = #selector(showDesktopPage(_:))
            }
            
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierScrollToComment.rawValue {
                item.target = self
                item.action = #selector(scrollToComment(_:))
            }
            
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierReply.rawValue {
                item.target = self
                item.action = #selector(reply(_:))
            }
            
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierRefresh.rawValue {
                item.target = self
                item.action = #selector(refresh(_:))
            }
            
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierFavorite.rawValue {
                item.target = self
                item.action = #selector(toggleFavorite(_:))
            }
            
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierAddToWatchList.rawValue {
                item.target = self
                item.action = #selector(toggleWatchList(_:))
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
    
    override func viewWillResignActive() {
        super.viewWillResignActive()
        if isViewVisible {
            if loadingController.state == .finished {
                recordThreadViewHistory()
                updateWatchingListDB(createIfNotExist: false)
            }
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
    }
    
    @objc func refresh(_ sender: AnyObject) {
        loadDB { [weak self] in
            if self?.favoriteRecordInDB != nil {
                sa_log_v2("this thread also exist in online favorite list", log: .ui, type: .info)
            }
            self?.loadHTMLFile()
        }
    }
    
    @objc func toggleFavorite(_ sender: AnyObject) {
        self.favoriteThread(sender)
    }
    
    @objc func toggleWatchList(_ sender: AnyObject) {
        if self.watchlingListRecordInDB == nil {
            self.addToWatchList(sender)
        } else {
            self.removeFromWatchingList(sender)
        }
    }
    
    @objc func reply(_ sender: AnyObject) {
        self.replyToMainThread()
    }
    
    @objc func showDesktopPage(_ sender: AnyObject) {
        self.openDesktopPage(sender)
    }
    
    @objc func share(_ sender: AnyObject) {
        self.showShareActivity(sender)
    }
    
    @objc func scrollToComment(_ sender: AnyObject) {
        self.jumpTo(page: 0)
    }
    
    override func viewFontDidChange(_ newTheme: SATheme) {
        super.viewFontDidChange(newTheme)
        reloadPage()
    }
    
    func reloadPage() {
        guard let _ = webView.url else {
            sa_log_v2("no url was loaded", log: .ui, type: .info)
            return
        }
        
        if webView.isLoading {
            sa_log_v2("is loading, run later", log: .ui, type: .info)
            let handler: ValueChangeHandler = ("loading", { (webView) in
                webView.evaluateJavaScript("reloadCSS();") { (obj, error) in
                    sa_log_v2("reloadPage", log: .ui, type: .info)
                }
            })
            webviewKeyValueChangeRunOnceHandlers.append(handler)
        } else {
            sa_log_v2("not loading, run immediately", log: .ui, type: .info)
            webView.evaluateJavaScript("reloadCSS();") { (obj, error) in
                sa_log_v2("reloadPage", log: .ui, type: .info)
            }
        }
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
        config.userContentController.addScriptMessageHandler(SAScriptThreadLoadMoreDataHandler(viewController: self), contentWorld: WKContentWorld.page, name: "threadloadmore")
        config.userContentController.addScriptMessageHandler(SAScriptThreadPollHandler(viewController: self), contentWorld: WKContentWorld.page, name: "threadpoll")
        config.userContentController.add(SAScriptThreadActionHandler(viewController: self), name: "threadaction")
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
        guard let tid = self.url?.sa_queryString("tid") else {
            sa_log_v2("save viewedthread tid is nil, not saved", log: .ui, type: .debug)
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
    
    // MARK: record history
    fileprivate func recordThreadViewHistory() {
        getThreadInfo { (threadData) in
            guard let threadData = threadData else { return }
        
            guard !threadData.fid.isEmpty && !threadData.tid.isEmpty else {
                sa_log_v2("save viewedthread fid is nil or tid is nil, not saved", log: .ui, type: .debug)
                return
            }
            
            let uid = Account().uid
            guard !uid.isEmpty else {
                return
            }
            
            let floor = threadData.floor
            guard floor > 0 else {return}
            
            sa_log_v2("record ThreadViewHistory floor: %@", log: .ui, type: .debug, NSNumber(value: floor))
            
            // because coredata saving could be in background thread
            let webviewYOffset = Float(self.webView!.scrollView.contentOffset.y)
            let lower = threadData.floor // TODO: get floor
            let replies = threadData.replies
            let subject = threadData.subject
            let author = threadData.author
            let authorID = threadData.authorid
            let tid = threadData.tid
            let fid = threadData.fid
            
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
                sa_log_v2("save viewedthread", log: .ui, type: .debug)
                
                if !tid.isEmpty {
                    AppController.current.getService(of: SACoreDataManager.self)!.cache?.viewedThreadIDs.append(tid)
                }
            }
        }
    }
    
    private func prepareDirectory() {
        let fm = FileManager.default
        let timeinterval = CFAbsoluteTimeGetCurrent()
        guard let tid = self.url?.sa_queryString("tid") else {
            sa_log_v2("prepareDirectory tid is nil", log: .ui, type: .debug)
            return
        }
        
        let htmlFileDirectory = AppController.current.threadHtmlFileDirectory.appendingPathComponent("\(timeinterval)_" + tid, isDirectory: true).path
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
            htmlFileDirectory + "/mahjong_placeholder.png" : Bundle.main.path(forResource: "mahjong_placeholder", ofType: "png")!,
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
        
        var htmlTemplateContent = try! String(contentsOfFile: Bundle.main.path(forResource: "thread_view_template", ofType: "html")!)
        htmlTemplateContent = htmlTemplateContent.replacingOccurrences(of: "${AVATAR_PLACEHOLDER_BASE64}", with: "noavatar_middle.png")
        htmlTemplateContent = htmlTemplateContent.replacingOccurrences(of: "${CSS_FILE_TIMESTAMP}", with: "\(Int(Date().timeIntervalSince1970 * 1000))")
        htmlTemplateContent = htmlTemplateContent.replacingOccurrences(of: "${REPLIES_PER_PAGE}", with: "\(SAGlobalConfig().number_of_replies_per_page)")
        try? htmlTemplateContent.write(toFile: htmlFilePath, atomically: false, encoding: .utf8)
        
        // update css template
        let cssFilePath = Bundle.main.path(forResource: "base", ofType: "css")
        var css = try! String(contentsOfFile: cssFilePath!)
        
        // font and color
        let activeTheme = Theme()
        let darkTheme = SATheme.darkTheme
        let whiteTheme = SATheme.whiteTheme

        let avatarSize = ceil(UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body).pointSize * 2 + 8)
        let showsAvatar = Account().preferenceForkey(SAAccount.Preference.thread_view_shows_avatar) as! Bool
        css = css.replacingOccurrences(of: "${avatar-display-style}", with: showsAvatar ? "block":"none")
        css = css.replacingOccurrences(of: "${avatar-image-size}", with: "\(avatarSize)px")
        css = css.replacingOccurrences(of: "${normal-font-size}", with: String(describing: floor(UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body).pointSize/96 * 72)) + "pt")
        css = css.replacingOccurrences(of: "${small-font-size}", with: String(describing: floor(UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.subheadline).pointSize/96 * 72)) + "pt")

        // adapt icon color
        if activeTheme.colorScheme == 0 {
            css = css.replacingOccurrences(of: "${icon-invert-percent}", with: "50%")
        } else {
            css = css.replacingOccurrences(of: "${icon-invert-percent}", with: "100%")
        }

        css = css.replacingOccurrences(of: "${thread-title-font-size}", with: String(describing: floor(UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline).pointSize/96 * 72)) + "pt")
  
        #if targetEnvironment(macCatalyst)
            css = css.replacingOccurrences(of: "${ipad-body-style}", with: "margin:0 auto;\n    max-width: \(SAContentViewControllerReadableAreaMaxWidth)px;")
            css = css.replacingOccurrences(of: "${img-max-width}", with: "\(SAContentViewControllerReadableAreaMaxWidth * 2/3)px")
        #else
            css = css.replacingOccurrences(of: "${ipad-body-style}", with: "")
            if UIDevice.current.userInterfaceIdiom == .pad {
                css = css.replacingOccurrences(of: "${img-max-width}", with: "300px")
            } else {
                css = css.replacingOccurrences(of: "${img-max-width}", with: "100%")
            }
        #endif
        
        // light theme
        css = css.replacingOccurrences(of: "${background-color}", with: (whiteTheme.backgroundColor))
        css = css.replacingOccurrences(of: "${foreground-color}", with: (whiteTheme.foregroundColor))
        css = css.replacingOccurrences(of: "${thread-title-color}", with: (whiteTheme.tableHeaderTextColor))
        css = css.replacingOccurrences(of: "${text-color}", with: (whiteTheme.textColor))
        css = css.replacingOccurrences(of: "${link-color}", with: (whiteTheme.htmlLinkColor))
        css = css.replacingOccurrences(of: "${header-background-color}", with: (whiteTheme.tableCellHighlightColor))
        css = css.replacingOccurrences(of: "${block-quote-text-color}", with: (whiteTheme.tableCellGrayedTextColor))
        css = css.replacingOccurrences(of: "${block-quote-background-color}", with: (whiteTheme.htmlBlockQuoteBackgroundColor))
        css = css.replacingOccurrences(of: "${table-cell-seperator-color}", with: UIColor.separator.sa_toHtmlCssColorFunction())
        
        // dark theme
        css = css.replacingOccurrences(of: "${background-color-dark}", with: (darkTheme.backgroundColor))
        css = css.replacingOccurrences(of: "${foreground-color-dark}", with: (darkTheme.foregroundColor))
        css = css.replacingOccurrences(of: "${thread-title-color-dark}", with: (darkTheme.tableHeaderTextColor))
        css = css.replacingOccurrences(of: "${text-color-dark}", with: (darkTheme.textColor))
        css = css.replacingOccurrences(of: "${link-color-dark}", with: (darkTheme.htmlLinkColor))
        css = css.replacingOccurrences(of: "${header-background-color-dark}", with: (darkTheme.tableCellHighlightColor))
        css = css.replacingOccurrences(of: "${block-quote-text-color-dark}", with: (darkTheme.tableCellGrayedTextColor))
        css = css.replacingOccurrences(of: "${block-quote-background-color-dark}", with: (darkTheme.htmlBlockQuoteBackgroundColor))
        css = css.replacingOccurrences(of: "${table-cell-seperator-color-dark}", with: UIColor.separator.sa_toHtmlCssColorFunction())
        
        if #available(iOS 13.0, *) {
            css = css.replacingOccurrences(of: "${table-cell-seperator-color-dark}", with: UIColor.separator.sa_toHtmlCssColorFunction())
        } else {
            css = css.replacingOccurrences(of: "${table-cell-seperator-color-dark}", with: darkTheme.tableCellSeperatorColor.sa_toColor().sa_toHtmlCssColorFunction())
        }
        css = css.replacingOccurrences(of: "${table-cell-grayed-text-color-dark}", with: (darkTheme.tableCellGrayedTextColor))
        
        try? FileManager.default.removeItem(atPath: htmlFileDirectory.appending("/base.css"))
        FileManager.default.createFile(atPath: htmlFileDirectory.appending("/base.css"), contents: css.data(using: String.Encoding.utf8), attributes: nil)

        self.fileURL = Foundation.URL.init(fileURLWithPath: htmlFilePath)
        self.fileDirectoryURL = Foundation.URL.init(fileURLWithPath: htmlFileDirectory)
    }
    
    private func loadDummyHTMLFile() {
        let content = try! String.init(contentsOf: dummyHTMLFileURL!)
        do {
            try content.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            sa_log_v2("write html to file failed error: %@", log: .ui, type: .error, error as CVarArg)
            return
        }
        _ = self.webView?.loadFileURL(fileURL, allowingReadAccessTo: fileDirectoryURL)
    }
    
    private func loadHTMLFile() {
        let url = fileURL!.sa_urlByReplacingQuery("floor", value: "\(historyRecordInDB?.lastviewfloor?.intValue ?? 1)").sa_urlByReplacingQuery("tid", value: self.url!.sa_queryString("tid")!)
        _ = self.webView?.loadFileURL(url, allowingReadAccessTo: fileDirectoryURL)
    }
    
    private func loadHTMLFilesAt(floor: Int) {
        let url = fileURL!.sa_urlByReplacingQuery("floor", value: "\(floor)").sa_urlByReplacingQuery("tid", value: self.url!.sa_queryString("tid")!)
        _ = self.webView?.loadFileURL(url, allowingReadAccessTo: fileDirectoryURL)
    }
    
    private func scrollWebPageTo(floor: Int, completion: (() -> Void)?) {
        self.webView?.evaluateJavaScript("scrollToFloor('\(floor)')", completionHandler: { (result, error) in
            if error != nil {
                sa_log_v2("error when scroll to last postition: %@", log: .ui, type: .debug, error! as NSError)
            }
            completion?()
        })
    }
    
    private func removeHTMLFiles() {
        try? FileManager.default.removeItem(at: fileDirectoryURL)
    }
    
    override func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if isDummy { return }
        self.loadingController.setFinished()
        self.navigationItem.rightBarButtonItems?.forEach({ (item) in
            item.isEnabled = true
        })
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
        
        guard let tid = self.url?.sa_queryString("tid") else {
            sa_log_v2("save viewedthread tid is nil, not saved", log: .ui, type: .debug)
            return
        }
        
        if let pid = url.sa_queryString("pid"), let ptid = url.sa_queryString("ptid"), ptid == tid {
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
        refresh(self)
    }
    
    func openDesktopPage(_ sender: AnyObject) {
        let tid = self.url!.sa_queryString("tid")!
        let link = SAGlobalConfig().forum_base_url + "thread-\(tid)-1-1.html"
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
    #if !targetEnvironment(macCatalyst)
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
        
        if !enableBottomRefreshing {
            return
        }
        bottomRefreshContainerView.isHidden = false
        let offset =  webView.scrollView.contentOffset.y + webView.scrollView.frame.size.height - webView.scrollView.contentSize.height - webView.scrollView.adjustedContentInset.bottom
        if offset > bottomRefreshContainerView.frame.size.height + bottomRefreshDraggingTriggerDistance {
            bottomRefresherIsRefreshing()
            doBottomRefreshing()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isDragging else {
            return
        }
        
        if !enableBottomRefreshing {
            return
        }
        
        bottomRefreshContainerView.isHidden = false
        let offset =  webView.scrollView.contentOffset.y + webView.scrollView.frame.size.height - webView.scrollView.contentSize.height - webView.scrollView.adjustedContentInset.bottom
        if offset > bottomRefreshContainerView.frame.size.height + bottomRefreshDraggingTriggerDistance {
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
        
        getThreadInfo { (threadInfo) in
            guard let threadInfo = threadInfo else { return }
            let tid = threadInfo.tid
            let page = threadInfo.floor / SAGlobalConfig().number_of_replies_per_page + 1
            
            self.urlSession.getTopicContent(of: tid, page: page) { [weak self] (result, error) in
                guard let self = self else {
                    return
                }
                
                guard error == nil,
                    let resultDict = result as? [String:AnyObject],
                    let variables = resultDict["Variables"] as? [String:Any],
                    let _ = variables["ppp"] as? String,
                    let thread = variables["thread"] as? [String:AnyObject],
                    let replyCount = thread["replies"] as? String,
                    let postlist = variables["postlist"] as? [[String:AnyObject]] else {
                        self.bottomRefresherDidRefresh()
                        return
                }
                
                var newPostList: [[String:AnyObject]] = []
                postlist.forEach { (reply) in
                    guard let floorNumber = Int(reply["number"] as! String) else {
                        return
                    }
                    if floorNumber > threadInfo.floor {
                        newPostList.append(reply)
                    }
                }
                
                guard !newPostList.isEmpty else {
                    let newReplyCount = Int(replyCount)!
                    if newReplyCount > threadInfo.replies {
                        self.doBottomRefreshing() // recursive
                        sa_log_v2("recursive bottom refreshing", log: .ui, type: .info)
                        return
                    }
                    
                    self.bottomRefresherDidRefresh()
                    return
                }
                
                SAThreadHTMLComposer.appendTail(threadInfo: thread, postList: newPostList, completion: { (content, parseError) in
                    guard !content.isEmpty else {
                        self.bottomRefresherDidRefresh()
                        return
                    }
                    let script = "appendPostListContent(\"\(content.sa_escapedStringForJavaScriptInput())\");"
                    self.webView?.evaluateJavaScript(script, completionHandler: { [weak self] (result, error) in
                        if error == nil {
                            sa_log_v2("append postlist ok", log: .ui, type: .info)
                        } else  {
                            sa_log_v2("append postlist error", log: .ui, type: .info)
                        }
                        self?.bottomRefresherDidRefresh()
                    })
                })
            }
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
    #endif
    
    override func loadingControllerDidRetry(_ controller: SALoadingViewController) {
        super.loadingControllerDidRetry(controller)
        loadHTMLFile()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func showShareActivity(_ sender: AnyObject) {
        sa_log_v2("clicked share button", log: .ui, type: .debug)
        let shareBarItem = navigationItem.rightBarButtonItems?.first
        getThreadInfo { (threadData) in
            guard let threadData = threadData else { return }
            let tid = threadData.tid
            let floor = threadData.floor/SAGlobalConfig().number_of_replies_per_page + 1
            
            let url = Foundation.URL(string: SAGlobalConfig().forum_base_url + "thread-\(tid)-\(floor)-1.html")!

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
            
            #if targetEnvironment(macCatalyst)
            activityController.popoverPresentationController?.sourceView = self.view
            activityController.popoverPresentationController?.sourceRect = CGRect(x: self.view.frame.size.width - 60, y: self.view.safeAreaInsets.top, width: 1, height: 1)
            #else
            activityController.popoverPresentationController?.barButtonItem = shareBarItem
            #endif
            self.present(activityController, animated: true, completion: nil)
        }
    }
    
    func replyToMainThread() {
        if !self.checkLoginWithHint("登录以后才能回复帖子") {
            return
        }
        
        getThreadInfo { (threadData) in
            guard let threadData = threadData else { return }
        
            var info = [String : AnyObject]()
            info["fid"] = threadData.fid as AnyObject?
            info["tid"] =  threadData.tid as AnyObject?
            info["formhash"] = threadData.formhash as AnyObject?
            info["subject"] = threadData.subject as AnyObject?
            info["quote_textcontent"] = threadData.subject as AnyObject?
            info["author"] = threadData.author as AnyObject?
            
            if #available(iOS 13.0, *) {
                if UIApplication.shared.supportsMultipleScenes && ((Account().preferenceForkey(.enable_multi_windows) as? Bool) ?? false) {
                    let userActivity = NSUserActivity(activityType: SAActivityType.replyThread.rawValue)
                    userActivity.isEligibleForHandoff = true
                    userActivity.title = SAActivityType.replyThread.title()
                    userActivity.userInfo = ["quoteInfo":info]
                    let options = UIScene.ActivationRequestOptions()
                    options.requestingScene = self.view.window?.windowScene
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
    
    private func favoriteThread(_ sender: AnyObject) {
        if !checkLoginWithHint("登录以后才能收藏帖子") {
            return
        }
        
        getThreadInfo { (threadData) in
            guard let threadData = threadData else { return }
            
            let tid = threadData.tid
            guard !tid.isEmpty, let formhash = threadData.formhash else {
                return
            }
            
            let activity = SAModalActivityViewController()
            self.present(activity, animated: true, completion: nil)
            
            self.urlSession.favorite(thread: tid, formhash: formhash) { (object, error) in
                activity.hideAndShowResult(of: true, info: "已收藏") { () in
                    let viewController = self.navigationController!.presentingViewController
                    viewController?.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
    
    private func addToWatchList(_ sender: AnyObject) {
        if !checkLoginWithHint("登录以后才能将帖子加入观察列表") {
            return
        }
        
        let addWatchingListAction = { () in
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
        getThreadInfo { (threadData) in
            guard let threadData = threadData else { return }
        
            let uid = Account().uid
            let fid = threadData.fid
            let tid = threadData.tid
            let replyCount = threadData.replies
            let subject = threadData.subject
            let author = threadData.author
            let authorid = threadData.authorid
            let currentPageLower = threadData.floor // TODO: floor
            
            if let obj = self.watchlingListRecordInDB {
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
    }
    
    func removeFromWatchingList(_ sender: AnyObject) {
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
    
    @objc func handleNightModeButtonClick(_ sender: UIAction) {
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
    
    /// Jump between pages
    /// - Parameter page: 0: select jump page number -1: jump to first page, -2: jump to last page
    func jumpTo(page: Int) {
        getThreadInfo { [weak self] (threadData) in
            guard let threadData = threadData else { return }
            let replies = threadData.replies
            let nowfloor = max(1, threadData.floor - 1)

            let totalPages = Int(ceil(Double(replies)/Double(SAGlobalConfig().number_of_replies_per_page)))
            let currentPage = Int(ceil(Double(nowfloor)/Double(SAGlobalConfig().number_of_replies_per_page)))
            
            if page == -1 {
                self?.loadHTMLFilesAt(floor: 0)
                return
            }
            
            if page == -2 {
                let nowfloor = (totalPages - 1) * SAGlobalConfig().number_of_replies_per_page + 1
                self?.loadHTMLFilesAt(floor: nowfloor)
                return
            }

            let alert = UIAlertController(title: "输入页码：", message: nil, preferredStyle: .alert)
            alert.popoverPresentationController?.barButtonItem = self?.navigationItem.rightBarButtonItem
            let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil)
            alert.addAction(cancelAction)

            let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default){ (action) in
                let textField = alert.textFields![0]
                guard textField.text != nil else {
                    return
                }
                guard var page = Int(textField.text!) else {
                    return
                }
                page = min(totalPages, max(0, page))
                
                let nowfloor = (page - 1) * SAGlobalConfig().number_of_replies_per_page + 1
                self?.loadHTMLFilesAt(floor: nowfloor)
            }
            alert.addAction(okAction)

            alert.addTextField { (textField) in
                textField.text = String.init(format: "%d", currentPage)
                textField.keyboardType = .numberPad
                textField.keyboardAppearance = Theme().keyboardAppearence
                
                let pageLabel = UILabel()
                pageLabel.font = textField.font
                pageLabel.textColor = Theme().tableCellGrayedTextColor.sa_toColor()
                pageLabel.text = "/共\(totalPages)页"
                pageLabel.sizeToFit()
                textField.rightView = pageLabel
                textField.rightViewMode = .always
            }
            
            self?.present(alert, animated: true, completion: nil)
        }
    }
}

// MARK: - SAReplyViewControllerDelegate
extension SAThreadContentViewController {
    func replyDidSucceed(_ replyViewController: SAReplyViewController) {
        loadHTMLFile()
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
            self.getThreadInfo { (threadData) in
                guard let threadData = threadData else { return }
                self.urlSession.reportAbuse(of: threadData.fid, tid: threadData.tid, rid: rid, reason: "广告/SPAM", formhash: threadData.formhash!, completion: { (obj, error) in
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
        
        getThreadInfo { (threadData) in
            guard let threadData = threadData else { return }
        
            var trimmedContent = replyContent as NSString
            if trimmedContent.length > 200 {
                trimmedContent = trimmedContent.substring(to: 200) as NSString
            }
            
            var info = [String : AnyObject]()
            info["fid"] = threadData.fid as AnyObject?
            info["formhash"] = threadData.formhash as AnyObject?
            info["tid"] = threadData.tid as AnyObject?
            info["subject"] = threadData.subject as AnyObject?
            info["quote_id"] = replyID as AnyObject?
            info["quote_name"] = authorName as AnyObject?
            
            let repliedOnLocalized = NSLocalizedString("TEXT_REPLIED_ON", comment: "Replied on")
            
            let quoteContent = "[quote][size=2][url=forum.php?mod=redirect&goto=findpost&pid=\(replyID)&ptid=\(threadData.tid)][color=#999999] \(authorName) \(repliedOnLocalized) \(time)[/color][/url][/size] \((trimmedContent as String)) [/quote]"
            info["quote_content_raw"] = quoteContent as AnyObject?

            info["quote_textcontent"] = replyContent as AnyObject?
            
            if #available(iOS 13.0, *) {
                if UIApplication.shared.supportsMultipleScenes && ((Account().preferenceForkey(.enable_multi_windows) as? Bool) ?? false) {
                    let userActivity = NSUserActivity(activityType: SAActivityType.replyThread.rawValue)
                    userActivity.isEligibleForHandoff = true
                    userActivity.title = SAActivityType.replyThread.title()
                    userActivity.userInfo = ["quoteInfo":info]
                    let options = UIScene.ActivationRequestOptions()
                    options.requestingScene = self.view.window?.windowScene
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
            self.present(navi, animated: true, completion: nil)
        }
    }
    
    func reloadHTMLPlaceholderImageTag(fromURL: URL, toURL: URL) {
        assert(Thread.isMainThread)
        assert(toURL.scheme == sa_wk_url_scheme)
        let str = fromURL.absoluteString.sa_escapedStringForJavaScriptInput()
        let toParam = "\"\(toURL.absoluteString.sa_escapedStringForJavaScriptInput())\""
        sa_log_v2("from: %@ to: %@", log: .ui, type: .info, fromURL as CVarArg, toURL as CVarArg)
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
    
    func getSavedImageFileUrl(fromURL: URL) -> URL? {
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
        
        return filePath
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
            sa_log_v2("will not save because dir not found", log: .ui, type: .error)
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
            sa_log_v2("will not save because dir not found", log: .ui, type: .error)
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
        if UIDevice.current.userInterfaceIdiom != .mac {
            return nil
        }
        
        // A context menu can have a `identifier`, a `previewProvider`,
        // and, finally, the `actionProvider that creates the menu
        let actionProviderMac: ([UIMenuElement]) -> UIMenu? = { _ in
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
                self?.jumpTo(page: 0)
            }
            
            let action2 = UIAction(title: "刷新") { [weak self] _ in
                self?.loadHTMLFile()
            }
            
            let action3 = UIAction(title: "回复主贴") { [weak self] _ in
                self?.replyToMainThread()
            }
    
            return UIMenu(title: NSLocalizedString("CONTEXT_MENU_TITLE", comment: "Shortcuts"), image: nil, identifier: nil, children: [action0, action1, action2, action3])
        }
        return UIContextMenuConfiguration(identifier: nil,
                                         previewProvider: nil,
                                         actionProvider: actionProviderMac)
    }
    
    func setupContextMenuAction() {
        view.addInteraction(UIContextMenuInteraction(delegate: self))
    }
}
