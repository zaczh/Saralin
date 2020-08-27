//
//  SASearchController.swift
//  Saralin
//
//  Created by zhang on 2019/6/20.
//  Copyright © 2019 zaczh. All rights reserved.
//

import UIKit
import CoreData

class SASearchController: SABaseViewController {
    enum ResultType {
        case localViewHistory
        case onlineGlobalSearch
    }
    
    var resultType: ResultType = ResultType.localViewHistory {
        didSet {
            searchResultsController.resultType = resultType
        }
    }
    var currentSearchingKeyword: String?
    private var searchingTimer: Timer?
    
    private var urlSession: URLSession! = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(30)
        return URLSession.init(configuration: configuration, delegate: nil, delegateQueue: nil)
    } ()
    
    private var searchResultsController = SASearchResultViewController()
    let searchBar = UISearchBar(frame: .zero)

    deinit {
        sa_log_v2("SASearchController deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem.init()
        
        searchBar.autocapitalizationType = .none
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self // Monitor when the search button is tapped.
        searchBar.placeholder = NSLocalizedString("SEARCH_BAR_PLACEHOLDER_SEARCH_HISTORY_RECORDS", comment: "")
        navigationItem.titleView = searchBar
        
        navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .plain, target: self, action: #selector(handleCancelButtonClick(_:)))
        
        searchResultsController.resultType = resultType
        searchResultsController.delegate = self
        view.addSubview(searchResultsController.view)
        addChild(searchResultsController)
        searchResultsController.didMove(toParent: self)
        searchResultsController.view.translatesAutoresizingMaskIntoConstraints = false
        searchResultsController.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        searchResultsController.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        searchResultsController.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        searchResultsController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        searchBar.becomeFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        searchingTimer = Timer.scheduledTimer(timeInterval: TimeInterval(100000), target: self, selector: #selector(searchingTimerFired(_:)), userInfo: nil, repeats: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let timer = searchingTimer {
            timer.invalidate()
            searchingTimer = nil
        }
    }
    
    // MARK: Events
    @objc func handleCancelButtonClick(_ sender: AnyObject) {
        navigationController?.popViewController(animated: false)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: Searching
    func search(with keyword: String) {
        let resultController = searchResultsController
        
        guard !keyword.isEmpty else {
            sa_log_v2("keyword isEmpty", module: .search, type: .info)
            searchingTimer?.fireDate = Date.distantFuture
            resultController.data.removeAll()
            resultController.localData.removeAll()
            resultController.cleanUpAndReloadData()
            return
        }
        
        if currentSearchingKeyword == keyword {
            sa_log_v2("keyword same", module: .search, type: .info)
            return
        }
        resultController.loadingController.setLoading()
        currentSearchingKeyword = keyword
        searchingTimer?.fireDate = Date(timeIntervalSinceNow: TimeInterval(2))
    }
    
    @objc func searchingTimerFired(_ timer: Timer) {
        sa_log_v2("searchingTimerFired", module: .search, type: .info)
        searchingTimer?.fireDate = Date.distantFuture
        let resultController = searchResultsController
        guard let keyword = currentSearchingKeyword else { return }
        saveSearchHistory(keyword)
        sa_log_v2("begin searching keyword: %@", module: .search, type: .info, keyword)
        let group = DispatchGroup()
        if resultType == .onlineGlobalSearch {
            // only online searching needs show this
            resultController.loadingController.setLoading()
            group.enter()
            searchOnlineDataWithKeywords(keyword, previousResult: nil) { [weak self] (result, error) in
                defer {
                    group.leave()
                }
                
                guard let self = self else {
                    sa_log_v2("self is nil, searching canceled", module: .search, type: .error)
                    return
                }
                
                if let error = error {
                    self.loadingController.setFailed(with: error)
                    return
                }
                
                guard let result = result else {
                    sa_log_v2("Error occurs when doing search", module: .search, type: .error)
                    return
                }
                
                if self.currentSearchingKeyword != keyword {
                    sa_log_v2("currentSearchingKeyword not match", module: .search, type: .error)
                    return
                }
                resultController.data = result
                sa_log_v2("finished online searching: %@", module: .search, type: .info, keyword)
            }
        } else {
            group.enter()
            searchLocalDataWithKeywords(keyword) { (result, error) in
                defer {
                    group.leave()
                }
                
                guard error == nil, let result = result else {
                    sa_log_v2("Error occurs when doing search")
                    return
                }
                
                if self.currentSearchingKeyword != keyword {
                    return
                }
                resultController.localData = result
                sa_log_v2("finished local searching: %@", module: .search, type: .info, keyword)
            }
        }
        
        group.notify(queue: DispatchQueue.main) {
            resultController.cleanUpAndReloadData()
        }
    }
    
    private func saveSearchHistory(_ searchText: String) {
        guard !searchText.isEmpty else {return}
        
        let uid = Account().uid
        let predicate = NSPredicate(format: "keyword==%@ AND uid==%@", searchText, uid)
        let date = Date()
        AppController.current.getService(of: SACoreDataManager.self)!.insertNewOrUpdateExist(fetchPredicate: predicate, sortDescriptors: nil, update: { (entity: SearchKeyword) in
            entity.date = date
            entity.count = NSNumber(value: (entity.count?.intValue ?? 0) + 1)
            entity.createdevicename = UIDevice.current.name
            entity.createdeviceidentifier = AppController.current.currentDeviceIdentifier
        }, create: { (entity: SearchKeyword) in
            entity.createdevicename = UIDevice.current.name
            entity.createdeviceidentifier = AppController.current.currentDeviceIdentifier
            entity.uid = uid
            entity.keyword = searchText
            entity.date = date
            entity.count = NSNumber(value: 1)
            
            // TODO: support searching more categories
            entity.category = "threads"
        }, completion: nil)
    }
    
    private func searchLocalDataWithKeywords(_ keywords: String, completion completionBlock: (([[String:String]]?, NSError?) -> Void)?) {
        AppController.current.getService(of: SACoreDataManager.self)!.withMainContext { (context) in
            let fetch = NSFetchRequest<ViewedThread>(entityName: "ViewedThread")
            fetch.predicate = NSPredicate(format:"subject CONTAINS[cd] %@ OR author CONTAINS[cd] %@", keywords, keywords)
            let sort = NSSortDescriptor(key: "lastviewtime", ascending: false)
            fetch.sortDescriptors = [sort]
            context.perform {
                let objects = try! context.fetch(fetch)
                var data:[[String:String]] = []
                for object in objects {
                    let dateStr = "最后浏览于" + ((object.lastviewtime as Date?)?.sa_prettyDate() ?? "未知")
                    data.append([
                        "author" : object.author ?? "",
                        "fid":object.fid ?? "",
                        "page":object.page?.description ?? "",
                        "subject":object.subject ?? "",
                        "tid":object.tid ?? "",
                        "uid":object.uid ?? "",
                        "date":dateStr,
                        ])
                }
                DispatchQueue.main.async {
                    completionBlock?(data, nil)
                }
            }
        }
    }
    
    private func searchOnlineDataWithKeywords(_ keywords: String, previousResult: AnyObject?, completion: (([String:AnyObject]?, NSError?) -> Void)?) {
        urlSession.searchThreads(with: keywords, previousResult: previousResult) { (obj, error) in
            guard error == nil else {
                completion?(nil, error!)
                return
            }
            
            guard let data = obj as? [String:AnyObject] else {
                completion?(nil, NSError.init(domain: "Search", code: -1, userInfo: nil))
                return
            }
            
            completion?(data, nil)
        }
    }
}

// MARK: - UISearchBarDelegate
extension SASearchController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let whitespaceCharacterSet = CharacterSet.whitespaces
        let strippedString = searchBar.text!.trimmingCharacters(in: whitespaceCharacterSet)
        search(with: strippedString)
    }
}

