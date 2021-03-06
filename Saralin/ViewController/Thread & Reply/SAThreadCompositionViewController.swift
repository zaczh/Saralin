//
//  SAThreadCompositionViewController.swift
//  Saralin
//
//  Created by zhang on 1/24/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import WebKit

class SAThreadCompositionViewController: SAUITableViewController {
    
    class TitleCell: UITableViewCell {
        let textField = UITextField.init()
        let titleLabel = UILabel.init()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            selectionStyle = .none
            
            contentView.addSubview(titleLabel)
            titleLabel.text = "帖子标题："
            titleLabel.font = UIFont.sa_preferredFont(forTextStyle: .body)
            titleLabel.textColor = Theme().textColor.sa_toColor()
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.leftAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leftAnchor, constant: 8).isActive = true
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
            titleLabel.setContentHuggingPriority(.required, for: .horizontal)
            
            contentView.addSubview(textField)
            textField.placeholder = "请输入标题"
            textField.font = UIFont.sa_preferredFont(forTextStyle: .body)
            textField.textColor = Theme().textColor.sa_toColor()
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.leftAnchor.constraint(equalTo: titleLabel.rightAnchor, constant: 8).isActive = true
            textField.rightAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.rightAnchor, constant: -8).isActive = true
            textField.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class InsertImageCell: UITableViewCell {
        let insertImageButton = UIButton(type: .custom)
        let titleLabel = UILabel.init()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            selectionStyle = .none

            contentView.addSubview(titleLabel)
            titleLabel.text = "插入图片："
            titleLabel.font = UIFont.sa_preferredFont(forTextStyle: .body)
            titleLabel.textColor = Theme().textColor.sa_toColor()
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.leftAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leftAnchor, constant: 8).isActive = true
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
            titleLabel.setContentHuggingPriority(.required, for: .horizontal)
           
            insertImageButton.imageView?.contentMode = .scaleAspectFit
            contentView.addSubview(insertImageButton)
            insertImageButton.setTitle(NSLocalizedString("TAP_TO_INSERT_IMAGE", comment: "Insert Image"), for: .normal)
            insertImageButton.translatesAutoresizingMaskIntoConstraints = false
            insertImageButton.rightAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.rightAnchor, constant: -8).isActive = true
            insertImageButton.widthAnchor.constraint(equalToConstant: 200).isActive = true
            insertImageButton.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            insertImageButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
       }
       
       required init?(coder aDecoder: NSCoder) {
           fatalError("init(coder:) has not been implemented")
       }
   }
    
    class CategoryCell: UITableViewCell {
        let categoryLabel = UILabel.init()
        
        let selectedCategoryLabel = UILabel.init()
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            selectionStyle = .none
            contentView.addSubview(categoryLabel)
            categoryLabel.text = "主题分类："
            categoryLabel.textColor = Theme().textColor.sa_toColor()
            categoryLabel.font = UIFont.sa_preferredFont(forTextStyle: .body)
            categoryLabel.translatesAutoresizingMaskIntoConstraints = false
            categoryLabel.leftAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leftAnchor, constant: 8).isActive = true
            categoryLabel.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            categoryLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
            categoryLabel.setContentHuggingPriority(.required, for: .horizontal)

            contentView.addSubview(selectedCategoryLabel)
            selectedCategoryLabel.translatesAutoresizingMaskIntoConstraints = false
            selectedCategoryLabel.font = UIFont.sa_preferredFont(forTextStyle: .body)
            selectedCategoryLabel.adjustsFontSizeToFitWidth = true
            selectedCategoryLabel.minimumScaleFactor = 0.3
            selectedCategoryLabel.textColor = Theme().textColor.sa_toColor()
            selectedCategoryLabel.translatesAutoresizingMaskIntoConstraints = false
            selectedCategoryLabel.leftAnchor.constraint(equalTo: categoryLabel.rightAnchor, constant: 8).isActive = true
            selectedCategoryLabel.rightAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.rightAnchor, constant: -8).isActive = true
            selectedCategoryLabel.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            selectedCategoryLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class BodyCell: UITableViewCell {
        let textView = UITextView.init()
        let placeholderLabel = UILabel.init()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            selectionStyle = .none
            
            contentView.addSubview(placeholderLabel)
            placeholderLabel.text = "输入内容"
            placeholderLabel.textColor = .init(red: 0, green: 0, blue: 0.1, alpha: 0.22)
            placeholderLabel.font = UIFont.sa_preferredFont(forTextStyle: .body)
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            placeholderLabel.leftAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leftAnchor, constant: 8).isActive = true
            placeholderLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8).isActive = true
            
            contentView.addSubview(textView)
            textView.font = UIFont.sa_preferredFont(forTextStyle: .body)
            textView.textColor = Theme().textColor.sa_toColor()
            textView.textContainerInset = UIEdgeInsets.init(top: 8, left: 4, bottom: 8, right: 4)
            textView.translatesAutoresizingMaskIntoConstraints = false
            textView.leftAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leftAnchor).isActive = true
            textView.rightAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.rightAnchor).isActive = true
            textView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
            
            contentView.bringSubviewToFront(placeholderLabel)
            NotificationCenter.default.addObserver(forName: UITextView.textDidChangeNotification, object: textView, queue: nil) { [weak self] (notification) in
                self?.placeholderLabel.isHidden = !(self?.textView.text.isEmpty ?? true)
            }
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    var fid: String!
    private var formData: [String:AnyObject] = [:]
    private var typeIDList: [[String:String]] = []
    private var selectedTypeIndex = -1
    #if !targetEnvironment(macCatalyst)
    private let typePickerView = UIPickerView()
    #endif
    
    func config(fid: String) {
        self.fid = fid
    }
    
    private let tableViewCells = [
        TitleCell(),
        CategoryCell(),
        InsertImageCell(),
        BodyCell(),
    ]
    
    private func findCellOfType<T>(_ type: T.Type) -> T? {
        for cell in tableViewCells {
            if let c = cell as? T {
                return c
            }
        }
        
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
        
        tableView.separatorInset = .zero
        tableView.tableFooterView = UIView()
        
        #if !targetEnvironment(macCatalyst)
        typePickerView.isHidden = true
        tableView.addSubview(typePickerView)
        typePickerView.translatesAutoresizingMaskIntoConstraints = false
        typePickerView.leftAnchor.constraint(equalTo: tableView.frameLayoutGuide.leftAnchor).isActive = true
        typePickerView.rightAnchor.constraint(equalTo: tableView.frameLayoutGuide.rightAnchor).isActive = true
        typePickerView.bottomAnchor.constraint(equalTo: tableView.frameLayoutGuide.bottomAnchor, constant: 0).isActive = true
        typePickerView.heightAnchor.constraint(equalTo: tableView.frameLayoutGuide.heightAnchor, multiplier: 0.33).isActive = true
        typePickerView.dataSource = self
        typePickerView.delegate = self
        #endif
        
        let leftItem = UIBarButtonItem(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .plain, target: self, action: #selector(SAThreadCompositionViewController.handleLeftButtonItemClick(_:)))
        let rightItem = UIBarButtonItem(title: NSLocalizedString("POST", comment: "Post"), style: .plain, target: self, action: #selector(SAThreadCompositionViewController.handleRightButtonItemClick(_:)))
        navigationItem.leftBarButtonItems = [leftItem]
        navigationItem.rightBarButtonItems = [rightItem]
        
        title = NSLocalizedString("COMPOSE_THREAD", comment: "发表新帖")
        
        if let titleCell = findCellOfType(TitleCell.self) {
            let toolbar = UIToolbar.init(frame: .init(x: 0, y: 0, width: 0, height: 44))
            let space = UIBarButtonItem.init(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let barItem = UIBarButtonItem.init(title: NSLocalizedString("CLOSE", comment: "Close"), style: .plain, target: self, action: #selector(handleClose(_:)))
            toolbar.items = [space, barItem]
            titleCell.textField.inputAccessoryView = toolbar
        }
        
        let insertImageCell = findCellOfType(InsertImageCell.self)!
        insertImageCell.insertImageButton.addTarget(self, action: #selector(handleInsertImageButtonTap(_:)), for: .touchUpInside)
        
        if let bodyCell = findCellOfType(BodyCell.self) {
            let toolbar = UIToolbar.init(frame: .init(x: 0, y: 0, width: 0, height: 44))
            let space = UIBarButtonItem.init(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let barItem = UIBarButtonItem.init(title: NSLocalizedString("CLOSE", comment: "Close"), style: .plain, target: self, action: #selector(handleClose(_:)))
            toolbar.items = [space, barItem]
            bodyCell.textView.inputAccessoryView = toolbar
        }
        
        guard let _ = self.fid else {
            return
        }
        doReload()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        #if targetEnvironment(macCatalyst)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        #endif
    }
    
    override func loadingControllerDidRetry(_ controller: SALoadingViewController) {
        doReload()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        
        let theme = Theme()
        tableView.backgroundColor = theme.backgroundColor.sa_toColor()
        
        #if !targetEnvironment(macCatalyst)
        typePickerView.backgroundColor = theme.foregroundColor.sa_toColor()
        #endif
        
        let titleCell = findCellOfType(TitleCell.self)!
        titleCell.backgroundColor = theme.backgroundColor.sa_toColor()
        titleCell.titleLabel.textColor = theme.textColor.sa_toColor()
        titleCell.textField.keyboardAppearance = theme.keyboardAppearence
        titleCell.textField.textColor = theme.textColor.sa_toColor()
        titleCell.textField.attributedPlaceholder = NSAttributedString(string: "请输入标题", attributes: [NSAttributedString.Key.foregroundColor : theme.tableCellGrayedTextColor.sa_toColor()])

        let insertImageCell = findCellOfType(InsertImageCell.self)!
        insertImageCell.backgroundColor = theme.backgroundColor.sa_toColor()
        insertImageCell.titleLabel.textColor = theme.textColor.sa_toColor()
        insertImageCell.insertImageButton.setTitleColor(theme.textColor.sa_toColor(), for: .normal)

        let categoryCell = findCellOfType(CategoryCell.self)!
        categoryCell.backgroundColor = theme.backgroundColor.sa_toColor()
        categoryCell.categoryLabel.textColor = theme.textColor.sa_toColor()
        categoryCell.selectedCategoryLabel.textColor = theme.textColor.sa_toColor()
        
        let bodyCell = findCellOfType(BodyCell.self)!
        bodyCell.backgroundColor = theme.backgroundColor.sa_toColor()
        bodyCell.textView.backgroundColor = .clear
        bodyCell.textView.textColor = theme.textColor.sa_toColor()
        bodyCell.textView.keyboardAppearance = theme.keyboardAppearence
        bodyCell.placeholderLabel.textColor = theme.tableCellGrayedTextColor.sa_toColor()
    }
    
    private func doReload() {
        loadingController.setLoading()
        URLSession.saCustomized.getComposingThreadHTTPForm(of: fid!) { [weak self] (html, error) in
            guard error == nil, let str = html as? String, let parser = try? HTMLParser.init(string: str) else {
                DispatchQueue.main.async {
                    let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"数据异常"])
                    self?.loadingController.setFailed(with: error)
                }
                return
            }
            
            guard let formhash = parser.body()?.findChild(withAttribute: "name", matchingName: "formhash", allowPartial: false)?.getAttributeNamed("value"),
                let posttime = parser.body()?.findChild(withAttribute: "name", matchingName: "posttime", allowPartial: false)?.getAttributeNamed("value") else {
                    DispatchQueue.main.async {
                        let error = NSError(domain: SAHTTPAPIErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey:"无法解析服务器数据"])
                        self?.loadingController.setFailed(with: error)
                    }
                    return
            }

            var typeIDArr: [[String:String]] = []
            parser.body()?.findChild(withAttribute: "id", matchingName: "typeid", allowPartial: false)?.children().forEach({ (node) in
                if let value = node.getAttributeNamed("value"), let name = node.contents() {
                    typeIDArr.append(["name": name, "value": value])
                }
            })

            DispatchQueue.main.async {
                self?.typeIDList.removeAll()
                self?.formData.removeAll()
                self?.typeIDList.append(contentsOf: typeIDArr)
                self?.formData["formhash"] = formhash as AnyObject
                self?.formData["posttime"] = posttime as AnyObject
                #if !targetEnvironment(macCatalyst)
                self?.typePickerView.reloadComponent(0)
                #endif
                self?.loadingController.setFinished()
                let titleCell = self?.findCellOfType(TitleCell.self)
                titleCell?.textField.becomeFirstResponder()
            }
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

    
    override func resignFirstResponder() -> Bool {
        let titleCell = findCellOfType(TitleCell.self)!
        titleCell.textField.resignFirstResponder()
        
        let bodyCell = findCellOfType(BodyCell.self)!
        bodyCell.textView.resignFirstResponder()
        
        return super.resignFirstResponder()
    }

    @objc func handleClose(_ sender: AnyObject) {
        _ = resignFirstResponder()
    }
    
    @objc func handleInsertImageButtonTap(_ sender: UIButton) {
        _ = resignFirstResponder()
        let insertImageCell = findCellOfType(InsertImageCell.self)!
        if let _ = insertImageCell.insertImageButton.image(for: .normal) {
            let sheet = UIAlertController(title: NSLocalizedString("HINT", comment: "Hint"), message: "是否删除图片", preferredStyle: .alert)
            sheet.popoverPresentationController?.sourceView = sender
            sheet.popoverPresentationController?.sourceRect = sender.bounds
            sheet.addAction(UIAlertAction(title: "删除", style: .destructive) { (action) in
                insertImageCell.insertImageButton.setImage(nil, for: .normal)
            })
            sheet.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel) { (action) in
            })
            present(sheet, animated: true, completion: nil)
            return
        }
        AppController.current.getImageFromPhotoLibrary(sender: self) { (image, error) in
            guard error == nil else {
                return
            }
            
            guard let insertImageCell = self.findCellOfType(InsertImageCell.self) else {
                return
            }

            insertImageCell.insertImageButton.setImage(image, for: .normal)
        }
    }
    
    @objc func handleLeftButtonItemClick(_:AnyObject) {
        if let presenting = self.navigationController?.presentingViewController {
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
    
    @objc func handleRightButtonItemClick(_ item:UIBarButtonItem) {
        let titleCell = findCellOfType(TitleCell.self)!
        let insertImageCell = findCellOfType(InsertImageCell.self)!
        let bodyCell = findCellOfType(BodyCell.self)!

        guard !(titleCell.textField.text?.isEmpty ?? true) && !bodyCell.textView.text.isEmpty else {
            let alert = UIAlertController(title: NSLocalizedString("HINT", comment: "Hint"), message: "帖子标题和内容不能为空。", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        guard selectedTypeIndex >= 0 else {
            let alert = UIAlertController(title: NSLocalizedString("HINT", comment: "Hint"), message: "请选择帖子分类。", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil)
            alert.addAction(cancelAction)
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        let modalActivity = SAModalActivityViewController(style: .loading, caption: "")
        self.present(modalActivity, animated: true, completion: nil)
        
        let attatchedImage = insertImageCell.insertImageButton.image(for: .normal)
        let queryParam: [String:String] = [
            "subject": titleCell.textField.text!,
            "typeid": typeIDList[selectedTypeIndex]["value"] ?? "0",
            "message": bodyCell.textView.text,
            "type": "image",
            "formhash": formData["formhash"] as! String,
            "posttime": formData["posttime"] as! String
        ]
        URLSession.saCustomized.submitComposingThreadForm(to: fid,
                                                          queryParam: queryParam,
                                                          attachment: attatchedImage) { (object, error) in
            guard error == nil, let html = object as? String else {
                DispatchQueue.main.async {
                    let modalActivity = self.presentedViewController as? SAModalActivityViewController
                    modalActivity?.hideAndShowResult(of: true, info: "失败") { () in
                    }
                }
                return
            }
                                            
            DispatchQueue.main.async {
                let modalActivity = self.presentedViewController as? SAModalActivityViewController
                if html.contains("非常感谢") {
                    modalActivity?.hideAndShowResult(of: true, info: "已发表") { () in
                        if let presenting = self.navigationController!.presentingViewController {
                            presenting.dismiss(animated: true, completion: nil)
                        } else {
                            if #available(iOS 13.0, *) {
                                if let sceneSession = self.view.window?.windowScene?.session {
                                    self.view.window?.resignFirstResponder()
                                    let options = UIWindowSceneDestructionRequestOptions()
                                    options.windowDismissalAnimation = .commit
                                    UIApplication.shared.requestSceneSessionDestruction(sceneSession, options: options, errorHandler:{ (error) in
                                        os_log("request scene session destruction returned: %@", error.localizedDescription)
                                    })
                                }
                            } else {
                                fatalError("This view controller must be presented if not in a new scene.")
                            }
                        }
                    }
                } else {
                    modalActivity?.hideAndShowResult(of: false, info: "失败") { () in
                    }
                }
            }
        }
    }
    
    // MARK: DataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableViewCells.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableViewCells[indexPath.row]
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case 3:
            return max(0, tableView.frame.size.height - 60 * 3 - tableView.safeAreaInsets.top - tableView.safeAreaInsets.bottom)
        default:
            return 60
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.row {
        case 0:
             break
        case 1:
            #if !targetEnvironment(macCatalyst)
            typePickerView.isHidden = false
            #else
            let cell = tableView.cellForRow(at: indexPath)!
            let alert = UIAlertController(title: "选择主题分类", message: nil, preferredStyle: .actionSheet)
            alert.popoverPresentationController?.sourceView = cell
            alert.popoverPresentationController?.sourceRect = cell.bounds
            for (row, item) in typeIDList.enumerated() {
                alert.addAction(UIAlertAction.init(title: item["name"], style: .default, handler: { (action) in
                    let categoryCell = self.findCellOfType(CategoryCell.self)!
                    categoryCell.selectedCategoryLabel.text = item["name"]
                    self.selectedTypeIndex = row
                }))
            }
            alert.addAction(UIAlertAction.init(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))
            present(alert, animated: false, completion: nil)
            #endif
            _ = resignFirstResponder()
            break
        case 2:
            break
        default:
            break
        }
    }
}

extension SAThreadCompositionViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return typeIDList.count
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        if component > 0 {
            return nil
        }
        let item = typeIDList[row]
        let attr = NSAttributedString.init(string: item["name"] ?? "", attributes: [NSAttributedString.Key.foregroundColor:Theme().textColor.sa_toColor()])
        return attr
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let item = typeIDList[row]
        let categoryCell = findCellOfType(CategoryCell.self)!
        categoryCell.selectedCategoryLabel.text = item["name"]
        selectedTypeIndex = row
        pickerView.isHidden = true
    }
}
