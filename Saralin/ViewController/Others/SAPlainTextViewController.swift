//
//  SAPlainTextViewController.swift
//  Saralin
//
//  Created by zhang on 8/2/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

class SAPlainTextViewController: SABaseViewController {
    private var textView: UITextView = UITextView()

    var showsBarCloseButton = false
    var barCloseButtonTitle: String?
    
    /// return false to invalid this click action
    var barActionButtonHandler: ((UIBarButtonItem) -> Bool)?
    
    var text: String?
    var attributedText: NSAttributedString?
    
    var font = UIFont.boldSystemFont(ofSize: 12) {
        didSet {
            if isViewLoaded {
                textView.font = self.font
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        navigationItem.largeTitleDisplayMode = .never
        
        if #available(iOS 11.0, *) {
            textView.contentInsetAdjustmentBehavior = .always
        } else {
            // Fallback on earlier versions
        }
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.alwaysBounceVertical = true
        textView.isEditable = false
        textView.font = font
        view.insertSubview(textView, at: 0)
        
        textView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        textView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        textView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        textView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        
        if showsBarCloseButton {
            let rightItem = UIBarButtonItem(title: barCloseButtonTitle ?? NSLocalizedString("CLOSE", comment: "Close"), style: .plain, target: self, action: #selector(handleRightBarItemClick(_:)))
            navigationItem.rightBarButtonItem = rightItem
        }
        
        DispatchQueue.main.async {
            if let attributedString = self.attributedText {
                self.textView.attributedText = attributedString
            } else if let text = self.text {
                self.textView.text = text
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillLayoutSubviews() {
        let inset = max(10, (view.frame.size.width - CGFloat(SAContentViewControllerReadableAreaMaxWidth))/2.0)
        textView.textContainerInset = UIEdgeInsets(top: 10, left: inset, bottom: 10, right: inset)
        super.viewWillLayoutSubviews()
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        textView.backgroundColor = newTheme.foregroundColor.sa_toColor()
        textView.textColor = newTheme.textColor.sa_toColor()
    }
    
    @objc func handleRightBarItemClick(_ sender: UIBarButtonItem) {
        if let handler = barActionButtonHandler {
            if !handler(sender) {
                return
            }
        }
        
        if let presenting = presentingViewController {
            presenting.dismiss(animated: true, completion: nil)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
}
