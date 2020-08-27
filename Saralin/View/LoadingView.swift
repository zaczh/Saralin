//
//  LoadingView.swift
//  Saralin
//
//  Created by zhang on 2018/8/15.
//  Copyright © 2018年 xxx. All rights reserved.
//

import UIKit

class LoadingView: UIView {
    private let kAnimationKey = "loading_view_animation"
    private let animationDuration = CFTimeInterval(1.5)

    private var ovalShapeLayer: CAShapeLayer?
    private var loadingView: UIView!
    override var intrinsicContentSize: CGSize { return CGSize.init(width: 40, height: 40) }
    
    var strokeColor: UIColor = UIColor.white {
        didSet {
            ovalShapeLayer?.strokeColor = strokeColor.cgColor
        }
    }
    
    var animationSpeed: Float = 1.0 {
        didSet {
            ovalShapeLayer?.speed = animationSpeed
        }
    }
    
    var animationTimeOffset: CFTimeInterval = 0 {
        didSet {
            if animationTimeOffset < 0 { return }
            
            if animationTimeOffset < 1.0 {
                ovalShapeLayer?.removeAllAnimations()
                ovalShapeLayer?.strokeStart = 0
                ovalShapeLayer?.strokeEnd = CGFloat(animationTimeOffset)
                ovalShapeLayer?.speed = 0
                return
            }
            
            ovalShapeLayer?.speed = 1
            beginSimpleAnimation()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadingView = UIView.init(frame: CGRect.init(origin: .zero, size: intrinsicContentSize))
        addSubview(loadingView)
        
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] (notification) in
            self?.ovalShapeLayer?.removeFromSuperlayer()
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] (notification) in
            self?.beginSimpleAnimation()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        loadingView.center = CGPoint.init(x: frame.size.width * 0.5, y: frame.size.height * 0.5)
    }
    
    override func didMoveToWindow() {
        if let _ = window {
            beginSimpleAnimation()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func beginSimpleAnimation() {
        if let layer = self.ovalShapeLayer {
            layer.removeFromSuperlayer()
            self.ovalShapeLayer = nil
        }
        
        let ovalShapeLayer = CAShapeLayer()
        ovalShapeLayer.strokeColor = strokeColor.cgColor
        ovalShapeLayer.fillColor = UIColor.clear.cgColor
        ovalShapeLayer.lineWidth = 4
        let anotherOvalRadius = loadingView.frame.size.height/2 * 0.8
        ovalShapeLayer.path = UIBezierPath(ovalIn: CGRect(x: loadingView.frame.size.width/2 - anotherOvalRadius,
                                                          y: loadingView.frame.size.height/2 - anotherOvalRadius,
                                                          width: anotherOvalRadius * 2,
                                                          height: anotherOvalRadius * 2)).cgPath
        ovalShapeLayer.lineCap = CAShapeLayerLineCap.round
        loadingView.layer.addSublayer(ovalShapeLayer)
        
        let strokeStartAnimate = CABasicAnimation(keyPath: "strokeStart")
        strokeStartAnimate.fromValue = -animationDuration/3.0
        strokeStartAnimate.toValue = animationDuration * 2/3.0
        
        let strokeEndAnimate = CABasicAnimation(keyPath: "strokeEnd")
        strokeEndAnimate.fromValue = 0.0
        strokeEndAnimate.toValue = animationDuration * 2/3.0
        
        let strokeAnimateGroup = CAAnimationGroup()
        strokeAnimateGroup.duration = animationDuration
        strokeAnimateGroup.repeatCount = HUGE
        strokeAnimateGroup.animations = [strokeStartAnimate, strokeEndAnimate]
        ovalShapeLayer.add(strokeAnimateGroup, forKey: kAnimationKey)
        self.ovalShapeLayer = ovalShapeLayer
    }
}
