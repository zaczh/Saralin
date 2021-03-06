//
//  SALoadingViewController.swift
//  Saralin
//
//  Created by zhang on 2/25/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

enum SALoadingState {
    case loading
    case empty
    case failed
    case finished
}

class SALoadingViewController: UIViewController {
    
    enum LoadingResult {
        case newData
        case emptyData
        case fail
    }
    
    fileprivate(set) var state: SALoadingState = .finished
    var hideWhenFinished: Bool = true
    var emptyLabelTitle: String = NSLocalizedString("NO_DATA", comment: "No Data") {
        didSet {
            emptyLabel.text = emptyLabelTitle
        }
    }
    
    var emptyLabelAttributedTitle: NSAttributedString? {
        didSet {
            emptyLabel.attributedText = emptyLabelAttributedTitle
        }
    }
    
    fileprivate let containerView = UIStackView()
    fileprivate let emptyLabel = UILabel()
    fileprivate let errorInfoLabel = UILabel()
    fileprivate let indicatorView = UIActivityIndicatorView(style: .medium)
    fileprivate let hintLabel = UILabel()
    fileprivate let retryButton = UIButton()
    fileprivate let retryInfoLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        
        view.isHidden = true
        
        containerView.axis = .vertical
        containerView.alignment = .center
        containerView.spacing = 20
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        if #available(iOS 11.0, *) {
            containerView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 20).isActive = true
            containerView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -20).isActive = true
        } else {
            // Fallback on earlier versions
            containerView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20).isActive = true
            containerView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20).isActive = true
        }
        containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 0).isActive = true

        emptyLabel.text = emptyLabelTitle
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        containerView.addArrangedSubview(emptyLabel)
        
        containerView.addArrangedSubview(indicatorView)
        
        hintLabel.text = NSLocalizedString("LOADING_HINT", comment: "loading")
        containerView.addArrangedSubview(hintLabel)
        
        retryInfoLabel.isHidden = true
        retryInfoLabel.text = NSLocalizedString("RETRY_INFO_HINT", comment: "loading failed due to error")
        containerView.addArrangedSubview(retryInfoLabel)
        
        errorInfoLabel.numberOfLines = 3
        errorInfoLabel.textAlignment = .center
        containerView.addArrangedSubview(errorInfoLabel)
        
        retryButton.isHidden = true
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 30, bottom: 6, right: 30)
        retryButton.layer.cornerRadius = 2.0
        retryButton.setTitle(NSLocalizedString("RETRY", comment: "重试"), for: UIControl.State.normal)
        retryButton.addTarget(self, action: #selector(SALoadingViewController.retryButtonClicked(_:)), for: .touchUpInside)
        containerView.addArrangedSubview(retryButton)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.SAUserPreferenceChangedNotification, object: nil)
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        
        view.backgroundColor = UIColor.sa_colorFromHexString(newTheme.foregroundColor)
        retryButton.backgroundColor = newTheme.tableCellHighlightColor.sa_toColor()
        emptyLabel.textColor =  UIColor.sa_colorFromHexString(newTheme.tableCellGrayedTextColor)
        hintLabel.textColor =  UIColor.sa_colorFromHexString(newTheme.tableCellGrayedTextColor)
        retryInfoLabel.textColor =  UIColor.sa_colorFromHexString(newTheme.tableCellGrayedTextColor)
        retryButton.setTitleColor(newTheme.globalTintColor.sa_toColor(), for: .normal)
        errorInfoLabel.textColor =  UIColor.sa_colorFromHexString(newTheme.tableCellGrayedTextColor)
        
        emptyLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
        hintLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
        retryInfoLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
        errorInfoLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
        retryButton.titleLabel!.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
    }
    
    func setFailed(with error: NSError?) {
        state = .failed
        view.isHidden = false
        emptyLabel.isHidden = true
        indicatorView.stopAnimating()
        hintLabel.isHidden = true
        retryButton.isHidden = false
        retryInfoLabel.isHidden = false
        if let info = error?.localizedDescription {
            errorInfoLabel.text = "(\(info))"
        } else {
            errorInfoLabel.text = nil
        }
    }
    
    func setEmpty() {
        state = .empty
        view.isHidden = false
        emptyLabel.isHidden = false
        retryButton.isHidden = true
        indicatorView.stopAnimating()
        hintLabel.isHidden = true
        retryInfoLabel.isHidden = true
        errorInfoLabel.text = nil
    }
    
    func setLoading() {
        state = .loading
        view.isHidden = false
        emptyLabel.isHidden = true
        indicatorView.startAnimating()
        hintLabel.isHidden = false
        retryButton.isHidden = true
        retryInfoLabel.isHidden = true
        errorInfoLabel.text = nil
    }
    
    func setFinished() {
        state = .finished
        view.isHidden = true
        errorInfoLabel.text = nil
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func retryButtonClicked(_: AnyObject) {
        if let baseViewController = parent {
            baseViewController.loadingControllerDidRetry(self)
        }
    }
    
}
