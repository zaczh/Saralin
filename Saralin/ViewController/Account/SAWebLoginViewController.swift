//
//  SAWebLoginViewController.swift
//  Saralin
//
//  Created by zhang on 5/14/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import WebKit

#if !targetEnvironment(macCatalyst)
class SAWebLoginViewController: SABaseViewController, UIWebViewDelegate {
    // use WKWebview with custom cookie handling is such a pain.
    // in fact, it has never worked.
    private let webView = UIWebView(frame: .zero)
    private let loginUrl = URL(string: SAGlobalConfig().login_url)!
    private let fetchAccountInfoUrl = URL(string: "api/mobile/index.php?module=login", relativeTo: URL(string: SAGlobalConfig().forum_base_url)!)!
    private let redirectUrls = [URL(string: "forum.php", relativeTo: URL(string: SAGlobalConfig().forum_base_url)!)!,
                                URL(string: SAGlobalConfig().forum_base_url)!]

    private var savedFormRecords: CredentialInfo?
    
    private let form_beautify_js = "document.querySelector(\"input[name=cookietime]\").checked=1;document.querySelector(\"input[name=cookietime]\").style.display=\"none\";"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
        
        webView.delegate = self
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
        
        let leftItem = UIBarButtonItem(title: NSLocalizedString("CLOSE", comment: "关闭"), style: .plain, target: self, action: #selector(SAWebLoginViewController.handleCloseButtonItemClick(_:)))
        navigationItem.leftBarButtonItems = [leftItem]
        let rightItem = UIBarButtonItem(title: NSLocalizedString("REGISTER", comment: "注册"), style: .plain, target: self, action: #selector(SAWebLoginViewController.handleRegisterButtonItemClicked(_:)))
        navigationItem.rightBarButtonItems = [rightItem]
        title = NSLocalizedString("LOGIN", comment: "Login")
        
        let request = URLRequest(url: loginUrl)
        webView.loadRequest(request)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func getUserInfoFailed() {
        
    }
    
    fileprivate func loginFinished() {
        let viewController = navigationController?.presentingViewController
        viewController?.dismiss(animated: true, completion: nil)
    }
    
    private func recordFormInfo() -> Bool {
        guard let username = webView.stringByEvaluatingJavaScript(from: "document.querySelector('input[name=\"username\"]').value"), !username.isEmpty,
            let password = webView.stringByEvaluatingJavaScript(from: "document.querySelector('input[name=\"password\"]').value"), !password.isEmpty else {
                return false
        }
        
        // these fields are optional
        let _ = webView.stringByEvaluatingJavaScript(from: "document.querySelector('select[name=\"questionid\"]').value")
        let _ = webView.stringByEvaluatingJavaScript(from: "document.querySelector('input[name=\"answer\"]').value")
        
        savedFormRecords = CredentialInfo(username: username, password: password)
        return true
    }
    
    // MARK: - UIWebViewDelegate
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
        if navigationType == UIWebView.NavigationType.formSubmitted {
            if !recordFormInfo() {
                showFormIncompleteAlert()
                return false
            }
            willSubmitForm()
            return true
        }
        
        guard let url = request.url else {
            return false
        }
        
        if url.sa_isExternal() {
            sa_log_v2("web login cancel external request: %@", module: .webView, type: .debug, url as CVarArg)
            return false
        }
        sa_log_v2("[Login Web] loading url: %@", module: .ui, type: .debug, url.absoluteString)
        
        if redirectUrls.contains(url) {
            fetchAccountInfo()
            return true
        }
        
        return true
    }
    
    func showFormIncompleteAlert() {
        let alert = UIAlertController(title: "", message: "用户名和密码不能为空", preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = webView
        alert.popoverPresentationController?.sourceRect = webView.bounds
        alert.popoverPresentationController?.permittedArrowDirections = [.up]
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }
    
    func willSubmitForm() {
        // redirect
        sa_log_v2("[Login Web] form submitted", module: .ui, type: .debug)
        
        // update UI
        title = NSLocalizedString("LOGIN_IN_PROGRESS", comment: "login in progress")
        let activity = UIActivityIndicatorView(style: .gray)
        let loadingItem = UIBarButtonItem(customView: activity)
        activity.startAnimating()
        navigationItem.leftBarButtonItems = [loadingItem]
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        if webView.request!.url == loginUrl {
            webView.stringByEvaluatingJavaScript(from: form_beautify_js)
        }
    }
    
    private func fetchAccountInfo() {
        UIApplication.shared.showNetworkIndicator()
        URLSession.saCustomized.dataTask(with: fetchAccountInfoUrl, completionHandler: { (data, response, error) in
            UIApplication.shared.hideNetworkIndicator()
            guard error == nil && data != nil else {return}
            DispatchQueue.main.async {
                self.parseAccountInfoResult(data: data!)
            }
        }).resume()
    }
    
    private func parseAccountInfoResult(data: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) as AnyObject else {
            sa_log_v2("[Login Web] parse account info failed: not json", module: .ui, type: .error)
            self.getUserInfoFailed()
            return
        }
        
        guard let info = savedFormRecords else {
            sa_log_v2("login finished but no form info", module: .ui, type: .error)
            self.getUserInfoFailed()
            return
        }
        
        let error = AppController.current.getService(of: SAAccountManager.self)!.parseAccountInfoResponse(obj, credential: info)
        if error != nil {
            sa_log_v2("[Login Web] parse account info failed error: %@", module: .ui, type: .error, error! as CVarArg)
            self.getUserInfoFailed()
            return
        }
        
        loginFinished()
        sa_log_v2("[Login Web] xhr result OK", module: .ui, type: .info)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    @objc func handleCloseButtonItemClick(_ sender: AnyObject) {
        if let presenting = navigationController?.presentingViewController {
            presenting.dismiss(animated: true, completion: nil)
        } else if let presenting = presentingViewController {
            presenting.dismiss(animated: true, completion: nil)
        } else {
            _ = navigationController?.popViewController(animated: true)
        }
    }
    
    @objc func handleRegisterButtonItemClicked(_ sender: AnyObject) {
        let url = Foundation.URL(string: SAGlobalConfig().register_url)!
        let page = SAContentViewController(url: url)
        page.title = NSLocalizedString("REGISTER", comment: "Register")
        navigationController?.pushViewController(page, animated: true)
    }
}
#endif
