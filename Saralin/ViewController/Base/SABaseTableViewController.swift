//
//  SABaseTableViewController.swift
//  Saralin
//
//  Created by zhang on 12/5/15.
//  Copyright © 2015 zaczh. All rights reserved.
//

import UIKit
import CoreData

class SABaseTableViewController: SABaseViewController, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, UITableViewDataSourcePrefetching, UISearchBarDelegate {
    var showsSearchItem: Bool {return false}
    var showsRefreshControl: Bool {return true}
    #if !targetEnvironment(macCatalyst)
    var refreshControl: UIRefreshControl?
    #endif
    var tableView: UITableView!
    
    var showsBottomRefreshView: Bool {return false}
    let tableFooterHeight: CGFloat = 80
    private var tableContentOffset: CGPoint?
    
    /// When significant time changed, we need to refresh the table view.
    private(set) var shouldRefreshTableWhenNextTimeViewAppear = false
    
    lazy var bottomRefreshView: BottomRefreshView = {
        let view = BottomRefreshView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: tableFooterHeight))
        view.tapHandler = { [weak self] () in
            guard let strongSelf = self else {return}
            
            if strongSelf.isFetchingMoreFailed && !strongSelf.isFetchingMoreThreads {
                strongSelf.doFetchingMore()
            }
        }
        return view
    }()
    
    func createSearchController() -> SASearchController {
        let searchController = SASearchController()
        searchController.searchBar.placeholder = NSLocalizedString("SEARCH_BAR_PLACEHOLDER_SEARCH_FORUM_THREADS", comment: "Search Forum Threads")
        return searchController
    }
    
    var isFetchingMoreThreads: Bool = false
    var fetchingMoreAction: ((SABaseTableViewController) -> Void)?
    var isFetchingMoreNoMoreData: Bool = false
    var isFetchingMoreFailed: Bool = false
    
    // This is used to checking if data is new
    var lastTimeReloadingDate: Date?
    
    // This is used to updating refresh title
    var thisTimeReloadingDate: Date? {
        didSet {
            #if !targetEnvironment(macCatalyst)
            if thisTimeReloadingDate == nil { return }
            let attributes = [NSAttributedString.Key.font:UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body), NSAttributedString.Key.foregroundColor:UIColor.sa_colorFromHexString(Theme().textColor)]
            refreshControl?.attributedTitle = NSAttributedString(string: "上次刷新时间：\(thisTimeReloadingDate!.sa_prettyDate())", attributes: attributes)
            #endif
        }
    }
    
    // MARK: - restoration
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(lastTimeReloadingDate, forKey: "lastTimeReloadingDate")
        coder.encode(isFetchingMoreNoMoreData, forKey: "isFetchingMoreNoMoreData")
        coder.encode(isFetchingMoreFailed, forKey: "isFetchingMoreFailed")
        coder.encode(thisTimeReloadingDate, forKey: "thisTimeReloadingDate")
        if let _ = tableView {
            #if !targetEnvironment(macCatalyst)
            coder.encode(tableView.contentOffset, forKey: "tableContentOffset")
            #endif
        }
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        lastTimeReloadingDate = coder.decodeObject(forKey: "lastTimeReloadingDate") as? Date
        isFetchingMoreNoMoreData = coder.decodeBool(forKey: "isFetchingMoreNoMoreData")
        isFetchingMoreFailed = coder.decodeBool(forKey: "isFetchingMoreFailed")
        thisTimeReloadingDate = coder.decodeObject(forKey: "thisTimeReloadingDate") as? Date
        tableContentOffset = coder.decodeCGPoint(forKey: "tableContentOffset")
        if let _ = tableView {
            #if !targetEnvironment(macCatalyst)
            tableView.contentOffset = tableContentOffset ?? CGPoint.zero
            #endif
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView = getTableView()
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 100
        if #available(iOS 10.0, *) {
            tableView.prefetchDataSource = self
        } else {
            // Fallback on earlier versions
        }
        view.insertSubview(tableView, at: 0)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        
        #if !targetEnvironment(macCatalyst)
        if showsRefreshControl {
            refreshControl = UIRefreshControl()
            if #available(iOS 10.0, *) {
                tableView.refreshControl = refreshControl
            } else {
                tableView.addSubview(refreshControl!) // This is a trick.
            }
            refreshControl!.addTarget(self, action: #selector(SABaseTableViewController.handleRefreshControlValueChanged(_:)), for: .valueChanged)
        }
        #endif
        
        if showsBottomRefreshView {
            tableView.tableFooterView = bottomRefreshView
            tableView.tableFooterView?.isHidden = true
        } else {
            tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 40))
        }
        
        #if !targetEnvironment(macCatalyst)
        if showsSearchItem {
            let searchBar = UISearchBar(frame: CGRect(x: 0, y: 0, width: 1, height: 0))
            searchBar.sizeToFit()
            searchBar.searchBarStyle = .minimal
            searchBar.delegate = self
            searchBar.placeholder = NSLocalizedString("SEARCH_BAR_PLACEHOLDER_SEARCH_FORUM_THREADS", comment: "Search Forum Threads")
            tableView.tableHeaderView = searchBar
        }
        #endif
        
        NotificationCenter.default.addObserver(self, selector: #selector(SABaseTableViewController.handleGetUserLoginNotification(_:)), name: Notification.Name.SAUserLoggedInNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SABaseTableViewController.handleGetUserLogoutNotification(_:)), name: Notification.Name.SAUserLoggedOutNotification, object: nil)
        
        _ = NotificationCenter.default.addObserver(forName: UIApplication.significantTimeChangeNotification, object: nil, queue: nil, using: { [weak self] (notification) in
            os_log("significantTimeChangeNotification", log: .ui, type: .info)
            self?.shouldRefreshTableWhenNextTimeViewAppear = true
        })
    }
    
    
    // MARK: search
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        let searchController = createSearchController()
        navigationController?.pushViewController(searchController, animated: false)
        return false
    }
    
    func reloadData() {
        tableView.reloadData()
        DispatchQueue.main.async {
            let sections = self.tableView.numberOfSections
            var rows = Int(0)
            for i in 0 ..< sections {
                rows = rows + self.tableView.numberOfRows(inSection: i)
            }
            
            if rows == 0 {
                self.loadingController.setEmpty()
            } else {
                self.loadingController.setFinished()
            }
        }
    }
    
    func cleanUpAndReloadData() {
        cleanUpBeforeReload()
        reloadData()
    }
    
    open func getTableView() -> UITableView {
        if #available(iOS 13.0, *) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                return UITableView(frame: CGRect.zero, style: .insetGrouped)
            } else {
                return UITableView(frame: CGRect.zero, style: .grouped)
            }
        } else {
            // Fallback on earlier versions
            return UITableView(frame: CGRect.zero, style: .grouped)
        }
    }
    
    open func cleanUpBeforeReload() {
        // Avoid `pull-down` refresh and `drag-up` refresh conflicting
        fetchingMoreAction = nil
        isFetchingMoreThreads = false
        isFetchingMoreNoMoreData = false
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        
        if let searchBar = tableView.tableHeaderView as? UISearchBar {
            searchBar.barTintColor = newTheme.foregroundColor.sa_toColor()
            searchBar.barStyle = newTheme.toolBarStyle
            searchBar.backgroundColor = newTheme.foregroundColor.sa_toColor()
        }
        
        tableView.backgroundColor = newTheme.backgroundColor.sa_toColor()
        tableView.separatorColor = UIColor.sa_colorFromHexString(newTheme.tableCellSeperatorColor)
        tableView.tintColor = UIColor.sa_colorFromHexString(newTheme.globalTintColor)
        #if !targetEnvironment(macCatalyst)
        refreshControl?.tintColor = UIColor.sa_colorFromHexString(newTheme.textColor)
        #endif
        
        bottomRefreshView.loadingLabel.textColor = UIColor.sa_colorFromHexString(newTheme.textColor)
        bottomRefreshView.loadingView.style = newTheme.activityIndicatorStyle
        bottomRefreshView.loadingView.color = UIColor.sa_colorFromHexString(newTheme.textColor)
        tableView.reloadData()
    }
    
    override func viewFontDidChange(_ newTheme: SATheme) {
        super.viewFontDidChange(newTheme)
        assert(isViewLoaded, "view must be loaded")
        bottomRefreshView.loadingLabel.font = UIFont.sa_preferredFont(forTextStyle: .body)
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: animated)
        }
    }
    
    private func refreshTableWhenAppearIfNeeded() {
        if !shouldRefreshTableWhenNextTimeViewAppear {
            return
        }
        
        shouldRefreshTableWhenNextTimeViewAppear = false
        
        if !showsRefreshControl {
            return
        }
        
        let refreshIndicator = UIActivityIndicatorView(style: Theme().activityIndicatorStyle)
        refreshIndicator.startAnimating()
        let refreshTitle = UILabel()
        if #available(iOS 13.0, *) {
            if let font = navigationController?.navigationBar.standardAppearance.titleTextAttributes[.font] as? UIFont {
                refreshTitle.font = font
            }
        } else {
            // Fallback on earlier versions
            if let font = navigationController?.navigationBar.titleTextAttributes?[.font] as? UIFont {
                refreshTitle.font = font
            }
        }
        refreshTitle.textColor = Theme().textColor.sa_toColor()
        refreshTitle.text = NSLocalizedString("REFRESHING_TITLE", comment: "Refreshing...")
        let stack = UIStackView(arrangedSubviews: [refreshIndicator, refreshTitle])
        stack.spacing = 10
        
        let restoreNavigationTitleView = navigationItem.titleView
        let restoreNavigationTitle = navigationItem.title
        let restoreTitle = title
        navigationItem.titleView = stack
        
        tableView.refreshControl?.beginRefreshing()
        refreshTableViewCompletion { [weak self] (_, _) in
            self?.tableView.refreshControl?.endRefreshing()
            
            // restore
            self?.navigationItem.titleView = restoreNavigationTitleView
            self?.navigationItem.title = restoreNavigationTitle
            self?.title = restoreTitle
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshTableWhenAppearIfNeeded()
    }
    
    override func viewDidBecomeActive() {
        super.viewDidBecomeActive()
        if isViewVisible {
            refreshTableWhenAppearIfNeeded()
        }
    }
    
    func handleTableLoadingResult(_ result: SALoadingViewController.LoadingResult, error: NSError?) {
        if result == .newData {
            loadingController.setFinished()
        } else if result == .emptyData {
            loadingController.setEmpty()
        } else {
            loadingController.setFailed(with: error)
        }
    }
    
    open func refreshControllWillShow() {
        os_log("refreshControllWillShow", log: .ui, type: .debug)
        if let lastView = thisTimeReloadingDate {
            thisTimeReloadingDate = lastView
        }
    }
    
    open func doFetchingMore() {
        // Override
    }
    
    func handleUserLoggedIn() {
    }
    
    func handleUserLoggedOut() {
    }
    
    open func refreshTableViewCompletion(_ completion: ((SALoadingViewController.LoadingResult, NSError?) -> Void)?) {
        completion?(.emptyData, nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        return proposedDestinationIndexPath
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
    }
    
    // MARK: - Prefetching
    public func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        
    }
    
    public func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        
    }
    
    // MARK: search
    func updateSearchResults(for searchController: UISearchController) {
        
    }
    
    // MARK: - UI events handlling
    
    @objc func handleGetUserLoginNotification(_ notification: Notification) {
        handleUserLoggedIn()
    }
    
    @objc func handleGetUserLogoutNotification(_ notification: Notification) {
        handleUserLoggedOut()
    }
    
    #if !targetEnvironment(macCatalyst)
    @objc func handleRefreshControlValueChanged(_ refreshControl: UIRefreshControl) {
        guard refreshControl.isRefreshing else {
            return
        }
        
        refreshTableViewCompletion { (_, _) in
            self.refreshControl?.endRefreshing()
        }
    }
    #endif
    
    // MARK: - UIScrollViewDelegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !showsBottomRefreshView {
            return
        }
        
        guard (scrollView as NSObject) == (tableView as NSObject) else {
            return
        }
        
        guard scrollView.frame.size.height != 0 && scrollView.contentSize.height > scrollView.frame.size.height else {
            tableView.tableFooterView?.isHidden = true
            return
        }
        
        let bounceY = scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.frame.size.height
        if bounceY > tableFooterHeight {
            return
        }
        tableView.tableFooterView?.isHidden = false
        
        if isFetchingMoreNoMoreData {
            return
        }
        
        if isFetchingMoreFailed {
            return
        }
        
        doFetchingMore()
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView == tableView else {
            return
        }
        
        let contentOffsetY = tableView.contentOffset.y + tableView.contentInset.top
        if contentOffsetY <= 0 {
            refreshControllWillShow()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        callFetchMoreHandlerAndSetNil()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            callFetchMoreHandlerAndSetNil()
        }
    }
    
    func callFetchMoreHandlerAndSetNil() {
        if fetchingMoreAction != nil {
            fetchingMoreAction!(self)
            fetchingMoreAction = nil
        }
    }
    
    // MARK: - reloading delegate
    override func loadingControllerDidRetry(_ controller: SALoadingViewController) {
        loadingController.setLoading()
        refreshTableViewCompletion { [weak self] (success, error) in
            guard self != nil else {
                return
            }
            #if !targetEnvironment(macCatalyst)
            self!.refreshControl?.endRefreshing()
            #endif
            if success == .newData {
                self!.loadingController.setFinished()
            } else if success == .emptyData {
                self!.loadingController.setEmpty()
            } else {
                self!.loadingController.setFailed(with: error)
            }
        }
    }
    
    // MARK: - Fetch More
    func fetchingMoreBegan() {
        bottomRefreshView.setLoading(text: NSLocalizedString("TABLE_VC_BOTTOM_LOADER_LOADING", comment: "loading..."))
    }
    
    func fetchingMoreFailed() {
        bottomRefreshView.setFailed(text: NSLocalizedString("TABLE_VC_BOTTOM_LOADER_LOAD_FAIL", comment: "load fail"))
    }
    
    func fetchingMoreCompleted() {
        bottomRefreshView.setMoreLoaded(text: NSLocalizedString("TABLE_VC_BOTTOM_LOADER_DRAG_UP_TO_LOAD_MORE", comment: "drag to load more"))
    }
    
    func fetchingMoreCompletedNoMoreData() {
        bottomRefreshView.setAllLoaded(text: NSLocalizedString("TABLE_VC_BOTTOM_LOADER_COMPLETED", comment: "all loaded"))
    }
}
