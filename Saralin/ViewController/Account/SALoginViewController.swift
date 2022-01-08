//
//  SALoginViewController.swift
//  Saralin
//
//  Created by zhang on 02/02/2018.
//  Copyright © 2018 zaczh. All rights reserved.
//

import UIKit

class SALoginViewController: SABaseViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    private let rowHeight: CGFloat = 55.0

    private var urlSession: URLSession!
    class FormCell: UITableViewCell {
        let label = UILabel()
        let textField = UITextField()
        
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            
            clipsToBounds = true
            contentView.addSubview(label)
            label.textColor = UIColor.darkGray
            label.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
            label.widthAnchor.constraint(equalToConstant: 120).isActive = true
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        
            contentView.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.leftAnchor.constraint(equalTo: label.rightAnchor, constant: 10).isActive = true
            textField.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    // the id list file
    private let questionIdList: Dictionary<String, String> = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "security_question_ids", ofType: "plist")!)! as! Dictionary<String, String>
    
    @IBOutlet var loginButtonBottomConstraint: NSLayoutConstraint!
    @IBOutlet var tableHeightConstraint: NSLayoutConstraint!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var loginButton: UIButton!
    @IBOutlet var formTable: UITableView!
    @IBOutlet var forumLogoImageView: UIImageView!
    @IBOutlet weak var webLoginButton: UIButton!
    
    @IBAction func handleViewTap(_ sender: UITapGestureRecognizer) {
        _ = resignFirstResponder()
    }
    
    @IBAction func handleLoginAction(_ sender: Any) {
        AppController.current.getService(of: SAAccountManager.self)?.logoutCurrentActiveAccount({
            self.doLogin()
        })
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let tableHeight = formTable.contentSize.height
        tableHeightConstraint.constant = tableHeight
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
                    item.title = t
                }
            }
        }
    }
    #endif
    
    @IBAction func handleWebLoginAction(_ sender: Any) {
        let webLogin = SAWebLoginViewController()
        navigationController?.pushViewController(webLogin, animated: true)
    }
    
    private func doLogin() {
        _ = resignFirstResponder()
        loadingIndicator.startAnimating()
        loginButton.isHidden = true
        
        let securityQuesionId = cells[1].textField.tag
        guard let username = cells[0].textField.text,
              let password = cells[3].textField.text else {
            sa_log_v2("login form info not full", log: .account, type: .info)
            return
        }
        
        let securityAnswer = cells[2].textField.text ?? ""
        if securityQuesionId != 0 && securityAnswer.isEmpty {
            sa_log_v2("login form info not full", log: .account, type: .info)
            return
        }
        
        let credential = CredentialInfo(username: username, password: password, questionid: "\(securityQuesionId)", answer: securityAnswer)
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 15
        urlSession = URLSession.init(configuration: sessionConfig)
        UIApplication.shared.showNetworkIndicator()
        sa_log_v2("delete account cookie before doing login", log: .account, type: .info)
        AppController.current.getService(of: SAAccountManager.self)!.clearCookie {
            self.urlSession.login(username: username, password: password, questionid: "\(securityQuesionId)", answer: securityAnswer) { [weak self] (content, error) in
                let failing : ((String?) -> Void) = { (reason) in
                    guard let self = self else {
                        return
                    }
                    self.loadingIndicator.stopAnimating()
                    self.loginButton.isHidden = false
                    self.loginFailed(reason)
                }
                
                guard error == nil else {
                    failing(error!.localizedDescription)
                    return
                }
                
                guard let str = content as? String else {
                    failing("服务器返回数据为空。")
                    return
                }
                
                guard let parser = try? HTMLParser.init(string: str) else {
                    sa_log_v2("[Login] login parser initializing failed")
                    failing("无法识别服务器返回数据格式。")
                    return
                }
                
                if parser.body()?.children().count ?? 0 == 0 {
                    sa_log_v2("[Login] login xml format not recognized")
                    failing("服务器数据格式错误。")
                    return
                }
                
                let rootElement = parser.body()!.children()[0]
                let rootContent = rootElement.contents() ?? ""
                
                guard rootContent.contains("succeedhandle_login") else {
                    // handling login failure
                    // response demo:
                    /*
                    "if(typeof errorhandle_login==\'function\') {errorhandle_login(\'登录失败，您还可以尝试 3 次\', {\'loginperm\':\'3\'});}]]>"
                    */
                    
                    sa_log_v2("[Login] login failed")
                    if rootContent.contains("errorhandle_login") {
                        let tips_start = rootContent.range(of: "errorhandle_login(\'")!.upperBound
                        var tips_end = tips_start
                        var index = tips_start
                        while index != rootContent.endIndex {
                            if String(rootContent[index]) == "\'" {
                                tips_end = index
                                break
                            }
                            index = rootContent.index(index, offsetBy: 1)
                        }
                        
                        let tips = rootContent[tips_start ..< tips_end]
                        if !tips.isEmpty {
                            failing(String(tips))
                            return
                        }
                        
                        sa_log_v2("no tips info.")
                    }
                    
                    failing("服务器返回数据缺少关键信息。")
                    return
                }
                
                // handling login success
                //
                /*
                 if(typeof succeedhandle_login==\'function\') {succeedhandle_login(\'https://bbs.saraba1st.com/2b/thread-1956764-1-1.html\', \'欢迎您回来，火球法师 redlips，现在将转入登录前页面\', {\'username\':\'redlips\',\'usergroup\':\'火球法师\',\'uid\':\'445568\',\'groupid\':\'49\',\'syn\':\'0\'});}hideWindow(\'login\');showDialog(\'欢迎您回来，火球法师 redlips，现在将转入登录前页面\', \'right\', null, function () { window.location.href =\'https://bbs.saraba1st.com/2b/thread-1956764-1-1.html\'; }, 0, null, null, null, null, null, 3);]]>
                 */
                
                guard let self = self else {
                    return
                }
                
                let group = DispatchGroup()
                var loginV2Obj: AnyObject?
                group.enter()
                self.urlSession.loginV2(username: username, password: password, questionid: "\(securityQuesionId)", answer: securityAnswer) { (loginV2Result, error) in
                    defer {
                        group.leave()
                    }
                    
                    guard error == nil, let loginV2Result = loginV2Result else {
                        return
                    }
                    
                    loginV2Obj = loginV2Result
                }
                
                group.enter()
                var loginObject: AnyObject?
                self.urlSession.auth { (obj, error) in
                    defer {
                        group.leave()
                    }
                    
                    UIApplication.shared.hideNetworkIndicator()
                    guard error == nil, let obj = obj else {
                        return
                    }
                    
                    loginObject = obj
                }
                
                group.notify(queue: .main) {
                    guard let obj = loginObject, let objv2 = loginV2Obj else {
                        failing("获取用户信息失败")
                        return
                    }
                    self.parseUserInfoObj(obj, objv2: objv2, credential: credential)
                }
            }
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    private func showAutoFill() {
        let savedAccounts = SAKeyChainService.loadAllCredentials()
        if savedAccounts.isEmpty {return}
        
        let alert = UIAlertController(title: NSLocalizedString("AUTO_FILL_ACCOUNT_EXIST", comment: ""), message: NSLocalizedString("AUTO_FILL_ACCOUNT_IF_AUTO_FILL", comment: ""), preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = formTable
        alert.popoverPresentationController?.sourceRect = formTable.bounds
        alert.popoverPresentationController?.permittedArrowDirections = [.up]
        alert.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))
        for account in savedAccounts {
            alert.addAction(UIAlertAction(title: account.username, style: .default, handler: { (action) in
                self.cells[0].textField.text = account.username
                if !account.questionid.isEmpty {
                    self.cells[1].textField.tag = Int(account.questionid) ?? 0
                    self.cells[1].textField.text = self.questionIdList[account.questionid]
                }
                self.cells[2].textField.text = account.answer
                self.cells[3].textField.text = account.password
                self.textFieldTextChanged()
                self.formTable.reloadData()
                self.view.setNeedsLayout()
            }))
        }

        if alert.actions.count > 1 {
            navigationController?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func parseUserInfoObj(_ obj: AnyObject, objv2: AnyObject, credential: CredentialInfo) {
        let error = AppController.current.getService(of: SAAccountManager.self)!.parseAccountInfoResponse(obj, loginV2Response: objv2, credential: credential)
        if error != nil {
            sa_log_v2("[Login Web] parse account info failed error: %@", log: .ui, type: .error, error! as CVarArg)
            self.loginFailed(nil)
            return
        }
        
        self.loginSucceeded()
        sa_log_v2("[Login] xhr result OK", log: .ui, type: .info)
    }
    
    private var cells: [FormCell] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = NSLocalizedString("LOGIN", comment: "Login")
        
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
        
        let leftItem = UIBarButtonItem(title: NSLocalizedString("CLOSE", comment: "关闭"), style: .plain, target: self, action: #selector(handleCloseButtonItemClick(_:)))
        let rightItem = UIBarButtonItem(title: NSLocalizedString("REGISTER", comment: "注册"), style: .plain, target: self, action: #selector(handleRegisterButtonItemClick(_:)))
        navigationItem.leftBarButtonItems = [leftItem]
        navigationItem.rightBarButtonItems = [rightItem]
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)
        
        titleLabel.text = SAGlobalConfig().forum_domain
        
        if let forumLogoURL = URL(string: SAGlobalConfig().forum_logo_image_url) {
            forumLogoImageView.sa_setImage(with: forumLogoURL)
        }
                
        if #available(iOS 11.0, *) {
            formTable.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
        formTable.dataSource = self
        formTable.delegate = self
        formTable.layer.cornerRadius = 12.0
        formTable.layer.borderWidth = 1.0
        formTable.layer.borderColor = UIColor(red: 0x33/255.0, green: 0x33/255.0, blue: 0x33/255.0, alpha: 0x33/255.0).cgColor
        formTable.layer.masksToBounds = true
        
        let usernameCell = FormCell(style: .default, reuseIdentifier: nil)
        usernameCell.label.text = NSLocalizedString("USER_NAME", comment: "User name")
        if #available(iOS 11.0, *) {
            usernameCell.textField.textContentType = .username
        }
        usernameCell.textField.autocorrectionType = .no
        usernameCell.textField.autocapitalizationType = .none
        usernameCell.textField.returnKeyType = .next
        usernameCell.textField.delegate = self
        usernameCell.separatorInset = .zero
        cells.append(usernameCell)
        
        let questionidCell = FormCell(style: .default, reuseIdentifier: nil)
        questionidCell.label.text = NSLocalizedString("LOGIN_FORM_SECURITY_QUESTION", comment: "Security Question")
        questionidCell.textField.delegate = self
        questionidCell.textField.text = questionIdList["0"]
        questionidCell.separatorInset = .zero
        cells.append(questionidCell)
        
        let questionAnswerCell = FormCell(style: .default, reuseIdentifier: nil)
        questionAnswerCell.label.text = NSLocalizedString("LOGIN_FORM_SECURITY_QUESTION_ANSWER", comment: "Answer")
        questionAnswerCell.textField.delegate = self
        questionAnswerCell.separatorInset = .zero
        cells.append(questionAnswerCell)
        
        let password = FormCell(style: .default, reuseIdentifier: nil)
        password.label.text = NSLocalizedString("PASSWORD", comment: "Password")
        if #available(iOS 11.0, *) {
            password.textField.textContentType = .password
        }
        password.textField.isSecureTextEntry = true
        password.textField.delegate = self
        password.textField.returnKeyType = .go
        password.separatorInset = UIEdgeInsets(top: 0, left: 1000, bottom: 0, right: 0)
        cells.append(password)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleTextFieldTextChange(_:)), name:UITextField.textDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        DispatchQueue.main.async {
            self.showAutoFill()
        }
    }
    
    deinit {
        sa_log_v2("[Login] deinit", log: .ui, type: .info)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: nil)
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        loginButton.setTitleColor(newTheme.textColor.sa_toColor(), for: .normal)
        webLoginButton.setTitleColor(newTheme.textColor.sa_toColor(), for: .normal)
    }
    
    override func viewFontDidChange(_ newTheme: SATheme) {
        super.viewFontDidChange(newTheme)
        loginButton.titleLabel?.font = UIFont.sa_preferredFont(forTextStyle: .headline)
        webLoginButton.titleLabel?.font = UIFont.sa_preferredFont(forTextStyle: .subheadline)
    }
    
    @objc func handleTap(_ tap: UITapGestureRecognizer) {
        let position = tap.location(in: formTable)
        if formTable.bounds.contains(position) {
            return
        }
        _ = resignFirstResponder()
    }
    
    // MARK: - UITextFieldDelegate
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField == cells[1].textField {
            showSecurityQuestionPickerAlert(textField)
            return false
        }
        
        return true
    }
    
    private func showSecurityQuestionPickerAlert(_ textField: UITextField) {
        let alert = UIAlertController(title: NSLocalizedString("HINT", comment: "Hint"), message: "选择一个安全问题", preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = textField
        alert.popoverPresentationController?.sourceRect = textField.bounds
        let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel) { (action) in
        }
        alert.addAction(cancelAction)
        
        let keys = questionIdList.keys.sorted { (first, second) -> Bool in
            return Int(first)! < Int(second)!
        }
        for index in keys {
            let name = questionIdList["\(index)"]
            let action = UIAlertAction(title: name, style: .default) { (action) in
                self.cells[1].textField.tag = Int(index)!
                self.cells[1].textField.text = name
                self.formTable.reloadData()
                self.view.setNeedsLayout()
            }
            alert.addAction(action)
        }
        present(alert, animated: true, completion: nil)
    }
    
    private func loginSucceeded() {
        if UIApplication.shared.supportsMultipleScenes {
            guard let sceneSession = self.view.window?.windowScene?.session else {
                sa_log_v2("request scene session destruction no session", log: .ui, type: .error)
                return
            }
            
            let options = UIWindowSceneDestructionRequestOptions()
            options.windowDismissalAnimation = .commit
            UIApplication.shared.requestSceneSessionDestruction(sceneSession, options: options, errorHandler: { (error) in
                sa_log_v2("request scene session destruction returned: %@", error.localizedDescription)
            })
        } else {
            navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
        }
    }
    
    //keyboard events
    @objc func handleKeyboardWillShow(_ notification: Notification) {
        if !cells[0].textField.isFirstResponder && !cells[2].textField.isFirstResponder && !cells[3].textField.isFirstResponder {
            return
        }
        
        guard view.window != nil else {
            return
        }
        
        let keyboardFrame = (notification.userInfo![UIResponder.keyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue!
        let keyboardLocalFrame = view.convert(keyboardFrame, from: nil)
        let offset = max(0, view.bounds.height - keyboardLocalFrame.origin.y)
        loginButtonBottomConstraint.constant = offset
        view.setNeedsUpdateConstraints()
        let duration = ((notification as NSNotification).userInfo![UIResponder.keyboardAnimationDurationUserInfoKey]! as AnyObject).doubleValue ?? 0
        let option: UIView.AnimationOptions = getAnimationCurveOption(notification as NSNotification)
        UIView.animate(withDuration: duration, delay: 0, options: option) {
            self.view.layoutIfNeeded()
        } completion: { (finished) in
        }
    }
    
    private func getAnimationCurveOption(_ keyboardNotifcation: NSNotification) -> UIView.AnimationOptions {
        let curve = UIView.AnimationCurve(rawValue: (keyboardNotifcation.userInfo![UIResponder.keyboardAnimationCurveUserInfoKey]! as AnyObject).intValue)!
        var option: UIView.AnimationOptions = .curveLinear
        switch curve {
        case .easeIn:
            option = .curveEaseIn
            break
        case .easeInOut:
            option = .curveEaseInOut
            break
        case .easeOut:
            option = .curveEaseOut
            break
        case .linear:
            option = .curveLinear
            break
        default:
            break
        }
        return option
    }
    
    @objc func handleKeyboardWillHide(_ notification: Notification) {
        if !cells[0].textField.isFirstResponder && !cells[2].textField.isFirstResponder && !cells[3].textField.isFirstResponder {
            return
        }
        
        guard view.window != nil else {
            return
        }
        
        loginButtonBottomConstraint.constant = 0
        view.setNeedsUpdateConstraints()
        let duration = ((notification as NSNotification).userInfo![UIResponder.keyboardAnimationDurationUserInfoKey]! as AnyObject).doubleValue ?? 0
        let option: UIView.AnimationOptions = getAnimationCurveOption(notification as NSNotification)
        UIView.animate(withDuration: duration, delay: 0, options: option) {
            self.view.layoutIfNeeded()
        } completion: { (finished) in
        }
    }
    
    @objc func handleCloseButtonItemClick(_ sender: AnyObject) {
        if let presenting = navigationController?.presentingViewController {
            presenting.dismiss(animated: true, completion: nil)
        } else if let presenting = presentingViewController {
            presenting.dismiss(animated: true, completion: nil)
        } else {
            _ = navigationController?.popViewController(animated: true)
        }
    }
    
    @objc func handleRegisterButtonItemClick(_ sender: AnyObject) {
        let url = URL(string: SAGlobalConfig().register_url)!
        UIApplication.shared.open(url, options: [:]) { (succeeded) in
            sa_log_v2("[Login] register open", log: .ui, type: .info)
        }
    }
    
    private func loginFailed(_ reason: String?) {
        let alert = UIAlertController(title: nil, message: reason ?? "登录失败", preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = formTable
        alert.popoverPresentationController?.sourceRect = formTable.bounds
        let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    @objc func handleTextFieldTextChange(_ notification: Notification) {
        guard let textField = notification.object as? UITextField else {return}
        guard textField.isEqual(cells[0].textField) ||
                textField.isEqual(cells[1].textField) ||
                textField.isEqual(cells[2].textField) ||
                textField.isEqual(cells[3].textField) else {return}
        textFieldTextChanged()
    }
    
    private func textFieldTextChanged() {
        if cells[0].textField.text?.isEmpty ?? true || cells[1].textField.text?.isEmpty ?? true {
            loginButton.isEnabled = false
            return
        }
        
        loginButton.isEnabled = true
    }
    
    override func resignFirstResponder() -> Bool {
        cells.forEach({$0.textField.resignFirstResponder()})
        return super.resignFirstResponder()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.row]
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 2 {
            let securityQuesionId = cells[1].textField.tag
            return securityQuesionId != 0 ? rowHeight : 0
        }
        return rowHeight
    }
}
