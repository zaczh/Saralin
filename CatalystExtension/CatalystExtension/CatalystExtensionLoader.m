//
//  CatalystExtensionLoader.m
//  CatalystExtension
//
//  Created by Junhui Zhang on 2020/4/6.
//  Copyright © 2020 zaczh. All rights reserved.
//

#import "CatalystExtensionLoader.h"
#import <AppKit/AppKit.h>

@implementation CatalystExtensionLoader
- (void)run {
    NSWindow *window = [NSApplication sharedApplication].keyWindow;
    if (window == nil) {
        [self performSelector:@selector(run) withObject:nil afterDelay:0];
        return;
    }
    [window setContentSize:NSMakeSize(1200, 900)];
    [window setContentMinSize:NSMakeSize(1200, 900)];
}
@end
