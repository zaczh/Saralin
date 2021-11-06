//
//  SATableViewCell.swift
//  Saralin
//
//  Created by zhang on 6/10/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

// MARK: - UITableViewCell

class SAThemedTableViewCell: UITableViewCell {
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var height = CGFloat(32)
        if let font = textLabel?.font {
            height = height + font.lineHeight
        }
        
        return CGSize.init(width: size.width, height: height)
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        selectedBackgroundView = UIView()
        textLabel?.numberOfLines = 0
        detailTextLabel?.numberOfLines = 0
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func themeDidUpdate(_ newTheme: SATheme) {
        super.themeDidUpdate(newTheme)
        selectedBackgroundView?.backgroundColor = UIColor.sa_colorFromHexString(Theme().tableCellHighlightColor)
        detailTextLabel?.textColor = UIColor.sa_colorFromHexString(Theme().tableCellTextColor)
        backgroundColor = UIColor.sa_colorFromHexString(Theme().foregroundColor)
        tintColor = UIColor.sa_colorFromHexString(Theme().tableCellTintColor)
        textLabel?.textColor = UIColor.sa_colorFromHexString(Theme().tableCellTextColor)
    }
    
    override func fontDidUpdate(_ newTheme: SATheme) {
        super.fontDidUpdate(newTheme)
        detailTextLabel?.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
        textLabel?.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline)
    }
}

class SADropdownMenuTableViewCell: SAThemedTableViewCell {
    var customLabel = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .none
        customLabel.textAlignment = .center
        contentView.addSubview(customLabel)
        customLabel.translatesAutoresizingMaskIntoConstraints = false
        customLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 0).isActive = true
        customLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: 0).isActive = true
        customLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0).isActive = true
        customLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func fontDidUpdate(_ newTheme: SATheme) {
        super.fontDidUpdate(newTheme)
        customLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
    }
    
    override func themeDidUpdate(_ newTheme: SATheme) {
        super.themeDidUpdate(newTheme)
        backgroundColor = UIColor.clear
        customLabel.textColor = Theme().globalTintColor.sa_toColor()
    }
}

class SAMessageInboxTableViewCell: SABoardTableViewCell {
    private let avatarImageViewSize = CGSize.init(width: UIFont.sa_bodyFontSize * 2.5, height: UIFont.sa_bodyFontSize * 2.5)
    let avatarImageView = UIImageView()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        avatarImageView.backgroundColor = UIColor.gray
        avatarImageView.layer.cornerRadius = 2
        avatarImageView.layer.masksToBounds = true
        customTitleLabel.numberOfLines = 2
        NSLayoutConstraint(item: avatarImageView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: avatarImageViewSize.width).isActive = true
        NSLayoutConstraint(item: avatarImageView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: avatarImageViewSize.height).isActive = true
        topStack.insertArrangedSubview(avatarImageView, at: 0)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SABoardTableViewCell: SAThemedTableViewCell {
    let contentStack = UIStackView()
    let topStack = UIStackView()
    let bottomStack = UIStackView()
    
    let timeLabelStack = UIStackView()
    let titleStack = UIStackView()
    let replyAndViewStack = UIStackView()

    let customNameLabel = UILabel()
    let customTitleLabel = UILabel()
    let customTimeLabel = UILabel()
    let customReplyLabel = UILabel()
    let customViewLabel = UILabel()
    let icloudIndicator = UIButton()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .none
        
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.leftAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leftAnchor, constant: 0).isActive = true
        contentStack.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor, constant: 0).isActive = true
        contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8).isActive = true
        contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8).isActive = true
        
        timeLabelStack.axis = .horizontal
        timeLabelStack.alignment = .leading
        timeLabelStack.addArrangedSubview(customTimeLabel)
        timeLabelStack.addArrangedSubview(icloudIndicator)
        
        topStack.axis = .horizontal
        topStack.alignment = .leading
        topStack.spacing = 8
        topStack.addArrangedSubview(customNameLabel)
        topStack.addArrangedSubview(UIView())
        topStack.addArrangedSubview(timeLabelStack)
        contentStack.addArrangedSubview(topStack)
        
        titleStack.axis = .horizontal
        titleStack.spacing = 8
        titleStack.addArrangedSubview(customTitleLabel)
        contentStack.addArrangedSubview(titleStack)
        
        bottomStack.axis = .horizontal
        bottomStack.spacing = 8
        
        replyAndViewStack.axis = .horizontal
        replyAndViewStack.spacing = 4
        replyAndViewStack.addArrangedSubview(customReplyLabel)
        replyAndViewStack.addArrangedSubview(customViewLabel)
        bottomStack.addArrangedSubview(UIView())
        bottomStack.addArrangedSubview(replyAndViewStack)
        
        contentStack.addArrangedSubview(bottomStack)
        
        customTitleLabel.lineBreakMode = .byWordWrapping
        customTitleLabel.numberOfLines = 0
        
        customTimeLabel.lineBreakMode = .byTruncatingMiddle
        
        icloudIndicator.setTitle("☁", for: .normal)
        icloudIndicator.isUserInteractionEnabled = false
        icloudIndicator.isHidden = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func themeDidUpdate(_ newTheme: SATheme) {
        super.themeDidUpdate(newTheme)

        let color = UIColor.sa_colorFromHexString(Theme().tableCellSupplementTextColor)
        customNameLabel.textColor = color
        customTimeLabel.textColor = color
        customViewLabel.textColor = color
        customReplyLabel.textColor = color
        customNameLabel.textColor = color
        if customTitleLabel.attributedText == nil {
            customTitleLabel.textColor = UIColor.sa_colorFromHexString(Theme().tableCellTextColor)
        }
    }
    
    override func fontDidUpdate(_ newTheme: SATheme) {
        super.fontDidUpdate(newTheme)
        customNameLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
        customTitleLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline)
        customTimeLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
        customViewLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
        customReplyLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
    }
}

