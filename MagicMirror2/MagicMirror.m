//
//  MMViewController.m
//  MagicMirror2
//
//  Created by James Tang on 7/12/2015.
//  Copyright © 2015 James Tang. All rights reserved.
//

@import AppKit;
#import "MagicMirror.h"
#import "MMWindowController.h"
#import "SketchPluginContext.h"
#import "MSLayerFlattener.h"
#import "MSLayerArray.h"
#import "MSArtboardGroup.h"
#import "MSShapeGroup.h"
#import "MSStyle.h"
#import "MSStyleFill.h"
#import "MSFillStyleCollection.h"
#import "MSExportRequest.h"
#import "MSExportRenderer.h"
#import "NSImage+Transform.h"
#import "MSShapePath.h"
#import "ImageRenderer.h"
#import "MMToolbarViewController.h"
#import "MMLayerProperties.h"
#import "MSArray.h"
#import "MSShapePathLayer.h"
#import "MSShapePath.h"
#import "NSBezierPath-Clockwise.h"
#import "NSBezierPath+Alter.h"
#import "MSCurvePoint.h"
#import "MMMath.h"
#import "MSContentDrawView.h"
#import "MMLicenseInfo.h"
#import "Weak.h"


NSString *const MagicMirrorSharedInstanceDidUpdateNotification = @"MagicMirrorSharedInstanceDidUpdateNotification";

@interface MagicMirror ()

@property (nonatomic, strong) MMWindowController *controller;
@property (nonatomic, strong) SketchPluginContext *context;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, strong) ImageRenderer *imageRenderer;

//@property (nonatomic, copy) NSNumber *imageQuality;
@property (nonatomic) ImageRendererColorSpaceIdentifier colorSpaceIdentifier;
@property (nonatomic) BOOL perspective;
@property (nonatomic, copy) NSDictionary *artboardsLookup;
@property (nonatomic, strong) NSURLSessionDataTask *task;

@end

@interface MagicMirror (Persist)

- (void)persistDictionary:(id)object withIdentifier:(NSString *)identifier;
- (NSDictionary *)persistedDictionaryForIdentifier:(NSString *)identifier;
- (void)removePersistedDictionaryForIdentifier:(NSString *)identifier;

@end

@interface MagicMirror (MMWindowControllerDelegate) <MMWindowControllerDelegate>

@end

@implementation MagicMirror

static NSMutableArray <Weak *>*_observers = nil;
static MagicMirror *_sharedInstance = nil;

+ (id)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

+ (void)setSharedInstance:(MagicMirror *)sharedInstance {
    _sharedInstance = sharedInstance;
    [_observers enumerateObjectsUsingBlock:^(Weak * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id <MMController> controller = [obj object];
        [controller setMagicmirror:_sharedInstance];
    }];
}

+ (void)load {
    if ( ! _observers) {
        _observers = [NSMutableArray array];
    }
}

+ (instancetype)addObserver:(id<MMController>)observer {
    [_observers addObject:[Weak weakWithObject:observer]];
    return [self sharedInstance];
}

- (id)initWithContext:(SketchPluginContext *)context {
    if (self = [super init]) {
        _context = context;
        _colorSpaceIdentifier = ImageRendererColorSpaceDeviceRGB;
        _imageRenderer = [[ImageRenderer alloc] init];
        _perspective = YES;
        _version = @"2.0";

        _imageRenderer = [[ImageRenderer alloc] init];

        return self;
    }
    return nil;
}

- (void)showWindow {
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Storyboard" bundle:[NSBundle bundleForClass:[MMWindowController class]]];
    _controller = [storyboard instantiateInitialController];
    _controller.magicmirror = self;
    _controller.delegate = self;
    [_controller showWindow:self];
    [self reloadData];
}

- (void)showLicenseInfo {
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Storyboard" bundle:[NSBundle bundleForClass:[MMWindowController class]]];
    _controller = [storyboard instantiateControllerWithIdentifier:[self isRegistered] ? @"RegisteredWindow" : @"LicenseWindow"];

    if ([_controller conformsToProtocol:@protocol(MMController)]) {
        _controller.magicmirror = self;
        _controller.delegate = self;
    }
    [_controller showWindow:self];
    [self reloadData];
}

