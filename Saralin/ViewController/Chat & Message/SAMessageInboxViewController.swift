//
//  SAMessageInboxViewController.swift
//  Saralin
//
//  Created by zhang on 1/10/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

private class SAImageFetchingOperation: Operation {
    var imageURL: URL
    var resultImage: UIImage?
    var indexPath: IndexPath
    
    init(imageURL: URL, indexPath: IndexPath) {
        self.imageURL = imageURL
        self.indexPath = indexPath
        super.init()
    }
    
    override func main() {
        if isCancelled {
            return
        }
        
        sa_log_v2("image download start", log: .ui, type: .debug)
        
        var downloadedData: Data?
        
        let group = DispatchGroup.init()
        group.enter()
        UIApplication.shared.showNetworkIndicator()
        let task = URLSession.saCustomized.dataTask(with: imageURL) { (data, response, error) in
            UIApplication.shared.hideNetworkIndicator()
            if error != nil {
                sa_log_v2("image download failed error: %@", log: .ui, type: .error, error! as CVarArg)
            }
            downloadedData = data
            group.leave()
        }
        task.resume()
        group.wait()
        if downloadedData != nil {
            guard let image = UIImage.init(data: downloadedData!) else {
                sa_log_v2("image download failed: not an image", log: .ui, type: .error)
                return
            }
            self.resultImage = image
            sa_log_v2("image download succeeded", log: .ui, type: .debug)
        } else {
            sa_log_v2("image download failed: no data", log: .ui, type: .error)
        }
    }
}

