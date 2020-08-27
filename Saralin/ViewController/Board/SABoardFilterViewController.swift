//
//  SABoardFilterViewController.swift
//  Saralin
//
//  Created by zhang on 12/1/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

protocol SABoardFilterDelegate: NSObjectProtocol {
    func boardFilterViewController(_: SABoardFilterViewController, didChooseSubBoardID fid: String, categoryID cid: String)
}

class SABoardFilterViewController: UITableViewController {
    
    weak var delegate: SABoardFilterDelegate?
    var isEmpty: Bool = true {
        didSet {
            emptyView?.isHidden = !isEmpty
        }
    }
    var emptyView: UILabel?
    
    var boards: [(String,String)]!
    var openedSection: NSInteger = -1
    var selectedBoard: String!
    var selectedCategory: String!
    var headerConstraints: [Int : (NSLayoutConstraint, NSLayoutConstraint, NSLayoutConstraint, UIView, UIView)] = [:]
    
    init(boards: [(String,String)], selectedBoard: String, categories: [(String, String)], selectedCategory: String) {
        super.init(style: .plain)
        self.boards = boards
        self.selectedBoard = selectedBoard
        self.selectedCategory = selectedCategory
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
        
        view.backgroundColor = Theme().backgroundColor.sa_toColor()
        tableView.backgroundColor = Theme().backgroundColor.sa_toColor()
        
        tableView.sectionHeaderHeight = 50
        tableView.rowHeight = 50.0
        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none
        tableView.register(SABoardFilterTableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.separatorColor = UIColor.sa_colorFromHexString(Theme().tableCellSeperatorColor)
        
        
        emptyView = UILabel()
        emptyView!.textAlignment = .center
        emptyView!.text = NSLocalizedString("THIS_BOARD_HAS_NO_CHILD", comment: "当前版块没有子版块")
        emptyView!.numberOfLines = 0
        emptyView!.textColor = UIColor.sa_colorFromHexString(Theme().globalTintColor)
        emptyView!.translatesAutoresizingMaskIntoConstraints = false
        emptyView!.isHidden = true
        view.addSubview(emptyView!)
        view.addConstraint(NSLayoutConstraint(item: emptyView!, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1.0, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: emptyView!, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1.0, constant: 0))
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if boards != nil {
            if openedSection != -1 {
                return 1
            } else {
                isEmpty = boards!.count == 0
                return boards!.count
            }
        } else {
            isEmpty = true
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let header = UIView()
        header.backgroundColor = UIColor.sa_colorFromHexString(Theme().foregroundColor)
        header.tag = section
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSectionHeaderTap(_:)))
        header.addGestureRecognizer(tap)
        
        let iconLeft = UIButton()
        iconLeft.isUserInteractionEnabled = false
        iconLeft.isHidden = openedSection == -1
        iconLeft.tintColor = UIColor.sa_colorFromHexString(Theme().tableCellTintColor)
        if openedSection != -1 {
            iconLeft.setBackgroundImage(UIImage.imageWithSystemName("chevron.down", fallbackName:"Expand_Arrow_50")?.withRenderingMode(.alwaysTemplate), for: UIControl.State.normal)
        } else {
            iconLeft.setBackgroundImage(UIImage.imageWithSystemName("chevron.up", fallbackName:"Collapse_Arrow_50")?.withRenderingMode(.alwaysTemplate), for: UIControl.State.normal)
        }
        iconLeft.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(iconLeft)
        header.addConstraint(NSLayoutConstraint(item: iconLeft, attribute: .centerY, relatedBy: .equal, toItem: header, attribute: .centerY, multiplier: 1.0, constant: 0))
        header.addConstraint(NSLayoutConstraint(item: iconLeft, attribute: .left, relatedBy: .equal, toItem: header, attribute: .left, multiplier: 1.0, constant: 16))
        
        let iconRight = UIButton()
        iconRight.isUserInteractionEnabled = false
        if openedSection != -1 {
            iconRight.isHidden = true
            iconRight.setBackgroundImage(UIImage.imageWithSystemName("chevron.up", fallbackName:"Collapse_Arrow_50")?.withRenderingMode(.alwaysTemplate), for: UIControl.State.normal)
        } else {
            iconRight.isHidden = false
            iconRight.setBackgroundImage(UIImage.imageWithSystemName("chevron.down", fallbackName:"Expand_Arrow_50")?.withRenderingMode(.alwaysTemplate), for: UIControl.State.normal)
        }
        iconRight.translatesAutoresizingMaskIntoConstraints = false
        iconRight.tintColor = UIColor.sa_colorFromHexString(Theme().tableCellTintColor)
        header.addSubview(iconRight)
        header.addConstraint(NSLayoutConstraint(item: iconRight, attribute: .centerY, relatedBy: .equal, toItem: header, attribute: .centerY, multiplier: 1.0, constant: 0))
        header.addConstraint(NSLayoutConstraint(item: iconRight, attribute: .right, relatedBy: .equal, toItem: header, attribute: .right, multiplier: 1.0, constant: -16))
        
        let label = UILabel()
        label.font = UIFont.sa_preferredFont(forTextStyle: UIFont.TextStyle.headline)
        label.textAlignment = .center
        label.textColor = UIColor.sa_colorFromHexString(Theme().tableHeaderTextColor)
        if openedSection != -1 {
            let name = boards![openedSection].1
            label.text = name
        } else {
            let name = boards![section].1
            label.text = name
        }
        label.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(label)
        header.addConstraint(NSLayoutConstraint(item: label, attribute: .centerY, relatedBy: .equal, toItem: header, attribute: .centerY, multiplier: 1.0, constant: 0))
        let labelLeftConstraint = NSLayoutConstraint(item: label, attribute: .left, relatedBy: .equal, toItem: header, attribute: .left, multiplier: 1.0, constant: 16)
        labelLeftConstraint.isActive = true
        
        let labelCenterConstraint = NSLayoutConstraint(item: label, attribute: .centerX, relatedBy: .equal, toItem: header, attribute: .centerX, multiplier: 1.0, constant: 16)
        labelCenterConstraint.isActive = false
        
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = UIColor.sa_colorFromHexString(Theme().tableCellSeperatorColor)
        header.addSubview(line)
        
        header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[l]|", options: [], metrics: nil, views: ["l":line]))
        header.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[l(==1)]|", options: [], metrics: nil, views: ["l":line]))
        let lineLeftConstraint = NSLayoutConstraint(item: line, attribute: .left, relatedBy: .equal, toItem: header, attribute: .left, multiplier: 1.0, constant: 16)
        lineLeftConstraint.isActive = true
        headerConstraints[section] = (labelLeftConstraint, labelCenterConstraint, lineLeftConstraint, iconLeft, iconRight)
        
        updateHeaderView(header)
        
        return header
    }
    
