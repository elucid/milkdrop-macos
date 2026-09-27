#pragma once
#import <AppKit/AppKit.h>
#import "PresetLibrary.h"

@interface MDPresetBrowser : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic) MDPresetLibrary* library;
@property(nonatomic, copy) NSString* currentPath;
@property(nonatomic, copy) void (^choosePreset)(MDPreset*);
- (void)refresh;
@end
