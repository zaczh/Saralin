//
//  SANoticeCenterViewController.swift
//  Saralin
//
//  Created by zhang on 6/3/17.
//  Copyright © 2017 zaczh. All rights reserved.
//

import UIKit

class SANoticeCenterViewController: SABaseTableViewController {
    var segmentedControl = UISegmentedControl(items: ["回复我的", "提到我的"])
    var replyToMeSource: [[String:AnyObject]] = []
    var mentionMeSource: [[String:AnyObject]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "我的提醒"
        
        let textColor = UIColor.sa_colorFromHexString(Theme().textColor)
        let placeholder = NSMutableAttributedString()
        placeholder.append(NSAttributedString(string: "无数据\n\n",
                                              attributes:[.font:UIFont.sa_preferredFont(forTextStyle: .headline), .foregroundColor:textColor]))
        placeholder.append(NSAttributedString(string: "暂时没有消息提醒",
                                              attributes: [.font:UIFont.sa_preferredFont(forTextStyle: .subheadline), .foregroundColor:textColor]))
        loadingController.emptyLabelAttributedTitle = placeholder
        
        tableView.register(SABoardTableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.estimatedRowHeight = 200
        tableView.tableFooterView?.frame = CGRect.zero

        let segmentWidth = CGFloat(80)
        segmentedControl.setWidth(segmentWidth, forSegmentAt: 0)
        segmentedControl.setWidth(segmentWidth, forSegmentAt: 1)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(handleSegmentedControlValueChanged(_:)), for: .valueChanged)
        navigationItem.titleView = segmentedControl
        
        loadingController.setLoading()
        refreshTableViewCompletion { [weak self] (result) in
            self?.handleTableLoadingResult(result)
        }
    }
    
    override func updateViewTheme() {
        super.updateViewTheme()
        tableView.backgroundColor = Theme().backgroundColor.sa_toColor()
        tableView.separatorColor = Theme().tableCellSeperatorColor.sa_toColor()
    }
    
    override func refreshTableViewCompletion(_ completion: ((SALoadingViewController.LoadingResult) -> Void)?) {
        let group = DispatchGroup()
        guard let url0 = URL(string: "home.php?mod=space&do=notice&view=mypost&type=post", relativeTo: URL(string: Config.s_forum_base_url)!) else {
            fatalError()
        }
        
        var data0:[[String:AnyObject]] = []
        var data1:[[String:AnyObject]] = []
        
        var result = true
        group.enter()
        URLSession.shared.dataTask(with: url0, completionHandler: { (data, response, error) in
            defer {
                group.leave()
            }
            guard data != nil else {result = false;return}
            let str = String.init(data: data!, encoding: String.Encoding.utf8)!
            guard let parser = try? HTMLParser.init(string: str) else {
                result = false
                return
            }
            
            parser.body()?.findChildTags("dl").forEach({ (i) in
                if let dl = i as? HTMLNode {
                    let notice = dl.getAttributeNamed("notice") ?? ""
                    let dd0 = dl.children()[1]
                    let a = dd0.children()[1]
                    let a_href = a.getAttributeNamed("href") ?? ""
                    let dd1 = dl.children()[5]
                    let a0 = dd1.children()[1]
                    let a0_content = a0.contents() ?? ""
                    let a1 = dd1.children()[3]
                    let a1_content = a1.contents() ?? ""
                    let a1_href = a1.getAttributeNamed("href") ?? ""
                    let a2 = dd1.children()[5]
                    let a2_href = a2.getAttributeNamed("href") ?? ""
                    let date = dl.children()[3].children()[3].contents() ?? ""
                    
                    let data: [String:String] = [
                        "notice":notice,
                        "thread-title":a1_content,
                        "notice-author":a0_content,
                        "notice-author-avatar-link":a_href,
                        "thread-link":a2_href,
                        "thread-reply-link":a1_href,
                        "date":date
                    ]
                    
                    data0.append(data as [String : AnyObject])
                }
            })
        }).resume()
    
        guard let url1 = URL(string: "home.php?mod=space&do=notice&view=mypost&type=at", relativeTo: URL(string: Config.s_forum_base_url)!) else {
            fatalError()
        }
        
        group.enter()
        URLSession.shared.dataTask(with: url1, completionHandler: { (data, response, error) in
            defer {
                group.leave()
            }
            guard data != nil else {result = false;return}
            let str = String.init(data: data!, encoding: String.Encoding.utf8)!
            guard let parser = try? HTMLParser.init(string: str) else {
                result = false
                return
            }
            
            parser.body()?.findChildTags("dl").forEach({ (i) in
                if let dl = i as? HTMLNode {
                    let notice = dl.getAttributeNamed("notice") ?? ""
                    let dd0 = dl.children()[1]
                    let a = dd0.children()[1]
                    let a_href = a.getAttributeNamed("href") ?? ""
                    let dd1 = dl.children()[5]
                    let a0 = dd1.children()[1]
                    let a0_content = a0.contents() ?? ""
                    let a1 = dd1.children()[3]
                    let a1_content = a1.contents() ?? ""
                    let a1_href = a1.getAttributeNamed("href") ?? ""
                    let a2 = dd1.children()[5]
                    let a2_href = a2.getAttributeNamed("href") ?? ""
                    let date = dl.children()[3].children()[3].contents() ?? ""
                    
                    let data: [String:String] = [
                        "notice":notice,
                        "thread-title":a1_content,
                        "notice-author":a0_content,
                        "notice-author-avatar-link":a_href,
                        "thread-link":a2_href,
                        "thread-reply-link":a1_href,
                        "date":date
                    ]
                    
                    data1.append(data as [String : AnyObject])
                }
            })
        }).resume()
        
        group.notify(queue: DispatchQueue.main) {
            if !result {
                completion?(.fail)
                return
            }
            
            self.replyToMeSource.removeAll()
            self.replyToMeSource.append(contentsOf: data0)
            self.mentionMeSource.removeAll()
            self.mentionMeSource.append(contentsOf: data1)
            self.reloadData()
            completion?(.newData)
        }
    }
    
