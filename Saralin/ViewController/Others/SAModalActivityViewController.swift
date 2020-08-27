//
//  SAModalActivityViewController.swift
//  Saralin
//
//  Created by zhang on 2/27/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit

enum SAModalActivityStyle {
    case loading
    case resultSuccess
    case resultFail
    case loadingWithCaption
}

class SAModalActivityViewController: UIViewController, UIViewControllerTransitioningDelegate {
    
    var activity: UIActivityIndicatorView!
    var titleLabel: UILabel!
    var resultImageView: UIImageView!
    var style = SAModalActivityStyle.loading
    var caption: String = ""
    
    convenience init(style: SAModalActivityStyle, caption: String) {
        self.init(nibName: nil, bundle: nil)
        self.style = style
        self.caption = caption
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        modalPresentationStyle = .custom
        transitioningDelegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        view.layer.cornerRadius = 4.0
        view.tintColor = Theme().globalTintColor.sa_toColor()
        
        activity = UIActivityIndicatorView(style: .whiteLarge)
        activity.startAnimating()
        activity.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activity)
        
        titleLabel = UILabel()
        titleLabel.textColor = UIColor(white: 0.8, alpha: 1.0)
        titleLabel.textAlignment = .center
        titleLabel.isHidden = true
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.text = self.caption
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        resultImageView = UIImageView()
        resultImageView.tintColor = UIColor(white: 0.8, alpha: 1.0)
        resultImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resultImageView)
        
        if style != .loading && style != .loadingWithCaption {
            activity.stopAnimating()
            activity.isHidden = true
            titleLabel.isHidden = false
            resultImageView.isHidden = false

        } else {
            resultImageView.isHidden = true
            activity.isHidden = false
            if style == .loadingWithCaption {
                titleLabel.isHidden = false
            }
        }
        
        if style == .resultFail {
            self.resultImageView.image = UIImage(named: "Incorrect")?.withRenderingMode(.alwaysTemplate)
            // Set some default caption
            if titleLabel.text == nil || titleLabel.text!.isEmpty {
                titleLabel.text = "操作失败"
            }
        } else if style == .resultSuccess {
            self.resultImageView.image = UIImage(named: "Correct")?.withRenderingMode(.alwaysTemplate)
            // Set some default caption
            if titleLabel.text == nil || titleLabel.text!.isEmpty {
                titleLabel.text = "操作成功"
            }
        }
        
        view.addConstraint(NSLayoutConstraint(item: activity!, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0))
        
        if style == .loadingWithCaption {
            titleLabel.sizeToFit()
            view.addConstraint(NSLayoutConstraint(item: activity!, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.0, constant: -0.5*titleLabel.frame.size.height))
            view.addConstraint(NSLayoutConstraint(item: titleLabel!, attribute: .top, relatedBy: .equal, toItem: activity, attribute: .bottom, multiplier: 1.0, constant: 10))
        } else {
            view.addConstraint(NSLayoutConstraint(item: activity!, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.0, constant: 0))
            view.addConstraint(NSLayoutConstraint(item: titleLabel!, attribute: .top, relatedBy: .equal, toItem: resultImageView, attribute: .bottom, multiplier: 1.0, constant: 10))
        }
        view.addConstraint(NSLayoutConstraint(item: titleLabel!, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1.0, constant: 16))
        view.addConstraint(NSLayoutConstraint(item: titleLabel!, attribute: .right, relatedBy: .equal, toItem: view, attribute: .right, multiplier: 1.0, constant: -16))
        
        NSLayoutConstraint(item: resultImageView!, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: 10).isActive = true
        NSLayoutConstraint(item: resultImageView!, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: resultImageView!, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 60).isActive = true
        NSLayoutConstraint(item: resultImageView!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 60).isActive = true

    }

    func show(completion: (() -> Void)?) {
        if let vc = UIApplication.shared.keyWindow?.rootViewController {
            vc.present(self, animated: true, completion: completion)
        } else {
            completion?()
        }
    }
    
    func hide(completion: (() -> Void)?) {
        guard let _ = presentingViewController else {
            completion?()
            return
        }
        dismiss(animated: true, completion: completion)
    }
    
    
    // Convenient method
    func hideAndShowResult(of status: Bool, info: String, completion: (() -> Void)?) {
        guard let presenting = presentingViewController else {
            completion?()
            return
        }
        dismiss(animated: true, completion: { () in
            let result = SAModalActivityViewController(style: status ? .resultSuccess : .resultFail, caption: info)
            presenting.present(result, animated: true, completion: {
                presenting.dismiss(animated: true, completion: { 
                    completion?()
                })
            })
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return SAModalActivityPresentationController(presentedViewController: presented, presenting: presentingViewController)
    }
    
    func animationControllerForPresentedController(_ presented: UIViewController, presentingViewController: UIViewController, sourceViewController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return SAModalActivityPresentationTransitioningObject()
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return SAModalActivityDismissalTransitioningObject()
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return SAModalActivityPresentationTransitioningObject()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

class SAModalActivityPresentationController: UIPresentationController {
    var width = CGFloat(120)
    var height = CGFloat(120)
    lazy var backgroundView: UIView = {(owner: UIPresentationController) in
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        view.isUserInteractionEnabled = true
        let gesture = UITapGestureRecognizer(target: owner, action: #selector(SAModalActivityPresentationController.handleTapBackground(_:)))
        view.addGestureRecognizer(gesture)
        
        return view
    }(self)
    
    override var frameOfPresentedViewInContainerView : CGRect {
        if let frame = containerView?.frame {
            return CGRect(x: frame.midX - width/2, y: frame.midY - height/2, width: width, height: height)
        }
        
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
    
    override func containerViewWillLayoutSubviews() {
        let prsetendView = presentedView
        guard prsetendView != nil && containerView != nil else {
            return
        }
        
        prsetendView!.frame = frameOfPresentedViewInContainerView
        prsetendView!.center = containerView!.center
    }
    
    override func presentationTransitionWillBegin() {
        if let container = containerView {
            container.addSubview(backgroundView)
            backgroundView.translatesAutoresizingMaskIntoConstraints = false
            containerView?.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[b]|", options: [], metrics: nil, views: ["b":backgroundView]))
            containerView?.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[b]|", options: [], metrics: nil, views: ["b":backgroundView]))
        }
    }
    
    @objc func handleTapBackground(_: AnyObject) {
    }
}

class SAModalActivityDismissalTransitioningObject: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)
        
        guard toViewController != nil else {
            transitionContext.completeTransition(false)
            return
        }
        
        let fromViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)
        UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
//            fromViewController!.view.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            fromViewController!.view.alpha = 0
        }, completion: { (finished) in
            fromViewController!.view.removeFromSuperview()
            transitionContext.completeTransition(true)
        }) 
    }
}