extension SASearchController: SASearchResultViewControllerDelegate {
    func searchResultViewController(_ searchResultViewController: SASearchResultViewController, didSelectSearchResultURL url: URL) {
        if let vc = SAContentViewController.viewControllerForURL(url: url, sender: self) {
            splitViewController?.showDetailViewController(vc, sender: self)
        }
    }
    
    func searchResultViewController(_ searchResultViewController: SASearchResultViewController, requestedLoadMoreDataWithCompletion completion: (([String:AnyObject]?, NSError?) -> Void)?) {
        let resultController = searchResultViewController
        if resultController.isFetchingMoreThreads {
            let error = NSError.init(domain: SAGeneralErrorDomain, code: -1, userInfo: ["msg":"Already searching"])
            completion?(nil, error)
            return
        }
        
        resultController.isFetchingMoreThreads = true
        resultController.fetchingMoreBegan()
        
        searchOnlineDataWithKeywords(currentSearchingKeyword ?? "", previousResult: resultController.data as AnyObject) { (obj, error) in
            defer {
                completion?(obj, error)
            }
            
            guard error == nil, var data = obj else {
                resultController.isFetchingMoreFailed = true
                resultController.isFetchingMoreThreads = false
                resultController.fetchingMoreFailed()
                return
            }
            
            guard var previous_list = resultController.data["results"] as? [[String:String]],
                let now_list = data["results"] as? [[String:String]], !now_list.isEmpty else {
                    resultController.isFetchingMoreFailed = false
                    resultController.isFetchingMoreThreads = false
                    resultController.isFetchingMoreNoMoreData = true
                    resultController.fetchingMoreCompletedNoMoreData()
                    return
            }
            
            var added: [IndexPath] = []
            for i in previous_list.count ..< previous_list.count + now_list.count {
                let indexpath = IndexPath(row: i, section: 0)
                added.append(indexpath)
            }
            
            previous_list.append(contentsOf: now_list)
            data["results"] = previous_list as AnyObject
            
            resultController.fetchingMoreAction = { () in
                if resultController.resultType == .localViewHistory {
                    resultController.isFetchingMoreFailed = false
                    resultController.isFetchingMoreThreads = false
                    resultController.fetchingMoreCompleted()
                    return
                }
                
                resultController.data = data
                resultController.tableView.insertRows(at: added, with: .bottom)
                resultController.isFetchingMoreThreads = false
                resultController.fetchingMoreCompleted()
            }
            
            if !resultController.tableView.isDragging && !resultController.tableView.isDecelerating {
                resultController.callFetchMoreHandlerAndSetNil()
            }
        }
    }
}
