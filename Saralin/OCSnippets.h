//
//  OCSnippets.h
//  Saralin
//
//  Created by zhang on 2018/8/16.
//  Copyright © 2018年 zaczh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UIImage;
@class UIColor;
NSDictionary <UIColor*, NSNumber *>* mainColoursInImage(UIImage *image, int detail);
double colourDistance(UIColor *color1, UIColor *color2);
NS_ASSUME_NONNULL_END
