//
//  main.m
//  GenerateMohjongEmojiPlist
//
//  Created by zhang on 2018/9/4.
//  Copyright © 2018年 xxx. All rights reserved.
//

#import <Foundation/Foundation.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *rootPath = [NSString stringWithUTF8String:argv[1]];
        NSString *emojiFileDir = [[rootPath stringByAppendingPathComponent:@"Mahjong"] stringByStandardizingPath];
        NSLog(@"Mahjong directory: %@", emojiFileDir);
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:emojiFileDir];
        if (!enumerator) {
            NSLog(@"WARNING: directory empty: %@", emojiFileDir);
            return -1;
        }
        
        NSMutableArray *plist = [NSMutableArray array];
        for (NSString *path in enumerator) {
            NSString *filePath = [emojiFileDir stringByAppendingPathComponent:path];
            BOOL isDir = NO;
            [fm fileExistsAtPath:filePath isDirectory:&isDir];
            if (!isDir) {
                continue;
            }
            
            NSLog(@"sub dir: %@", path);
            NSString *firstChar = [path substringToIndex:1];
            NSMutableDictionary *emoji = [NSMutableDictionary new];
            [emoji setObject:[path stringByReplacingOccurrencesOfString:@"2017" withString:@""] forKey:@"info"];
            NSMutableArray *emojiArr = [NSMutableArray array];
            for (NSString *mahjongFile in [fm enumeratorAtPath:filePath]) {
                NSString *number = [mahjongFile stringByDeletingPathExtension];
                NSString *image = [NSString stringWithFormat:@"%@/%@", path, mahjongFile];
                NSString *text = [NSString stringWithFormat:@"[%@:%@]", firstChar, number];
                [emojiArr addObject:@{@"text":text,@"image":image}];
            }
            
            [emoji setObject:emojiArr forKey:@"emojis"];
            
            [emojiArr sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                NSDictionary *dict1 = (NSDictionary *)obj1;
                NSDictionary *dict2 = (NSDictionary *)obj2;
                NSString *info1 = dict1[@"text"];
                NSString *info2 = dict2[@"text"];
                return [info1 compare:info2];
            }];
            
            [plist addObject:emoji];
        }
        
        [plist sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NSDictionary *dict1 = (NSDictionary *)obj1;
            NSDictionary *dict2 = (NSDictionary *)obj2;
            NSString *info1 = dict1[@"info"];
            NSString *info2 = dict2[@"info"];
            return [info1 compare:info2];
        }];
        
        NSDictionary *dict = @{@"version":@"1.0",@"items":plist};
        [dict writeToFile:[NSString stringWithFormat:@"%@/Mahjong/emoji.plist", rootPath] atomically:YES];
    }
    return 0;
}
