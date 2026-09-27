#pragma once
#import <Foundation/Foundation.h>

@interface MDPreset : NSObject
@property(nonatomic, readonly, copy) NSString* path;
@property(nonatomic, readonly, copy) NSString* name;
@property(nonatomic, readonly, copy) NSString* category;
@property(nonatomic, readonly, copy) NSString* searchText;
- (instancetype)initWithPath:(NSString*)path root:(NSString*)root;
@end

@interface MDPresetLibrary : NSObject
@property(nonatomic, readonly, copy) NSString* root;
@property(nonatomic, readonly, copy) NSArray<MDPreset*>* presets;
+ (instancetype)scanFolder:(NSString*)folder error:(NSError**)error;
- (NSArray<MDPreset*>*)matchingQuery:(NSString*)query;
@end

NSString* MDAssetRoot(void);
NSString* MDInstalledCollection(void);
NSArray<NSString*>* MDTexturePaths(NSString* preset, NSString* collectionRoot, NSString* customTextures);
