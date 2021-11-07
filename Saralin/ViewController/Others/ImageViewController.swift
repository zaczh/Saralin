//
//  ImageViewController.swift
//  ChildViewControllerInspect
//
//  Created by zhang on 2018/7/31.
//  Copyright © 2018年 xxx. All rights reserved.
//

import UIKit
import CloudKit

class ImageViewController: UIViewController, UIViewControllerTransitioningDelegate, UIScrollViewDelegate {
    private class PresentationTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
        weak var transitioningView: UIView?
        weak var targetView: UIView?
        
        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            return 0.3
        }
        
        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            guard let toVC = transitionContext.viewController(forKey: .to) as? ImageViewController else {
                return
            }
            guard let toView = transitionContext.view(forKey: .to) else {
                return
            }
            
            let toVCFrame = transitionContext.finalFrame(for: toVC)
            
            let container = transitionContext.containerView
            let duration = transitionDuration(using: transitionContext)
            
            if let transitioningView = transitioningView, let targetView = targetView {
                let targetFrame = targetView.convert(targetView.bounds, to: container)
                
                toView.alpha = 0
                container.addSubview(toView)
                toView.frame = toVCFrame
                
                guard let snapshot = transitioningView.resizableSnapshotView(from: transitioningView.bounds, afterScreenUpdates: true, withCapInsets: .zero) else { fatalError() }
                
                let showsSnapshotView = targetFrame.size.width > 0 && targetFrame.size.height > 0
                
                // prevent bad animation when targetFrame is zero
                if showsSnapshotView {
                    container.addSubview(snapshot)
                    snapshot.frame = container.convert(transitioningView.frame, from: nil) // transitioningView is in window coordination
                }
                toView.alpha = 0
                toVC.imageView.isHidden = true
                
                UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
                    toView.alpha = 1
                    
                    if showsSnapshotView {
                        snapshot.frame = targetFrame
                    }
                }, completion: { (finished) in
                    toVC.imageView.isHidden = false
                    if showsSnapshotView {
                        snapshot.removeFromSuperview()
                    }
                    transitionContext.completeTransition(true)
                })
            } else {
                container.addSubview(toView)
                toView.frame = toVCFrame
                toView.transform = CGAffineTransform.identity.scaledBy(x: 0.001, y: 0.001)

                UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
                    toView.transform = .identity
                }, completion: { (finished) in
                    transitionContext.completeTransition(true)
                })
            }
        }
    }
    
    private class DismissalTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
        weak var transitioningView: UIView?
        weak var targetView: UIView?

        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            return 0.3
        }
        
        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            guard let fromVC = transitionContext.viewController(forKey: .from) as? ImageViewController, let toVC = transitionContext.viewController(forKey: .to) else {
                return
            }
            
            guard let fromView = transitionContext.view(forKey: .from), let toView = transitionContext.view(forKey: .to) else {
                return
            }
            
            let toVCFrame = transitionContext.finalFrame(for: toVC)
            
            let container = transitionContext.containerView
            let duration = transitionDuration(using: transitionContext)
            
            container.addSubview(toView)
            toView.frame = toVCFrame
            
            if let transitioningView = transitioningView, let targetView = targetView {
                guard let snapshot = transitioningView.resizableSnapshotView(from: transitioningView.bounds, afterScreenUpdates: false, withCapInsets: .zero) else { fatalError() }
                container.addSubview(snapshot)
                snapshot.frame = transitioningView.convert(transitioningView.bounds, to: container)
                fromVC.imageView.alpha = 0
                UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
                    snapshot.frame = targetView.convert(targetView.bounds, to: container)
                    fromView.alpha = 0
                }, completion: { (finished) in
                    let canceled = transitionContext.transitionWasCancelled
                    snapshot.removeFromSuperview()
                    if canceled {
                        toView.removeFromSuperview()
                    }
                    fromView.alpha = 1
                    fromVC.imageView.alpha = 1
                    transitionContext.completeTransition(!canceled)
                })
            } else {
                let fromVCBgColor = fromView.backgroundColor
                fromView.backgroundColor = .clear
                UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
                    fromView.transform = CGAffineTransform.identity.scaledBy(x: 0.01, y: 0.01)
                }, completion: { (finished) in
                    let canceled = transitionContext.transitionWasCancelled
                    fromView.backgroundColor = fromVCBgColor
                    if canceled {
                        toView.removeFromSuperview()
                    }
                    transitionContext.completeTransition(!canceled)
                })
            }
        }
    }
    
    public var bouncedDraggingDismissalDistance: CGFloat = 50
    
    private let presentationTransitioning = PresentationTransitioning()
    private let dismissalTransitioning = DismissalTransitioning()
    
    private var tapGesuture: UITapGestureRecognizer!
    private var doubleTapGesture: UITapGestureRecognizer!
    private var longPressGesture: UILongPressGestureRecognizer!

    private var imageURL: URL!
    private var thumbnailImage: UIImage?
    private var fullSizeImage: UIImage?
    private var transitioningView: UIView?
    
    // upvote
    private var upvotedNumber: Int = 0 {
        didSet {
            bottomContainerLikeButton.setTitle(" \(self.upvotedNumber)赞", for: .normal)
        }
    }
    
    private var viewedNumber: Int = 1 {
        didSet {
            let upvotedNumber = self.upvotedNumber
            self.upvotedNumber = upvotedNumber // trigger a `didSet` event
        }
    }
    
    
    private var hasUpvoted = false {
        didSet {
            let upvotedNumber = self.upvotedNumber
            self.upvotedNumber = upvotedNumber // trigger a `didSet` event
            if !hasUpvoted {
                bottomContainerLikeButton.setImage(#imageLiteral(resourceName: "thumb-up").withRenderingMode(.alwaysTemplate), for: .normal)
                bottomContainerLikeButton.tintColor = .white
                return
            }
            
            bottomContainerLikeButton.setImage(UIImage(named: "thumb-up-filled")?.withRenderingMode(.alwaysTemplate), for: .normal)
            bottomContainerLikeButton.tintColor = .red
        }
    }
    
    private var imageView: UIImageView!
    private var scrollView: UIScrollView!
    private var topContainerShareButton: UIButton!
    private var topContainerDismissButton: UIButton!
    
    private var topContainer: UIView!
    private var topContainerTopConstraint: NSLayoutConstraint!
    private var bottomContainerLikeButton: UIButton!

    private var bottomContainer: UIStackView!
    private var bottomContainerBottomConstraint: NSLayoutConstraint!

    private var isActionButtonsHidden: Bool = true
    
    private var forcesStatusBarHidden = false
    override var prefersStatusBarHidden: Bool {return forcesStatusBarHidden}
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {return .fade}
    
    private var loadingIndicatorView = UIActivityIndicatorView(style: .medium)
    struct ImageItem {
        var imageURL: URL
        var fullSizeImage: UIImage?
        var thumbnailImage: UIImage?
        var imageDescription: String?
    }
    
    // MARK: CloudKit
    private let container = CKContainer(identifier: SACloudKitImageShareContainerIdentifier)
    private let recordType: CKRecord.RecordType = "Image"
    private var database: CKDatabase {
        return container.publicCloudDatabase
    }
    
    func config(imageURL: URL?, thumbnailImage: UIImage?, fullSizeImage: UIImage?, transitioningView: UIView?) {
        transitioningDelegate = self
        modalPresentationStyle = .fullScreen
        self.transitioningView = transitioningView
        self.imageURL = imageURL
        self.thumbnailImage = thumbnailImage
        self.fullSizeImage = fullSizeImage
    }
    
    deinit {
        syncUIAndDatabase()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        forcesStatusBarHidden = true
        setNeedsStatusBarAppearanceUpdate()
        setActionButtons(hidden: false)
        
        #if targetEnvironment(macCatalyst)
        if let titlebar = view.window?.windowScene?.titlebar, let titleItems = titlebar.toolbar?.items {
            for item in titleItems {
                
                if item.itemIdentifier.rawValue == SAToolbarItemIdentifierShare.rawValue {
                    item.target = self
                    item.action = #selector(self.handleLongPress(_:))
                }
            }
        }
        #endif
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        let effect = UIBlurEffect.init(style: .dark)
        let visualEffectView = UIVisualEffectView.init(effect: effect)
        view.addSubview(visualEffectView)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0).isActive = true
        visualEffectView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        visualEffectView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        
        scrollView = UIScrollView.init(frame: view.bounds)
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
            automaticallyAdjustsScrollViewInsets = false
        }
        scrollView.delegate = self
        scrollView.maximumZoomScale = 4.0
        view.addSubview(scrollView)
        
        imageView = UIImageView.init(image: nil)
        scrollView.addSubview(imageView)
        
        setupTopContainer()
        setupBottomContainer()
        
        updateScrollView(size: view.frame.size)
        setupTransitioning()
        setupLoadingView()
                
        guard let _ = imageURL else {
            return
        }
        
        loadImage { [weak self] (finished, image) -> (Void) in
            guard let strongSelf = self else { return }
            if !finished {
                return
            }
            
            strongSelf.setupGestureRecoginizers()
            strongSelf.imageView.image = image
            strongSelf.updateTintColor()
            strongSelf.updateScrollView(size: strongSelf.view.frame.size)
            strongSelf.loadingIndicatorView.stopAnimating()
        }
        syncDatabaseAndUI()
    }
    
    private func setupGestureRecoginizers() {
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)
        tapGesuture = tap
        
        let doubleTap = UITapGestureRecognizer.init(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        tap.require(toFail: doubleTap)
        doubleTapGesture = doubleTap
        
        longPressGesture = UILongPressGestureRecognizer.init(target: self, action: #selector(handleLongPress(_:)))
        view.addGestureRecognizer(longPressGesture)
    }
    
    private func loadImage(completed: ((Bool, UIImage?) -> (Void))?) {
        if fullSizeImage != nil {
            completed?(true, fullSizeImage)
            return
        }
        
        UIApplication.shared.showNetworkIndicator()
        URLSession.saCustomized.dataTask(with: imageURL) { (data, response, error) in
            UIApplication.shared.hideNetworkIndicator()
            guard let data = data else {
                DispatchQueue.main.async {
                    completed?(false, nil)
                }
                return
            }
            
            guard let image = UIImage.init(data: data) else {
                DispatchQueue.main.async {
                    completed?(false, nil)
                }
                return
            }
            
            DispatchQueue.main.async {
                completed?(true, image)
            }
        }.resume()
    }
    
    private func updateTintColor() {
        guard let currentImage = imageView.image else {return}
        DispatchQueue.global().async {
            if let color = mainColoursInImage(currentImage, 1).sorted(by: { (first, second) -> Bool in
                return first.value.floatValue > second.value.floatValue
            }).first?.key {
                var newColor:UIColor!
                if colourDistance(color, UIColor.white) < 10 {
                    newColor = UIColor.black
                } else {
                    newColor = color
                }
                
                let bgColor = newColor.withAlphaComponent(0.4)
                // let colorImage = imageFrom(color: bgColor, size: CGSize(width: 1, height: 1))
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction], animations: {
                        self.view.backgroundColor = newColor
                        self.topContainerShareButton.backgroundColor = bgColor
                        self.topContainerDismissButton.backgroundColor = bgColor
                        self.bottomContainerLikeButton.backgroundColor = bgColor
                    })
                }
            }
        }
    }
    
    private func setupLoadingView() {
        loadingIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicatorView)
        loadingIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        loadingIndicatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 0).isActive = true
        loadingIndicatorView.startAnimating()
    }
    
    private let buttonDemension: CGFloat = 30
    private func setupTopContainer() {
        let barHeight: CGFloat = 52
        
        topContainer = UIView()
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topContainer)
        if #available(iOS 11.0, *) {
            topContainerTopConstraint = topContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -100)
        } else {
            topContainerTopConstraint = topContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: -100)
        }
        topContainerTopConstraint.isActive = true
        topContainer.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0).isActive = true
        topContainer.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        topContainer.heightAnchor.constraint(equalToConstant: barHeight).isActive = true

        topContainerShareButton = UIButton(type: .system)
        topContainerShareButton.tintColor = .white
        topContainerShareButton.backgroundColor = UIColor.init(white: 0, alpha: 0.6)
        topContainerShareButton.setImage(#imageLiteral(resourceName: "icons8-more-50.png"), for: .normal)
        topContainerShareButton.addTarget(self, action: #selector(handleActionButtonClick(_:)), for: .touchUpInside)
        
        let shareVisualView = createVisualEffectView(for: topContainerShareButton)
        shareVisualView.clipsToBounds = true
        topContainer.addSubview(shareVisualView)
        shareVisualView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            shareVisualView.rightAnchor.constraint(equalTo: topContainer.safeAreaLayoutGuide.rightAnchor, constant: -20).isActive = true
        } else {
            shareVisualView.rightAnchor.constraint(equalTo: topContainer.rightAnchor, constant: -20).isActive = true
        }
        shareVisualView.centerYAnchor.constraint(equalTo: topContainer.centerYAnchor, constant: 0).isActive = true
        shareVisualView.widthAnchor.constraint(equalToConstant: buttonDemension).isActive = true
        shareVisualView.heightAnchor.constraint(equalToConstant: buttonDemension).isActive = true
        shareVisualView.layer.cornerRadius = buttonDemension/2.0
        
        topContainerDismissButton = UIButton(type: .system)
        topContainerDismissButton.tintColor = .white
        topContainerDismissButton.backgroundColor = UIColor.init(white: 0, alpha: 0.6)
        topContainerDismissButton.setImage(#imageLiteral(resourceName: "icons8-multiply-50.png"), for: .normal)
        topContainerDismissButton.addTarget(self, action: #selector(handleDismissButtonClick(_:)), for: .touchUpInside)
        
        let dismissVisualView = createVisualEffectView(for: topContainerDismissButton)
        dismissVisualView.clipsToBounds = true
        topContainer.addSubview(dismissVisualView)
        dismissVisualView.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 11.0, *) {
            dismissVisualView.leftAnchor.constraint(equalTo: topContainer.safeAreaLayoutGuide.leftAnchor, constant: 20).isActive = true
        } else {
            dismissVisualView.leftAnchor.constraint(equalTo: topContainer.leftAnchor, constant: 20).isActive = true
        }
        dismissVisualView.centerYAnchor.constraint(equalTo: topContainer.centerYAnchor, constant: 0).isActive = true
        dismissVisualView.widthAnchor.constraint(equalToConstant: buttonDemension).isActive = true
        dismissVisualView.heightAnchor.constraint(equalToConstant: buttonDemension).isActive = true
        dismissVisualView.layer.cornerRadius = buttonDemension/2.0
        
        #if targetEnvironment(macCatalyst)
        topContainer.isHidden = true
        #endif
    }
    
    private func setupBottomContainer() {
        bottomContainer = UIStackView()
        bottomContainer.axis = .horizontal
        
        // bottomContainer.isHidden = true
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomContainer)
        bottomContainerBottomConstraint = bottomContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 100)
        bottomContainerBottomConstraint.isActive = true
        bottomContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 0).isActive = true
        
        bottomContainerLikeButton = UIButton(type: .custom)
        bottomContainerLikeButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        bottomContainerLikeButton.tintColor = .white
        bottomContainerLikeButton.setImage(#imageLiteral(resourceName: "thumb-up").withRenderingMode(.alwaysTemplate), for: .normal)
        bottomContainerLikeButton.addTarget(self, action: #selector(handleThumbUpButtonClick(_:)), for: .touchUpInside)
        bottomContainerLikeButton.setTitle("\(self.upvotedNumber)赞", for: .normal)
        bottomContainerLikeButton.setTitleColor(.white, for: .normal)
        bottomContainerLikeButton.setTitleColor(.gray, for: .disabled)
        
        let visualEffectView = createVisualEffectView(for: bottomContainerLikeButton)
        bottomContainer.addArrangedSubview(visualEffectView)
        visualEffectView.layer.cornerRadius = 3.0
        visualEffectView.clipsToBounds = true
    }
    
    private func createVisualEffectView(for view: UIView, effect: UIVisualEffect = UIBlurEffect(style: .dark)) -> UIVisualEffectView {
        let visualEffectView = UIVisualEffectView.init(effect: effect)
        visualEffectView.contentView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.leftAnchor.constraint(equalTo: visualEffectView.contentView.leftAnchor, constant: 0).isActive = true
        view.rightAnchor.constraint(equalTo: visualEffectView.contentView.rightAnchor, constant: 0).isActive = true
        view.topAnchor.constraint(equalTo: visualEffectView.contentView.topAnchor, constant: 0).isActive = true
        view.bottomAnchor.constraint(equalTo: visualEffectView.contentView.bottomAnchor, constant: 0).isActive = true
        return visualEffectView
    }
    
    private func setupTransitioning() {
        presentationTransitioning.transitioningView = transitioningView
        presentationTransitioning.targetView = imageView
        dismissalTransitioning.transitioningView = imageView
        dismissalTransitioning.targetView = transitioningView
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if scrollView.frame.size.equalTo(view.frame.size) {
            return
        }
        updateScrollView(size: view.frame.size)
    }
    
    private func updateScrollView(size: CGSize) {
        scrollView.zoomScale = 1.0
        scrollView.frame = .init(x: 0, y: 0, width: size.width, height: size.height)
        guard let image = imageView.image else {
            return
        }
        
        let originalRatio = image.size.width/image.size.height
        let scrollViewRatio = scrollView.frame.size.width/scrollView.frame.size.height
        
        var width: CGFloat
        var height: CGFloat
        if originalRatio > scrollViewRatio {
            width = scrollView.frame.size.width
            height = width/originalRatio
            scrollView.maximumZoomScale = max(scrollView.maximumZoomScale, scrollView.frame.size.height/height)
        } else {
            height = scrollView.frame.size.height
            width = height * originalRatio
            scrollView.maximumZoomScale = max(scrollView.maximumZoomScale, scrollView.frame.size.width/width)
        }
        imageView.transform = .identity
        imageView.frame = .init(x: 0, y: 0, width: width, height: height)
        scrollView.contentSize = imageView.frame.size
        adjustScrollViewInsets()
    }
    
    private func adjustScrollViewInsets() {
        let xoffset = max(0, (scrollView.frame.size.width - scrollView.contentSize.width)/2.0)
        let yoffset = max(0, (scrollView.frame.size.height - scrollView.contentSize.height)/2.0)
        scrollView.contentInset = UIEdgeInsets.init(top: yoffset, left: xoffset, bottom: yoffset, right: xoffset)
    }
    
    // MARK: - UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        adjustScrollViewInsets()
        setActionButtons(hidden: scrollView.zoomScale > 1.0)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        setActionButtons(hidden: scrollView.zoomScale >= 1.0)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        setActionButtons(hidden: scrollView.zoomScale > 1.0)
        
        if scrollView.zoomScale == 1.0 {
            let offsetY = scrollView.contentOffset.y + scrollView.contentInset.top
            if abs(offsetY) > bouncedDraggingDismissalDistance {
                dismiss(animated: true, completion: nil)
            }
        }
    }
    
    private func setActionButtons(hidden: Bool) {
        if hidden == isActionButtonsHidden {
            return
        }
        
        isActionButtonsHidden = hidden
        if hidden {
            topContainerTopConstraint.constant = -100
            bottomContainerBottomConstraint.constant = 100
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        } else {
            topContainerTopConstraint.constant = 10
            bottomContainerBottomConstraint.constant = -20
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc func handleActionButtonClick(_ sender: AnyObject) {
        showShareActionSheet(senderView: sender as! UIButton, senderItem: nil)
    }
    
    @objc func handleDismissButtonClick(_ sender: AnyObject?) {
        if let presenting = self.presentingViewController {
            presenting.dismiss(animated: true, completion: nil)
        } else {
            if #available(iOS 13.0, *) {
                if let sceneSession = self.view.window?.windowScene?.session {
                    self.view.window?.resignFirstResponder()
                    let options = UIWindowSceneDestructionRequestOptions()
                    options.windowDismissalAnimation = .standard
                    UIApplication.shared.requestSceneSessionDestruction(sceneSession, options: options, errorHandler: { (error) in
                        os_log("request scene session destruction returned: %@", error.localizedDescription)
                    })
                }
            } else {
                fatalError("This view controller must be presented if not in a new scene.")
            }
        }
    }
    
    @objc func handleThumbUpButtonClick(_ sender: UIButton) {
        hasUpvoted.toggle()
        if hasUpvoted {
            upvotedNumber = max(0, upvotedNumber + 1)
        } else {
            upvotedNumber = max(0, upvotedNumber - 1)
        }
    }
    
    @objc func handleTap(_ sender: AnyObject) {
        setActionButtons(hidden: !isActionButtonsHidden)
    }
    
    @objc func handleDoubleTap(_ sender: AnyObject) {
        if !loadingIndicatorView.isHidden {
            return
        }
        
        if scrollView.zoomScale > 1.0 {
            UIView.animate(withDuration: 0.3) {
                self.updateScrollView(size: self.view.frame.size)
            }
            return
        } else {
            scrollView.setZoomScale(scrollView.maximumZoomScale, animated: true)
        }
    }
    
    @objc func handleLongPress(_ sender: AnyObject) {
        handleActionButtonClick(topContainerShareButton)
    }
    
    func showShareActionSheet(senderView: UIView?, senderItem: UIBarButtonItem?) {
        if !loadingIndicatorView.isHidden {
            return
        }
        
        var items: [AnyObject] = []
        if let image = imageView.image {
            items.append(image)
        } else {
            items.append(imageURL as AnyObject)
        }
        
        
        let activityController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        #if !targetEnvironment(macCatalyst)
        activityController.modalPresentationStyle = .popover
        #endif
        activityController.completionWithItemsHandler = { (activityType, completed, returnedItems, activityError) in
            if let error = activityError {
                let alert = UIAlertController(title: "错误", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .cancel, handler: nil))
                #if !targetEnvironment(macCatalyst)
                if let item = senderItem {
                    alert.popoverPresentationController?.barButtonItem = item
                } else if let senderView = senderView {
                    alert.popoverPresentationController?.sourceView = senderView
                    alert.popoverPresentationController?.sourceRect = senderView.bounds
                }
                #endif
                self.present(alert, animated: true, completion: nil)
                return
            }
            
            var title:String?
            if activityType == UIActivity.ActivityType.copyToPasteboard {
                title = "已复制到剪贴板"
            } else if activityType == UIActivity.ActivityType.saveToCameraRoll {
                title = "已保存到相册"
            }
            
            if let _ = title {
                let alert = UIAlertController(title: nil, message: title!, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .cancel, handler: nil))
                #if !targetEnvironment(macCatalyst)
                alert.popoverPresentationController?.sourceView = self.view
                alert.popoverPresentationController?.sourceRect = self.view.bounds
                #endif
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        #if !targetEnvironment(macCatalyst)
        if let item = senderItem {
            activityController.popoverPresentationController?.barButtonItem = item
        } else if let senderView = senderView {
            activityController.popoverPresentationController?.sourceView = senderView
            activityController.popoverPresentationController?.sourceRect = senderView.bounds
        }
        #endif
        present(activityController, animated: true, completion: nil)
    }
    
    // MARK: UIViewControllerTransitioningDelegate
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return presentationTransitioning
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return dismissalTransitioning
    }
}