class SASearchTableViewCell: SABoardTableViewCell {
    let quoteView = UIView()
    let quoteTextLabel = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        quoteView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(quoteView)
        
        quoteTextLabel.translatesAutoresizingMaskIntoConstraints = false
        quoteTextLabel.numberOfLines = 5
        quoteView.addSubview(quoteTextLabel)
        quoteTextLabel.translatesAutoresizingMaskIntoConstraints = false
        quoteTextLabel.leftAnchor.constraint(equalTo: quoteView.leftAnchor, constant: 20).isActive = true
        quoteTextLabel.rightAnchor.constraint(equalTo: quoteView.rightAnchor, constant: -20).isActive = true
        quoteTextLabel.topAnchor.constraint(equalTo: quoteView.topAnchor, constant: 20).isActive = true
        quoteTextLabel.bottomAnchor.constraint(equalTo: quoteView.bottomAnchor, constant: -20).isActive = true
        
        contentStack.insertArrangedSubview(quoteView, at: 2)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func themeDidUpdate(_ newTheme: SATheme) {
        super.themeDidUpdate(newTheme)
        quoteView.backgroundColor = Theme().htmlBlockQuoteBackgroundColor.sa_toColor()
        quoteTextLabel.textColor = Theme().htmlBlockQuoteTextColor.sa_toColor()
    }
    
    override func fontDidUpdate(_ newTheme: SATheme) {
        super.fontDidUpdate(newTheme)
        quoteTextLabel.font = UIFont.sa_preferredFont(forTextStyle: .body)
    }
}

class SABoardFilterTableViewCell: SAThemedTableViewCell {
    
    let customLine = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        customLine.translatesAutoresizingMaskIntoConstraints = false
        addSubview(customLine)
        
        let views = ["l":customLine]
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "H:|-16-[l]|", options: [], metrics: nil, views: views))
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "V:[l(==1)]|", options: [], metrics: nil, views: views))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func themeDidUpdate(_ newTheme: SATheme) {
        super.themeDidUpdate(newTheme)
        customLine.backgroundColor = UIColor.sa_colorFromHexString(Theme().tableCellSeperatorColor)
    }
    
    override func fontDidUpdate(_ newTheme: SATheme) {
        super.fontDidUpdate(newTheme)
        textLabel?.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
    }
}

class SAAccountCenterHeaderCell: SAThemedTableViewCell {
    let customImageView = UIImageView.init(image: UIImage(named: "noavatar_middle"))
    let uin = UILabel()
    let name = UILabel()
    let checkInButton = UIButton()
    let imageHeightWidth = 60
    var checkInHandler: (() -> (Void))?
    
