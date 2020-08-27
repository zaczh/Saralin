//
//  SASearchResultViewController.swift
//  Saralin
//
//  Created by zhang on 5/30/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import CoreData

protocol SASearchResultViewControllerDelegate: NSObjectProtocol {
    var currentSearchingKeyword: String? {get}
    func searchResultViewController(_ searchResultViewController: SASearchResultViewController, didSelectSearchResultURL url: URL)
    func searchResultViewController(_ searchResultViewController: SASearchResultViewController, requestedLoadMoreDataWithCompletion completion: (([String:AnyObject]?, NSError?) -> Void)?)
}


class SASearchResultViewController: SABaseTableViewController {
    override var showsSearchItem: Bool { return false }
    weak var delegate: SASearchResultViewControllerDelegate?
    
    var data: [String:AnyObject] = [:]
    var localData: [[String:String]] = []
    override var showsBottomRefreshView: Bool { return true }
    
    var resultType: SASearchController.ResultType = .localViewHistory
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadingController.emptyLabelTitle = "暂无搜索历史"
        
        tableView.register(SAThemedTableViewCell.self, forCellReuseIdentifier: "SAThemedTableViewCell")
        tableView.register(SASearchTableViewCell.self, forCellReuseIdentifier: "SASearchTableViewCell")
        tableView.register(SABoardTableViewCell.self, forCellReuseIdentifier: "SABoardTableViewCell")
        tableView.estimatedRowHeight = 120
        tableView.delegate = self
    }
    
    override func getTableView() -> UITableView {
        return UITableView(frame: .zero, style: .plain)
    }
    
    override func reloadData() {
        loadingController.emptyLabelTitle = "搜索结果为空"
        super.reloadData()
    }
    
    @objc func handleCancelButtonClick(_ sender:AnyObject) {
        presentingViewController?.dismiss(animated: false, completion: nil)
    }
    
    override func viewFontDidChange(_ newTheme: SATheme) {
        super.viewFontDidChange(newTheme)
        reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if resultType == .onlineGlobalSearch {
            if let results = data["results"] as? [[String:String]] {
                return results.count
            }
            return 0
        } else {
            return localData.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard  let keywords = delegate?.currentSearchingKeyword else { return tableView.dequeueReusableCell(withIdentifier: "SABoardTableViewCell", for: indexPath) }

        if resultType == .onlineGlobalSearch {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SASearchTableViewCell", for: indexPath) as! SASearchTableViewCell
            guard let list = data["results"] as? [[String:String]] else {
                return cell
            }
            let info = list[indexPath.row]
            cell.customNameLabel.text = info["author-name"]
            
            if let title = info["thread-title"] {
                cell.customTitleLabel.attributedText = show(Keywords: keywords, in: title)
            }
            
            if let view = info["view-count"] {
                cell.customViewLabel.text = "看" + view
            }
            
            if let reply = info["reply-count"] {
                cell.customReplyLabel.text = "回" + reply
            }
            
            if let abstract = info["thread-abstract"]?.trimmingCharacters(in: .whitespacesAndNewlines), !abstract.isEmpty {
                cell.quoteTextLabel.attributedText = show(Keywords: keywords, in: abstract)
            } else {
                cell.quoteTextLabel.text = "[附件]"
            }
            
            cell.customTimeLabel.text = info["date"]
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SABoardTableViewCell", for: indexPath) as! SABoardTableViewCell
            
            let dict = localData[indexPath.row]
            if let author = dict["author"] {
                cell.customNameLabel.attributedText = show(Keywords: keywords, in: author)
            }
            
            if let subject = dict["subject"] {
                cell.customTitleLabel.attributedText = show(Keywords: keywords, in: subject)
            }
            
            if let date = dict["date"] {
                cell.customTimeLabel.text = date
            }
            
            return cell
        }
    }
    
    private func show(Keywords: String, in text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let range = (text as NSString).localizedStandardRange(of: Keywords)
        if range.location != NSNotFound {
            attributedString.addAttributes([NSAttributedString.Key.foregroundColor : UIColor.red], range: range)
        }
        
        return attributedString
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if resultType == .onlineGlobalSearch {
            let info = (data["results"] as! [[String:String]])[indexPath.row]
            if let link = info["thread-link"] {
                if let url = URL.init(string: link, relativeTo: URL(string: SAGlobalConfig().forum_base_url)!) {
                    self.delegate?.searchResultViewController(self, didSelectSearchResultURL: url)
                }
            } else {
                // anonymous thread
                sa_log_v2("anonymous thread", module: .search, type: .info)
            }
        } else {
            let data = localData[indexPath.row]
            let fid = data["fid"]
            let tid = data["tid"]
            let page = data["page"]
            if let url = URL(string: "\(SAGlobalConfig().forum_base_url)?mod=viewthread&fid=\(fid ?? "")&tid=\(tid ?? "")&page=\(page ?? "")") {
                self.delegate?.searchResultViewController(self, didSelectSearchResultURL: url)
            }
        }
    }
    
    // MARK: - loading delegate
    override func loadingControllerDidRetry(_ controller: SALoadingViewController) {
        //TODO: reload search table
    }
    
    override func doFetchingMore() {
        guard let delegate = delegate else {
            super.doFetchingMore()
            return
        }
        delegate.searchResultViewController(self, requestedLoadMoreDataWithCompletion: nil)
    }
}
