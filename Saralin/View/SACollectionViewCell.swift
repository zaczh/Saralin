//
//  SACollectionViewCell.swift
//  Saralin
//
//  Created by zhang on 6/4/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit


protocol SAEmojiCollectionWrapperViewDelegate: NSObjectProtocol {
    func insertEmojiNamed(_ name: String, replacementString: String)
}

class SAEmojiCollectionViewCell: UICollectionViewCell {
    let imageView = UIImageView(image: nil)
    let previewView = UIView()
    override var isSelected: Bool {
        didSet {
            previewView.isHidden = !isSelected
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
//        backgroundView = UIImageView(image: UIImage(named: "New-Moon"))
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.isHidden = true
        addSubview(previewView)
        
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "H:|[iv]|", options: [], metrics: nil, views: ["iv":imageView]))
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "V:|[iv]|", options: [], metrics: nil, views: ["iv":imageView]))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SAEmojiCollectionWrapperView: UICollectionViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    var collectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
    var emojis = NSArray()
    let emptyView = UILabel()
    weak var delegate: SAEmojiCollectionWrapperViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "H:|[c]|", options: [], metrics: nil, views: ["c":collectionView]))
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "V:|[c]|", options: [], metrics: nil, views: ["c":collectionView]))

        emptyView.text = "没有常用表情"
        emptyView.numberOfLines = 0
        emptyView.textColor = Theme().textColor.sa_toColor()
        emptyView.font = UIFont.sa_preferredFont(forTextStyle: .title2)
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emptyView)
        NSLayoutConstraint.init(item: emptyView, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint.init(item: emptyView, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0).isActive = true
        
        collectionView.scrollsToTop = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(SAEmojiCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = UIColor.clear
        let collectionViewLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        collectionViewLayout.scrollDirection = .vertical
        collectionViewLayout.itemSize = CGSize(width: 30, height: 30)
        collectionViewLayout.minimumLineSpacing = 10
        collectionViewLayout.minimumInteritemSpacing = 30
        collectionViewLayout.sectionInset = UIEdgeInsets.init(top: 10, left: 20, bottom: 10, right: 20)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let itemsCount = emojis.count
        emptyView.isHidden = itemsCount > 0
        return itemsCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! SAEmojiCollectionViewCell
        if emojis.count > (indexPath as NSIndexPath).row {
            let emoji = emojis[(indexPath as NSIndexPath).row] as! NSDictionary
            
            //emojis and favorite emojis have different name
            if let name = emoji["image"] as? String {
                let imagePath = Bundle.main.path(forResource: "Mahjong", ofType: nil)! + "/" + name
                cell.imageView.image = UIImage(contentsOfFile: imagePath)
                return cell
            }
        }
        
        os_log("emoji image not found", log: .ui, type: .error)
        cell.imageView.image = nil
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if (indexPath as NSIndexPath).row < emojis.count {
            let emoji = emojis[indexPath.item] as! NSDictionary
            var name = (emoji["image"]) as? String
            
            //compatible with older version
            if name == nil {
                name = emoji["imageName"] as? String
            }
            guard name != nil else {
                return
            }
            
            let replacementString = (emoji["text"]) as! String
            delegate?.insertEmojiNamed(name!, replacementString: replacementString)
        }
    }
}

protocol SAReplyImagePreviewCollectionViewCellDelegate {
    func cellDeleteButtonClicked(_ cell: SAReplyImageAndContentPreviewCollectionViewCell)
}

class SAReplyImageAndContentPreviewCollectionViewCell: UICollectionViewCell {
    let imageView = UIImageView(image: nil)
    let deleteButton = UIButton()
    var delegate: SAReplyImagePreviewCollectionViewCellDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        deleteButton.setImage(UIImage(named:"Cancel")?.withRenderingMode(.alwaysTemplate), for: .normal)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.addTarget(self, action: #selector(handleDeleteButtonClick(_:)), for: .touchUpInside)
        addSubview(deleteButton)
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "H:[delete(==30)]|", options: [], metrics: nil, views: ["delete":deleteButton]))
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "V:|[delete(==30)]", options: [], metrics: nil, views: ["delete":deleteButton]))
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(imageView, belowSubview: deleteButton)
        
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "H:|[iv]|", options: [], metrics: nil, views: ["iv":imageView]))
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "V:|[iv]|", options: [], metrics: nil, views: ["iv":imageView]))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func handleDeleteButtonClick(_ sender: UIButton) {
        delegate?.cellDeleteButtonClicked(self)
    }
}

