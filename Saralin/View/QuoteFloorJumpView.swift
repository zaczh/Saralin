//
//  QuoteFloorJumpView.swift
//  Saralin
//
//  Created by zhang on 2019/3/23.
//  Copyright © 2019 zaczh. All rights reserved.
//

import UIKit

class QuoteFloorJumpView: UIView {
    private let radius = CGFloat(24)
    
    private var backgroundView = UIVisualEffectView.init(effect: UIBlurEffect.init(style: UIBlurEffect.Style.light))
    private var jumpingFloorButton = UIButton()
    private var jumpingFloorNumberLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.leftAnchor.constraint(equalTo: leftAnchor, constant: 0).isActive = true
        backgroundView.topAnchor.constraint(equalTo: topAnchor, constant: 0).isActive = true
        backgroundView.rightAnchor.constraint(equalTo: rightAnchor, constant: 0).isActive = true
        backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0).isActive = true
        backgroundView.layer.cornerRadius = radius
        backgroundView.layer.masksToBounds = true
        backgroundView.layer.borderWidth = 2.0
        
        jumpingFloorButton.isUserInteractionEnabled = false
        jumpingFloorButton.imageEdgeInsets = UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 10)
        jumpingFloorButton.setImage(#imageLiteral(resourceName: "return"), for: .normal)
        jumpingFloorButton.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.contentView.addSubview(jumpingFloorButton)
        jumpingFloorButton.leftAnchor.constraint(equalTo: backgroundView.contentView.leftAnchor, constant: 0).isActive = true
        jumpingFloorButton.topAnchor.constraint(equalTo: backgroundView.contentView.topAnchor, constant: 0).isActive = true
        jumpingFloorButton.rightAnchor.constraint(equalTo: backgroundView.contentView.rightAnchor, constant: 0).isActive = true
        jumpingFloorButton.bottomAnchor.constraint(equalTo: backgroundView.contentView.bottomAnchor, constant: 0).isActive = true
        
        jumpingFloorNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        jumpingFloorNumberLabel.textAlignment = .center
        jumpingFloorNumberLabel.adjustsFontSizeToFitWidth = true
        jumpingFloorNumberLabel.minimumScaleFactor = 0.4
        jumpingFloorButton.addSubview(jumpingFloorNumberLabel)
        jumpingFloorNumberLabel.centerYAnchor.constraint(equalTo: jumpingFloorButton.centerYAnchor, constant: 0).isActive = true
        jumpingFloorNumberLabel.rightAnchor.constraint(equalTo: jumpingFloorButton.rightAnchor, constant: -2).isActive = true
        jumpingFloorNumberLabel.widthAnchor.constraint(equalToConstant: 18).isActive = true
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize.init(width: 2 * radius, height: 2 * radius)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func updateWith(theme: SATheme) {
        jumpingFloorNumberLabel.font = UIFont.sa_preferredFont(forTextStyle: .headline)
        jumpingFloorButton.tintColor = theme.globalTintColor.sa_toColor()
        backgroundView.layer.borderColor = theme.globalTintColor.sa_toColor().cgColor
        jumpingFloorNumberLabel.textColor = theme.globalTintColor.sa_toColor()
    }
    
    var inStackFloors: Int = 0 {
        didSet {
            jumpingFloorNumberLabel.text = "\(inStackFloors)"
            isHidden = inStackFloors <= 0
        }
    }
    
    func updateVisibility() {
        let count = inStackFloors
        inStackFloors = count
    }
}
