//
//  SAIAPManager.swift
//  Saralin
//
//  Created by zhang on 22/12/2017.
//  Copyright © 2017 zaczh. All rights reserved.
//

import UIKit
import StoreKit

class SAIAPManager: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    private var iapProductRequest: SKProductsRequest?
    private var iapProducts:[SKProduct] = []
    private var iapProcessingActivityController: SAModalActivityViewController?
    
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    
    func presentIAPInterface() {
        if !SKPaymentQueue.canMakePayments() {
            showIAPCanNotPayAlert()
            return
        }
        
        guard let window = AppController.current.currentActiveWindow else {
            return
        }
        
        if iapProcessingActivityController != nil {
            iapProcessingActivityController!.hide(completion: nil)
        }
        
        iapProcessingActivityController = SAModalActivityViewController.init(style: SAModalActivityStyle.loading, caption: NSLocalizedString("PROCESSING_HINT", comment: "Processing"))
        window.rootViewController?.present(iapProcessingActivityController!, animated: true, completion: nil)
        let pid_path = Bundle.main.path(forResource: "product_ids", ofType: "plist")!
        let pids = NSArray.init(contentsOfFile: pid_path)! as! Array<String>
        let productIdentifier: Set<String> = Set.init(pids)
        let request = SKProductsRequest.init(productIdentifiers: productIdentifier)
        request.delegate = self
        request.start()
        self.iapProductRequest = request
    }
    
    // MARK: - SKProductRequestDelegate
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        iapProducts.removeAll()
        iapProducts.append(contentsOf: response.products)
//        for invalidIdentifier in response.invalidProductIdentifiers {
//            // handle it
//        }
        
        if iapProducts.count == 0 {
            iapProcessingActivityController?.hide(completion: {
                self.showIAPFailAlert()
            })
            return
        }
        
        // currently there is only one iap item for donation
        let payment = SKMutablePayment.init(product: iapProducts.first!)
        payment.quantity = 1
        SKPaymentQueue.default().add(payment)
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        sa_log_v2("request products failed with error: %@", module: .ui, type: .info, error as CVarArg)
        iapProcessingActivityController?.hide(completion: {
            self.showIAPFailAlert()
        })
        return
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                sa_log_v2("iap purchasing", module: .ui, type: .info)
                break
            case .purchased:
                iapProcessingActivityController?.hide(completion: {
                    self.showIAPSuccessAlert()
                })
                SKPaymentQueue.default().finishTransaction(transaction)
                sa_log_v2("iap succeeded", module: .ui, type: .info)
            break// purchase succeeded
            case .failed:
                iapProcessingActivityController?.hide(completion: {
                    self.showIAPFailAlert()
                })
                SKPaymentQueue.default().finishTransaction(transaction)
                sa_log_v2("iap failed", module: .ui, type: .info)
            break// purchase failed
            case .restored:
                iapProcessingActivityController?.hide(completion: nil)
                SKPaymentQueue.default().finishTransaction(transaction)
                sa_log_v2("iap restored", module: .ui, type: .info)
                break
            case .deferred:
                sa_log_v2("iap deferred", module: .ui, type: .info)
                break
            @unknown default:
                fatalError()
            }
        }
    }
    
    private func showIAPSuccessAlert() {
        guard let window = AppController.current.currentActiveWindow else {
            return
        }
        
        let alert = UIAlertController(title: NSLocalizedString("THANK_YOU", comment: "Thank You"), message: NSLocalizedString("IAP_DONATE_SUCCESS_THANK_YOU_LETTER", comment: "Thank You"), preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = window
        alert.popoverPresentationController?.sourceRect = window.bounds
        let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        window.rootViewController?.present(alert, animated: true, completion: nil)
    }
    
    private func showIAPCanNotPayAlert() {
        guard let window = AppController.current.currentActiveWindow else {
            return
        }
        
        let alert = UIAlertController(title: NSLocalizedString("HINT", comment: "Hint"), message: NSLocalizedString("IAP_DONATE_IAP_CAN_NOT_PAY", comment: "Can not make purchase"), preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = window
        alert.popoverPresentationController?.sourceRect = window.bounds
        let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        window.rootViewController?.present(alert, animated: true, completion: nil)
    }
    
    private func showIAPFailAlert() {
        guard let window = AppController.current.currentActiveWindow else {
            return
        }
        
        let alert = UIAlertController(title: NSLocalizedString("HINT", comment: "Hint"), message: NSLocalizedString("IAP_DONATE_FAIL_NOTICE", comment: "There is an error"), preferredStyle: .alert)
        alert.popoverPresentationController?.sourceView = window
        alert.popoverPresentationController?.sourceRect = window.bounds
        let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        window.rootViewController?.present(alert, animated: true, completion: nil)
    }
}
