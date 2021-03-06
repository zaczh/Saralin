//
//  SABlockedListConfigureViewController.swift
//  Saralin
//
//  Created by zhang on 2/7/18.
//  Copyright © 2017 zaczh. All rights reserved.
//

import UIKit
import CoreData

class SABlockedListConfigureViewController: SABaseTableViewController, NSFetchedResultsControllerDelegate {
    let segmentedControl = UISegmentedControl(items: ["用户", "帖子"])
    private var fetchController: NSFetchedResultsController<NSFetchRequestResult>?
    private var loginObeserver: NSObjectProtocol?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = NSLocalizedString("ACCOUNT_VC_BLACKLIST", comment: "黑名单")
        let segmentWidth = CGFloat(60)
        segmentedControl.setWidth(segmentWidth, forSegmentAt: 0)
        segmentedControl.setWidth(segmentWidth, forSegmentAt: 1)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(handleSegmentedControlValueChanged(_:)), for: .valueChanged)
        navigationItem.titleView = segmentedControl
        
        let textColor = UIColor.sa_colorFromHexString(Theme().textColor)
        let placeholder = NSMutableAttributedString()
        placeholder.append(NSAttributedString(string: "无数据\n\n",
                                              attributes:[.font:UIFont.sa_preferredFont(forTextStyle: .headline), .foregroundColor:textColor]))
        placeholder.append(NSAttributedString(string: "屏蔽名单为空",
                                              attributes: [.font:UIFont.sa_preferredFont(forTextStyle: .subheadline), .foregroundColor:textColor]))
        loadingController.emptyLabelAttributedTitle = placeholder
        
        tableView.register(SAThemedTableHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "SAThemedTableHeaderFooterView")
        tableView.register(SAThemedTableViewCell.self, forCellReuseIdentifier: "SAThemedTableViewCell")
        tableView.register(SABoardTableViewCell.self, forCellReuseIdentifier: "SABoardTableViewCell")
        
        refreshTableViewCompletion(nil)
        loginObeserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.SAUserLoggedInNotification, object: nil, queue: nil) { [weak self] (notification) in
            self?.refreshTableViewCompletion(nil)
        }
    }
    
    override func refreshTableViewCompletion(_ completion: ((SALoadingViewController.LoadingResult, NSError?) -> Void)?) {
        AppController.current.getService(of: SACoreDataManager.self)!.withMainContext { [weak self] (context) in
            guard let self = self else {
                completion?(.fail, nil)
                return
            }
            
            if self.segmentedControl.selectedSegmentIndex == 0 {
                let fetch = NSFetchRequest<BlockedUser>(entityName: "BlockedUser")
                fetch.predicate = NSPredicate(format: "reporteruid==%@", Account().uid)
                fetch.sortDescriptors = [NSSortDescriptor.init(key: "reportingtime", ascending: false)]
                self.fetchController = NSFetchedResultsController(fetchRequest: fetch, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil) as? NSFetchedResultsController<NSFetchRequestResult>
                self.fetchController?.delegate = self
            } else if self.segmentedControl.selectedSegmentIndex == 1 {
                let fetch = NSFetchRequest<BlockedThread>(entityName: "BlockedThread")
                fetch.predicate = NSPredicate(format: "uid==%@", Account().uid)
                fetch.sortDescriptors = [NSSortDescriptor.init(key: "dateofadding", ascending: false)]
                self.fetchController = NSFetchedResultsController(fetchRequest: fetch, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil) as? NSFetchedResultsController<NSFetchRequestResult>
                self.fetchController?.delegate = self
            } else {
                completion?(.newData, nil)
                return
            }
            
            try! self.fetchController!.performFetch()
            if self.fetchController!.fetchedObjects == nil || self.fetchController!.fetchedObjects!.count == 0 {
                self.loadingController.setEmpty()
                completion?(.emptyData, nil)
            } else {
                self.loadingController.setFinished()
                completion?(.newData, nil)
            }
        
            self.reloadData()
        }
    }
    
    deinit {
        if let ob = loginObeserver {
            NotificationCenter.default.removeObserver(ob)
        }
    }
    
    override var showsRefreshControl: Bool {
        return false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet.init(integer: sectionIndex), with: .fade)
        case .delete:
            tableView.deleteSections(IndexSet.init(integer: sectionIndex), with: .fade)
        default:
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .automatic)
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .automatic)
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .automatic)
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        @unknown default:
            fatalError()
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
        if (controller.fetchedObjects?.count ?? 0) == 0 {
            loadingController.setEmpty()
        } else {
            loadingController.setFinished()
        }
    }
    
    // MARK: - UITableViewDelegate
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SAThemedTableHeaderFooterView") as! SAThemedTableHeaderFooterView
        view.delegate = self
        if segmentedControl.selectedSegmentIndex == 0 {
            view.setTitleWith(description: "屏蔽名单中的用户，其回帖和主贴均会被隐藏。", link: nil, url: nil)
        }
        
        return view
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard fetchController != nil else {
            return 0
        }
        
        if let sections = fetchController!.sections {
            return sections[section].numberOfObjects
        }
        
        return 0
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        guard fetchController != nil else {
            return 0
        }
        
        if let sections = fetchController!.sections {
            return sections.count
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard fetchController != nil else {
            return UITableViewCell()
        }

        
        if segmentedControl.selectedSegmentIndex == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SAThemedTableViewCell", for: indexPath) as! SAThemedTableViewCell
            let managedObject = fetchController!.object(at: indexPath) as! BlockedUser
            cell.textLabel?.text = managedObject.name
            cell.detailTextLabel?.text = managedObject.uid
            return cell
        } else if segmentedControl.selectedSegmentIndex == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SABoardTableViewCell", for: indexPath) as! SABoardTableViewCell
            let managedObject = fetchController!.object(at: indexPath) as! BlockedThread
            cell.customTitleLabel.attributedText = NSAttributedString(string: managedObject.title ?? "", attributes: [NSAttributedString.Key.foregroundColor: UIColor.sa_colorFromHexString(Theme().tableCellTextColor)])
            let attributes: [NSAttributedString.Key:Any] = [.foregroundColor: Theme().tableCellGrayedTextColor.sa_toColor()]
            cell.customNameLabel.attributedText = NSAttributedString.init(string: managedObject.authorname ?? "", attributes: attributes)
            cell.customTimeLabel.attributedText = NSAttributedString.init(string: (managedObject.dateofcreating as Date?)?.sa_prettyDate() ?? "", attributes: attributes)
            cell.customReplyLabel.attributedText = NSAttributedString()
            return cell
        }
        
        return UITableViewCell()
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if segmentedControl.selectedSegmentIndex == 0 {
            let managedObject = fetchController!.object(at: indexPath) as! BlockedUser
            guard let uid = managedObject.uid else {return}
            AppController.current.getService(of: SACoreDataManager.self)!.undoBlockUser(uid: uid)
        } else if segmentedControl.selectedSegmentIndex == 1 {
            let managedObject = fetchController!.object(at: indexPath) as! BlockedThread
            guard let tid = managedObject.tid else {return}
            AppController.current.getService(of: SACoreDataManager.self)!.undoBlockThread(tid: tid)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if segmentedControl.selectedSegmentIndex == 0 {
            let managedObject = fetchController!.object(at: indexPath) as! BlockedUser
            guard let uid = managedObject.uid else {return}
            guard let url = URL(string: SAGlobalConfig().profile_url_template.replacingOccurrences(of: "%{UID}", with: uid)) else {
                os_log("bad record in db of type `BlockedUser` uid: %@", log: .database, type:.fault, uid)
                return
            }
            let page = SAAccountInfoViewController(url: url)
            navigationController?.pushViewController(page, animated: true)
        } else if segmentedControl.selectedSegmentIndex == 1 {
            let managedObject = fetchController!.object(at: indexPath) as! BlockedThread
            guard let tid = managedObject.tid else {return}
            guard let url = URL(string: SAGlobalConfig().forum_base_url + "forum.php?mod=viewthread&tid=\(tid)&page=1&mobile=1&simpletype=no") else {
                os_log("bad record in db of type `BlockedThread` tid: %@", log: .database, type:.fault, tid)
                return
            }
            let contentViewer = SAThreadContentViewController(url: url)
            navigationController?.pushViewController(contentViewer, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "移除"
    }

    @objc func handleSegmentedControlValueChanged(_ s: UISegmentedControl) {
        refreshTableViewCompletion(nil)
    }
}

