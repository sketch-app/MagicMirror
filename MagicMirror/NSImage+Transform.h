//
//  NSImage+Transform.h
//  MagicMirror2
//
//  Created by James Tang on 9/12/2015.
//  Copyright © 2015 James Tang. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MSShapePath;

@interface NSImage (Transform)

- (NSImage *)imageForPath:(MSShapePath *)path;

@end