    open var hasCheckedIn: Bool = false {
        didSet {
            if hasCheckedIn {
                checkInButton.isEnabled = false
                checkInButton.setTitle(NSLocalizedString("HAVE_PUNCHED_IN_TODAY", comment: "已签到"), for: .normal)
            } else {
                checkInButton.isEnabled = true
                checkInButton.setTitle(NSLocalizedString("CLICK_TO_PUNCH_IN_TODAY", comment: "点击签到"), for: .normal)
            }
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        customImageView.tag = 1
        customImageView.backgroundColor = UIColor.clear
        customImageView.translatesAutoresizingMaskIntoConstraints = false
        customImageView.layer.cornerRadius = 2.0
        customImageView.layer.masksToBounds = true
        contentView.addSubview(customImageView)
        
        uin.tag = 2
        uin.text = Account().uid
        uin.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(uin)
        
        name.tag = 3
        name.text = Account().name
        name.numberOfLines = 0
        name.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(name)
        
        checkInButton.tag = 4
        checkInButton.layer.cornerRadius = 4.0
        checkInButton.contentEdgeInsets = UIEdgeInsets.init(top: 4, left: 8, bottom: 4, right: 8)
        checkInButton.translatesAutoresizingMaskIntoConstraints = false
        checkInButton.setTitle(NSLocalizedString("CLICK_TO_PUNCH_IN_TODAY", comment: "打卡签到"), for: .normal)
        checkInButton.addTarget(self, action: #selector(handleCheckInButtonClick(_:)), for: .touchUpInside)
        contentView.addSubview(checkInButton)
        
        // contentview height constraint here
        customImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15).isActive = true
        customImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -15).isActive = true
        let imageHeightConstraint = NSLayoutConstraint.init(item: customImageView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: CGFloat(imageHeightWidth))
        
        customImageView.leftAnchor.constraint(equalTo: layoutMarginsGuide.leftAnchor, constant: 0).isActive = true

        // To clear the layout warning
        imageHeightConstraint.priority = .defaultHigh
        imageHeightConstraint.isActive = true
        NSLayoutConstraint.init(item: customImageView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: CGFloat(imageHeightWidth)).isActive = true
        
        name.leftAnchor.constraint(equalTo: customImageView.rightAnchor, constant: 16).isActive = true
        uin.leftAnchor.constraint(equalTo: name.leftAnchor, constant: 0).isActive = true
        
        name.centerYAnchor.constraint(equalTo: customImageView.centerYAnchor, constant: -20).isActive = true
        uin.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 10).isActive = true
        
        NSLayoutConstraint.init(item: checkInButton, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint.init(item: checkInButton, attribute: .right, relatedBy: .equal, toItem: contentView, attribute: .right, multiplier: 1.0, constant: -16).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func handleCheckInButtonClick(_ sender: UIButton) {
        checkInHandler?()
    }
    
    override func themeDidUpdate(_ newTheme: SATheme) {
        super.themeDidUpdate(newTheme)
        checkInButton.backgroundColor = Theme().backgroundColor.sa_toColor()
        checkInButton.setTitleColor(Theme().tableCellTextColor.sa_toColor(), for: .normal)
        name.textColor = UIColor.sa_colorFromHexString(Theme().tableCellTextColor)
        uin.textColor = UIColor.sa_colorFromHexString(Theme().tableCellSupplementTextColor)
    }
    
    override func fontDidUpdate(_ newTheme: SATheme) {
        super.fontDidUpdate(newTheme)
        checkInButton.titleLabel?.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
        uin.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
        name.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
    }
}

class SAAccountCenterBodyCell: SAThemedTableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        textLabel?.backgroundColor = UIColor.clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func themeDidUpdate(_ newTheme: SATheme) {
        super.themeDidUpdate(newTheme)
        detailTextLabel?.textColor = UIColor.sa_colorFromHexString(Theme().tableCellTextColor)
        textLabel?.textColor = UIColor.sa_colorFromHexString(Theme().tableCellTextColor)
        if let pageControl = accessoryView as? UISegmentedControl {
            pageControl.tintColor = UIColor.sa_colorFromHexString(Theme().globalTintColor)
        }
    }
    
    override func fontDidUpdate(_ newTheme: SATheme) {
        super.fontDidUpdate(newTheme)
        detailTextLabel?.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline)
        textLabel?.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline)
    }
}

