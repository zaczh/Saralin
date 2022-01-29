//
//  SAWebLoginViewController.swift
//  Saralin
//
//  Created by zhang on 5/14/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import WebKit
import SafariServices

class SAWebLoginViewController: SABaseViewController {
    private var webView: WKWebView!
    private var savedFormRecords: CredentialInfo?
    private var webViewKvoContext: String?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
        
        let config = WKWebViewConfiguration()
        config.processPool = WKProcessPool()
        config.userContentController.add(SALoginWebviewScriptMessageHandler(viewController: self), name: "login")
        config.userContentController.addUserScript(WKUserScript.init(source: "" +
            "var form = document.forms[0];" +
            "var originalOnsubmit = form.onsubmit;" +
            "form.querySelector(\"input[name='cookietime']\").checked = true;" +
            "form.onsubmit = function(e) {" +
            "var username = form.querySelector(\"input[name='username']\").value;" +
            "var password = form.querySelector(\"input[name='password']\").value;" +
            "if (username == null || username.length == 0) {" +
            "    alert('用户名不能为空');" +
            "    return false;" +
            "}" +
            "if (password == null || password.length == 0) {" +
            "    alert('密码不能为空');" +
            "    return false;" +
            "}" +
            "var questionid = form.querySelector(\"select[name='questionid']\").value;" +
            "var answer = form.querySelector(\"input[name='answer']\").value;" +
            "" +
            "window.webkit.messageHandlers.login.postMessage({'action':'submit','data':{'username':username,'password':password,'questionid':questionid,'answer':answer}});" +
            "return originalOnsubmit(e);" +
            "};", injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = SAGlobalConfig().mobile_useragent_string
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        if #available(iOS 11.0, *) {
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        } else {
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
            webView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        }

        let rightItem = UIBarButtonItem(title: NSLocalizedString("REGISTER", comment: "注册"), style: .plain, target: self, action: #selector(SAWebLoginViewController.handleRegisterButtonItemClicked(_:)))
        navigationItem.rightBarButtonItems = [rightItem]
        title = NSLocalizedString("LOGIN", comment: "Login")
        
        sa_log_v2("delete account cookie before doing login", log: .account, type: .info)
        AppController.current.getService(of: SAAccountManager.self)!.logoutCurrentActiveAccount {
            self.reloadWebPage()
        }
    }
    
    private var doCheckingWhenLoadingFinished = false
    private func reloadWebPage() {
        doCheckingWhenLoadingFinished = false
        title = NSLocalizedString("LOGIN", comment: "Login")
        navigationItem.leftBarButtonItems = nil
        let loginUrl = URL(string: SAGlobalConfig().login_url)!
        webView.load(URLRequest.init(url: loginUrl))
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent != nil {
            if webViewKvoContext == nil {
                webViewKvoContext = ""
                webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: [.new], context: &webViewKvoContext)
            }
        } else {
            if webViewKvoContext != nil {
                webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), context: &webViewKvoContext)
            }
        }
    }
    
    deinit {
        sa_log_v2("[Login Web] deinit", log: .ui, type: .info)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func loginFailed() {
        let alert = UIAlertController(title: "", message: "登录失败，请重试", preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = webView
        alert.popoverPresentationController?.sourceRect = webView.bounds
        alert.popoverPresentationController?.permittedArrowDirections = [.up]
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: { (action) in
            self.reloadWebPage()
        }))
        navigationController?.present(alert, animated: true, completion: nil)
    }
    
    fileprivate func loginSucceeded() {
        let viewController = navigationController?.presentingViewController
        viewController?.dismiss(animated: true, completion: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &webViewKvoContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        guard let change = change, let isLoading = change[.newKey] as? Bool else {
            return
        }
        
        guard !isLoading else {
            sa_log_v2("[Login Web] still loading", log: .ui, type: .info)
            return
        }
        
        if !doCheckingWhenLoadingFinished {
            sa_log_v2("[Login Web] ignore finish loading", log: .ui, type: .info)
            return
        }
        // login succeeded
        sa_log_v2("[Login Web] login succeeded", log: .ui, type: .info)
        let fetchAccountInfoUrl = URL(string: "api/mobile/index.php?module=login", relativeTo: URL(string: SAGlobalConfig().forum_base_url)!)!
        webView!.evaluateJavaScript("var url = '\(fetchAccountInfoUrl.absoluteString)';" +
            "var oReq = new XMLHttpRequest();" +
            "oReq.onload = function(e) {" +
            "    if (oReq.responseText != null) {" +
            "        window.webkit.messageHandlers.login.postMessage({'action':'fetchAccountInfo','data':{'info':oReq.responseText}});" +
            "    } else {" +
            "        window.webkit.messageHandlers.login.postMessage({'action':'fetchAccountInfo','data':{'info':''}});" +
            "    }" +
            "};" +
            "oReq.open('GET', url);" +
            "oReq.send();" +
            "", completionHandler: {(result, error) in
                guard error == nil else {
                    sa_log_v2("[Login Web] js execute error: %@", log: .ui, type: .error, error!.localizedDescription)
                    return
                }

                sa_log_v2("[Login Web] form submitted: %@", log: .ui, type: .info, result.debugDescription)
        })
    }
    
    func willSubmitForm(_ data: [String:AnyObject]) {
        // redirect
        sa_log_v2("[Login Web] form submitted", log: .ui, type: .info)
        guard let username = data["username"] as? String,
              let password = data["password"] as? String,
              let questionid = data["questionid"] as? String,
              let answer = data["answer"] as? String else {
            sa_log_v2("[Login Web] form not enough info", log: .ui, type: .error)
            return
        }
        
        savedFormRecords = CredentialInfo(username: username, password: password, questionid: questionid, answer: answer)
        
        // update UI
        title = NSLocalizedString("LOGIN_IN_PROGRESS", comment: "login in progress")
        let activity = UIActivityIndicatorView(style: .medium)
        let loadingItem = UIBarButtonItem(customView: activity)
        activity.startAnimating()
        navigationItem.leftBarButtonItems = [loadingItem]
    }
    
    func parseAccountInfoResult(data: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) as AnyObject else {
            sa_log_v2("[Login Web] parse account info failed: not json", log: .ui, type: .error)
            self.loginFailed()
            return
        }
        
        guard let info = savedFormRecords else {
            sa_log_v2("login finished but no form info", log: .ui, type: .error)
            self.loginFailed()
            return
        }
        
        let error = AppController.current.getService(of: SAAccountManager.self)!.parseAccountInfoResponse(obj, credential: info)
        if error != nil {
            sa_log_v2("[Login Web] parse account info failed error: %@", log: .ui, type: .error, error! as CVarArg)
            self.loginFailed()
            return
        }
        
        AppController.current.getService(of: SACookieManager.self)!.syncWKCookiesToNSCookieStorage {
            self.loginSucceeded()
            sa_log_v2("[Login Web] xhr result OK", log: .ui, type: .info)
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    @objc func handleRegisterButtonItemClicked(_ sender: AnyObject) {
        let url = Foundation.URL(string: SAGlobalConfig().register_url)!
        
        let safariViewer = SFSafariViewController(url: url)
        if #available(iOS 10.0, *) {
            safariViewer.preferredBarTintColor = Theme().barTintColor.sa_toColor()
        } else {
            // Fallback on earlier versions
        }
        if #available(iOS 10.0, *) {
            safariViewer.preferredControlTintColor = Theme().globalTintColor.sa_toColor()
        } else {
            // Fallback on earlier versions
        }
        safariViewer.delegate = self
        present(safariViewer, animated: true, completion: nil)
    }
}


extension SAWebLoginViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let method = navigationAction.request.httpMethod, method == "POST"  {
            doCheckingWhenLoadingFinished = true
        }
        decisionHandler(.allow)
    }
}


extension SAWebLoginViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "", message: message, preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = webView
        alert.popoverPresentationController?.sourceRect = webView.bounds
        alert.popoverPresentationController?.permittedArrowDirections = [.up]
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
        completionHandler()
    }
}

extension SAWebLoginViewController: SFSafariViewControllerDelegate {
    func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {
        sa_log_v2("register page redirect to: %@", log: .account, type: .info, URL.absoluteString)
    }
}
