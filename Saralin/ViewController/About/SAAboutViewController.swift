//
//  SAAboutViewController.swift
//  Saralin
//
//  Created by zhang on 9/25/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit
import MessageUI

class SAAboutViewController: SABaseTableViewController, MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate {
    
    class HeaderView: UITableViewHeaderFooterView {
        let stack = UIStackView()
        let imageView = UIImageView.init(image: UIImage(named: "logo"))
        let versionLabel = UILabel()
        let configVersionLabel = UILabel()

        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            commonInit()
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            commonInit()
        }
        
        private func commonInit() {
            stack.axis = .vertical
            stack.alignment = .center
            imageView.widthAnchor.constraint(equalToConstant: 90).isActive = true
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 1.0).isActive = true
            imageView.layer.cornerRadius = 45
            imageView.layer.masksToBounds = true
            stack.addArrangedSubview(imageView)
            stack.setCustomSpacing(20, after: imageView)

            let bundleVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
            versionLabel.textAlignment = .center
            versionLabel.textColor = UIColor.sa_colorFromHexString(Theme().textColor)
            versionLabel.font = UIFont.boldSystemFont(ofSize: 16)
            
            let version = NSLocalizedString("APP_VERSION", comment: "Version") + ": \(bundleVersion)\n"
            versionLabel.text = version
            stack.addArrangedSubview(versionLabel)
            stack.setCustomSpacing(4, after: versionLabel)
            
            configVersionLabel.textAlignment = .center
            configVersionLabel.textColor = UIColor.sa_colorFromHexString(Theme().textColor)
            configVersionLabel.font = UIFont.boldSystemFont(ofSize: 16)
            
            var onlineConfigVersion = "[None]"
            if let localData = try? Data.init(contentsOf: AppController.current.appOnlineConfigFileURL),
                let localDict = try? PropertyListSerialization.propertyList(from: localData, options: [], format: nil) as? [String:AnyObject],
                let onlineVersion = localDict["ConfigVersion"] as? String {
                onlineConfigVersion = onlineVersion
            }
            let configVersionStr = NSLocalizedString("CONFIG_VERSION", comment: "Config") + ": \(onlineConfigVersion)"
            configVersionLabel.text = configVersionStr
            stack.addArrangedSubview(configVersionLabel)
            stack.setCustomSpacing(4, after: configVersionLabel)

