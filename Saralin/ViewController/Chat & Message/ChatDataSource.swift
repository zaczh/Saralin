/*
 The MIT License (MIT)

 Copyright (c) 2015-present Badoo Trading Limited.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

import Foundation

func createTextMessageModel(_ uid: String, text: String, isIncoming: Bool, date: Date = Date(), status: MessageStatus = .success) -> DemoTextMessageModel {
    let messageModel = createMessageModel(uid, isIncoming: isIncoming, type: TextMessageModel<MessageModel>.chatItemType, date: date, status: status)
    let textMessageModel = DemoTextMessageModel(messageModel: messageModel, text: text)
    return textMessageModel
}

func createMessageModel(_ uid: String, isIncoming: Bool, type: String, date: Date = Date(), status: MessageStatus = .success) -> MessageModel {
    let senderId = isIncoming ? "1" : "2"
    let messageModel = MessageModel(uid: uid, senderId: senderId, type: type, isIncoming: isIncoming, date: date, status: status)
    return messageModel
}

func createPhotoMessageModel(_ uid: String, image: UIImage, size: CGSize, isIncoming: Bool) -> DemoPhotoMessageModel {
    let messageModel = createMessageModel(uid, isIncoming: isIncoming, type: PhotoMessageModel<MessageModel>.chatItemType)
    let photoMessageModel = DemoPhotoMessageModel(messageModel: messageModel, imageSize:size, image: image)
    return photoMessageModel
}

extension TextMessageModel {
    static var chatItemType: ChatItemType {
        return "text"
    }
}

extension PhotoMessageModel {
    static var chatItemType: ChatItemType {
        return "photo"
    }
}

class ChatDataSource: ChatDataSourceProtocol {
    var conversation: ChatViewController.Conversation
    var nextMessageId: Int = 0

    var messages: [MessageModelProtocol] = []

    init(conversation: ChatViewController.Conversation) {
        self.conversation = conversation
        loadPrevious()
    }

    lazy var messageSender: MessageSender = {
        let sender = MessageSender()
        sender.conversation = self.conversation
        sender.onMessageChanged = { [weak self] (message) in
            guard let sSelf = self else { return }
            sSelf.delegate?.chatDataSourceDidUpdate(sSelf)
        }
        return sender
    }()

    var hasMoreNext: Bool {
        return false
    }

    var hasMorePrevious: Bool {
        return false
    }

    var chatItems: [ChatItemProtocol] {
        return self.messages
    }

    weak var delegate: ChatDataSourceDelegateProtocol?

    func loadNext() {
    }

    func loadPrevious() {
        let totalPage = Int(ceil(Double(conversation.numberOfMessages)/5))

        URLSession.saCustomized.getHistoryMessage(with: conversation.cid, page: totalPage + 1) { (result, error) in
            let errorHandler = { () in
            }
            
            guard error == nil,
                let variables = result?["Variables"] as? [String: AnyObject],
                let list = variables["list"] as? [[String: AnyObject]],
                list.count > 0 ,
                !Account().isGuest else {
                    errorHandler()
                    return
            }
            
            self.conversation.formhash = variables["formhash"] as! String
            self.conversation.pmid = variables["pmid"] as! String
            self.messageSender.conversation = self.conversation
            
            // let currentPage = Int(variables["page"] as! String)! // current page
            // let count = Double(variables["count"] as! String)!
            
            for item in list {
                let fromUid = item["msgfromid"] as! String
                let interval = Int(item["dateline"] as! String)!
                let contentRaw = item["message"] as! String
                
                var content = ""
                // This message is actually HTML code, so we need to translate it to plain text
                let html = "<html><meta charset=\"utf-8\"><body><div>" + contentRaw + "</div></body></html>"
                guard let parser = try? HTMLParser.init(string: html) else {
                    continue
                }
                content += parser.body()?.allContents() ?? ""
                
                let message = createTextMessageModel("\(self.nextMessageId)", text: content, isIncoming: Account().uid != fromUid, date: Date(timeIntervalSince1970: TimeInterval(interval)))
                self.nextMessageId = self.nextMessageId + 1
                self.messages.append(message)
            }
            self.delegate?.chatDataSourceDidUpdate(self, updateType: .firstLoad)
        }
    }

    func addTextMessage(_ text: String, isIncoming: Bool = false, date: Date = Date()) {
        let uid = "\(self.nextMessageId)"
        self.nextMessageId += 1
        let message = createTextMessageModel(uid, text: text, isIncoming: isIncoming, date: date, status: .sending)
        self.messageSender.sendMessage(message)
        self.messages.append(message)
        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func addPhotoMessage(_ image: UIImage) {
        let uid = "\(self.nextMessageId)"
        self.nextMessageId += 1
        let message = createPhotoMessageModel(uid, image: image, size: image.size, isIncoming: false)
        self.messageSender.sendMessage(message)
        self.messages.append(message)
        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func adjustNumberOfMessages(preferredMaxCount: Int?, focusPosition: Double, completion:(_ didAdjust: Bool) -> Void) {
        completion(false)
    }
}
