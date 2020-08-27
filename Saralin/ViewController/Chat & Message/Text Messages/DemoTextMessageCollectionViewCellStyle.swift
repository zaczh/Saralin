//
//  DemoTextMessageCollectionViewCellStyle.swift
//  Saralin
//
//  Created by zhang on 30/01/2018.
//  Copyright © 2018 zaczh. All rights reserved.
//

import UIKit

class DemoTextMessageCollectionViewCellStyle: TextMessageCollectionViewCellDefaultStyle {
    convenience init() {
        let textStyle = TextMessageCollectionViewCellDefaultStyle.TextStyle(
            font: UIFont.sa_preferredFont(forTextStyle: .body),
            incomingColor: UIColor.black,
            outgoingColor: UIColor.white,
            incomingInsets: UIEdgeInsets(top: 10, left: 19, bottom: 10, right: 15),
            outgoingInsets: UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 19)
        )
        
        self.init(bubbleImages: TextMessageCollectionViewCellDefaultStyle.createDefaultBubbleImages(),
                  textStyle: textStyle,
                  baseStyle: BaseMessageCollectionViewCellDefaultStyle())
    }
}
