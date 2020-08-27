//
//  DatabaseRecordsViewController.swift
//  Saralin
//
//  Created by zhang on 2019/6/19.
//  Copyright © 2019 zaczh. All rights reserved.
//

import UIKit
import CoreData

class DatabaseRecordsCell: UITableViewCell {
    let textView = UITextView()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        textView.scrollsToTop = false
        textView.isUserInteractionEnabled = false
        textView.isEditable = false
        contentView.addSubview(textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = contentView.bounds
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        return textView.sizeThatFits(size)
    }
}

class DatabaseRecordsViewController: UITableViewController {
    private(set) var fetchRequest: NSFetchRequest<NSFetchRequestResult>!
    private var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
    
    init(fetchRequest: NSFetchRequest<NSFetchRequestResult>) {
        super.init(style: .plain)
        self.fetchRequest = fetchRequest
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        
        AppController.current.getService(of: SACoreDataManager.self)!.withMainContext { [weak self] (context) in
            guard let self = self else {
                return
            }
            
            let controller = NSFetchedResultsController(fetchRequest: self.fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
            self.fetchedResultsController = controller
            do {
               try controller.performFetch()
            } catch {
               fatalError("Failed to fetch entities: \(error)")
            }
            
            do {
                try controller.performFetch()
            } catch {
                sa_log_v2("performFetch failed with error: %@", error.localizedDescription)
            }
        }
       
        tableView.register(DatabaseRecordsCell.self, forCellReuseIdentifier: "cell")
        
        title = "\(fetchRequest.entityName ?? "") (\(fetchedResultsController?.fetchedObjects?.count ?? 0))"
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController?.sections!.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionInfo = self.fetchedResultsController?.sections?[section] else {
            return 0
        }
        return sectionInfo.numberOfObjects
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! DatabaseRecordsCell
        let object = self.fetchedResultsController?.object(at: indexPath)
        // Configure the cell with data from the managed object.
        cell.textView.text = object?.description
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionInfo = fetchedResultsController?.sections?[section] else {
            return nil
        }
        return sectionInfo.name
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return fetchedResultsController?.sectionIndexTitles
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        let result = fetchedResultsController?.section(forSectionIndexTitle: title, at: index) ?? 0
        return result
    }

}
