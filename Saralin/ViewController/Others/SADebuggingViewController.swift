//
//  SADebuggingViewController.swift
//  Saralin
//
//  Created by junhui zhang on 2019/3/25.
//  Copyright © 2019 zaczh. All rights reserved.
//

import UIKit

class SADebuggingViewController: SABaseTableViewController {
    private var documentInteractionController: UIDocumentInteractionController?
    private var cells: [UITableViewCell]!
    convenience init() {
        self.init(nibName: nil, bundle: nil)
        
        let viewLogCell = SAThemedTableViewCell.init(style: .default, reuseIdentifier: nil)
        viewLogCell.textLabel?.text = "查看日志"
        
        let viewFileCell = SAThemedTableViewCell.init(style: .default, reuseIdentifier: nil)
        viewFileCell.textLabel?.text = "查看数据库"
        
        let viewUserDefaultsCell = SAThemedTableViewCell.init(style: .default, reuseIdentifier: nil)
        viewUserDefaultsCell.textLabel?.text = "查看用户配置"
        
        let crashCell = SAThemedTableViewCell.init(style: .default, reuseIdentifier: nil)
        crashCell.textLabel?.text = "性能分析"
        cells = [
            viewLogCell, viewFileCell, viewUserDefaultsCell, crashCell
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sa_log_v2("open debug entry", log: .ui, type: .info)

        title = NSLocalizedString("DEBUG_ENTRY", comment: "DEBUG ENTRY")
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cells[indexPath.row]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if indexPath.row == 0 {
            showLogViewer()
        } else if indexPath.row == 1 {
            showFileViewer()
        } else if indexPath.row == 2 {
            showUserDefaults()
        } else if indexPath.row == 3 {
            showCrashFiles()
        }
    }
    
    @objc private func handleLogShareButtonClick(_ sender: UIBarButtonItem) {
        let url = URL.init(fileURLWithPath: sa_current_log_file_path())
        sa_log_v2("clicked share button", log: .ui, type: .info)
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityController.modalPresentationStyle = .popover
        activityController.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
        }
        activityController.popoverPresentationController?.barButtonItem = sender
        present(activityController, animated: true, completion: nil)
    }

    private func showLogViewer() {
        let url = URL.init(fileURLWithPath: sa_current_log_file_path())
        guard let info = try? String.init(contentsOf: url) else {
            return
        }
        let viewController = SAPlainTextViewController.init()
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(handleLogShareButtonClick(_:)))
        viewController.title = url.lastPathComponent
        viewController.text = info
        viewController.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    private func showFileViewer() {
        let dbViewController = DatabaseMetaViewController()
        navigationController?.pushViewController(dbViewController, animated: true)
    }
    
    private func showUserDefaults() {
        var info = ""
        let dict = UserDefaults.standard.dictionaryRepresentation() as [String:AnyObject]
        for (k, v) in dict {
            info.append("\(k):\(v.description ?? "[none]")\n")
        }
        let viewController = SAPlainTextViewController.init()
        viewController.text = info
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    private func showCrashFiles() {
        let directoryURL = AppController.current.diagnosticsReportFilesDirectory
        let localFileManager = FileManager()
         
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey, .fileSizeKey])
        let directoryEnumerator = localFileManager.enumerator(at: directoryURL, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)!
        var fileURLs: [URL] = []
        for case let fileURL as URL in directoryEnumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys), let fileSize = resourceValues.fileSize, fileSize > 0, let isDirectory = resourceValues.isDirectory, !isDirectory else {
                continue
            }
            
            fileURLs.append(fileURL)
        }
        guard !fileURLs.isEmpty else {
            let alert = UIAlertController(title: nil, message: "Wow! There are no diagnostics files yet.", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("CANCEL", comment: "Cancel"), style: .cancel) { (action) in
            }
            alert.addAction(cancelAction)
            present(alert, animated: true, completion: nil)
            return
        }
        
        let alert = UIAlertController(title: "View Crash Log", message: "Choose a diagnostics report file to view.", preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = view.bounds
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel) { (action) in
        }
        alert.addAction(cancelAction)
        for u in fileURLs {
            let fileName = u.lastPathComponent
            let action = UIAlertAction(title: fileName, style: .default) { (action) in
                guard let info = try? String.init(contentsOf: u) else {
                    return
                }
                let viewController = SAPlainTextViewController.init()
                viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(self.handleLogShareButtonClick(_:)))
                viewController.title = u.lastPathComponent
                viewController.text = info
                viewController.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
                self.navigationController?.pushViewController(viewController, animated: true)
            }
            alert.addAction(action)
        }
        present(alert, animated: true, completion: nil)
    }
}

extension SADebuggingViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
}
