//
//  SAReplyViewController.swift
//  Saralin
//
//  Created by zhang on 10/21/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import CoreData

private let maximumFavoriteEmojis: Int = 18
private let emojiToolBarHeight = CGFloat(44)

protocol SAReplyViewControllerDelegate {
    func replyDidSucceed(_ replyViewController: SAReplyViewController)
    func replyDidFail(_ replyViewController: SAReplyViewController)
}

class SAReplyViewController: SABaseViewController, UITextViewDelegate, UICollectionViewDataSource, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate, SAReplyImagePreviewCollectionViewCellDelegate, SAEmojiCollectionWrapperViewDelegate {
    
    //ui
    @IBOutlet var imagePreviewCollectionViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var replyPreviewView: UIView!
    @IBOutlet var replyPreviewViewBodyLabel: UILabel!

    @IBOutlet var replyPreviewViewLeftLine: UIView!
    @IBOutlet var replyPreviewViewBodyLabelBottomConstraint: NSLayoutConstraint!
    @IBOutlet var replyPreviewViewBodyLabelTopConstraint: NSLayoutConstraint!
    @IBOutlet var emojiView: UIView!
    
    @IBOutlet var toolBarBottomConstraint: NSLayoutConstraint!

    // saddly, top layout guide can not be set in xib
    var replyPreviewViewTopConstraint: NSLayoutConstraint!
    @IBOutlet var replyPreviewViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet var placeholderLabel: UILabel!
    @IBOutlet var toolbar: UIToolbar!
    @IBOutlet var textView: UITextView!
    @IBOutlet var imagePreviewCollectionView: UICollectionView!
    //emoji selection
    //show favorited emoji view if value is -1
    private var selectedEmojiCategoryIndex: Int = 0
    
    private var shouldSaveDraft = true
    
    //data
    private var uploadingImages: [UIImage] = []
    lazy var mahjongInfo: [[String:AnyObject]] = {
        let url = AppController.current.mahjongEmojiDirectory.appendingPathComponent("emoji.plist")
        return NSDictionary(contentsOf: url)!.object(forKey: "items") as! [[String : AnyObject]]
    }()
    fileprivate var quoteInfo: [String:AnyObject] = [:]
    
    var delegate: SAReplyViewControllerDelegate?
    
    func config(quoteInfo: [String:AnyObject]) {
        self.quoteInfo = quoteInfo
    }
    