            addSubview(stack)
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0).isActive = true
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0).isActive = true
        }
        
        override func themeDidUpdate(_ newTheme: SATheme) {
            super.themeDidUpdate(newTheme)
            versionLabel.textColor = UIColor.sa_colorFromHexString(newTheme.textColor)
            configVersionLabel.textColor = UIColor.sa_colorFromHexString(newTheme.textColor)
        }
    }
    
    class FooterView: UITableViewHeaderFooterView {
        let stack = UIStackView()
        let donateButton = UIButton.init()
        let openSourceProjectButton = UIButton.init()
        let submitFeedbackButton = UIButton.init()
        let rateInAppStoreButton = UIButton.init()

        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            commonInit()
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            commonInit()
        }
        
        private func commonInit() {
            stack.axis = .vertical
            stack.spacing = 10
            stack.alignment = .center
            stack.distribution = .equalSpacing
#if false
            let openSourceTitle = NSAttributedString.init(string: NSLocalizedString("ABOUT_VC_OPEN_SOURCE_PROJECT_URL", comment: "Project Source Code"),
                                                          attributes: [.foregroundColor:UIColor.blue,.underlineStyle:NSNumber(value:NSUnderlineStyle.single.rawValue)])
            openSourceProjectButton.setAttributedTitle(openSourceTitle, for: .normal)
            openSourceProjectButton.titleLabel?.font = UIFont.sa_preferredFont(forTextStyle: .body)
            stack.addArrangedSubview(openSourceProjectButton)
            stack.setCustomSpacing(10, after: openSourceProjectButton)
#endif
            
            stack.addArrangedSubview(submitFeedbackButton)
            stack.addArrangedSubview(rateInAppStoreButton)
            stack.addArrangedSubview(donateButton)
            
            addSubview(stack)
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0).isActive = true
            stack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0).isActive = true
        }
        
        override func themeDidUpdate(_ newTheme: SATheme) {
            super.themeDidUpdate(newTheme)
            
            let color = newTheme.textColor.sa_toColor()            
            let linkIcon = NSTextAttachment()
            linkIcon.image = UIImage.init(named: "icons8-external-link-60")?.imageWithColor(newColor: color)
            linkIcon.bounds = .init(x: 0, y: -4, width: 20, height: 20)
            
            let submitAttributedTitle = NSAttributedString.init(string: NSLocalizedString("ABOUT_VC_FEEDBACK", comment: "Feedback"), attributes:
                [.foregroundColor:color,.underlineStyle:NSNumber(value:NSUnderlineStyle.single.rawValue)])
            submitFeedbackButton.setAttributedTitle(submitAttributedTitle, for: .normal)
                        
            let rateAttributedTitle = NSMutableAttributedString.init(string: NSLocalizedString("ABOUT_VC_APP_STORE_RATE", comment: "Rate in App Store"), attributes: [.foregroundColor:color,.underlineStyle:NSNumber(value:NSUnderlineStyle.single.rawValue)])
            rateAttributedTitle.append(NSAttributedString.init(attachment: linkIcon))
            rateInAppStoreButton.setAttributedTitle(rateAttributedTitle, for: .normal)
            
            let donateAttributedTitle = NSAttributedString.init(string: NSLocalizedString("ABOUT_VC_DONATE", comment: "Donate the developer"),
                                                              attributes: [.foregroundColor:UIColor.red,.underlineStyle:NSNumber(value:NSUnderlineStyle.single.rawValue)])
            donateButton.setAttributedTitle(donateAttributedTitle, for: .normal)
        }
        
        override func fontDidUpdate(_ newTheme: SATheme) {
            super.fontDidUpdate(newTheme)
            let font = UIFont.boldSystemFont(ofSize: 16)
            submitFeedbackButton.titleLabel?.font = font
            rateInAppStoreButton.titleLabel?.font = font
            donateButton.titleLabel?.font = font
        }
    }
    
    private var dataSource: [[[String:Any]]]!
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        dataSource = [
            [
                ["title":NSLocalizedString("LEGAL_NOTICE_VC_TITLE", comment: "Legal"), "detail":"", "action":#selector(actionViewLegalLicense(_:))],
                ["title":NSLocalizedString("ABOUT_VC_ELUA", comment: "EULA"), "detail":"", "action":#selector(actionViewEULA(_:))],
            ]
        ]
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SAThemedTableViewCell.self, forCellReuseIdentifier: "SAThemedTableViewCell")
        tableView.register(HeaderView.self, forHeaderFooterViewReuseIdentifier: "HeaderView")
        tableView.register(FooterView.self, forHeaderFooterViewReuseIdentifier: "FooterView")
        title = NSLocalizedString("ABOUT_VC_TITLE", comment: "About")
    }
    
    override var showsRefreshControl: Bool {
        return false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].count
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section > 0 {
            return nil
        }
        
        guard let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderView") as? HeaderView else {
            return nil
        }
        
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(handleLogoImageTap(_:)))
        tap.numberOfTapsRequired = 5
        view.imageView.addGestureRecognizer(tap)
        view.imageView.isUserInteractionEnabled = true
        return view
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section > 0 {
            return nil
        }
        
        guard let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "FooterView") as? FooterView else {
            return nil
        }
        view.donateButton.addTarget(self, action: #selector(handleDonateButtonClick(_:)), for: .touchUpInside)
        view.openSourceProjectButton.addTarget(self, action: #selector(handleOpenSourceButtonClick(_:)), for: .touchUpInside)
        view.submitFeedbackButton.addTarget(self, action: #selector(actionSubmitFeedBack(_:)), for: .touchUpInside)
        view.rateInAppStoreButton.addTarget(self, action: #selector(actionRateInAppStore(_:)), for: .touchUpInside)
        return view
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 200
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 200
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SAThemedTableViewCell", for: indexPath) as! SAThemedTableViewCell

        let info = dataSource[indexPath.section][indexPath.row]
        // Configure the cell...
        cell.textLabel?.text = info["title"] as? String
        cell.detailTextLabel?.text = info["detail"] as? String
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cell = tableView.cellForRow(at: indexPath)!
        if let sel = dataSource[indexPath.section][indexPath.row]["action"] as? Selector {
            perform(sel, with: cell)
        }
    }
    
    @objc func actionRateInAppStore(_ sender: AnyObject) {
        if let url = URL(string: SAGlobalConfig().app_store_link + "?action=write-review") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    @objc func handleLogoImageTap(_ sender: AnyObject) {
        let debug = SADebuggingViewController()
        navigationController?.pushViewController(debug, animated: true)
    }
    
    @objc func actionSubmitFeedBack(_ sender: AnyObject) {
        let cell = sender as! UIView
        let bundleVersion = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
        let alert = UIAlertController(title: nil, message: "请选择联系方式", preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = cell
        alert.popoverPresentationController?.sourceRect = cell.bounds
        alert.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel) { (action) in
        })
        
        alert.addAction(UIAlertAction(title: "iMessage(推荐)", style: .default){ (action) in
            if !MFMessageComposeViewController.canSendText() {
                os_log("message services are not available", log: .ui, type: .info)
                return
            }
            
            let composeVC = MFMessageComposeViewController()
            composeVC.messageComposeDelegate = self
            
            // Configure the fields of the interface.
            composeVC.recipients = [SAGlobalConfig().developer_imessage_address]
            composeVC.body = "Saralin(\(bundleVersion))意见反馈\n"
            
            // add log files
            let tempFileName = NSTemporaryDirectory() + "/\(Int(Date().timeIntervalSince1970 * 1000)).log"
            let tempFileURL = URL.init(fileURLWithPath: tempFileName, isDirectory: false)
            if let _ = try? FileManager.default.copyItem(atPath: sa_current_log_file_path(), toPath: tempFileName) {
                composeVC.addAttachmentURL(tempFileURL, withAlternateFilename: tempFileURL.lastPathComponent)
            } else {
                os_log("can not copy log file", type: .error)
            }
            // Present the view controller modally.
            self.present(composeVC, animated: true, completion: nil)
        })
        
        alert.addAction(UIAlertAction(title: "电子邮件", style: .default){ (action) in
            if !MFMailComposeViewController.canSendMail() {
                os_log("Mail services are not available", log: .ui, type: .info)
                return
            }
            
            let composeVC = MFMailComposeViewController()
            composeVC.mailComposeDelegate = self
            
            // Configure the fields of the interface.
            composeVC.setToRecipients([SAGlobalConfig().developer_email_address])
            composeVC.setSubject("Saralin(\(bundleVersion))意见反馈\n")
            composeVC.setMessageBody("", isHTML: false)
            
            // add log files
            let tempFileName = "\(Int(Date().timeIntervalSince1970 * 1000)).log"
            let logFilePath = URL(fileURLWithPath: sa_current_log_file_path())
            if let logFileData = try? Data.init(contentsOf: logFilePath, options: []) {
                composeVC.addAttachmentData(logFileData, mimeType: "text/plain", fileName: tempFileName)
            }
            // Present the view controller modally.
            self.present(composeVC, animated: true, completion: nil)
        })
        present(alert, animated: true, completion: nil)
    }
    
    @objc func actionViewLegalLicense(_ sender: AnyObject) {
        let vc = SAPlainTextViewController()
        vc.title = NSLocalizedString("LEGAL_NOTICE_VC_TITLE", comment: "法律许可")
        let url = Bundle.main.url(forResource: "license", withExtension: "txt")!
        let text = try! String.init(contentsOf: url)
        vc.text = text
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func actionViewEULA(_ sender: AnyObject) {
        let vc = SAPlainTextViewController()
        vc.title = NSLocalizedString("EULA_VC_TITLE", comment: "EULA")
        let url = Bundle.main.url(forResource: "eula", withExtension: "txt")!
        let text = try! String.init(contentsOf: url)
        vc.text = text
        navigationController?.pushViewController(vc, animated: true)
    }
    
    // delegate
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Check the result or perform other tasks.
        controller.dismiss(animated: true, completion: nil)
    }
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: nil)
    }
        
    @objc func handleDonateButtonClick(_ sender: UIButton) {
        let alert = UIAlertController(title: NSLocalizedString("IAP_DONATE_TITLE", comment: "Donate"), message:  NSLocalizedString("IAP_DONATE_FIVE_YUAN_DESCRIPTION", comment: "Donate"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction.init(title: NSLocalizedString("OK", comment: "OK"), style: .default, handler: { (action) in
            // show iap purchase
            AppController.current.getService(of: SAIAPManager.self)!.presentIAPInterface()
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc func handleOpenSourceButtonClick(_ sender: UIButton) {
        let url = URL.init(string: SAGlobalConfig().project_source_code_url)!
        UIApplication.shared.open(url)
    }
}
