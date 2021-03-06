//
//  SAAccountInfoViewController.swift
//  Saralin
//
//  Created by zhang on 1/10/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import WebKit

class SAAccountInfoViewController: SABaseTableViewController {
    struct AccountModel {
        var name: String
        var uid: String
        var customTitle: String?
        var signature: String?
        var friendsCount: Int
        var repliedThreadsCount: Int
        var createdThreadsCount: Int
        var gender: Int // 0 unknown 1 male 2 female
        var birthday: String?
        
        // 活跃概况
        var userGroupName: String?
        var onlineHours: String?
        var accountCreationDate: String?
        var lastOnlineDate: String?
        var lastActivityDate: String?
        var timeZone: String?
        var registerIp: String?
        var lastActiveIp: String?
        
        // 统计信息
        var usedSpace: String?
        var points: String?
        var fightForce: String?
        var gold: String?
        var pounchInPoint: String?
        var mannerPoint: String?
    }
    
    var url: URL?
    var uid: String?
    var doType: String?
    private var account = AccountModel(name: "0", uid: "0", customTitle: nil, signature: nil, friendsCount: 0, repliedThreadsCount: 0, createdThreadsCount: 0, gender: 0, birthday: nil, userGroupName: nil, onlineHours: nil, accountCreationDate: nil, lastOnlineDate: nil, lastActivityDate: nil, timeZone: nil, registerIp: nil, lastActiveIp:nil, usedSpace: nil, points: nil, fightForce: nil, gold: nil, pounchInPoint: nil, mannerPoint: nil)
    
    private var tableCells:[[UITableViewCell]] = []
    
    // account manager mode adds a 'log out' button
    var isAccountManager = false
    var isViewingSelf: Bool {
        if uid == nil {
            return true
        } else {
            return uid!.compare(Account().uid) == .orderedSame
        }
    }
    
