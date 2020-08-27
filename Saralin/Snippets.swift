//
//  Snippets.swift
//  Saralin
//
//  Created by zhang on 2019/3/27.
//  Copyright © 2019 zaczh. All rights reserved.
//

import UIKit

func imageFrom(color: UIColor, size: CGSize) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
    let context = UIGraphicsGetCurrentContext()!
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1.0, y: -1.0)
    context.setBlendMode(.normal)
    let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    color.setFill()
    context.fill(rect)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return newImage
}