class SAEmojiCollectionSwitchCell: UICollectionViewCell {
    let imageView = UIImageView(image: nil)
    let descriptionLabel = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        descriptionLabel.font = UIFont.systemFont(ofSize: 8)
        descriptionLabel.textColor = Theme().textColor.sa_toColor()
        descriptionLabel.textAlignment = .center
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(descriptionLabel)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "H:|-10-[iv]-10-|", options: [], metrics: nil, views: ["iv":imageView,"dl":descriptionLabel]))
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "H:|[dl]|", options: [], metrics: nil, views: ["iv":imageView,"dl":descriptionLabel]))
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "V:|-1-[iv(==30)][dl(==10)]", options: [], metrics: nil, views: ["iv":imageView,"dl":descriptionLabel]))
        
        let selectedView = UIView()
        selectedView.backgroundColor = UIColor.sa_colorFromHexString(Theme().backgroundColor)
        selectedBackgroundView = selectedView
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SATextAttachment: NSTextAttachment {
    var imageName: String!
    var imageCategory: String!
    var replacementString: String = ""
}

// MARK: - UICollectionViewCell
class SAThemeSelectCell: UICollectionViewCell {
    
    let previewView = UIImageView()
    let previewTitleLabel = UILabel()
    let previewSubTitleLabel = UILabel()
    let previewBodyLabel = UILabel()
    let titleLabel = UILabel()
    let checkButton = UIButton()
    
    var isChecked: Bool = false {
        didSet {
            if isChecked {
                checkButton.setBackgroundImage(UIImage(named:"Checked_Circle")?.withRenderingMode(.alwaysTemplate), for: .normal)
                layer.borderColor = UIColor.sa_colorFromHexString(Theme().globalTintColor).cgColor
                layer.borderWidth = 2
            } else {
                checkButton.setBackgroundImage(UIImage(named:"Unchecked_Circle")?.withRenderingMode(.alwaysTemplate), for: .normal)
                layer.borderColor = UIColor.lightGray.cgColor
                layer.borderWidth = 0.5
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        
        previewView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(previewView)
        
        previewTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        previewTitleLabel.text = "标题"
        previewTitleLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline)
        previewView.addSubview(previewTitleLabel)
        
        previewSubTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        previewSubTitleLabel.text = "子标题"
        previewSubTitleLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
        previewView.addSubview(previewSubTitleLabel)
        
        previewBodyLabel.translatesAutoresizingMaskIntoConstraints = false
        previewBodyLabel.text = "正文"
        previewBodyLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
        previewView.addSubview(previewBodyLabel)
        NSLayoutConstraint(item: previewTitleLabel, attribute: .centerX, relatedBy: .equal, toItem: previewView, attribute: .centerX, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: previewSubTitleLabel, attribute: .centerX, relatedBy: .equal, toItem: previewView, attribute: .centerX, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: previewBodyLabel, attribute: .centerX, relatedBy: .equal, toItem: previewView, attribute: .centerX, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "V:|-30-[c]-10-[p]-10-[t]", options: [], metrics: nil, views: ["c":previewTitleLabel,"p":previewSubTitleLabel,"t":previewBodyLabel]))
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.body)
        contentView.addSubview(titleLabel)
        
        checkButton.translatesAutoresizingMaskIntoConstraints = false
        checkButton.isUserInteractionEnabled = false
        checkButton.setBackgroundImage(UIImage(named:"Unchecked_Circle")?.withRenderingMode(.alwaysTemplate), for: .normal)
        contentView.addSubview(checkButton)
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "H:|-10-[c(==30)]", options: [], metrics: nil, views: ["c":checkButton,"p":previewView,"t":titleLabel]))
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "V:|-10-[c(==30)]", options: [], metrics: nil, views: ["c":checkButton,"p":previewView,"t":titleLabel]))
        
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "H:[p(==80)]", options: [], metrics: nil, views: ["p":previewView,"t":titleLabel]))
        NSLayoutConstraint(item: previewView, attribute: .centerX, relatedBy: .equal, toItem: contentView, attribute: .centerX, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "H:[t(<=120)]", options: [], metrics: nil, views: ["p":previewView,"t":titleLabel]))
        NSLayoutConstraint(item: titleLabel, attribute: .centerX, relatedBy: .equal, toItem: contentView, attribute: .centerX, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint.activate(NSLayoutConstraint.constraints(withVisualFormat: "V:|-50-[p(==142)]-10-[t]", options: [], metrics: nil, views: ["p":previewView,"t":titleLabel]))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
