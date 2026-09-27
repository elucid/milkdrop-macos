#import "PresetLibrary.h"
#include "ShuffleBag.hpp"
#include <set>
#include <cstdio>
#include <cstdlib>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); std::exit(1); } } while (0)

int main() {
    @autoreleasepool {
        ShuffleBag bag(42);
        CHECK(!bag.next());
        bag.reset(1, 0); CHECK(bag.next(0) == 0);
        bag.reset(100, 17);
        std::set<std::size_t> visited{17};
        std::size_t last = 17;
        for (int i=0;i<99;++i) { auto next=bag.next(last); CHECK(next && *next != last); CHECK(visited.insert(*next).second); last=*next; }
        CHECK(visited.size()==100);
        visited.clear();
        for (int i=0;i<100;++i) { auto next=bag.next(last); CHECK(next && *next != last); CHECK(visited.insert(*next).second); last=*next; }
        bag.reset(2,1); CHECK(bag.next(1)==0); CHECK(bag.next(0)==1);
        bag.reset(0); CHECK(!bag.next());

        NSString* root = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        NSFileManager* fm=NSFileManager.defaultManager;
        for (NSString* name in @[@"Fractal",@".hidden",@"textures",@"Other"]) [fm createDirectoryAtPath:[root stringByAppendingPathComponent:name] withIntermediateDirectories:YES attributes:nil error:nil];
        for (NSString* name in @[@"Fractal/Martín - Blue Ocean.MILK",@"Other/Blue Sun.milk",@".hidden/Hidden.milk",@"Not Supported.milk2"]) [@"[preset00]\n" writeToFile:[root stringByAppendingPathComponent:name] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        NSError* error=nil;
        MDPresetLibrary* library=[MDPresetLibrary scanFolder:root error:&error];
        CHECK(library && !error && library.presets.count==2);
        CHECK([library matchingQuery:@"  BLUE  "].count==2);

        CHECK([library matchingQuery:@"martin fractal"].count==1);
        CHECK([library matchingQuery:@"ocean sun"].count==0);
        CHECK([library matchingQuery:@""].count==2);
        NSArray* paths=MDTexturePaths(library.presets[0].path,root,[root stringByAppendingPathComponent:@"textures"]);
        CHECK([paths containsObject:[library.root stringByAppendingPathComponent:@"textures"]]);
        CHECK([NSSet setWithArray:paths].count==paths.count);
        CHECK([paths.firstObject isEqualToString:library.presets[0].path.stringByDeletingLastPathComponent]);
        [fm removeItemAtPath:root error:nil];
        CHECK(![MDPresetLibrary scanFolder:root error:&error] && error);
        puts("PASS: no-repeat shuffle cycles, recursive scanning, multiword/diacritic search, texture paths and missing folders");
    }
}