- (void)keepAround {
    _context.shouldKeepAround = YES;
    MMLog(@"keepAround");
}

- (void)goAway {
    _context.shouldKeepAround = NO;
    MMLog(@"goAway");
}

- (id)valueForKey:(NSString *)key onLayer:(id)layer {
    return [_context.command valueForKey:key onLayer:layer];
}

- (void)setValue:(id)value forKey:(NSString *)key onLayer:(id)layer {
    [_context.command setValue:value forKey:key onLayer:layer];
}

- (void)reloadData {
    if ([_controller conformsToProtocol:@protocol(MMController)]) {
        [_controller reloadData];
    }
}

#pragma mark Subclass

- (void)layerSelectionDidChange:(NSArray *)layers {
    [self reloadData];
    [_controller reloadData];
}

- (void)layerDidUpdate:(id<MSShapeGroup>)layer {
    [self refreshLayer:layer];
}

#pragma - Fill

- (void)disableFillLayer:(id <MSShapeGroup>)layer {
    MSStyleFill *fill = [layer.style.fills firstObject];
    [fill setIsEnabled:NO];
}

- (void)fillLayer:(id <MSShapeGroup>)layer withImage:(NSImage *)image {
    MSStyleFill *fill = [layer.style.fills firstObject];
    if ( ! fill) {
        fill = [layer.style.fills addNewStylePart];
    }
    [fill setFillType:4];
    [fill setPatternFillType:1];
    [fill setIsEnabled:true];
    [fill setPatternImage:image];
}

#pragma - Per Layer

- (void)clearLayer:(id <MSShapeGroup>)layer {
    MMLayerProperties *properties = [self layerPropertiesForLayer:layer];
    if (properties.source) {
        NSDictionary *artboardLookup = [_context artboardsLookup];
        if (artboardLookup[properties.source]) {
            [layer setName:[[layer name] stringByAppendingString:@"_detached"]];
            [self disableFillLayer:layer];
        }
    }

    [self setValue:nil forKey:@"source" onLayer:layer];
    [self setValue:nil forKey:@"imageQuality" onLayer:layer];
    [self setValue:_version forKey:@"version" onLayer:layer];
}

- (void)flipLayer:(id <MSShapeGroup>)layer {
    MSArray *array = [layer layers];
    MSShapePathLayer *shape = [array firstObject];
    NSBezierPath *bezierPath = [layer bezierPathInBounds];
    MMLog(@"bezierPath: %lu", [bezierPath count]);
    CGRect rect = [layer bounds];

    NSBezierPath *fixedDirection;
    NSBezierPath *flipped = [bezierPath flipPoints];
    MMLog(@"flipped: %lu", [flipped count]);

    fixedDirection = [flipped antiClockwisePoints];
    MMLog(@"fixedDirection: %lu", [fixedDirection count]);

    id <MSShapePath> newPath = [NSClassFromString(@"MSShapePath") pathWithBezierPath:fixedDirection inRect:rect];
    MMLog(@"newPath before close: %llu", [newPath numberOfPoints]);

    //    if ([bezierPath isClosed] && [newPath numberOfPoints] > 4) {
    //        [newPath removeLastPoint];
    //    }
    [newPath setIsClosed:[bezierPath isClosed]];

    MMLog(@"newPath before: %llu", [newPath numberOfPoints]);
    [shape setPath:newPath];

    MMLog(@"newPath after: %llu", [[shape path] numberOfPoints]);

    layer.isFlippedHorizontal = ![layer isFlippedHorizontal];
    //[shape closeLastPath:[bezierPath isClosed]];
}

- (void)mirrorLayer:(id <MSShapeGroup>)layer fromArtboard:(id <MSArtboardGroup>)artboard scale:(CGFloat)scale {
    ImageRenderer *renderer = _imageRenderer;
    if (artboard) {
        renderer.layer = artboard;
        renderer.scale = scale;
        renderer.colorSpaceIdentifier = _colorSpaceIdentifier;
        renderer.disablePerspective = ! _perspective;
        renderer.bezierPath = [layer bezierPathInBounds];
        NSImage *image = renderer.exportedImage;
        [self fillLayer:layer withImage:image];
    }
}

