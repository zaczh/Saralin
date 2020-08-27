//
//  SALoginViewController.swift
//  Saralin
//
//  Created by zhang on 02/02/2018.
//  Copyright © 2018 zaczh. All rights reserved.
//

import UIKit

class SALoginViewController: SABaseViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    private var urlSession: URLSession!
    class FormCell: UITableViewCell {
        let label = UILabel()
        let textField = UITextField()
        
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            contentView.addSubview(label)
            label.textColor = UIColor.darkGray
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.3
            label.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
            label.widthAnchor.constraint(equalToConstant: 60).isActive = true
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        
            contentView.addSubview(textField)
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 80).isActive = true
            textField.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
            textField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    @IBOutlet var loginButtonBottomConstraint: NSLayoutConstraint!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var loginButton: UIButton!
    @IBOutlet var formTable: UITableView!
    
    @IBOutlet var forumDomainLabel: UILabel!
    @IBAction func handleViewTap(_ sender: UITapGestureRecognizer) {
        _ = resignFirstResponder()
    }
    
    @IBAction func handleLoginAction(_ sender: Any) {
        doLogin()
    }
    
    private func doLogin() {
        _ = resignFirstResponder()
        loadingIndicator.startAnimating()
        loginButton.isHidden = true
        guard let username = cells[0].textField.text, let password = cells[1].textField.text else { return }
        let credential = CredentialInfo(username: username, password: password)

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 15
        urlSession = URLSession.init(configuration: sessionConfig)
        UIApplication.shared.showNetworkIndicator()
        urlSession.login(username: username, password: password) { [weak self] (content, error) in
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
            
            guard let _ = parser.body()?.findChild(withAttribute: "title", matchingName: "退出", allowPartial: true) else {
                sa_log_v2("[Login] login failed")
                if let jump_c = parser.body()?.findChild(withAttribute: "class", matchingName: "jump_c", allowPartial: true),
                    jump_c.children().count > 1, let p = jump_c.children()[1].contents(), !p.isEmpty {
                    failing(p)
                    return
                }
                
                failing("服务器返回数据缺少关键信息。")
                return
            }
            
            guard let self = self else {
                return
            }
            
            
            let group = DispatchGroup()
            var loginV2Obj: AnyObject?
            group.enter()
            self.urlSession.loginV2(username: username, password: password) { (loginV2Result, error) in
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
                self.cells[1].textField.text = account.password
                self.textFieldTextChanged()
            }))
        }

        if alert.actions.count > 1 {
            navigationController?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func parseUserInfoObj(_ obj: AnyObject, objv2: AnyObject, credential: CredentialInfo) {
        let error = AppController.current.getService(of: SAAccountManager.self)!.parseAccountInfoResponse(obj, loginV2Response: objv2, credential: credential)
        if error != nil {
            sa_log_v2("[Login Web] parse account info failed error: %@", module: .ui, type: .error, error! as CVarArg)
            self.loginFailed(nil)
            return
        }
        
        self.loginSucceeded()
        sa_log_v2("[Login] xhr result OK", module: .ui, type: .info)
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
        
        forumDomainLabel.text = SAGlobalConfig().forum_domain
        
        if #available(iOS 11.0, *) {
            formTable.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
        formTable.isScrollEnabled = false
        formTable.dataSource = self
        formTable.delegate = self
        formTable.layer.cornerRadius = 12.0
        formTable.layer.borderWidth = 1.0
        formTable.layer.borderColor = UIColor(red: 0x33/255.0, green: 0x33/255.0, blue: 0x33/255.0, alpha: 0x33/255.0).cgColor
        formTable.layer.masksToBounds = true
        formTable.rowHeight = 55
        
        let usernameCell = FormCell(style: .default, reuseIdentifier: nil)
        usernameCell.label.text = "用户名"
        if #available(iOS 11.0, *) {
            usernameCell.textField.textContentType = .username
        }
        usernameCell.textField.autocorrectionType = .no
        usernameCell.textField.autocapitalizationType = .none
        usernameCell.textField.returnKeyType = .next
        usernameCell.textField.delegate = self
        usernameCell.separatorInset = .zero
        cells.append(usernameCell)
        
        let password = FormCell(style: .default, reuseIdentifier: nil)
        password.label.text = "密码"
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
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: nil)
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        loginButton.titleLabel?.font = UIFont.sa_preferredFont(forTextStyle: .headline)
    }
    
    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if cells[0].textField.isFirstResponder {
            cells[1].textField.becomeFirstResponder()
            return true
        } else if cells[1].textField.isFirstResponder {
            if cells[0].textField.text?.isEmpty ?? true || cells[1].textField.text?.isEmpty ?? true {
                return false
            }
            
            DispatchQueue.main.async {
                self.doLogin()
            }
            return true
        }
        
        return false
    }
    
    private func loginSucceeded() {
        navigationController?.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    //keyboard events
    @objc func handleKeyboardWillShow(_ notification: Notification) {
        if !cells[0].textField.isFirstResponder && !cells[1].textField.isFirstResponder {
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
        UIView.beginAnimations("", context: nil)
        UIView.setAnimationDuration((notification.userInfo![UIResponder.keyboardAnimationDurationUserInfoKey]! as AnyObject).doubleValue)
        UIView.setAnimationCurve(UIView.AnimationCurve(rawValue: ((notification as NSNotification).userInfo![UIResponder.keyboardAnimationCurveUserInfoKey]! as AnyObject).intValue)!)
        view.layoutIfNeeded()
        UIView.commitAnimations()
    }
    
    @objc func handleKeyboardWillHide(_ notification: Notification) {
        if !cells[0].textField.isFirstResponder && !cells[1].textField.isFirstResponder {
            return
        }
        
        guard view.window != nil else {
            return
        }
        
        loginButtonBottomConstraint.constant = 0
        view.setNeedsUpdateConstraints()
        UIView.beginAnimations("", context: nil)
        UIView.setAnimationDuration((notification.userInfo![UIResponder.keyboardAnimationDurationUserInfoKey]! as AnyObject).doubleValue)
        UIView.setAnimationCurve(UIView.AnimationCurve(rawValue: (notification.userInfo![UIResponder.keyboardAnimationCurveUserInfoKey]! as AnyObject).intValue)!)
        view.layoutIfNeeded()
        UIView.commitAnimations()
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
            sa_log_v2("[Login] register open", module: .ui, type: .info)
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
        guard textField.isEqual(cells[0].textField) || textField.isEqual(cells[1].textField) else {return}
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
}