    convenience init(url: Foundation.URL) {
        self.init(nibName: nil, bundle: nil)
        
        self.url = url
        let component = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        if let modeQueryItems = component!.queryItems?.filter({ (i) -> Bool in
            return i.name == "uid"
        }) {
            if modeQueryItems.count > 0 {
                self.uid = modeQueryItems[0].value
            }
        }
        
        if let modeQueryItems = component!.queryItems?.filter({ (i) -> Bool in
            return i.name == "do"
        }) {
            if modeQueryItems.count > 0 {
                self.doType = modeQueryItems[0].value
            }
        }
        if self.doType != "favorite" &&
            self.doType != "pm" &&
            self.doType != "thread" &&
            url.lastPathComponent.hasPrefix("space-uid-") {
            //http://bbs.saraba1st.com/2b/space-uid-445568.html
            uid = url.lastPathComponent.components(separatedBy: "-")[2].components(separatedBy: ".")[0]
        }
        
        if uid == nil {
            uid = Account().uid
        }
        
        account.uid = uid!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        tableCells = [
            [SAAccountInfoHeaderCell()], // section 0
            [SAThemedTableViewCell(), SAThemedTableViewCell(), SAThemedTableViewCell(), SAThemedTableViewCell(), SAThemedTableViewCell(), SAThemedTableViewCell(), SAThemedTableViewCell()], // section 1
            [SAThemedTableViewCell(), SAThemedTableViewCell(), SAThemedTableViewCell(), SAThemedTableViewCell(), SAThemedTableViewCell()], // section 2
            [SACenterTitleCell()], // section 3
        ]
        if !isAccountManager {
            tableCells.removeLast()
        }
        
        tableView.estimatedRowHeight = 100
        tableView.sectionFooterHeight = 0
        
        if !isViewingSelf {
            let dmBarItem = UIBarButtonItem(title: "发消息", style: .plain, target: self, action: #selector(SAAccountInfoViewController.handleDmButtonClicked(_:)))
            dmBarItem.isEnabled = false
            self.navigationItem.rightBarButtonItems = [dmBarItem]
        }
        
        #if targetEnvironment(macCatalyst)
        let contextMenuInteraction = UIContextMenuInteraction(delegate: self)
        view.addInteraction(contextMenuInteraction)
        #endif
        
        loadingController.setLoading()
        refreshTableViewCompletion { [weak self] (result, error) in
            guard let self = self else {
                return
            }
            
            if result != .fail {
                self.navigationItem.rightBarButtonItems?.forEach{$0.isEnabled = true}
            }
            self.reloadData()
            // this view controller should never be set to failed state
            self.loadingController.setFinished()
            self.title = self.account.name
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func refreshTableViewCompletion(_ completion: ((SALoadingViewController.LoadingResult, NSError?) -> Void)?) {
        guard self.uid != nil && !self.uid!.isEmpty else {
            let error = NSError.init(domain: SAGeneralErrorDomain, code: -1, userInfo: ["msg":"uid is empty"])
            dispatch_async_main {
                completion?(.fail, error)
            }
            return
        }
        
        URLSession.saCustomized.getUserInfoOf(uid: self.uid!) { [weak self] (bodyStr, error) in
            guard let strongSelf = self else {
                let error = NSError.init(domain: SAGeneralErrorDomain, code: -1, userInfo: ["msg":"request was canceled"])
                dispatch_async_main {
                    completion?(.fail, error)
                }
                return
            }
            
            guard error == nil, let str = bodyStr as? String else {
                let error = NSError.init(domain: SAGeneralErrorDomain, code: -1, userInfo: ["msg":"Bad response"])
                dispatch_async_main {
                    completion?(.fail, error)
                }
                return
            }
            
            guard let parser = try? HTMLParser.init(string: str) else {
                let error = NSError(domain: SAGeneralErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"create parser failed"])
                dispatch_async_main {
                    completion?(.fail, error)
                }
                return
            }
            
            guard let body = parser.body() else {
                let error = NSError(domain: SAGeneralErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"no body"])
                dispatch_async_main {
                    completion?(.fail, error)
                }
                return
            }
            
            guard strongSelf.fillAccountModelWithUserInfoBody(body) else {
                let error = NSError.init(domain: SAGeneralErrorDomain, code: -1, userInfo: ["msg":"unknown response from server"])
                dispatch_async_main {
                    completion?(.fail, error)
                }
                return
            }
            
            dispatch_async_main {
                completion?(.newData, nil)
            }
        }
    }
    
    private func showComposedThreadsViewController() {
        guard let uid = self.uid, !uid.isEmpty else {
            return
        }
        
        let myThreads = SAUserThreadViewController<OthersThreadModel>()
        myThreads.title = String.init(format: NSLocalizedString("OTHERS_THREADS_VC_TITLE", comment: "my threads vc title"), self.account.name)
        
        myThreads.dataFiller = { (model, cell, indexPath) in
            if let title = model.title {
                let threadTitle = title.sa_stringByReplacingHTMLTags() as String
                let attributedTitle = NSMutableAttributedString(string: threadTitle, attributes:[NSAttributedString.Key.font: UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline),NSAttributedString.Key.foregroundColor: UIColor.sa_colorFromHexString(Theme().tableCellTextColor)])
                cell.customTitleLabel.attributedText = attributedTitle
            } else {
                cell.customTitleLabel.attributedText = nil
            }
            
            if let reply = model.replyCount {
                cell.customReplyLabel.text = NSLocalizedString("REPLY", comment: "reply wording") + " " + reply
            }
            
            if let date = model.createDate {
                cell.customTimeLabel.text = date
            }
        }
        
        myThreads.dataInteractor = { [weak self] (vc, model, indexPath) in
            guard let tid = model.tid else {return}
            let link = SAGlobalConfig().forum_base_url + "forum.php?mod=viewthread&tid=\(tid)&page=1&mobile=1&simpletype=no"
            let url = URL(string: link)!
            let contentViewer = SAThreadContentViewController(url: url)
            self?.navigationController?.pushViewController(contentViewer, animated: true)
        }
        
        myThreads.themeUpdator = { (vc) in
            let textColor = UIColor.sa_colorFromHexString(Theme().textColor)
            let placeholder = NSMutableAttributedString()
            placeholder.append(NSAttributedString(string: "无数据\n\n", attributes: [NSAttributedString.Key.font:UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline), NSAttributedString.Key.foregroundColor:textColor]))
            placeholder.append(NSAttributedString(string: "该用户尚未在论坛发表过帖子", attributes: [NSAttributedString.Key.font:UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.subheadline), NSAttributedString.Key.foregroundColor:textColor]))
            vc.loadingController.emptyLabelAttributedTitle = placeholder
        }
        
        URLSession.saCustomized.getThreadsOf(uid: uid) { (content, error) in
            guard error == nil, let str = content as? String else {
                myThreads.loadingController.setFailed(with: error!)
                return
            }
            
            guard let parser = try? HTMLParser.init(string: str) else {
                let error = NSError(domain: SAGeneralErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"create parser failed"])
                myThreads.loadingController.setFailed(with: error)
                return
            }
            
            guard let body = parser.body() else {
                let error = NSError(domain: SAGeneralErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Need login."])
                myThreads.loadingController.setFailed(with: error)
                return
            }
            
            var trs: [HTMLNode] = []
            for bm in body.findChildren(ofClass: "tl") {
                trs.append(contentsOf: bm.findChildTags("tr").filter({ (node) -> Bool in
                    if let class_attr = node.getAttributeNamed("class"), class_attr == "th" {
                        return false
                    }
                    
                    return true
                }))
            }
            
            let nodes = trs
            var models: [OthersThreadModel] = []
            for node in nodes {
                let children = node.children()
                if children.count <= 9 {
                    continue
                }
                
                let title: String? = {() in
                    let cc = children[3].children()
                    if cc.count <= 1 {
                        return nil
                    }
                    
                    return cc[1].contents()
                }()
                
                let tid: String? = {() in
                    let cc = children[3].children()
                    if cc.count <= 1 {
                        return nil
                    }
                    
                    if let href_c = cc[1].getAttributeNamed("href")?.components(separatedBy: "-"), href_c.count > 1 {
                        return href_c[1]
                    }
                    
                    return nil
                }()
                
                let arthor: String? = {() in
                    let cc = children[9].children()
                    if cc.count <= 1 {
                        return nil
                    }
                    
                    let ccc = cc[1].children()
                    if ccc.count == 0 {
                        return nil
                    }
                    
                    return ccc[0].contents()
                }()

                let date: String? = {() in
                    let cc = children[9].children()
                    if cc.count <= 3 {
                        return nil
                    }
                    
                    let ccc = cc[3].children()
                    if ccc.count == 0 {
                        return nil
                    }
                    
                    return ccc[0].contents()
                }()

                let replyCount: String? = {() in
                    let cc = children[7].children()
                    if cc.count <= 3 {
                        return nil
                    }
                    
                    return cc[3].contents()
                }()

                let model = OthersThreadModel.init(tid: tid, title: title, createDate: date, authorName: arthor, replyCount: replyCount)
                models.append(model)
            }
            
            myThreads.fetchedData = models
        }
        
        navigationController?.pushViewController(myThreads, animated: true)
    }
    
    private func fillAccountModelWithUserInfoBody(_ body: HTMLNode) -> Bool {
        let name = body.findChildren(ofClass: "mt").filter({ (node) -> Bool in
            return node.tagName() == "h2"
        }).first?.contents()?.replacingOccurrences(of: "\r\n", with: "")
        
        let groupName = body.findChildren(ofClass: "xi2").filter({ (node) -> Bool in
            return node.tagName() == "span"
        }).first?.allContents()
        
        var onlineTime: String?
        var regTime: String?
        var lastVisit: String?
        var ip: String?
        var last_ip: String?
        var lastActiveTime: String?
        var lastPublicTime: String?
        var zone: String?
        var usedSpace: String?
        var points: String?
        var fightForce: String?
        var gold: String?
        var pounchInPoint: String?
        var mannerPoint: String?
        var signature: String?
        
        let bbda = body.findChildren(ofClass: "pbm mbm bbda cl").filter({ (node) -> Bool in
            return node.tagName() == "div"
        }).first
        
        guard let bbda_ul = bbda?.findChildTags("ul") else {
            return false
        }
        
        bbda_ul.forEach({ (node) in
            let children = node.children().filter({ (node) -> Bool in
                return node.tagName() == "li"
            })
            
            children.forEach({ (node) in
                let children = node.children()
                guard children.count > 1 else {return}
                
                guard let keyName = children[0].contents(), let value = children[1].allContents() else {return}
                
                if keyName == "个人签名  " {
                    signature = value
                }
            })
        })
        
        guard let psts = body.getElementById("psts")?.findChildTags("li"), let lis = body.getElementById("pbbs")?.findChildTags("li") else {
            return false
        }
        
        (psts + lis).forEach({ (node) in
            let children = node.children()
            guard children.count > 1 else {return}
            guard let keyName = children[0].contents(), let value = children[1].allContents() else {return}
            
            if keyName == "在线时间" {
                onlineTime = value
            } else if keyName == "注册时间" {
                regTime = value
            } else if keyName == "最后访问" {
                lastVisit = value
            } else if keyName == "注册 IP" {
                ip = value
            } else if keyName == "上次访问 IP" {
                last_ip = value
            } else if keyName == "上次活动时间" {
                lastActiveTime = value
            } else if keyName == "上次发表时间" {
                lastPublicTime = value
            } else if keyName == "上所在时区" {
                zone = value
            }
                 else if keyName == "已用空间" {
                usedSpace = value
            } else if keyName == "积分" {
                points = value
            } else if keyName == "战斗力" {
                fightForce = value
            } else if keyName == "金币" {
                gold = value
            } else if keyName == "签到" {
                pounchInPoint = value
            } else if keyName == "人品" {
                mannerPoint = value
            }
        })
        
        self.account.name = name!
        self.account.accountCreationDate = regTime
        self.account.lastActivityDate = lastVisit
        self.account.registerIp = ip
        self.account.lastActiveIp = last_ip
        self.account.userGroupName = groupName
        self.account.onlineHours = onlineTime
        self.account.lastOnlineDate = lastActiveTime
        self.account.lastActivityDate = lastPublicTime
        self.account.timeZone = zone
        self.account.usedSpace = usedSpace
        self.account.points = points
        self.account.pounchInPoint = pounchInPoint
        self.account.fightForce = fightForce
        self.account.gold = gold
        self.account.mannerPoint = mannerPoint
        self.account.signature = signature
        return true
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableCells.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let arr = tableCells[section]
        return arr.count
    }
    
    @objc func handleHeaderViewThreadButtonClick(_ sender: UIButton) {
        showComposedThreadsViewController()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableCells[indexPath.section][indexPath.row] as! SAAccountInfoHeaderCell
            
            if let url = URL(string: SAGlobalConfig().avatar_base_url + "avatar.php?uid=\(self.uid!)&size=middle") {
                UIApplication.shared.showNetworkIndicator()
                URLSession.saCustomized.dataTask(with: url, completionHandler: { (data, response, error) in
                    UIApplication.shared.hideNetworkIndicator()
                    guard error == nil && data != nil else {
                        os_log("image download failed", type: .error)
                        return
                    }
                    
                    if let image = UIImage(data: data!) {
                        DispatchQueue.main.async(execute: {
                            cell.avatarImageView.image = image
                        })
                    }
                    
                }).resume()
            }
            cell.viewThreadsButton.isHidden = isViewingSelf
            cell.viewThreadsButton.addTarget(self, action: #selector(handleHeaderViewThreadButtonClick(_:)), for: .touchUpInside)
        } else if indexPath.section == 3 {
            let centerTitleCell = tableCells[indexPath.section][indexPath.row] as! SACenterTitleCell
            centerTitleCell.customLabel.text = "退出登录"
            return centerTitleCell
        }
        
        let cell = tableCells[indexPath.section][indexPath.row] as! SAThemedTableViewCell
        cell.selectionStyle = .none
        cell.accessoryType = .none
        
        cell.textLabel?.text = nil
        cell.detailTextLabel?.text = nil
        
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                cell.textLabel?.text = "用户名"
                cell.detailTextLabel?.text = account.name
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "用户组"
                cell.detailTextLabel?.text = account.userGroupName
            } else if indexPath.row == 2 {
                cell.textLabel?.text = "阅读权限"
            } else if indexPath.row == 3 {
                cell.textLabel?.text = "注册时间"
                if let date = account.accountCreationDate {
                    cell.detailTextLabel?.text = date
                }
            } else if indexPath.row == 4 {
                cell.textLabel?.text = "在线时间"
                cell.detailTextLabel?.text = account.onlineHours
            } else if indexPath.row == 5 {
                cell.textLabel?.text = "最后访问"
                if let date = account.lastOnlineDate {
                    cell.detailTextLabel?.text = date
                }
            } else if indexPath.row == 6 {
                cell.textLabel?.text = "上次发表"
                if let date = account.lastActivityDate {
                    cell.detailTextLabel?.text = date
                }
            }
        } else if indexPath.section == 2 {
            if indexPath.row == 0 {
                cell.textLabel?.text = "积分"
                cell.detailTextLabel?.text = account.points
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "战斗力"
                cell.detailTextLabel?.text = account.fightForce
            } else if indexPath.row == 2 {
                cell.textLabel?.text = "签到"
                cell.detailTextLabel?.text = account.pounchInPoint
            } else if indexPath.row == 3 {
                cell.textLabel?.text = "金币"
                //I think the key name `conisbind` is misspelled, I thought it should be `coinsbind`
                cell.detailTextLabel?.text = account.gold
            } else if indexPath.row == 4 {
                cell.textLabel?.text = "个性签名"
                cell.detailTextLabel?.text = account.signature
            }
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 120
        }
        
        if indexPath.section == 2 && indexPath.row == 4 {
            if let sig = account.signature {
                let size = sig.boundingRect(with: CGSize(width: 200, height: 1000000), options: [.usesFontLeading, .usesLineFragmentOrigin], attributes: [NSAttributedString.Key.font : UIFont.sa_preferredFont(forTextStyle: .headline)], context: nil).size
                return ceil(size.height) + 32
            }
        }
        
        let height = UIFont.sa_preferredFont(forTextStyle: .headline).pointSize + 32
        return height
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.section == 3, let centerTitleCell = cell as? SACenterTitleCell {
            centerTitleCell.customLabel.textColor = UIColor.red
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 3 {
            if indexPath.row == 0 {
                tableView.deselectRow(at: indexPath, animated: true)
                let alert = UIAlertController(title: "确定要退出当前账号吗？", message: "退出账号不会清除数据和设置。", preferredStyle: .actionSheet)
                alert.modalPresentationStyle = .fullScreen
                
                alert.popoverPresentationController?.sourceView = tableView.tableFooterView
                alert.popoverPresentationController?.sourceRect = tableView.tableFooterView?.bounds ?? .zero
                
                let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel) { (action) in
                    
                }
                alert.addAction(cancelAction)
                
                let threadAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .destructive){ (action) in
                    AppController.current.getService(of: SAAccountManager.self)!.logoutCurrentActiveAccount({ () in
                        self.tableCells.removeLast()
                        self.tableView.reloadData()
                        self.navigationController?.popViewController(animated: true)
                    })
                }
                alert.addAction(threadAction)
                present(alert, animated: true, completion: nil)
            }
        }
    }
    
    @objc func handleDmButtonClicked(_: AnyObject) {
        if Account().isGuest {
            let alert = UIAlertController(title: "提示", message: "登录之后才能发送消息，是否现在登录？", preferredStyle: .alert)
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            
            let threadAction = UIAlertAction(title: "登录", style: .default){ (action) in
                AppController.current.presentLoginViewController(sender: self, completion: nil)
            }
            alert.addAction(threadAction)
            present(alert, animated: true, completion: nil)
            return
        }
        
        let touid = self.uid!
        let tousername = account.name.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? "未知昵称"
        let pmnum = "0"
        let url = Foundation.URL(string: SAGlobalConfig().forum_base_url + "home.php?mod=spacecp&ac=pm&touid=\(touid)&mobile=1&tousername=\(tousername)&pmnum=\(pmnum)")!
        let dm = SAMessageCompositionViewController(url: url)
        navigationController?.pushViewController(dm, animated: true)
    }
    
    @objc func handleDismiss() {
        navigationController?.dismiss(animated: true, completion: nil)
    }
}

#if targetEnvironment(macCatalyst)
@available(iOS 13.0, *)
extension SAAccountInfoViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        
        let action: UIContextMenuActionProvider = { (menu) in
            let action1 = UIAction(title: "发送消息", image: UIImage.imageWithSystemName("eye.slash", fallbackName: ""), identifier: nil, discoverabilityTitle: nil, attributes: .init(rawValue: 0), state: .off) { [weak self] (action) in
                guard let self = self else { return }
                
                self.perform(#selector(SAAccountInfoViewController.handleDmButtonClicked(_:)), with: nil)
            }
            
            let amenu = UIMenu(title: "可选操作", image: nil, identifier: nil, options: .init(rawValue: 0), children: [action1])
            return amenu
        }
        
        let contextMenuConfiguration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: action)
        return contextMenuConfiguration
    }
}
#endif
