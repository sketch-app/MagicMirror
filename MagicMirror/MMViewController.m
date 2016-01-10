//
//  MMViewController.m
//  MagicMirror2
//
//  Created by James Tang on 21/12/2015.
//  Copyright © 2015 James Tang. All rights reserved.
//

#import "MMViewController.h"
#import "SketchEventsController.h"

@interface MMViewController ()

@property (nonatomic, strong) id comboboxObserver;

@end

@implementation MMViewController
@synthesize magicmirror = _magicmirror;

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    [MagicMirror addObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self reloadData];
}

- (void)dealloc {
    self.shouldObserveCombobox = NO;
}

- (MagicMirror *)magicmirror {
    return _magicmirror;
}

- (void)setMagicmirror:(MagicMirror *)magicmirror {
    if (_magicmirror != magicmirror) {
        _magicmirror = magicmirror;
        [self reloadData];
    }
}

- (void)reloadData {
}

#pragma - Close

- (IBAction)closeButtonDidPress:(id)sender {
    [self close];
}

- (void)close {
    [self.view.window.windowController close];
}

#pragma - ComboBox

- (void)setShouldObserveCombobox:(BOOL)shouldObserveCombobox {
    if (_shouldObserveCombobox != shouldObserveCombobox) {
        if (shouldObserveCombobox) {
            [self observeComboBox];
        } else {
            [self unobserveCombobox];
        }
        _shouldObserveCombobox = shouldObserveCombobox;
    }
}

- (void)observeComboBox {
    __weak __typeof (self) weakSelf = self;
    self.comboboxObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSComboBoxSelectionDidChangeNotification
                                                                              object:nil
                                                                               queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {

                                                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                                                       [weakSelf comboBoxValueDidChange:note.object];
                                                                                   });
                                                                               }];
}

- (void)unobserveCombobox {
    [[NSNotificationCenter defaultCenter] removeObserver:self.comboboxObserver];
}

- (void)comboBoxValueDidChange:(NSComboBox *)sender {
}

@end