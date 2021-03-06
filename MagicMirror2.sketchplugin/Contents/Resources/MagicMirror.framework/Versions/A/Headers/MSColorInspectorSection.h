//
//     Generated by class-dump 3.5 (64 bit).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2013 by Steve Nygard.
//

#import "CHViewController.h"

#import "MSAssetPickerHeaderViewDelegate.h"
#import "MSPresetPickerViewDelegate.h"

@class MSAssetPickerView, NSArray, NSScrollView, NSString;

@interface MSColorInspectorSection : CHViewController <MSPresetPickerViewDelegate, MSAssetPickerHeaderViewDelegate>
{
    id <MSColorInspectorSectionDelegate> _delegate;
    NSArray *_styleParts;
    MSAssetPickerView *_globalPresetPicker;
    MSAssetPickerView *_documentPresetPicker;
    NSScrollView *_globalPresetPickerScrollView;
    NSScrollView *_documentPresetPickerScrollView;
}

+ (void)initialize;

- (void)addAsset:(id)arg1 forPickerView:(id)arg2;
- (void)addPresetForPickerView:(id)arg1;
- (id)assetAtIndex:(unsigned long long)arg1 forPickerView:(id)arg2;
- (id)assetCollectionForPresetPicker:(id)arg1;
- (void)assetHeaderViewDidClick:(id)arg1;
- (id)assetPickerViewKeys;
- (id)assetPickerViews;
- (unsigned long long)assetType;
- (void)colorPickerChangedTo:(id)arg1;
- (void)dealloc;
@property(nonatomic) __weak id <MSColorInspectorSectionDelegate> delegate; // @synthesize delegate=_delegate;
@property(retain, nonatomic) MSAssetPickerView *documentPresetPicker; // @synthesize documentPresetPicker=_documentPresetPicker;
@property(retain, nonatomic) NSScrollView *documentPresetPickerScrollView; // @synthesize documentPresetPickerScrollView=_documentPresetPickerScrollView;
- (void)drawContentForCellInPickerView:(id)arg1 atIndex:(unsigned long long)arg2 inRect:(struct CGRect)arg3;
- (long long)fillType;
@property(retain, nonatomic) MSAssetPickerView *globalPresetPicker; // @synthesize globalPresetPicker=_globalPresetPicker;
@property(retain, nonatomic) NSScrollView *globalPresetPickerScrollView; // @synthesize globalPresetPickerScrollView=_globalPresetPickerScrollView;
- (BOOL)hasPresetPickers;
- (id)indexesOfAsset:(id)arg1 forPickerView:(id)arg2;
- (id)initWithDelegate:(id)arg1;
- (void)insertAsset:(id)arg1 atIndex:(unsigned long long)arg2 forPickerView:(id)arg3;
- (BOOL)isEnabled;
- (BOOL)moveAssetAtIndex:(unsigned long long)arg1 beforeObjectAtIndex:(unsigned long long)arg2 ForPickerView:(id)arg3;
- (unsigned long long)numberOfAssetsForPickerView:(id)arg1;
- (unsigned long long)numberOfPresetsInPickerView:(id)arg1;
- (BOOL)pickerView:(id)arg1 didDragPresetAtIndex:(unsigned long long)arg2 toIndex:(unsigned long long)arg3;
- (void)pickerView:(id)arg1 didPickPresetAtIndex:(unsigned long long)arg2;
- (void)pickerView:(id)arg1 removePresetAtIndex:(unsigned long long)arg2;
- (BOOL)pickerViewSupportsDrag:(id)arg1 fromIndex:(unsigned long long)arg2;
- (BOOL)pickerViewSupportsDrop:(id)arg1;
- (void)popoverWillClose;
- (void)refreshAction:(id)arg1;
- (void)reloadPresetPicker;
- (void)reloadPresetPicker:(id)arg1;
- (void)removeAssetAtIndex:(unsigned long long)arg1 forPickerView:(id)arg2;
@property(copy, nonatomic) NSArray *styleParts; // @synthesize styleParts=_styleParts;
- (BOOL)shouldShowAddPresetButton:(id)arg1;
- (void)undoNotification:(id)arg1;
- (void)validate;
- (id)viewsWithColorPickerView:(id)arg1 blendingView:(id)arg2;
- (id)wrapPickerInScrollView:(id)arg1;

// Remaining properties
@property(readonly, copy) NSString *debugDescription;
@property(readonly, copy) NSString *description;
@property(readonly) unsigned long long hash;
@property(readonly) Class superclass;

@end