class SACenterTitleCell: SAThemedTableViewCell {
    let customLabel = UILabel(frame: CGRect.zero)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        accessoryType = .none
        customLabel.translatesAutoresizingMaskIntoConstraints = false
        customLabel.textAlignment = .center
        contentView.addSubview(customLabel)
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "H:|-16-[l]-16-|", options: [], metrics: nil, views: ["l":customLabel]))
        NSLayoutConstraint(item: customLabel, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1.0, constant: 0).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func themeDidUpdate(_ newTheme: SATheme) {
        super.themeDidUpdate(newTheme)
        customLabel.textColor = .red
    }
    
    override func fontDidUpdate(_ newTheme: SATheme) {
        super.fontDidUpdate(newTheme)
        customLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline)
    }
}

class SAAccountInfoHeaderCell: SAThemedTableViewCell {
    var avatarImageView: UIImageView!
    var viewThreadsButton: UIButton!
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        let imageView = UIImageView.init(image: UIImage(named: "noavatar_middle"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        contentView.addSubview(imageView)
        NSLayoutConstraint(item: imageView, attribute: .centerX, relatedBy: .equal, toItem: contentView, attribute: .centerX, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: imageView, attribute: .centerY, relatedBy: .equal, toItem: contentView, attribute: .centerY, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: imageView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 80).isActive = true
        NSLayoutConstraint(item: imageView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 80).isActive = true
        avatarImageView = imageView
        
        let button = UIButton()
        button.setTitleColor(Theme().textColor.sa_toColor(), for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        button.setTitle("查看Ta的帖子", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(button)
        if #available(iOS 11.0, *) {
            button.rightAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.rightAnchor, constant: -12).isActive = true
        } else {
            // Fallback on earlier versions
            button.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -12).isActive = true
        }
        NSLayoutConstraint(item: button, attribute: .bottom, relatedBy: .equal, toItem: contentView, attribute: .bottom, multiplier: 1.0, constant: -10).isActive = true
        viewThreadsButton = button
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UITableViewHeaderFooterView
class SAThemedTableHeaderFooterView: UITableViewHeaderFooterView, UITextViewDelegate {
    var delegate: UIViewController?
    private var textViewHeightConstraint: NSLayoutConstraint!
    func setTitleWith(description: String?, link: String?, url: String?) {
        let attributedStr = NSMutableAttributedString.init()
        if let description = description {
            attributedStr.append(NSAttributedString(string: description, attributes: nil))
        }
        attributedStr.addAttributes([NSAttributedString.Key.foregroundColor : Theme().tableCellGrayedTextColor.sa_toColor()], range: NSMakeRange(0, attributedStr.length))
        
        if let description_link_title = link, let description_link_target = url {
            let link = NSAttributedString(string: " " + description_link_title, attributes: [.underlineStyle: NSNumber.init(value: Int8(NSUnderlineStyle.single.rawValue)), .link:description_link_target, .foregroundColor: UIColor.blue])
            attributedStr.append(link)
        }
        attributedStr.addAttributes([NSAttributedString.Key.font : UIFont.sa_preferredFont(forTextStyle: .subheadline)], range: NSMakeRange(0, attributedStr.length))
        summaryTextView.attributedText = attributedStr
        textViewHeightConstraint.isActive = attributedStr.length == 0
    }
    
    let summaryTextView = UITextView(frame: CGRect.zero)
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        summaryTextView.textContainerInset = UIEdgeInsets.zero
        summaryTextView.delegate = self
        summaryTextView.isScrollEnabled = false
        summaryTextView.backgroundColor = UIColor.clear
        summaryTextView.dataDetectorTypes = [.link]
        summaryTextView.isEditable = false
        summaryTextView.isSelectable = true
        summaryTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(summaryTextView)
        summaryTextView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 15).isActive = true
        summaryTextView.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -15).isActive = true
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "V:|-8-[l]-8-|", options: [], metrics: nil, views: ["l":summaryTextView]))
        textViewHeightConstraint = summaryTextView.heightAnchor.constraint(equalToConstant: 0)
        textViewHeightConstraint.isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func themeDidUpdate(_ newTheme: SATheme) {
        if backgroundView == nil {
            backgroundView = UIView()
        }
        backgroundView?.backgroundColor = Theme().backgroundColor.sa_toColor()
    }
    
    override func fontDidUpdate(_ newTheme: SATheme) {
        super.fontDidUpdate(newTheme)
        summaryTextView.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
    }
    
    // MARK: - UITextViewDelegate
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        _ = AppController.current.open(url: URL, sender: delegate)
        return false
    }
}