    fileprivate func updateHeaderView(_ header: UIView) {
        let section = header.tag
        guard headerConstraints.count > section else {
            return
        }
        guard let constraint = headerConstraints[section] else {
            return
        }
        
        if openedSection != -1 {
            constraint.0.isActive = false
            constraint.1.isActive = true
            constraint.2.constant = 0
            constraint.3.isHidden = false
            constraint.4.isHidden = true
        } else {
            constraint.0.isActive = true
            constraint.1.isActive = false
            constraint.2.constant = 16
            constraint.3.isHidden = true
            constraint.4.isHidden = false
        }
        header.setNeedsLayout()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if openedSection != -1 {
            if section == 0 {
                let fid = boards[openedSection].0
                
                var forum: NSDictionary! = nil
                let forumInfo = NSDictionary(contentsOf: AppController.current.forumInfoConfigFileURL)! as! [String:AnyObject]
                let forumList = forumInfo["items"] as! [[String:AnyObject]]
                for obj in forumList {
                    let aFid = obj["fid"] as! String
                    if aFid == fid {
                        forum = obj as NSDictionary
                        break
                    }
                }
                guard forum != nil else {
                    sa_log_v2("forum is nil. Showing all", module: .ui, type: .debug)
                    return 1
                }
                
                let categorylist = forum["types"] as! [[String:String]]
                
                return categorylist.count + 1 // `+ 1` for "No Filter" option
            }
            
            return 0
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SABoardFilterTableViewCell
        
        cell.customLine.isHidden = (indexPath as NSIndexPath).row == tableView.numberOfRows(inSection: (indexPath as NSIndexPath).section) - 1
        
        if (indexPath as NSIndexPath).row == 0 {
            if openedSection == (indexPath as NSIndexPath).section && selectedCategory == "0" {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
            cell.textLabel?.text = NSLocalizedString("ALL", comment: "全部")
            return cell
        }
        
        let fid = boards[openedSection].0
        var forum: NSDictionary! = nil
        
        let forumInfo = NSDictionary(contentsOf: AppController.current.forumInfoConfigFileURL)! as! [String:AnyObject]
        let forumList = forumInfo["items"] as! [[String:AnyObject]]
        for obj in forumList {
            let aFid = obj["fid"] as! String
            if aFid == fid {
                forum = obj as NSDictionary
                break
            }
        }
        guard forum != nil else {
            sa_log_v2("forum is nil", module: .ui, type: .debug)
            return cell
        }
        
        let categorylist = forum["types"] as! [[String:String]]
        let categoryID = categorylist[(indexPath as NSIndexPath).row - 1]["typeid"]
        let categoryName = categorylist[(indexPath as NSIndexPath).row - 1]["typename"]
        
        if openedSection == (indexPath as NSIndexPath).section && selectedCategory == categoryID {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        
        cell.textLabel?.text = categoryName
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let fid = boards![openedSection].0
        if (indexPath as NSIndexPath).row == 0 {
            delegate?.boardFilterViewController(self, didChooseSubBoardID: fid, categoryID: "0")
            dismiss(animated: true, completion: nil)
            return
        }
        
        let forumInfo = NSDictionary(contentsOf: AppController.current.forumInfoConfigFileURL)! as! [String:AnyObject]
        let forumList = forumInfo["items"] as! [[String:AnyObject]]
        var forum: NSDictionary! = nil
        for obj in forumList {
            let aFid = obj["fid"] as! String
            if aFid == fid {
                forum = obj as NSDictionary
                break
            }
        }
        guard forum != nil else {
            sa_log_v2("forum is nil", module: .ui, type: .debug)
            return
        }
        
        let categorylist = forum["types"] as! [[String:String]]
        let categoryID = categorylist[(indexPath as NSIndexPath).row - 1]["typeid"]
        
        delegate?.boardFilterViewController(self, didChooseSubBoardID: fid, categoryID: categoryID!)
        dismiss(animated: true, completion: nil)
    }
    
    @objc func handleSectionHeaderTap(_ tap: UITapGestureRecognizer) {
        let header = tap.view!
        let section = header.tag
        var indexPathes = [IndexPath]()
        
        let fid = boards![section].0
        
        var forum: NSDictionary! = nil
        
        let forumInfo = NSDictionary(contentsOf: AppController.current.forumInfoConfigFileURL)! as! [String:AnyObject]
        let defaultList = forumInfo["items"] as! [[String:AnyObject]]
        for obj in defaultList {
            let aFid = obj["fid"] as! String
            if aFid == fid {
                forum = obj as NSDictionary
                break
            }
        }
        
        var categorylist: [[String:String]]!
        if forum == nil {
            sa_log_v2("forum is nil", module: .ui, type: .debug)
            categorylist = []
        } else {
            categorylist = (forum["types"] as! [[String:String]])
        }
        
        for i in 0 ... categorylist.count {
            indexPathes.append(IndexPath(row: i, section: 0))
        }
        
        if openedSection == -1 {
            let sectionsDeleteTop = NSMutableIndexSet()
            if section - 1 >= 0 {
                for i in 0 ... section - 1 {
                    sectionsDeleteTop.add(i)
                }
            }
            
            let sectionsDeleteBottom = NSMutableIndexSet()
            if section + 1 <= boards.count - 1 {
                for i in section + 1 ... boards.count - 1 {
                    sectionsDeleteBottom.add(i)
                }
            }
            openedSection = section
            tableView.beginUpdates()
            tableView.insertRows(at: indexPathes, with: .automatic)
            tableView.deleteSections(sectionsDeleteTop as IndexSet, with: .top)
            tableView.deleteSections(sectionsDeleteBottom as IndexSet, with: .bottom)
            
            tableView.endUpdates()
        } else {
            let sectionsInsertBottom = NSMutableIndexSet()
            if section - 1 >= 0 {
                for i in 0 ... section - 1 {
                    //make reverse
                    sectionsInsertBottom.add(section - 1 - i)
                }
            }
            
            let sectionsInsertTop = NSMutableIndexSet()
            if section + 1 <= boards.count - 1 {
                for i in section + 1 ... boards.count - 1 {
                    sectionsInsertTop.add(i)
                }
            }
            openedSection = -1
            tableView.beginUpdates()
            tableView.deleteRows(at: indexPathes, with: .automatic)
            tableView.insertSections(sectionsInsertTop as IndexSet, with: .top)
            tableView.insertSections(sectionsInsertBottom as IndexSet, with: .bottom)
            tableView.endUpdates()
        }
        updateHeaderView(header)
    }
}