class SAModalActivityPresentationTransitioningObject:NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 1
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let containerView = transitionContext.containerView
        let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to) as? SAModalActivityViewController
        
        guard toViewController != nil else {
            transitionContext.completeTransition(false)
            return
        }
        
        let toFinalFrame = transitionContext.finalFrame(for: toViewController!)
        
        toViewController!.view.frame = toFinalFrame
        
        let view = UIView()
        view.layer.cornerRadius = 4.0
        // need to reduce the mask view height by 40 to avoid animate the caption label
        view.frame = CGRect(x: toFinalFrame.origin.x, y: toFinalFrame.origin.y, width: toFinalFrame.size.width, height: toFinalFrame.size.height - 40)
        if toViewController!.style == .loading || toViewController!.style == .loadingWithCaption || toViewController!.style == .resultFail {
            view.backgroundColor = UIColor.clear
        } else {
            view.backgroundColor = UIColor.black
        }
        containerView.addSubview(toViewController!.view)
        containerView.addSubview(view)

        if toViewController!.style != .loadingWithCaption {
            toViewController?.titleLabel.alpha = 0
        }
        UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
                view.frame = CGRect(x: toFinalFrame.origin.x + toFinalFrame.width, y: toFinalFrame.origin.y, width: 0, height: toFinalFrame.height - 40)
                toViewController?.titleLabel.alpha = 1.0
            }, completion: { (finished) in
                view.removeFromSuperview()
                transitionContext.completeTransition(true)
        })
    }
}
