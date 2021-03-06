//
//  main.c
//  Saralin
//
//  Created by Junhui Zhang on 2020/11/15.
//  Copyright © 2020 zaczh. All rights reserved.
//

#import <UIKit/UIKit.h>

int main(int argc, char **argv) {
#if TARGET_OS_MACCATALYST
    NSString *macCatalystExtensionBundlePath = [NSBundle.mainBundle.builtInPlugInsPath stringByAppendingString: @"/CatalystExtension.bundle"];
    NSBundle *bundle = [[NSBundle alloc] initWithPath:macCatalystExtensionBundlePath];
    Class cls = bundle.principalClass;
    [cls performSelector:@selector(run)];
#endif
    return UIApplicationMain(argc, argv, nil, @"Saralin.SAAppDelegate");
}
