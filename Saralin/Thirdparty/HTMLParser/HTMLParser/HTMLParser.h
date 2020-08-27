//
//  HTMLParser.h
//  StackOverflow
//
//  Created by Ben Reeves on 09/03/2010.
//  Copyright 2010 Ben Reeves. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libxml/HTMLparser.h>
#import "HTMLNode.h"

@class HTMLNode;

@interface HTMLParser : NSObject 
{
	@public
	htmlDocPtr _Nonnull _doc;
}

-(instancetype _Nullable)initWithContentsOfURL:(NSURL*_Nonnull)url error:(NSError*_Nullable * _Nullable) error;
-(instancetype _Nullable)initWithData:(NSData*_Nonnull)data error:(NSError*_Nullable * _Nullable)error;
-(instancetype _Nullable)initWithString:(NSString*_Nonnull)string error:(NSError*_Nullable * _Nullable)error;

//Returns the doc tag
-(HTMLNode*_Nullable)doc;

//Returns the body tag
-(HTMLNode*_Nullable)body;

//Returns the html tag
-(HTMLNode*_Nullable)html;

//Returns the head tag
- (HTMLNode*_Nullable)head;

@end