// MARK: Upvote State Sync
extension ImageViewController {
    private func syncDatabaseAndUI() {
        bottomContainerLikeButton.isEnabled = false
        guard let imageURL = self.imageURL?.absoluteString.lowercased() else {
            return
        }
        
        let uid = Account().uid
        guard uid != "0" else {
            return
        }
        
        let predicate = NSPredicate(format: "url = %@", imageURL)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        database.perform(query, inZoneWith: nil) { (returnedRecords, error) in
            guard error == nil else {
                os_log("query database failed: %@", log: .cloudkit, type:.error, error!.localizedDescription)
                return
            }
            
            self.updateUIBy(record: returnedRecords?.first, uid: uid)
        }
    }
    
    private func updateUIBy(record: CKRecord?, uid: String) {
        let upvotedUids = record?["upvoted"] as? [String] ?? []
        let viewedUids = record?["viewed"] as? [String] ?? []
        if upvotedUids.contains(uid) {
            DispatchQueue.main.async {
                self.upvotedNumber = upvotedUids.count
                self.hasUpvoted = true
                self.bottomContainerLikeButton.isEnabled = true
                self.viewedNumber = max(1, viewedUids.count)
            }
        } else {
            DispatchQueue.main.async {
                self.upvotedNumber = upvotedUids.count
                self.hasUpvoted = false
                self.bottomContainerLikeButton.isEnabled = true
                self.viewedNumber = max(1, viewedUids.count)
            }
        }
    }
    
