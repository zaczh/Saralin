//
//  HTMLNode.h
//  StackOverflow
//
//  Created by Ben Reeves on 09/03/2010.
//  Copyright 2010 Ben Reeves. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libxml/HTMLparser.h>
#import "HTMLParser.h"

@class HTMLParser;

#define ParsingDepthUnlimited 0
#define ParsingDepthSame -1
#define ParsingDepth size_t

typedef enum
{
	HTMLHrefNode,
	HTMLTextNode,
	HTMLUnkownNode,
	HTMLCodeNode,
	HTMLSpanNode,
	HTMLPNode,
	HTMLLiNode,
	HTMLUlNode,
	HTMLImageNode,
	HTMLOlNode,
	HTMLStrongNode,
	HTMLPreNode,
	HTMLBlockQuoteNode,
} HTMLNodeType;


@interface HTMLNode : NSObject 
{
@public
	xmlNode * _Nonnull _node;
}

//Init with a lib xml node (shouldn't need to be called manually)
//Use [parser doc] to get the root Node
-(id _Nonnull)initWithXMLNode:(xmlNode* _Nonnull)xmlNode;

//Returns a single child of class
-(HTMLNode* _Nullable)findChildOfClass:(NSString* _Nonnull)className;

//Returns all children of class
-(NSArray <HTMLNode*>* _Nonnull)findChildrenOfClass:(NSString * _Nonnull)className;

//Finds a single child with a matching attribute 
//set allowPartial to match partial matches 
//e.g. <img src="http://www.google.com> [findChildWithAttribute:@"src" matchingName:"google.com" allowPartial:TRUE]
-(HTMLNode* _Nullable)findChildWithAttribute:(NSString*_Nonnull)attribute matchingName:(NSString*_Nonnull)className allowPartial:(BOOL)partial;

//Finds all children with a matching attribute
-(NSArray <HTMLNode*>* _Nonnull)findChildrenWithAttribute:(NSString*_Nonnull)attribute matchingName:(NSString*_Nonnull)className allowPartial:(BOOL)partial;

//Gets the attribute value matching tha name
-(NSString* _Nullable)getAttributeNamed:(NSString*_Nonnull)name;

//Find childer with the specified tag name
-(NSArray <HTMLNode*>* _Nonnull)findChildTags:(NSString*_Nonnull)tagName;

//Looks for a tag name e.g. "h3"
-(HTMLNode* _Nullable)findChildTag:(NSString*_Nonnull)tagName;

// Find child with the specified id
- (HTMLNode * _Nullable)getElementById:(NSString * _Nonnull)tagId;

//Returns the first child element
-(HTMLNode* _Nullable)firstChild;

//Returns the plaintext contents of node
-(NSString* _Nullable)contents;

//Returns the plaintext contents of this node + all children
-(NSString* _Nullable)allContents;

//Returns the html contents of the node 
-(NSString* _Nullable)rawContents;

//Returns next sibling in tree
-(HTMLNode* _Nullable)nextSibling;

//Returns previous sibling in tree
-(HTMLNode* _Nullable)previousSibling;

//Returns the class name
-(NSString* _Nullable)className;

//Returns the tag name
-(NSString* _Nullable)tagName;

//Returns the parent
-(HTMLNode* _Nonnull)parent;

//Returns the first level of children
-(NSArray <HTMLNode*> * _Nonnull)children;

//Returns the node type if know
-(HTMLNodeType)nodetype;

//C functions for minor performance increase in tight loops
NSString * _Nullable getAttributeNamed(xmlNode *_Nonnull node, const char *_Nonnull nameStr);
void setAttributeNamed(xmlNode *_Nonnull node, const char *_Nonnull nameStr, const char *_Nonnull value);
HTMLNodeType nodeType(xmlNode*_Nonnull node);
NSString * _Nullable allNodeContents(xmlNode*_Nonnull node);
NSString * _Nullable rawContentsOfNode(xmlNode *_Nonnull node);


@end