class SAMessageInboxViewController: SABaseTableViewController {
    var messages: [PrivateMessageSummary] = []
    private let loadingOperationQueue = OperationQueue.init()
    private var loadingImageResult:[(IndexPath, UIImage?)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        title = NSLocalizedString("DIRECT_MESSAGE_VC_TITLE", comment: "direct message vc title")
        let textColor = UIColor.sa_colorFromHexString(Theme().textColor)
        let placeholder = NSMutableAttributedString()
        placeholder.append(NSAttributedString(string: "无数据\n\n",
                                              attributes:[.font:UIFont.sa_preferredFont(forTextStyle: .headline), .foregroundColor:textColor]))
        placeholder.append(NSAttributedString(string: "暂时没有收到消息",
                                              attributes: [.font:UIFont.sa_preferredFont(forTextStyle: .subheadline), .foregroundColor:textColor]))
        loadingController.emptyLabelAttributedTitle = placeholder
        
        tableView.register(SAMessageInboxTableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.estimatedRowHeight = 100
        tableView.tableFooterView = UIView()
        
        loadingController.setLoading()
        refreshTableViewCompletion { [weak self] (finished, error) in
            self?.handleTableLoadingResult(finished, error: error)
        }
    }
    
    override func handleUserLoggedIn() {
        loadingController.setLoading()
        refreshTableViewCompletion(nil)
    }
    
    deinit {
        loadingOperationQueue.cancelAllOperations()
    }
    
    override func refreshTableViewCompletion(_ completion: ((SALoadingViewController.LoadingResult, NSError?) -> Void)?) {
        AppController.current.getService(of: SABackgroundTaskManager.self)!.fetchDirectMessageInBackground { (list, error) in
            DispatchQueue.main.async {
                guard error == nil else {
                    completion?(.fail, error! as NSError)
                    return
                }
                
                self.messages.removeAll()
                self.loadingOperationQueue.cancelAllOperations()
                self.messages.append(contentsOf: list)
                self.reloadData()
                completion?(self.messages.count > 0 ? .newData : .emptyData, nil)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SAMessageInboxTableViewCell
        
        let dateString = messages[indexPath.row].lastupdate
        let dateInterval = Int(dateString)!
        let isNew = messages[indexPath.row].isnew
        cell.customNameLabel.text = messages[indexPath.row].tousername
        let title = messages[indexPath.row].message
        if !title.isEmpty {
            let trimmed = title.sa_stringByReplacingHTMLTags() as String
            let attributedTitle = NSMutableAttributedString(string: trimmed, attributes:[NSAttributedString.Key.font: UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline),NSAttributedString.Key.foregroundColor: UIColor.sa_colorFromHexString(Theme().tableCellTextColor)])
            if isNew != 0 {
                attributedTitle.insert(NSAttributedString(string: "[新]", attributes: [
                    NSAttributedString.Key.font: UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline),
                    NSAttributedString.Key.foregroundColor: UIColor.green]), at: 0)
            }
            
            cell.customTitleLabel.attributedText = attributedTitle
        }
        
        cell.customTimeLabel.text = Date(timeIntervalSince1970: TimeInterval(dateInterval)).sa_prettyDate()
        
        cell.avatarImageView.image = UIImage(named: "noavatar_middle")!

        let touid = messages[indexPath.row].touid
        let avatarImageURL = URL(string: SAGlobalConfig().avatar_base_url + "avatar.php?uid=\(touid)&size=middle")!
        if let operation = loadingOperationQueue.operations.filter({ (operation) -> Bool in
            let operation = operation as! SAImageFetchingOperation
            if operation.imageURL == avatarImageURL {
                return true
            }
            return false
        }).first as? SAImageFetchingOperation {
            if operation.isFinished {
                cell.avatarImageView.image = operation.resultImage ?? UIImage(named: "noavatar_middle")!
            } else {
                // not finished yet
            }
        } else {
            if let result = loadingImageResult.filter({ (element) -> Bool in
                return element.0 == indexPath
            }).first {
                cell.avatarImageView.image = result.1 ?? UIImage(named: "noavatar_middle")!
            } else {
                // not queued yet
                self.tableView(tableView, prefetchRowsAt: [indexPath])
            }
            return cell
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let dict = messages[indexPath.row]
        let touid = dict.touid
        guard !touid.isEmpty else {
            return
        }
        
        let toUserName = dict.tousername
        guard !toUserName.isEmpty else {
            return
        }
        
        messages[indexPath.row] = dict
        DispatchQueue.main.async {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
        
        let count = dict.pmnum
        let participants = Set.init(arrayLiteral: touid, Account().uid)
        let conversation = ChatViewController.Conversation(cid: touid, pmid: "", formhash:"", name: toUserName, participants: participants, numberOfMessages:count)
        let chatViewController = ChatViewController(conversation: conversation)
        navigationController?.pushViewController(chatViewController, animated: true)
        // refresh bg result
        AppController.current.getService(of: SABackgroundTaskManager.self)?.startBackgroundTask(with: { Result in
            
        })
    }
    
    // MARK: - Prefetching
    override func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        indexPaths.forEach { (indexPath) in
            let contains = self.loadingImageResult.contains(where: { (element) -> Bool in
                return element.0 == indexPath
            })
            if contains {return}
            
            let touid = messages[indexPath.row].touid
            guard !touid.isEmpty else {
                return
            }
            
            let avatarImageURL = URL(string: SAGlobalConfig().avatar_base_url + "avatar.php?uid=\(touid)&size=middle")!
            let operation = SAImageFetchingOperation.init(imageURL: avatarImageURL, indexPath: indexPath)
            operation.completionBlock = {() in
                DispatchQueue.main.async {
                    self.loadingImageResult.append((operation.indexPath, operation.resultImage))
                    if tableView.indexPathsForVisibleRows?.contains(operation.indexPath) ?? false {
                        if let cell = tableView.cellForRow(at: operation.indexPath) as? SAMessageInboxTableViewCell {
                            cell.avatarImageView.image = operation.resultImage ?? UIImage(named: "noavatar_middle")!
                        }
                    }
                }
            }
            self.loadingOperationQueue.addOperation(operation)
        }
    }
    
    override func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        
    }
}
