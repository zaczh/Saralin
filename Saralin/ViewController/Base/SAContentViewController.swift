//
//  SAContentViewController.swift
//  Saralin
//
//  Created by zhang on 1/9/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import WebKit
import SafariServices

class SAContentViewController: SABaseViewController, WKNavigationDelegate, SFSafariViewControllerDelegate, UIScrollViewDelegate {
    var webView: WKWebView!
    var loadingProgressView = UIProgressView.init(progressViewStyle: .bar)
    var url: Foundation.URL?
    var shouldSetDesktopBrowserUserAgent = false
    var automaticallyShowsLoadingView = true
    var automaticallyLoadsURL = true
    var shouldLoadAllRequestsWithin = false
    var showsLoadingProgressView: Bool = true
    var automaticallySetTitleWhenFinishLoading = false
    
    typealias ValueChangeHandler = (String, ((WKWebView) -> Void))
    var webviewKeyValueChangeRunOnceHandlers:[ValueChangeHandler] = []
    
    required init(url: Foundation.URL) {
        super.init(nibName: nil, bundle: nil)
        self.url = url
        if url.isFileURL {
            automaticallyShowsLoadingView = false
        }
    }
    
    func config(url: Foundation.URL) {
        self.url = url
        if url.isFileURL {
            automaticallyShowsLoadingView = false
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
        
        webView = WKWebView(frame: view.bounds, configuration: getWebViewConfiguration())
        webView.allowsLinkPreview = false
        webView.scrollView.delegate = self
        webView.scrollView.isDirectionalLockEnabled = true
        webView.isOpaque = false
        webView.navigationDelegate = self
        view.insertSubview(webView, at: 0)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        webView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
        webView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
        
        let globalConfig = SAGlobalConfig()
        if shouldSetDesktopBrowserUserAgent {
            webView.customUserAgent = globalConfig.pc_useragent_string
        } else  {
            webView.customUserAgent = globalConfig.mobile_useragent_string
        }
        
        webView!.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView!.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView!.addObserver(self, forKeyPath: #keyPath(WKWebView.loading), options: [.new, .initial], context: nil)
        
        view.addSubview(loadingProgressView)
        loadingProgressView.translatesAutoresizingMaskIntoConstraints = false
        loadingProgressView.leftAnchor.constraint(equalTo: webView.leftAnchor).isActive = true
        loadingProgressView.rightAnchor.constraint(equalTo: webView.rightAnchor).isActive = true
        loadingProgressView.topAnchor.constraint(equalTo: webView.topAnchor).isActive = true
        loadingProgressView.heightAnchor.constraint(equalToConstant: 1).isActive = true
        loadingProgressView.isHidden = true

        guard let url = url, automaticallyLoadsURL else {
            return
        }
        
        // show loading view before actually loading
        if automaticallyShowsLoadingView {
            loadingController.setLoading()
        }
        
        if url.isFileURL {
            let ext = url.pathExtension.lowercased()
            if ext == "html" {
                webView!.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            } else {
                if let data = try? Data(contentsOf: url) {
                    webView.load(data, mimeType: "text/plain", characterEncodingName: "utf-8", baseURL: url)
                } else {
                    fatalError("File not recognized.")
                }
            }
        } else {
            webView!.load(URLRequest(url: url))
        }
    }
    
    deinit {
        if let webView = webView {
            webView.scrollView.delegate = nil
            webView.navigationDelegate = nil
            webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
            webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
            webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.loading))
        }
    }
    
    open func getWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let scriptLogHandler = SABaseScriptLogHandler(viewController: self)
        configuration.userContentController.add(scriptLogHandler, name: "log")
        return configuration
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        webView!.backgroundColor = UIColor.sa_colorFromHexString(newTheme.backgroundColor)
        