    private func syncUIAndDatabase() {
        guard isViewLoaded else {
            return
        }
        
        if !bottomContainerLikeButton.isEnabled {
            return
        }
        
        let upvoted = self.hasUpvoted
        guard let imageURL = self.imageURL?.absoluteString.lowercased() else {
            return
        }
        
        let uid = Account().uid
        guard uid != "0" else {
            return
        }
        
        let database = self.database
        let recordType = self.recordType
        ImageViewController.doSync(uid: uid, upvoted: upvoted, imageURL: imageURL, database: database, recordType: recordType)
    }
    
    private static func doSync(uid: String,
                        upvoted: Bool,
                        imageURL: String,
                        database: CKDatabase,
                        recordType: CKRecord.RecordType,
                        retryAttempt: Int = 0) {
        if retryAttempt >= SACloudKitSyncRequestMaxAttempt {
            os_log("retry reaches limit", log: .cloudkit, type:.info)
            return
        }
        
        if retryAttempt > 0 {
            os_log("retry syncing ui and cloudkit", log: .cloudkit, type:.info)
        }
        
        let predicate = NSPredicate(format: "url = %@", imageURL)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        database.perform(query, inZoneWith: nil) { (returnedRecords, error) in
            guard error == nil else {
                os_log("save database failed: %@", log: .cloudkit, type:.error, error!.localizedDescription)
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    ImageViewController.doSync(uid: uid, upvoted: upvoted, imageURL: imageURL, database: database, recordType: recordType, retryAttempt: retryAttempt + 1)
                }
                return
            }
            
            guard let record = returnedRecords?.first else {
                os_log("no record. Create new one.", log: .cloudkit, type:.info)
                let recordID = CKRecord.ID(recordName: imageURL)
                let record = CKRecord(recordType: recordType, recordID: recordID)
                record["url"] = imageURL
                record["domain"] = SAGlobalConfig().forum_domain
                record["viewed"] = [uid]
                record["upvoted"] = upvoted ? [uid] : [String]()
                database.save(record) { (returnedRecord, error) in
                    guard error == nil else {
                        os_log("save database failed: %@", log: .cloudkit, type:.error, error!.localizedDescription)
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                            ImageViewController.doSync(uid: uid, upvoted: upvoted, imageURL: imageURL, database: database, recordType: recordType, retryAttempt: retryAttempt + 1)
                        }
                        return
                    }
                }
                return
            }
            
            // update viewed record
            var viewedUids = (record["viewed"] as? [String]) ?? []
            if !viewedUids.contains(uid) {
                viewedUids.append(uid)
            }
            record["viewed"] = viewedUids
            
            // update upvote record
            var upvotedUids = record["upvoted"] as? [String] ?? []
            if upvoted {
                if !upvotedUids.contains(uid) {
                    upvotedUids.append(uid)
                }
            } else {
                upvotedUids.removeAll { (existUid) -> Bool in
                    return uid == existUid
                }
            }
            record["upvoted"] = upvotedUids
            
            database.save(record) { (record, error) in
                if error == nil {
                    return
                }
                
                os_log("save database failed: %@", log: .cloudkit, type:.error, error!.localizedDescription)
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    ImageViewController.doSync(uid: uid, upvoted: upvoted, imageURL: imageURL, database: database, recordType: recordType, retryAttempt: retryAttempt + 1)
                }
            }
        }
    }
}
