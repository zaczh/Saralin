//
//  ChatViewController.swift
//  SwiftExample
//
//  Created by Dan Leonard on 5/11/16.
//  Copyright © 2016 MacMeDan. All rights reserved.
//

import UIKit

class ChatViewController: BaseChatViewController {
    struct Conversation {
        var cid: String
        var pmid: String
        var formhash: String
        var name: String
        var participants: Set<String>
        var numberOfMessages: Int
    }
    
    var messageSender: MessageSender!
    
    lazy private var baseMessageHandler: BaseMessageHandler = {
        return BaseMessageHandler(messageSender: self.messageSender)
    }()
    
    init(conversation: Conversation) {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        let dataSource = ChatDataSource(conversation: conversation)
        self.chatDataSource = dataSource
        self.messageSender = dataSource.messageSender
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            navigationItem.largeTitleDisplayMode = .never
        } else {
            // Fallback on earlier versions
        }
        
        title = (self.chatDataSource as! ChatDataSource).conversation.name
        super.chatItemsDecorator = ChatItemsDecorator()
        
        if let textView = self.chatInputPresenter.chatInputBar.value(forKey: "textView") as? UITextView {
            textView.becomeFirstResponder()
        }
    }
    
    override func viewThemeDidChange(_ newTheme: SATheme) {
        super.viewThemeDidChange(newTheme)
        self.view.backgroundColor = newTheme.foregroundColor.sa_toColor()
        self.inputBarContainer.backgroundColor = newTheme.foregroundColor.sa_toColor()
        self.inputContentContainer.backgroundColor = newTheme.foregroundColor.sa_toColor()
        if let textView = self.chatInputPresenter.chatInputBar.value(forKey: "textView") as? UITextView {
            textView.textColor = newTheme.textColor.sa_toColor()
        }
    }
    
    var chatInputPresenter: BasicChatInputBarPresenter!
    override func createChatInputView() -> UIView {
        let chatInputView = ChatInputBar.loadNib()
        var appearance = ChatInputBarAppearance()
        appearance.sendButtonAppearance.font = UIFont.sa_preferredFont(forTextStyle: .body)
        appearance.textInputAppearance.font = UIFont.sa_preferredFont(forTextStyle: .body)
        appearance.textInputAppearance.placeholderFont = UIFont.sa_preferredFont(forTextStyle: .body)
        appearance.sendButtonAppearance.title = NSLocalizedString("SEND", comment: "")
        appearance.textInputAppearance.placeholderText = NSLocalizedString("INPUT_MESSAGE", comment: "")
        self.chatInputPresenter = BasicChatInputBarPresenter(chatInputBar: chatInputView, chatInputItems: self.createChatInputItems(), chatInputBarAppearance: appearance)
        chatInputView.maxCharactersCount = 1000
        return chatInputView
    }
    
    override func createPresenterBuilders() -> [ChatItemType: [ChatItemPresenterBuilderProtocol]] {
        
        let textMessagePresenter = TextMessagePresenterBuilder(
            viewModelBuilder: DemoTextMessageViewModelBuilder(),
            interactionHandler: DemoTextMessageHandler(baseHandler: self.baseMessageHandler)
        )
        textMessagePresenter.textCellStyle = DemoTextMessageCollectionViewCellStyle()
        textMessagePresenter.baseMessageStyle = BaseMessageCollectionViewCellAvatarStyle()
        
        let photoMessagePresenter = PhotoMessagePresenterBuilder(
            viewModelBuilder: DemoPhotoMessageViewModelBuilder(),
            interactionHandler: DemoPhotoMessageHandler(baseHandler: self.baseMessageHandler)
        )
        photoMessagePresenter.baseCellStyle = BaseMessageCollectionViewCellAvatarStyle()
        
        return [
            DemoTextMessageModel.chatItemType: [
                textMessagePresenter
            ],
            DemoPhotoMessageModel.chatItemType: [
                photoMessagePresenter
            ],
            SendingStatusModel.chatItemType: [SendingStatusPresenterBuilder()],
            TimeSeparatorModel.chatItemType: [TimeSeparatorPresenterBuilder()]
        ]
    }
    
    func createChatInputItems() -> [ChatInputItemProtocol] {
        var items = [ChatInputItemProtocol]()
        items.append(self.createTextInputItem())
        items.append(self.createPhotoInputItem())
        return items
    }
    
    private func createTextInputItem() -> TextChatInputItem {
        let item = TextChatInputItem()
        item.textInputHandler = { [weak self] text in
            (self?.chatDataSource as? ChatDataSource)?.addTextMessage(text, isIncoming: false, date: Date())
        }
        return item
    }
    
    private func createPhotoInputItem() -> PhotosChatInputItem {
        let item = PhotosChatInputItem(presentingController: self)
        item.photoInputHandler = { [weak self] image in
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "提示", message: "暂不支持发送图片", preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .cancel, handler: nil)
                alert.addAction(cancelAction)
                alert.popoverPresentationController?.sourceView = self?.chatInputPresenter.chatInputBar
                alert.popoverPresentationController?.sourceRect = self?.chatInputPresenter.chatInputBar.bounds ?? CGRect.zero
                self?.present(alert, animated: true, completion: nil)
            }
        }
        return item
    }
    
}

extension ChatInputBar {
    override func themeDidUpdate(_ newTheme: SATheme) {
        super.themeDidUpdate(newTheme)
        self.backgroundColor = newTheme.foregroundColor.sa_toColor()
        for v in subviews {
            if v.frame.size.height == 1 {
                v.backgroundColor = newTheme.tableCellSeperatorColor.sa_toColor()
            } else {
                v.backgroundColor = .clear
            }
        }
        self.scrollView.backgroundColor = .clear
        self.textView.backgroundColor = .clear
        self.textView.tintColor = newTheme.globalTintColor.sa_toColor()
        self.textView.setTextPlaceholderColor(newTheme.textColor.sa_toColor())
        self.textView.layer.borderColor = newTheme.tableCellTextColor.sa_toColor().cgColor
    }
}