        if webView.isLoading {
            let handler: ValueChangeHandler = ("loading", { (webView) in
                webView.evaluateJavaScript("document.body.setAttribute('style','color:\(newTheme.textColor);')", completionHandler: nil)
            })
            webviewKeyValueChangeRunOnceHandlers.append(handler)
        } else {
            webView!.evaluateJavaScript("document.body.setAttribute('style','color:\(newTheme.textColor);')", completionHandler: nil)
        }
    }
    
    private func asyncLoadWebarchive() {
        UIApplication.shared.showNetworkIndicator()
        URLSession.saCustomized.dataTask(with: url!, completionHandler: { [weak self] (data, response, error) in
            UIApplication.shared.hideNetworkIndicator()
            guard let strongSelf = self else {
                return
            }
            
            guard error == nil else {
                os_log("wrong data from url: %@", log: .ui, type: .debug, strongSelf.url!.absoluteString)
                return
            }
            
            if let data = data {
                DispatchQueue.main.async {
                    strongSelf.webView!.load(data, mimeType: "application/x-webarchive", characterEncodingName: "UTF-8", baseURL: Foundation.URL(string:"about:blank")!)
                }
            }
        }).resume()
    }
    
    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard (object as? WKWebView) == webView else {
            os_log("I am not observing this keyPath!", log: .ui, type: .debug)
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        guard let _ = keyPath else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        defer {
            var removing: [Int] = []
            for (i, handler) in webviewKeyValueChangeRunOnceHandlers.enumerated() {
                if handler.0 == keyPath {
                    handler.1(webView!)
                    removing.append(i)
                }
            }
            for i in removing.reversed() {
                webviewKeyValueChangeRunOnceHandlers.remove(at: i)
            }
        }
        
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            guard let progress = (change![NSKeyValueChangeKey.newKey]) as? Float else {
                return
            }
            
            if showsLoadingProgressView {
                loadingProgressView.progress = progress
                loadingProgressView.isHidden = progress == 1.0
            }
        } else if keyPath == #keyPath(WKWebView.title) {
            if automaticallySetTitleWhenFinishLoading {
                if let pageTitle = change![NSKeyValueChangeKey.newKey] as? String {
                    self.title = pageTitle
                }
            }
        } else if keyPath == #keyPath(WKWebView.loading) {
            let isLoading = (change![NSKeyValueChangeKey.newKey]) as! Bool
            
            if automaticallyShowsLoadingView && webView?.url != nil {
                if isLoading {
                    self.loadingController.setLoading()
                } else  {
                    self.loadingController.setFinished()
                }
            }
        }
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if let url = navigationAction.request.url {
            os_log("decidePolicyForNavigationAction: %@", log: .ui, type: .debug, url.absoluteString)
        }
        
        guard navigationAction.request.url != nil else {
            decisionHandler(.allow)
            return
        }
        
        if navigationAction.navigationType != .linkActivated {
            if let frame = navigationAction.targetFrame, !frame.isMainFrame, let url = navigationAction.request.url, url.sa_isExternal() {
                decisionHandler(.cancel)
                os_log("cancel external requests: %@", log: .ui, type: .debug, url.absoluteString)
                return
            }
            
            decisionHandler(.allow)
            return
        }
        
        guard webView.url != nil else {
            decisionHandler(.allow)
            return
        }
        
        if shouldLoadAllRequestsWithin {
            decisionHandler(.allow)
            return
        }
        
        if shouldRequestLoadInCurrentPage(navigationAction.request) {
            decisionHandler(.allow)
            return
        }
        
        decisionHandler(.cancel)

        if navigationAction.request.url!.sa_isExternal() {
            guard presentedViewController == nil else {
                os_log("Cannot present two view controllers at same time!")
                return
            }
            
            guard let url = navigationAction.request.url else { return }
            
            // SafariViewController only supports HTTP and HTTPS URLs.
            // Load other types of url will crash.
            guard let scheme = url.scheme else { return }
            
            guard scheme.lowercased() == "http" || scheme.lowercased() == "https" else {
                // handle other protocols like mailto:xxx@example.com
                self.openUsingSharedApplication(url)
                return
            }
            
            if url.host?.lowercased() == "itunes.apple.com" {
                // open app store link
                self.openUsingSharedApplication(url)
                return
            }
            
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
            return
        }
        
        if let url = navigationAction.request.url, let vc = SAContentViewController.viewControllerForURL(url: url, sender: self) {
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Swift.Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        os_log("didFailNavigation")
        //do nothing
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if automaticallyShowsLoadingView {
            loadingController.setFinished()
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        //do nothing
        os_log("webView did finish load", log: .webView, type: .info)
    }
    
    // Sometimes when app awake from background, webview display a blank page.
    // This is because the web process has been terminated by system.
    // We need to refresh page if this happends
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        os_log("web process has been terminated")
        let error = NSError.init(domain: SAGeneralErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"Web进程已终止。"])
        loadingController.setFailed(with: error)
    }

    // MARK: - Public methods
    @objc func handleDismiss() {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    func openUsingSharedApplication(_ url: Foundation.URL) {
        os_log("open url with shared application", log: .ui, type: .info)
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: { (success: Bool) in
                os_log("open result: %d", log: .ui, type: .info, success as CVarArg)
            })
        } else {
            // Fallback on earlier versions
            UIApplication.shared.openURL(url)
        }
    }
    
    //load in current page, not open a new vc
    func shouldRequestLoadInCurrentPage(_ request: URLRequest) -> Bool {
        return false
    }
    
    // MARK: viewcontroller dispatch
    class func viewControllerForURL(url: URL, sender: UIViewController?) -> UIViewController? {
        
        // handle desktop link click
        if url.lastPathComponent.hasPrefix("space-uid-") {
            return SAAccountInfoViewController(url: url)
        } else if url.lastPathComponent.hasPrefix("thread-") {
            return SAThreadContentViewController(url: url.sa_uniformURL())
        } else if url.lastPathComponent.hasPrefix("forum-") {
            // http://bbs.saraba1st.com/2b/forum-75-1.html
            let components = url.lastPathComponent.components(separatedBy: "-")
            if components.count > 2 {
                return SABoardViewController(url: url.sa_uniformURL())
            } else {
                // unknown
                return SAContentViewController(url: url)
            }
        }
        
        // handle mobile link
        let mode = url.sa_queryString("mod")
        if mode == nil {
            return SAContentViewController(url: url)
        } else if mode == "forumdisplay" {
            return SABoardViewController(url: url)
        } else if mode == "viewthread" {
            return SAThreadContentViewController(url: url)
        } else if mode == "post" {
            let action = url.sa_queryString("action")
            if action?.lowercased() == "reply" {
                if let threadView = sender as? SAThreadContentViewController {
                    threadView.replyToMainThread()
                    return nil
                }
            }
            
            return SAContentViewController(url: url)
        } else if mode == "space" {
            let doType = url.sa_queryString("do")
            let subopType = url.sa_queryString("subop")
            if doType?.lowercased() == "pm" {
                if subopType == "view" {
                    if  let _ = url.sa_queryString("touid"),
                        let _ = url.sa_queryString("tousername") {
                        return SAMessageCompositionViewController(url: url)
                    }
                    return SAContentViewController(url: url)
                } else  {
                    return SAContentViewController(url: url)
                }
            } else {
                return SAAccountInfoViewController(url: url)
            }
        } else if mode == "spacecp" {
            return SAMessageCompositionViewController(url: url)
        } else if mode == "redirect" {
            if let goto = url.sa_queryString("goto") {
                if goto == "findpost" {
                    guard let ptid = url.sa_queryString("ptid") else {
                        return nil
                    }
                    let newUrl = url.sa_urlByReplacingQuery("tid", value: ptid)
                    return SAThreadContentViewController(url: newUrl)
                }
            }
        }
        
        if url.lastPathComponent.hasPrefix("forum.php") {
            return SAForumViewController.init()
        }
        
        // default view controller
        return SAContentViewController(url: url)
    }
}

