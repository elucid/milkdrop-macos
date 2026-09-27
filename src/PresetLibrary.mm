#import "PresetLibrary.h"
#include <cstdlib>

static NSString* physicalPath(NSString* path) {
    char* resolved = realpath(path.fileSystemRepresentation, nullptr);
    NSString* result = resolved ? [NSFileManager.defaultManager stringWithFileSystemRepresentation:resolved length:strlen(resolved)] : path.stringByStandardizingPath;
    free(resolved);
    return result;
}

static NSString* searchKey(NSString* text) {
    return [text stringByFoldingWithOptions:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
}

@implementation MDPreset
- (instancetype)initWithPath:(NSString*)path root:(NSString*)root {
    self = [super init];
    if (self) {
        _path = [path copy];
        _name = path.lastPathComponent.stringByDeletingPathExtension;
        NSString* prefix = [root stringByAppendingString:@"/"];
        NSString* relative = [path hasPrefix:prefix] ? [path substringFromIndex:prefix.length] : path.lastPathComponent;
        _category = relative.stringByDeletingLastPathComponent;
        _searchText = searchKey([NSString stringWithFormat:@"%@ %@", _name, _category]);
    }
    return self;
}
@end

@implementation MDPresetLibrary
+ (instancetype)scanFolder:(NSString*)folder error:(NSError**)error {
    BOOL directory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:folder isDirectory:&directory] || !directory) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoSuchFileError userInfo:@{NSLocalizedDescriptionKey:@"The preset folder is unavailable."}];
        return nil;
    }
    MDPresetLibrary* library = [MDPresetLibrary new];
    library->_root = physicalPath(folder);
    NSMutableArray<MDPreset*>* presets = [NSMutableArray new];
    __block NSError* scanError = nil;
    NSDirectoryEnumerator* files = [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:library.root] includingPropertiesForKeys:@[NSURLIsRegularFileKey] options:NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsPackageDescendants errorHandler:^BOOL(NSURL*, NSError* failure) {
        if (!scanError) scanError = failure;
        return YES;
    }];
    for (NSURL* url in files) {
        if (![url.pathExtension.lowercaseString isEqualToString:@"milk"]) continue;
        NSNumber* regular = nil;
        [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
        if (regular.boolValue) [presets addObject:[[MDPreset alloc] initWithPath:url.path root:library.root]];
    }
    [presets sortUsingComparator:^NSComparisonResult(MDPreset* a, MDPreset* b) { return [a.path localizedStandardCompare:b.path]; }];
    library->_presets = [presets copy];
    if (scanError && error) *error = scanError;
    return library;
}
- (NSArray<MDPreset*>*)matchingQuery:(NSString*)query {
    NSArray<NSString*>* words = [searchKey(query) componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray<MDPreset*>* result = [NSMutableArray new];
    for (MDPreset* preset in self.presets) {
        BOOL matches = YES;
        for (NSString* word in words) if (word.length && ![preset.searchText containsString:word]) { matches = NO; break; }
        if (matches) [result addObject:preset];
    }
    return result;
}
@end

NSString* MDAssetRoot(void) {
    NSString* override = NSProcessInfo.processInfo.environment[@"MILKDROP_ASSET_DIR"];
    if (override.length) return override.stringByExpandingTildeInPath.stringByStandardizingPath;
    NSString* support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    return [support stringByAppendingPathComponent:@"MilkDrop macOS"];
}
NSString* MDInstalledCollection(void) { return [MDAssetRoot() stringByAppendingPathComponent:@"Collections/Cream of the Crop"]; }

NSArray<NSString*>* MDTexturePaths(NSString* preset, NSString* collectionRoot, NSString* customTextures) {
    NSString* local = preset.stringByDeletingLastPathComponent;
    NSArray* candidates = @[local ?: @"", [local stringByAppendingPathComponent:@"textures"] ?: @"",
        collectionRoot.length ? [collectionRoot stringByAppendingPathComponent:@"textures"] : @"",
        customTextures ?: @"", [MDAssetRoot() stringByAppendingPathComponent:@"Textures/MilkDrop"]];
    NSMutableOrderedSet<NSString*>* paths = [NSMutableOrderedSet new];
    for (NSString* candidate in candidates) {
        BOOL directory = NO;
        if (candidate.length && [NSFileManager.defaultManager fileExistsAtPath:candidate isDirectory:&directory] && directory)
            [paths addObject:physicalPath(candidate)];
    }
    return paths.array;
}