    // MARK: table view data source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if segmentedControl.selectedSegmentIndex == 0 {
            return self.replyToMeSource.count
        }
        else if segmentedControl.selectedSegmentIndex == 1 {
            return self.mentionMeSource.count
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if segmentedControl.selectedSegmentIndex == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SABoardTableViewCell
            let data = replyToMeSource[indexPath.row]
            guard let threadTitle = data["thread-title"] as? String,
                let time = data["date"] as? String,
                let replierName = data["notice-author"] as? String,
                let _ = data["thread-link"] as? String,
                let _ = data["thread-reply-link"] as? String else {
                    return cell
            }
            
            let font = cell.customTitleLabel.font!
            
            let attributedString = NSMutableAttributedString()
            attributedString.append(NSAttributedString(string: replierName, attributes: [NSAttributedStringKey.font: font, NSAttributedStringKey.foregroundColor: Theme().htmlLinkColor.sa_toColor()]))
            attributedString.append(NSAttributedString(string: " 在帖子 \(threadTitle) 中回复了你，点击查看。", attributes: [NSAttributedStringKey.font: font, NSAttributedStringKey.foregroundColor: Theme().textColor.sa_toColor()]))
            cell.customTitleLabel.attributedText = attributedString
            cell.customTimeLabel.text = time
            return cell
        }
        else if segmentedControl.selectedSegmentIndex == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SABoardTableViewCell
            let data = mentionMeSource[indexPath.row]
            guard let threadTitle = data["thread-title"] as? String,
                let time = data["date"] as? String,
                let replierName = data["notice-author"] as? String,
                let _ = data["thread-link"] as? String,
                let _ = data["thread-reply-link"] as? String,
                let quote = data["blockQuoteContent"] as? String else {
                    return cell
            }
            
            let font = cell.customTitleLabel.font!
            
            let attributedString = NSMutableAttributedString()
            attributedString.append(NSAttributedString(string: replierName, attributes: [NSAttributedStringKey.font: font, NSAttributedStringKey.foregroundColor: Theme().htmlLinkColor.sa_toColor()]))
            attributedString.append(NSAttributedString(string: " 在帖子 \(threadTitle) 中提到了你\n", attributes: [NSAttributedStringKey.font: font, NSAttributedStringKey.foregroundColor: Theme().textColor.sa_toColor()]))
            attributedString.append(NSAttributedString(string: "\(quote)\n", attributes: [NSAttributedStringKey.font: font, NSAttributedStringKey.foregroundColor: Theme().tableCellGrayedTextColor.sa_toColor()]))
            attributedString.append(NSAttributedString(string: "点击查看", attributes: [NSAttributedStringKey.font: font, NSAttributedStringKey.foregroundColor: Theme().textColor.sa_toColor()]))
            cell.customTitleLabel.attributedText = attributedString
            cell.customTimeLabel.text = time
            return cell
        }
        
        return UITableViewCell()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if segmentedControl.selectedSegmentIndex == 0 {
            let data = replyToMeSource[indexPath.row]
            guard let threadLink = data["thread-link"] as? String,
                let _ = data["thread-reply-link"] as? String else {
                    return
            }
            
            if let url = URL(string: threadLink, relativeTo: URL(string: Config.s_forum_base_url)!) {
                let context: [String:AnyObject?] = [openURLContextSplitViewControllerKey: splitViewController, openURLContextShouldPreserveStackKey: true as Optional<AnyObject>]
                SAContentViewController.openURL(url, inContext: context, sender: self)
            }
        }
        else if segmentedControl.selectedSegmentIndex == 1 {
            let data = mentionMeSource[indexPath.row]
            guard let viewReplyLink = data["thread-reply-link"] as? String else {
                return
            }
            
            if let url = URL(string: viewReplyLink, relativeTo: URL(string: Config.s_forum_base_url)!) {
                let context: [String:AnyObject?] = [openURLContextSplitViewControllerKey: splitViewController, openURLContextShouldPreserveStackKey: true as Optional<AnyObject>]
                SAContentViewController.openURL(url, inContext: context, sender: self)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func handleSegmentedControlValueChanged(_ s: UISegmentedControl) {
        reloadData()
    }

}
