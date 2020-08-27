//
//  BottomRefreshView.swift
//  Saralin
//
//  Created by zhang on 2019/6/20.
//  Copyright © 2019 zaczh. All rights reserved.
//

import UIKit

class BottomRefreshView: UIView {
    private var stackView: UIStackView!
    var loadingView: UIActivityIndicatorView!
    var loadingLabel: UILabel!
    
    var tapHandler: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    private func setupViews() {
        isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleFooterTap(_:)))
        addGestureRecognizer(tap)
        
        stackView = UIStackView.init(frame: .zero)
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint(item: stackView!, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: stackView!, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0).isActive = true
        
        loadingView = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.white)
        loadingView.startAnimating()
        stackView.addArrangedSubview(loadingView)
        
        loadingLabel = UILabel()
        stackView.addArrangedSubview(loadingLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
    }
    
    @objc func handleFooterTap(_ tap: UITapGestureRecognizer) {
        tapHandler?()
    }
    
    func setFailed(text: String) {
        loadingLabel.text = text
        loadingView.stopAnimating()
    }
    
    func setAllLoaded(text: String) {
        loadingLabel.text = text
        loadingView.stopAnimating()
    }
    
    func setLoading(text: String) {
        loadingLabel.text = text
        loadingView.startAnimating()
    }
    
    func setMoreLoaded(text: String) {
        loadingLabel.text = text
        loadingView.stopAnimating()
    }
}
