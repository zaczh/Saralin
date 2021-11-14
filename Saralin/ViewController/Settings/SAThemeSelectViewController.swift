//
//  SAThemeSelectViewController.swift
//  Saralin
//
//  Created by zhang on 10/2/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

class SAThemeSelectViewController: SABaseCollectionViewController {
    class FooterView: UICollectionReusableView {
        let descriptionLabel = UILabel(frame: .zero)
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            descriptionLabel.numberOfLines = 0
            addSubview(descriptionLabel)
            descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
            descriptionLabel.leftAnchor.constraint(equalTo: safeAreaLayoutGuide.leftAnchor, constant: 20).isActive = true
            descriptionLabel.rightAnchor.constraint(equalTo: safeAreaLayoutGuide.rightAnchor, constant: -20).isActive = true
            descriptionLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func themeDidUpdate(_ newTheme: SATheme) {
            super.themeDidUpdate(newTheme)
            descriptionLabel.textColor = newTheme.textColor.sa_toColor()
        }
        
        override func fontDidUpdate(_ newTheme: SATheme) {
            super.fontDidUpdate(newTheme)
            descriptionLabel.font = UIFont.sa_preferredFont(forTextStyle: .body)
        }
    }
    
    private var themes = SATheme.allThemes
    
    convenience init() {
        let layout = UICollectionViewFlowLayout()
        layout.headerReferenceSize = CGSize(width: 20, height: 20)
        if #available(iOS 12.0, *) {
            layout.footerReferenceSize = CGSize(width: 0, height: 200)
        } else {
            layout.footerReferenceSize = CGSize(width: 0, height: 20)
        }
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.itemSize = CGSize(width: 145, height: 240)
        layout.sectionInset = UIEdgeInsets.init(top: 0, left: 10, bottom: 0, right: 10)
        self.init(collectionViewLayout: layout)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = NSLocalizedString("OPTION_THEME_SETTING", comment: "Theme")
        
        collectionView?.register(SAThemeSelectCell.self, forCellWithReuseIdentifier: "SAThemeSelectCell")
        collectionView?.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "UICollectionReusableView")
        collectionView?.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "UICollectionReusableView")
        collectionView?.register(FooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "FooterView")
    }
    
    override func viewThemeDidChange(_ newTheme:SATheme) {
        super.viewThemeDidChange(newTheme)
        collectionView?.backgroundColor = newTheme.foregroundColor.sa_toColor()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if #available(iOS 13.0, *) {
            return themes.count + 1
        }
        return themes.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SAThemeSelectCell", for: indexPath) as! SAThemeSelectCell
        
        var autoSwitchEnabled = false
        if #available(iOS 13.0, *) {
            autoSwitchEnabled = Account().preferenceForkey(.automatically_change_theme_to_match_system_appearance) as? Bool ?? true
            if indexPath.item == themes.count {
                cell.previewView.backgroundColor = .lightGray
                cell.previewView.image = UIImage(named: "black_right_angled_triangle")
                cell.titleLabel.text = "跟随系统"
                cell.previewTitleLabel.textColor = .clear
                cell.previewSubTitleLabel.textColor = .clear
                cell.previewBodyLabel.textColor = .clear
                cell.isChecked = autoSwitchEnabled
                return cell
            }
        } else {
            
        }
        
        let theme = themes[indexPath.item]
        cell.previewView.backgroundColor = UIColor.sa_colorFromHexString(theme.foregroundColor)
        cell.previewView.image = nil
        cell.titleLabel.text = theme.name
        
        cell.previewTitleLabel.textColor = UIColor.sa_colorFromHexString(theme.tableHeaderTextColor)
        cell.previewSubTitleLabel.textColor = UIColor.sa_colorFromHexString(theme.tableCellSupplementTextColor)
        cell.previewBodyLabel.textColor = UIColor.sa_colorFromHexString(theme.tableCellTextColor)
        
        if autoSwitchEnabled {
            cell.isChecked = false
        } else {
            if let index = themes.firstIndex(of: Theme()), index == indexPath.item {
                cell.isChecked = true
            } else {
                cell.isChecked = false
            }
        }
        
        return cell
    }
        
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionFooter, indexPath.section == 0, indexPath.item == 0 else {
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "UICollectionReusableView", for: indexPath)
        }
        
        if #available(iOS 13.0, *) {
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "FooterView", for: indexPath) as! FooterView
            let autoSwitchEnabled = Account().preferenceForkey(.automatically_change_theme_to_match_system_appearance) as? Bool ?? true
            if autoSwitchEnabled {
                footer.descriptionLabel.text = "开启该选项之后可以让部分场景的界面（如分享菜单以及弹窗提示等）在深色模式下有更匹配的显示效果。"
            } else {
                footer.descriptionLabel.text = nil
            }
            return footer
        } else {
            return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "UICollectionReusableView", for: indexPath)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedIndex = indexPath.item
        if selectedIndex == themes.count {
            setAutoUpdateThemeMode()
            collectionView.reloadData()
            return
        }
        
        let account = Account()
        guard let index = themes.firstIndex(of: Theme()), index != selectedIndex else {
            account.savePreferenceValue(false as AnyObject, forKey: .automatically_change_theme_to_match_system_appearance)
            collectionView.reloadData()
            return
        }
        
        let theme = themes[selectedIndex]
        AppController.current.getService(of: SAThemeManager.self)!.activeTheme = theme
        // turn off auto-switch option
        account.savePreferenceValue(false as AnyObject, forKey: .automatically_change_theme_to_match_system_appearance)
        account.savePreferenceValue(theme.identifier as AnyObject, forKey: SAAccount.Preference.theme_id)
        collectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        guard let selected = collectionView.indexPathsForSelectedItems?.first, selected.item == themes.count else {
            return CGSize(width: 1, height: 200)
        }
        return CGSize(width: 1, height: 20)
    }
    
    private func setAutoUpdateThemeMode() {
        Account().savePreferenceValue(true as AnyObject, forKey: .automatically_change_theme_to_match_system_appearance)
        if #available(iOS 13.0, *) {
            if (traitCollection.userInterfaceStyle == .dark && Theme().colorScheme == 1) ||
                (traitCollection.userInterfaceStyle == .light && Theme().colorScheme == 0) {
                return
            }
            AppController.current.getService(of: SAThemeManager.self)?.switchTheme()
        }
    }
}