- (void)refreshLayer:(id<MSShapeGroup>)layer {
    MMLayerProperties *original = [self layerPropertiesForLayer:layer];
    NSString *selectedName = original.source;
    id <MSArtboardGroup> artboard = [self artboardsLookup][selectedName];
    if ( ! selectedName) {
        [self clearLayer:layer];
    } else {
        NSInteger index = [original.imageQuality integerValue];
        CGFloat scale = 1;
        if (index < 3) {
            scale = MAX(1, index);
        } else {
            scale = CGSizeAspectFillRatio(artboard.rect.size, layer.rect.size) * 3;
        }
        [self mirrorLayer:layer fromArtboard:artboard scale:scale];
    }
    [self setVersion:_version];
}

- (void)rotateLayer:(id <MSShapeGroup>)layer {
    MSArray *array = [layer layers];
    MSShapePathLayer *shape = [array firstObject];
    id <MSShapePath> path = [shape path];
    id point = [path lastPoint];
    [path removeLastPoint];
    [path insertPoint:point atIndex:0];
}

- (void)setArtboard:(id<MSArtboardGroup>)artboard forLayer:(id<MSShapeGroup>)layer {
    if (artboard != nil) {
        [self setValue:[artboard name] forKey:@"source" onLayer:layer];
    }
    [self refreshLayer:layer];
}

- (void)setImageQuality:(NSNumber *)imageQuality forLayer:(id <MSShapeGroup>)layer {
    if (imageQuality != nil) {
        [self setValue:imageQuality forKey:@"imageQuality" onLayer:layer];
    }
    [self refreshLayer:layer];
}

#pragma - Other

- (void)jumpToArtboard:(NSString *)artboardName {
    id <MSArtboardGroup> artboard = _context.artboardsLookup[artboardName];

    if (artboard) {
        [_context.document setCurrentPage:artboard.parentPage];
        [[(MSContentDrawView *)_context.document currentView] zoomToFitRect:NSInsetRect(artboard.rect, -50, -50)];
    }
}

#pragma mark -

- (void)configureSelection {
    MMLog(@"configureSelection");
    [self showWindow];
}

- (NSArray *)artboards {
    return [_context artboards];
}

- (NSDictionary *)artboardsLookup {
    if ( ! _artboardsLookup) {
        _artboardsLookup = [_context artboardsLookup];
    }
    return _artboardsLookup;
}

- (NSArray *)selectedLayers {
    return [_context selectedLayers];
}

- (void)licenseInfo {
    NSLog(@"licenseInfo");
    [self showLicenseInfo];
}

#pragma mark Apply

- (void)setArtboard:(id<MSArtboardGroup>)artboard {
    __weak typeof (self) weakSelf = self;
    [self.selectedLayers enumerateObjectsUsingBlock:^(id <MSShapeGroup> _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [weakSelf setArtboard:artboard forLayer:obj];
        [obj setName:[artboard name]];
    }];
}

- (void)setImageQuality:(NSNumber *)imageQuality {
    __weak typeof (self) weakSelf = self;
    [self.selectedLayers enumerateObjectsUsingBlock:^(id <MSShapeGroup> _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [weakSelf setImageQuality:imageQuality forLayer:obj];
    }];
}

- (void)setClear {
    __weak typeof (self) weakSelf = self;
    [self.selectedLayers enumerateObjectsUsingBlock:^(id <MSShapeGroup> _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        MMLayerProperties *properties = [weakSelf layerPropertiesForLayer:obj];
        if (properties.source) {
            [weakSelf clearLayer:obj];
        }
    }];
}

// Entry Points

- (void)mirrorPage {
    MMLog(@"mirrorPage");
    _artboardsLookup = nil;

    __weak __typeof (self) weakSelf = self;
    [_context.selectedLayers enumerateObjectsUsingBlock:^(id <MSShapeGroup> _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [weakSelf refreshLayer:obj];
    }];
}