    private var urlSession: URLSession! = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(30)
        return URLSession.init(configuration: configuration, delegate: nil, delegateQueue: nil)
    } ()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
            
            // We handle the inset manually in this VC
            textView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
            
            // We handle the inset manually in this VC
            automaticallyAdjustsScrollViewInsets = false
        }
            
        placeholderLabel.font = UIFont.sa_preferredFont(forTextStyle: .body)
        
        insertQuoteAsReply(quoteName: quoteInfo["quote_name"] as? String, quoteAuthor:quoteInfo["author"] as? String, quoteText: quoteInfo["quote_textcontent"] as? String)
        
        textView.delegate = self
        textView.keyboardType = .default
        
        let layout = imagePreviewCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
        layout.scrollDirection = .horizontal
        layout.headerReferenceSize = CGSize(width: 0, height: 0)
        layout.footerReferenceSize = CGSize(width: 0, height: 0)
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 0
        layout.itemSize = CGSize(width: 100, height: 100)
        layout.sectionInset = UIEdgeInsets.init(top: 10, left: 0, bottom: 0, right: 0)
        imagePreviewCollectionView.scrollsToTop = false
        imagePreviewCollectionView.dataSource = self
        imagePreviewCollectionView.delegate = self
        imagePreviewCollectionView.register(SAReplyImageAndContentPreviewCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        replyPreviewViewTopConstraint = NSLayoutConstraint(item: replyPreviewView!, attribute: .top, relatedBy: .equal, toItem: view.safeAreaLayoutGuide, attribute: .top, multiplier: 1.0, constant: 10)
        replyPreviewViewTopConstraint.isActive = true
                
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("SEND", comment: "Reply"), style: .plain, target: self, action: #selector(handleSendBarItemClick(_:)))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("CLOSE", comment: "Reply"), style: .plain, target: self, action: #selector(handleCloseBarItemClick(_:)))
        
        loadDraftIfExist()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppEnterBackgroundNotification(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        
        view.backgroundColor = newTheme.foregroundColor.sa_toColor()
        toolbar.barStyle = newTheme.toolBarStyle
        placeholderLabel.textColor = newTheme.tableCellGrayedTextColor.sa_toColor()

        replyPreviewView.backgroundColor = newTheme.htmlBlockQuoteBackgroundColor.sa_toColor()
        replyPreviewViewBodyLabel.backgroundColor = UIColor.clear
        replyPreviewViewLeftLine.backgroundColor = newTheme.htmlBlockQuoteTextColor.sa_toColor()
        textView.textColor = newTheme.textColor.sa_toColor()
        textView.backgroundColor = UIColor.sa_colorFromHexString(newTheme.foregroundColor)
        textView.keyboardAppearance = newTheme.keyboardAppearence
        textView.font = UIFont.sa_preferredFont(forTextStyle: .body)
        imagePreviewCollectionView.backgroundColor = UIColor.clear
    }
    
    @objc func handleAppEnterBackgroundNotification(_ notification: NSNotification) {
        if shouldSaveDraft {
            saveDraft()
        }
    }
    
    private func insertQuoteAsReply(quoteName: String?, quoteAuthor: String?, quoteText: String?) {
        if quoteName == nil {
            replyPreviewViewBodyLabel.attributedText = nil
            replyPreviewViewBodyLabelTopConstraint.constant = 0
            replyPreviewViewBodyLabelBottomConstraint.constant = 0
            
            self.title = "回复主贴"
            return
        }
        
        let attributedText = NSMutableAttributedString()
        attributedText.append(NSAttributedString(string: "@" + quoteName! + ": ", attributes: [NSAttributedString.Key.font:UIFont.sa_preferredFont(forTextStyle: .headline), NSAttributedString.Key.foregroundColor: Theme().htmlBlockQuoteTextColor.sa_toColor()]))
        attributedText.append(NSAttributedString(string: quoteText ?? "", attributes: [NSAttributedString.Key.font:UIFont.sa_preferredFont(forTextStyle: .body), NSAttributedString.Key.foregroundColor: Theme().htmlBlockQuoteTextColor.sa_toColor()]))
        replyPreviewViewBodyLabel.attributedText = attributedText
        replyPreviewViewBodyLabelTopConstraint.constant = 8
        replyPreviewViewBodyLabelBottomConstraint.constant = 8
        
        self.title = NSLocalizedString("REPLY", comment: "Reply") + ": \(quoteName!)"
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let dest = segue.destination as? SAReplyEmojiViewController {
            dest.modalPresentationStyle = .popover
            if UIDevice.current.userInterfaceIdiom == .phone || UIDevice.current.userInterfaceIdiom == .pad {
                dest.popoverPresentationController?.delegate = self
            }
            dest.preferredContentSize = CGSize(width: view.frame.size.width * 0.8, height: 200)
            dest.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
            dest.cellDelegate = self
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerKeyboardEvents()
        
        #if targetEnvironment(macCatalyst)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        #endif
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 13.0, *) {
            view.window?.windowScene?.userActivity = getUserActivity()
        } else {
            // Fallback on earlier versions
        }
    }
    
    #if targetEnvironment(macCatalyst)
    override func updateToolBar(_ viewAppeared: Bool) {
        super.updateToolBar(viewAppeared)
        
        guard let titlebar = UIApplication.shared.windows.first?.windowScene?.titlebar, let titleItems = titlebar.toolbar?.items else {
            return
        }
        
        for item in titleItems {
            if item.itemIdentifier.rawValue == SAToolbarItemIdentifierReply.rawValue {
                item.isEnabled = viewAppeared
                item.target = self
                item.action = #selector(handleSendBarItemClick(_:))
            }
        }
    }
    #endif
    
    private func getUserActivity() -> NSUserActivity? {
        guard let _ = quoteInfo["fid"] as? String, let _ = quoteInfo["tid"] as? String else {
            return nil
        }
        
        let userActivity = NSUserActivity(activityType: SAActivityType.replyThread.rawValue)
        userActivity.isEligibleForHandoff = true
        userActivity.title = SAActivityType.replyThread.title()
        userActivity.userInfo = ["quoteInfo":quoteInfo]
        return userActivity
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterKeyboardEvents()
        if shouldSaveDraft {
            saveDraft()
        }
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        guard isViewLoaded else {
            return
        }
        
        if newCollection.verticalSizeClass == .compact {
            replyPreviewViewHeightConstraint.constant = 60
        } else {
            replyPreviewViewHeightConstraint.constant = 120
        }
        coordinator.animate(alongsideTransition: { (coordinator) in
            self.hideInputView(animated: false)
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    fileprivate func registerKeyboardEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    fileprivate func unregisterKeyboardEvents() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // MARK: - Draft Saving & Restoring
    private func loadDraftIfExist() {
        let uid = Account().uid
        
        guard let fid = quoteInfo["fid"] as? String, let tid = quoteInfo["tid"] as? String else {
            os_log("bad data, not save draft", log: .ui, type: .error)
            return
        }
        let quote_id = quoteInfo["quote_id"] as? String
        let predicate = NSPredicate(format: "fid==%@ AND tid==%@ AND quote_id==%@ AND uid==%@", fid, tid, quote_id ?? NSNull(), uid)
        
        AppController.current.getService(of: SACoreDataManager.self)!.fetch(predicate: predicate, sortDesscriptors: nil) { (entity: [ReplyDraft]) in
            guard let entity = entity.first else {
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(0)) {
                    self.textView.becomeFirstResponder()
                }
                return
            }
            
            if let imageData = entity.attachedimagedata {
                if let image = UIImage.init(data: imageData as Data) {
                    self.insertImageAsReply(image)
                }
            }
            
            // reload placeholder
            if let text = entity.draftcontent {
                self.textView.text = text
                self.insertQuoteAsReply(quoteName: entity.quote_name, quoteAuthor: entity.quote_author, quoteText: entity.quote_textcontent)
                self.textViewDidChange(self.textView)
                self.textView.layoutIfNeeded()
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.milliseconds(0)) {
                    self.textView.becomeFirstResponder()
                }
            }
        }
    }
    
    private func deleteDraftAfterSent() {
        let uid = Account().uid
        guard let fid = quoteInfo["fid"] as? String, let tid = quoteInfo["tid"] as? String else {
            os_log("bad data, not delete draft", log: .ui, type: .error)
            return
        }
        let quote_id = quoteInfo["quote_id"] as? String
        let predicate = NSPredicate(format: "fid==%@ AND tid==%@ AND quote_id==%@ AND uid==%@", fid, tid, quote_id ?? NSNull(), uid)
        AppController.current.getService(of: SACoreDataManager.self)!.delete(predicate: predicate) { (entities: [ReplyDraft]) in
            os_log("draft deleted", log: .ui, type: .info)
        }
    }
    
    private func saveDraft() {
        if textView.text.isEmpty && uploadingImages.isEmpty {
            os_log("reply view empty, not save to draft")
            return
        }
        
        let uid = Account().uid
        guard let fid = quoteInfo["fid"] as? String,
            let tid = quoteInfo["tid"] as? String else {
                os_log("bad data, not save draft", log: .ui, type: .error)
                return
        }
        let quote_id = quoteInfo["quote_id"] as? String
        let predicate = NSPredicate(format: "fid==%@ AND tid==%@ AND quote_id==%@ AND uid==%@", fid, tid, quote_id ?? NSNull(), uid)
        
        let quote_name = quoteInfo["quote_name"] as? String
        let quote_author = quoteInfo["author"] as? String

        let quote_textcontent = quoteInfo["quote_textcontent"] as? String
        
        
        let image = self.uploadingImages.first
        let text = self.textView.text
        AppController.current.getService(of: SACoreDataManager.self)!.insertNewOrUpdateExist(fetchPredicate: predicate, sortDescriptors: nil, update: { (entity: ReplyDraft) in
            entity.createdate = Date()
            if let image = image {
                entity.attachedimagedata = image.pngData()
            } else {
                entity.attachedimagedata = nil
            }
            entity.quote_textcontent = quote_textcontent
            entity.draftcontent = text
            entity.quote_author = quote_author
            entity.createdevicename = UIDevice.current.name
            entity.createdeviceidentifier = AppController.current.currentDeviceIdentifier
        }, create: { (entity: ReplyDraft) in
            entity.createdevicename = UIDevice.current.name
            entity.createdeviceidentifier = AppController.current.currentDeviceIdentifier
            entity.createdate = Date()
            entity.fid = fid
            entity.tid = tid
            entity.quote_id = quote_id
            entity.uid = uid
            entity.quote_name = quote_name
            entity.quote_author = quote_author
            if let image = image {
                entity.attachedimagedata = image.pngData()
            }
            entity.quote_textcontent = quote_textcontent
            entity.draftcontent = text
        }, completion: nil)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: - TextViewDelete
    func textViewDidChange(_ textView: UITextView) {
        if textView == self.textView {
            placeholderLabel.isHidden = !textView.text.isEmpty
        }
    }
    
    // MARK: - collection view
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == imagePreviewCollectionView {
            return uploadingImages.count
        }
        
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == imagePreviewCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! SAReplyImageAndContentPreviewCollectionViewCell
            cell.delegate = self
            let image = uploadingImages[indexPath.item]
            cell.imageView.image = image

            return cell
        }
        
        return UICollectionViewCell()
    }
    
    func insertEmojiNamed(_ name: String, replacementString: String) {
        let imagePath = AppController.current.mahjongEmojiDirectory.path + "/" + name
        let image = UIImage.init(contentsOfFile: imagePath)
        let attachment = SATextAttachment()
        attachment.image = image
        attachment.replacementString = replacementString
        
        let font = textView.font!
        let textColor = textView.textColor!
        attachment.bounds = CGRect(x: 0, y: font.descender, width: font.lineHeight, height: font.lineHeight)
        let str: NSMutableAttributedString = NSAttributedString(attachment: attachment).mutableCopy() as! NSMutableAttributedString
        str.addAttribute(NSAttributedString.Key.font, value: font, range: NSMakeRange(0, str.length))
        str.addAttribute(NSAttributedString.Key.foregroundColor, value: textColor, range: NSMakeRange(0, str.length))
        textView.textStorage.insert(str, at: textView.selectedRange.location)
        
        textView.selectedRange.location = textView.selectedRange.location + 1
        textView.textStorage.addAttributes(textView.typingAttributes, range: NSMakeRange(0, textView.textStorage.length))
        textView.scrollRangeToVisible(NSMakeRange(textView.selectedRange.location - 2, 1))
        
        if !placeholderLabel.isHidden {
            placeholderLabel.isHidden = true
        }
        reportEmojiUsage(replacementString, imageName: name)
    }
    
    
    fileprivate func getInputText() -> String {
        let attributedText = textView.attributedText.mutableCopy() as! NSMutableAttributedString
        attributedText.enumerateAttribute(NSAttributedString.Key.attachment, in: NSMakeRange(0, attributedText.length), options: []) { (attribute, range, stop) in
            guard attribute != nil else {
                return
            }
            let attach = attribute as! SATextAttachment
            attributedText.replaceCharacters(in: range, with: attach.replacementString)
        }
        
        let inputText = attributedText.string
        return inputText
    }
    
    
    func reportEmojiUsage(_ text: String, imageName: String) {
        let emoji = NSDictionary(dictionary: ["text":text, "imageName": imageName, "image": imageName])
        
        let favoriteEmoji = Account().favoriteEmojis.mutableCopy() as! NSMutableArray
        for _emoji in favoriteEmoji {
            let emoji = _emoji as! NSDictionary
            if let in_text = emoji["text"] as? String {
                if in_text == text {
                    return
                }
            }
        }
        
        favoriteEmoji.insert(emoji, at: 0)
        if favoriteEmoji.count > maximumFavoriteEmojis {
            favoriteEmoji.removeObjects(in: NSMakeRange(maximumFavoriteEmojis, favoriteEmoji.count - maximumFavoriteEmojis))
        }
        Account().favoriteEmojis = favoriteEmoji
    }
    
    private func insertImageAsReply(_ image: UIImage) {
        imagePreviewCollectionViewHeightConstraint.constant = 120
        view.setNeedsLayout()
        view.layoutIfNeeded()
        uploadingImages.append(image)
        let indexPath = IndexPath(item: uploadingImages.count - 1, section: 0)
        imagePreviewCollectionView.insertItems(at: [indexPath])
    }
    
    // MARK: - UIImagePickerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            insertImageAsReply(image)
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - SAReplyImagePreviewCollectionViewCellDelegate
    func cellDeleteButtonClicked(_ cell: SAReplyImageAndContentPreviewCollectionViewCell) {
        if let indexPath = imagePreviewCollectionView.indexPath(for: cell) {
            uploadingImages.remove(at: indexPath.item)
            imagePreviewCollectionView.deleteItems(at: [indexPath])
            if uploadingImages.count == 0 {
                imagePreviewCollectionViewHeightConstraint.constant = 0
                view.setNeedsLayout()
            }
        }
    }
    
    //keyboard events
    @objc func handleKeyboardWillShow(_ notification: Notification) {
        
        if !textView.isFirstResponder {
            return
        }
        
        guard view.window != nil else {
            return
        }
        
        for item in toolbar.items! {
            if item.tag == 9 {
                item.image = UIImage(named: "Expand_Arrow_50")
            }
        }
        
        let keyboardBounds = ((notification as NSNotification).userInfo![UIResponder.keyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue!
        let localBounds = view.convert(keyboardBounds, from: nil)
        replyPreviewViewTopConstraint.constant = -imagePreviewCollectionView.frame.height - replyPreviewView.frame.height
        if #available(iOS 11.0, *) {
            // keyboard bounds already have safearea insets
            toolBarBottomConstraint.constant = -view.frame.size.height + localBounds.origin.y + view.safeAreaInsets.bottom
        } else {
            // Fallback on earlier versions
            toolBarBottomConstraint.constant = -view.frame.size.height + localBounds.origin.y
        }

        let duration = ((notification as NSNotification).userInfo![UIResponder.keyboardAnimationDurationUserInfoKey]! as AnyObject).doubleValue ?? 0
        let curve = UIView.AnimationCurve(rawValue: ((notification as NSNotification).userInfo![UIResponder.keyboardAnimationCurveUserInfoKey]! as AnyObject).intValue)!
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
        
        UIView.animate(withDuration: duration, delay: 0, options: option) {
            self.view.layoutIfNeeded()
        } completion: { (finished) in
        }
    }
    
    @objc func handleKeyboardWillHide(_ notification: Notification) {
        if !textView.isFirstResponder {
            return
        }
        
        guard view.window != nil else {
            return
        }
        
        for item in toolbar.items! {
            if item.tag == 9 {
                item.image = UIImage(named: "Collapse_Arrow_50")
            }
        }

        replyPreviewViewTopConstraint.constant = 10
        toolBarBottomConstraint.constant = 0

        let duration = ((notification as NSNotification).userInfo![UIResponder.keyboardAnimationDurationUserInfoKey]! as AnyObject).doubleValue ?? 0
        let curve = UIView.AnimationCurve(rawValue: ((notification as NSNotification).userInfo![UIResponder.keyboardAnimationCurveUserInfoKey]! as AnyObject).intValue)!
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
        
        UIView.animate(withDuration: duration, delay: 0, options: option) {
            self.view.layoutIfNeeded()
        } completion: { (finished) in
        }
    }
    
    //bar item actions
    @IBAction func handleAddLinkItemClick(_ sender: AnyObject) {
        if textView.isFirstResponder {
            textView.resignFirstResponder()
        }
        
        let alert = UIAlertController(title: "插入链接", message: "输入链接文字和URL", preferredStyle: .alert)
        alert.addTextField { (textfield) in
            textfield.placeholder = "输入链接显示的文字"
            textfield.keyboardType = .default
            textfield.keyboardAppearance = Theme().keyboardAppearence
        }
        alert.addTextField { (textfield) in
            textfield.placeholder = "输入链接跳转的目标URL"
            textfield.keyboardType = .URL
            textfield.keyboardAppearance = Theme().keyboardAppearence
        }
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { (action) in
            let fail = { () in
                let failAlert = UIAlertController(title: "提示", message: "链接地址无效", preferredStyle: .alert)
                failAlert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { (action) in
                    
                }))
                self.present(failAlert, animated: true, completion: nil)
            }
            
            guard let title = alert.textFields![0].text, let link = alert.textFields![1].text else {
                fail()
                return
            }
            
            guard let _ = Foundation.URL(string: link) else {
                fail()
                return
            }
            let content = "[url=\(link)]\(title)[/url]"
            self.textView.insertText(content)
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { (action) in
            
        }))
        alert.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
        present(alert, animated: true, completion: nil)
    }
    
    private func hideInputView(animated: Bool) {
        for item in toolbar.items! {
            if item.tag == 9 {
                item.image = UIImage(named: "Collapse_Arrow_50")
            }
        }
        
        replyPreviewViewTopConstraint.constant = 10
        toolBarBottomConstraint.constant = 0
        UIView.animate(withDuration: animated ? 0.3 : 0, animations: {
            self.view.layoutIfNeeded()
        }) { (finished) in
        }
    }
    
    @IBAction func handleImgBarItemClick(_ sender: AnyObject) {
        if textView.isFirstResponder {
            textView.resignFirstResponder()
        }
        
        let alert = UIAlertController(title: "插入站外图片", message: "输入图片URL", preferredStyle: .alert)
        alert.addTextField { (textfield) in
            textfield.keyboardType = .URL
            textfield.placeholder = "输入图片URL"
            textfield.keyboardAppearance = Theme().keyboardAppearence
        }
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { (action) in
            let fail = { () in
                let failAlert = UIAlertController(title: nil, message: "URL为空", preferredStyle: .alert)
                failAlert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { (action) in
                    
                }))
                self.present(failAlert, animated: true, completion: nil)
            }
            
            guard let username = alert.textFields![0].text else {
                fail()
                return
            }
            
            guard !username.isEmpty else {
                fail()
                return
            }
            
            let content = "[img]\(username)[/img]"
            self.textView.insertText(content)
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: { (action) in
            
        }))
        alert.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func handleUploadImageBarItemClick(_ sender: UIBarButtonItem) {
        
        if uploadingImages.count > 0 {
            if textView.isFirstResponder {
                textView.resignFirstResponder()
            }
            let alert = UIAlertController(title: "提示", message: "论坛目前仅支持上传单个图片。如需重新上传，请先删除已有图片。", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: {(action) in
            })
            alert.addAction(cancelAction)
            present(alert, animated: true, completion: nil)
            return
        }
        
        let noPermissionBlock: (() -> Void) = {
            let alert = UIAlertController(title: "提示", message: "无法选择照片", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        let sheet = UIAlertController(title: "上传本地图片", message: "选择照片源", preferredStyle: .actionSheet)
        sheet.popoverPresentationController?.barButtonItem = sender
        
        sheet.addAction(UIAlertAction(title: "系统相册", style: .default) { (action) in
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let types = UIImagePickerController.availableMediaTypes(for: .photoLibrary)
                guard types != nil else {
                    noPermissionBlock()
                    return
                }
                
                let imagePicker = UIImagePickerController()
                imagePicker.delegate = self
                imagePicker.sourceType = .photoLibrary
                imagePicker.mediaTypes = types!
                self.present(imagePicker, animated: true, completion: nil)
            } else {
                noPermissionBlock()
            }
        })
        
        sheet.addAction(UIAlertAction(title: "拍摄", style: .default) { (action) in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let types = UIImagePickerController.availableMediaTypes(for: .camera)
                guard types != nil else {
                    noPermissionBlock()
                    return
                }
                
                let imagePicker = UIImagePickerController()
                imagePicker.delegate = self
                imagePicker.sourceType = .camera
                imagePicker.mediaTypes = types!
                self.present(imagePicker, animated: true, completion: nil)
            }
        })
        
        sheet.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))
        
        present(sheet, animated: true, completion: nil)
    }
    
    
    @objc func handleSendBarItemClick(_ sender: UIBarButtonItem) {
        if textView.isFirstResponder {
            textView.resignFirstResponder()
        }
        
        if textView.text.isEmpty && uploadingImages.count == 0 {
            let alert = UIAlertController(title: "提示", message: "必须填写回复内容，或者上传图片才能发送", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            present(alert, animated: true, completion: nil)
            return
        }
        
        let fid = self.quoteInfo["fid"] as! String
        
        let message = self.getInputText()
        let formhash = self.quoteInfo["formhash"] as! String
        let tid = self.quoteInfo["tid"] as! String
        
        let quote_id = quoteInfo["quote_id"] as? String
        let quote_content = quoteInfo["quote_content_raw"] as? String
        let activity = SAModalActivityViewController()
        present(activity, animated: true, completion: nil)
        if uploadingImages.count > 0 {
            urlSession.uploadImage(to: fid, image: uploadingImages.first!, progress: nil) { (result, error) in
                if error != nil || result == nil {
                    self.delegate?.replyDidFail(self)
                    activity.hideAndShowResult(of: false, info: "失败") { () in
                        
                    }
                    return
                }
                
                let attachid = result as! String
                self.urlSession.reply(quoteId: quote_id, quoteMessage: quote_content, tid: tid, message: message, attachid: attachid, formhash: formhash, completion: { (result, error) in
                    if error == nil {
                        self.delegate?.replyDidSucceed(self)
                        activity.hideAndShowResult(of: true, info: "已发送") { () in
                            self.shouldSaveDraft = false
                            self.deleteDraftAfterSent()
                            if let presenting = self.presentingViewController {
                                presenting.dismiss(animated: true, completion: nil)
                            } else {
                                if #available(iOS 13.0, *) {
                                    if let sceneSession = self.view.window?.windowScene?.session {
                                        self.view.window?.resignFirstResponder()
                                        let options = UIWindowSceneDestructionRequestOptions()
                                        options.windowDismissalAnimation = .commit
                                        UIApplication.shared.requestSceneSessionDestruction(sceneSession, options: options, errorHandler: { (error) in
                                            os_log("request scene session destruction returned: %@", error.localizedDescription)
                                        })
                                    }
                                } else {
                                    fatalError("This view controller must be presented if not in a new scene.")
                                }
                            }
                        }
                    } else {
                        self.delegate?.replyDidFail(self)
                        activity.hideAndShowResult(of: false, info: "失败") { () in
                            
                        }
                    }
                })
            }
        } else {
            urlSession.reply(quoteId: quote_id, quoteMessage: quote_content, tid: tid, message: message, attachid: nil, formhash: formhash, completion: { (result, error) in
                if error == nil {
                    self.delegate?.replyDidSucceed(self)
                    activity.hideAndShowResult(of: true, info: "已发送") { () in
                        self.shouldSaveDraft = false
                        self.deleteDraftAfterSent()
                        if let presenting = self.presentingViewController {
                            presenting.dismiss(animated: true, completion: nil)
                        } else {
                            if #available(iOS 13.0, *) {
                                if let sceneSession = self.view.window?.windowScene?.session {
                                    self.view.window?.resignFirstResponder()
                                    let options = UIWindowSceneDestructionRequestOptions()
                                    options.windowDismissalAnimation = .commit
                                    UIApplication.shared.requestSceneSessionDestruction(sceneSession, options: options, errorHandler: { (error) in
                                        os_log("request scene session destruction returned: %@", error.localizedDescription)
                                    })
                                }
                            } else {
                                fatalError("This view controller must be presented if not in a new scene.")
                            }
                        }
                    }
                } else  {
                    self.delegate?.replyDidFail(self)
                    activity.hideAndShowResult(of: false, info: "失败") { () in
                        
                    }
                }
            })
        }
    }
    
    @IBAction func handleCallapseBarItemClick(_ sender: UIBarButtonItem) {
        if textView.isFirstResponder {
            textView.resignFirstResponder()
            sender.image = UIImage(named: "Collapse_Arrow_50")
            return
        }
        
        sender.image = UIImage(named: "Expand_Arrow_50")
        textView.becomeFirstResponder()
    }
    
    @objc func handleCloseBarItemClick(_ sender: UIBarButtonItem) {
        shouldSaveDraft = true
        saveDraft()
        if let presenting = self.presentingViewController {
            presenting.dismiss(animated: true, completion: nil)
        } else {
            if #available(iOS 13.0, *) {
                if let sceneSession = self.view.window?.windowScene?.session {
                    self.view.window?.resignFirstResponder()
                    let options = UIWindowSceneDestructionRequestOptions()
                    options.windowDismissalAnimation = .decline
                    UIApplication.shared.requestSceneSessionDestruction(sceneSession, options: options, errorHandler: { (error) in
                        os_log("request scene session destruction returned: %@", error.localizedDescription)
                    })
                }
            } else {
                fatalError("This view controller must be presented if not in a new scene.")
            }
        }
    }
}


extension SAReplyViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
