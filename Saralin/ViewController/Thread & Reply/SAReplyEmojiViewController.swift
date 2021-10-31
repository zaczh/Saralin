//
//  SAReplyEmojiViewController.swift
//  Saralin
//
//  Created by zhang on 2021/10/30.
//  Copyright © 2021 zaczh. All rights reserved.
//

import UIKit

// storyboard id : reply_emoji_collection_vc
class SAReplyEmojiViewController: UIViewController {
    
    @IBOutlet var emojiViewSwitchCollectionView: UICollectionView!
    @IBOutlet var emojiViewSwitchDeleteButton: UIButton!
    @IBOutlet var emojiView: UIView!
    @IBOutlet var emojiViewCollectionView: UICollectionView!
    
    lazy var mahjongInfo: [[String:AnyObject]] = {
        let url = AppController.current.mahjongEmojiDirectory.appendingPathComponent("emoji.plist")
        return NSDictionary(contentsOf: url)!.object(forKey: "items") as! [[String : AnyObject]]
    }()
    
    var cellDelegate: SAEmojiCollectionWrapperViewDelegate?
        
    override func viewDidLoad() {
        super.viewDidLoad()
            
        emojiViewCollectionView.scrollsToTop = false
        emojiViewCollectionView.register(SAEmojiCollectionWrapperView.self, forCellWithReuseIdentifier: "cell")
        emojiViewCollectionView.showsVerticalScrollIndicator = false
        emojiViewCollectionView.showsHorizontalScrollIndicator = false
        emojiViewCollectionView.dataSource = self
        emojiViewCollectionView.delegate = self
        emojiViewCollectionView.isPagingEnabled = true
        emojiViewCollectionView.backgroundColor = UIColor.sa_colorFromHexString(Theme().tableCellGrayedTextColor)
        emojiViewCollectionView.contentInsetAdjustmentBehavior = .never
        let collectionViewLayout = emojiViewCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.minimumInteritemSpacing = 0
        collectionViewLayout.minimumLineSpacing = 0
        collectionViewLayout.itemSize = CGSize(width: emojiViewCollectionView.frame.width, height: emojiViewCollectionView.frame.height)

        emojiViewSwitchCollectionView.scrollsToTop = false
        emojiViewSwitchCollectionView.register(SAEmojiCollectionSwitchCell.self, forCellWithReuseIdentifier: "cell")
        emojiViewSwitchCollectionView.showsVerticalScrollIndicator = false
        emojiViewSwitchCollectionView.showsHorizontalScrollIndicator = false
        emojiViewSwitchCollectionView.dataSource = self
        emojiViewSwitchCollectionView.delegate = self
        let switchViewLayout = emojiViewSwitchCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
        switchViewLayout.scrollDirection = .horizontal
        switchViewLayout.minimumInteritemSpacing = 20
        switchViewLayout.itemSize = CGSize(width: 50, height: 40)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let collectionViewLayout = emojiViewCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
        if collectionViewLayout.itemSize.equalTo(emojiViewCollectionView.bounds.size) {
            return
        }
        collectionViewLayout.itemSize = CGSize(width: emojiViewCollectionView.frame.width, height: emojiViewCollectionView.frame.height)
        collectionViewLayout.invalidateLayout()
    }
    
    @IBAction func handleEmojiViewSwitchDeleteButtonClick(_ sender: UIButton) {
    }
}


extension SAReplyEmojiViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if collectionView == emojiViewCollectionView {
            return mahjongInfo.count + 1
        } else if collectionView == emojiViewSwitchCollectionView {
            return mahjongInfo.count + 1
        }
        
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == emojiViewCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! SAEmojiCollectionWrapperView
            cell.delegate = cellDelegate
            if indexPath.item > 0 {
                let emojis = mahjongInfo[indexPath.item - 1]
                cell.emojis = emojis["emojis"] as! NSArray
                cell.collectionView.contentOffset = CGPoint.zero
                cell.collectionView.reloadData()
            } else {
                cell.emojis = Account().favoriteEmojis
                cell.collectionView.contentOffset = CGPoint.zero
                cell.collectionView.reloadData()
            }
            return cell
        } else if collectionView == emojiViewSwitchCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! SAEmojiCollectionSwitchCell
            
            if indexPath.item == 0 {
                cell.imageView.image = UIImage.init(named: "like_filled")
                cell.descriptionLabel.text = "常用"
                return cell
            }
            
            let emojis = mahjongInfo[indexPath.row - 1]
            let faceInfo = emojis["emojis"] as! NSArray
            let description = emojis["info"] as! String

            let name = (faceInfo[0] as! NSDictionary)["image"] as! String
            let imagePath = AppController.current.mahjongEmojiDirectory.path + "/" + name
            cell.imageView.image = UIImage.init(contentsOfFile: imagePath)
            cell.descriptionLabel.text = description
            return cell
        }
        
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == emojiViewSwitchCollectionView {
            emojiViewCollectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
    }
}

extension SAReplyEmojiViewController: UIScrollViewDelegate {
    // MARK: - scrollview
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == emojiViewCollectionView else {
            return
        }
        
        let page = Int(ceil(scrollView.contentOffset.x/scrollView.frame.width))
        if page < emojiViewCollectionView.numberOfItems(inSection: 0) {
            let targetIndexPath = IndexPath(item: page, section: 0)
            emojiViewSwitchCollectionView.selectItem(at: targetIndexPath, animated: true, scrollPosition: .centeredHorizontally)
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView == emojiViewCollectionView else {
            return
        }
        
        if !decelerate {
            scrollViewDidEndDecelerating(scrollView)
        }
    }
}