- (void)rotateSelection {
    MMLog(@"rotateSelection");
    _artboardsLookup = nil;

    __weak __typeof (self) weakSelf = self;
    [_context.selectedLayers enumerateObjectsUsingBlock:^(id <MSShapeGroup> _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [weakSelf rotateLayer:obj];
        [weakSelf refreshLayer:obj];
    }];
}

- (void)flipSelection {
    MMLog(@"flipSelection");

    __weak __typeof (self) weakSelf = self;
    [_context.selectedLayers enumerateObjectsUsingBlock:^(id <MSShapeGroup> _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [weakSelf flipLayer:obj];
        [weakSelf refreshLayer:obj];
    }];
}

- (void)jumpSelection {
    id <MSShapeGroup> layer = [[_context selectedLayers] firstObject];
    NSString *source = [self sourceForLayer:layer];
    [self jumpToArtboard:source];
}

@end


@implementation MagicMirror (MMWindowControllerDelegate)

- (void)controllerDidShow:(MMWindowController *)controller {

}

- (void)controllerDidClose:(MMWindowController *)controller {
    _controller = nil;
}

@end


@implementation MagicMirror (MSShapeGroup)

- (NSString *)sourceForLayer:(id <MSShapeGroup>)layer {
    MMLayerProperties *properties = [self layerPropertiesForLayer:layer];
    return properties.source;
}

- (void)setProperties:(MMLayerProperties *)properties forLayer:(id<MSShapeGroup>)layer {
    NSString *name = properties.source;
    [layer setName:name];
    [self setValue:properties.source forKey:@"source" onLayer:layer];
    if (properties.imageQuality) {
        [self setValue:properties.imageQuality forKey:@"imageQuality" onLayer:layer];
    }
}

- (MMLayerProperties *)layerPropertiesForLayer:(id<MSShapeGroup>)layer {
    NSString *source = [self valueForKey:@"source" onLayer:layer];
    NSString *version = [self valueForKey:@"version" onLayer:layer];
    if ([version hasPrefix:@"2"] && ( ! source || [source length] == 0)) {
        source = [layer name];
    }
    NSNumber *imageQuality = [self valueForKey:@"imageQuality" onLayer:layer];
    MMLayerProperties *properties = [MMLayerProperties propertiesWithImageQuality:imageQuality
                                                                           source:source
                                                                          version:version
                                     ];
    return properties;
}

@end

@implementation MagicMirror (API)

- (void)unlockLicense:(NSString *)license completion:(MMLicenseUnlockHandler)completion {

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:5000/verify/%@.json", license]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                 completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                                     NSError *parseError;

                                                                     id json = [NSJSONSerialization JSONObjectWithData:data
                                                                                                               options:0
                                                                                                                 error:&parseError];


                                                                     NSError *mapError;

                                                                     MMLicenseInfo *info = nil;

                                                                     if (json) {
                                                                         info = [MMLicenseInfo licenseInfoWithDictionary:json error:&mapError];
                                                                     }

                                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                                         NSError *anyError = error ?: parseError ?: mapError;
                                                                         if (info && ! anyError) {
                                                                             [self persistDictionary:[info toDictionary] withIdentifier:@"design.magicmirror.licensedto"];
                                                                         }
                                                                         completion(info, anyError);
                                                                     });
                                                                 }];

    [task resume];
    self.task = task;
}

- (MMLicenseInfo *)licensedTo {
    NSDictionary *dict = [self persistedDictionaryForIdentifier:@"design.magicmirror.licensedto"];
    return [MMLicenseInfo licenseInfoWithDictionary:dict error:nil];
}

- (void)deregister {
    [self removePersistedDictionaryForIdentifier:@"design.magicmirror.licensedto"];
}

- (BOOL)isRegistered {
    return [self licensedTo] != nil;
}

@end


@implementation MagicMirror (Persist)

- (void)removePersistedDictionaryForIdentifier:(NSString *)identifier {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:identifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDictionary *)persistedDictionaryForIdentifier:(NSString *)identifier {
    return [[NSUserDefaults standardUserDefaults] objectForKey:identifier];
}

- (void)persistDictionary:(NSDictionary *)dictionary withIdentifier:(NSString *)identifier {
    [[NSUserDefaults standardUserDefaults] setObject:dictionary
                                              forKey:identifier];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

