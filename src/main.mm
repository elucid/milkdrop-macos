#import "VisualizerView.h"
#import "PresetLibrary.h"
#import "PresetBrowser.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include "ShuffleBag.hpp"
#include <cstdio>

static NSString* smokeOutput;
static NSString* initialPreset;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate> {
    ShuffleBag shuffle_;
    NSTimeInterval deadline_;
    NSUInteger scanGeneration_;
    BOOL scanning_;
}
@property NSWindow* window;
@property VisualizerView* visualizer;
@property NSTextField* status;
@property NSTextField* libraryStatus;
@property NSButton* autoButton;
@property NSPopUpButton* intervalButton;
@property NSTimer* playbackTimer;
@property MDPresetLibrary* library;
@property MDPresetBrowser* browser;
@property NSUInteger presetIndex;
@property NSMutableSet<NSString*>* failedPresets;
@property BOOL automatic;
@property NSInteger interval;
- (void)nextPreset:(id)sender;
- (BOOL)selectIndex:(NSUInteger)index manual:(BOOL)manual;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{@"ShuffleEnabled":@YES, @"ShuffleInterval":@30}];
    self.automatic = !smokeOutput && !initialPreset && [NSUserDefaults.standardUserDefaults boolForKey:@"ShuffleEnabled"];
    self.interval = [NSUserDefaults.standardUserDefaults integerForKey:@"ShuffleInterval"];
    if (![@[@10,@15,@30,@60,@120] containsObject:@(self.interval)]) self.interval = 30;
    self.failedPresets = [NSMutableSet new];
    self.presetIndex = NSNotFound;
    NSString* demos = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"presets"];
    self.library = [MDPresetLibrary scanFolder:demos error:nil];
    shuffle_.reset(self.library.presets.count);

    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1100, 740) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"MilkDrop macOS";
    self.window.minSize = NSMakeSize(880, 420);
    self.window.delegate = self;
    self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    NSView* content = self.window.contentView;
    self.visualizer = [[VisualizerView alloc] initWithFrame:NSMakeRect(0, 76, 1100, 664)];
    if (!self.visualizer) { fprintf(stderr, "No OpenGL 4.1 pixel format available\n"); std::exit(1); }
    self.visualizer.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    self.visualizer.presetPath = initialPreset ?: self.library.presets.firstObject.path;
    self.visualizer.collectionRoot = demos;
    self.visualizer.smokeOutput = smokeOutput;
    self.visualizer.customTexturePath = [NSUserDefaults.standardUserDefaults stringForKey:@"TextureFolder"];
    __weak AppDelegate* weakSelf = self;
    self.visualizer.report = ^(NSString* text) { weakSelf.status.stringValue = text; };
    [content addSubview:self.visualizer];

    self.status = [NSTextField labelWithString:@"Starting renderer…"];
    self.status.frame = NSMakeRect(16, 47, 1068, 19);
    self.status.autoresizingMask = NSViewWidthSizable;
    self.status.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [content addSubview:self.status];
    NSButton* folder = [NSButton buttonWithTitle:@"Browse Presets…" target:self action:@selector(showBrowser:)];
    NSButton* next = [NSButton buttonWithTitle:@"Shuffle now →" target:self action:@selector(nextPreset:)];
    self.autoButton = [NSButton checkboxWithTitle:@"Auto shuffle" target:self action:@selector(toggleAutomatic:)];
    self.autoButton.state = self.automatic ? NSControlStateValueOn : NSControlStateValueOff;
    self.intervalButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    for (NSNumber* seconds in @[@10,@15,@30,@60,@120]) {
        [self.intervalButton addItemWithTitle:[NSString stringWithFormat:@"%@ seconds", seconds]];
        self.intervalButton.lastItem.tag = seconds.integerValue;
    }
    [self.intervalButton selectItemWithTag:self.interval];
    self.intervalButton.target = self; self.intervalButton.action = @selector(changeInterval:);
    NSButton* audio = [NSButton buttonWithTitle:@"Demo / System Audio" target:self action:@selector(toggleAudio:)];
    self.libraryStatus = [NSTextField labelWithString:@""];
    self.libraryStatus.textColor = NSColor.secondaryLabelColor;
    self.libraryStatus.lineBreakMode = NSLineBreakByTruncatingTail;
    NSStackView* controls = [NSStackView stackViewWithViews:@[folder,next,self.autoButton,self.intervalButton,audio,self.libraryStatus]];
    controls.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    controls.spacing = 12;
    controls.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:controls];
    [NSLayoutConstraint activateConstraints:@[
        [controls.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:12],
        [controls.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-12],
        [controls.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-10],
        [controls.heightAnchor constraintEqualToConstant:28]]];
    [self.libraryStatus setContentCompressionResistancePriority:200 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [self createMenus];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self updateLibraryStatus];
    if (smokeOutput) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            fprintf(stderr, "FAIL: render smoke test timed out\n"); std::exit(1);
        });
        return;
    }
    self.playbackTimer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer*) { [weakSelf tick]; }];
    [[NSRunLoop mainRunLoop] addTimer:self.playbackTimer forMode:NSRunLoopCommonModes];
    if (!initialPreset) {
        NSString* folder = [NSUserDefaults.standardUserDefaults stringForKey:@"PresetFolder"];
        BOOL exists = NO;
        if (!folder.length || ![NSFileManager.defaultManager fileExistsAtPath:folder isDirectory:&exists] || !exists) folder = MDInstalledCollection();
        if (![NSFileManager.defaultManager fileExistsAtPath:folder]) folder = demos;
        [self loadLibrary:folder remember:NO];
    }
}
- (void)createMenus {
    NSMenu* bar = [NSMenu new];
    NSMenuItem* app = [NSMenuItem new];
    NSMenu* appMenu = [NSMenu new];
    [appMenu addItemWithTitle:@"Quit MilkDrop macOS" action:@selector(terminate:) keyEquivalent:@"q"];
    app.submenu = appMenu; [bar addItem:app];
    NSMenuItem* edit = [NSMenuItem new];
    NSMenu* editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    edit.submenu = editMenu; [bar addItem:edit];
    NSMenuItem* file = [NSMenuItem new];
    NSMenu* fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    for (NSArray* entry in @[
        @[@"Browse Presets…",@"showBrowser:",@"b"],
        @[@"Open Preset…",@"openPreset:",@"o"],
        @[@"Open Preset Folder…",@"openPresetFolder:",@"O"],
        @[@"Use Cream of the Crop",@"useInstalledCollection:",@""],
        @[@"Choose Shared Texture Folder…",@"chooseTextures:",@""]]) {
        NSMenuItem* item = [fileMenu addItemWithTitle:entry[0] action:NSSelectorFromString(entry[1]) keyEquivalent:entry[2]];
        item.target = self;
    }
    file.submenu = fileMenu; [bar addItem:file];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];
    NSMenuItem* playback = [NSMenuItem new];
    NSMenu* playbackMenu = [[NSMenu alloc] initWithTitle:@"Playback"];
    NSMenuItem* next = [playbackMenu addItemWithTitle:@"Shuffle Now" action:@selector(nextPreset:) keyEquivalent:@"n"]; next.target = self;
    NSMenuItem* automatic = [playbackMenu addItemWithTitle:@"Auto Shuffle" action:@selector(toggleAutomatic:) keyEquivalent:@"s"]; automatic.target = self;
    playback.submenu = playbackMenu; [bar addItem:playback];
    NSMenuItem* audio = [NSMenuItem new];
    NSMenu* audioMenu = [[NSMenu alloc] initWithTitle:@"Audio"];
    NSMenuItem* toggle = [audioMenu addItemWithTitle:@"Switch Demo / System Audio" action:@selector(toggleAudio:) keyEquivalent:@"a"]; toggle.target = self;
    toggle.keyEquivalentModifierMask = NSEventModifierFlagCommand|NSEventModifierFlagOption;
    audio.submenu = audioMenu; [bar addItem:audio];
    NSMenuItem* view = [NSMenuItem new];
    NSMenu* viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    NSMenuItem* fullscreen = [viewMenu addItemWithTitle:@"Toggle Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
    fullscreen.keyEquivalentModifierMask = NSEventModifierFlagControl|NSEventModifierFlagCommand;
    view.submenu = viewMenu; [bar addItem:view];
    NSApp.mainMenu = bar;
}
- (BOOL)validateMenuItem:(NSMenuItem*)item {
    if (item.action == @selector(toggleAutomatic:)) item.state = self.automatic ? NSControlStateValueOn : NSControlStateValueOff;
    if (item.action == @selector(nextPreset:)) return !scanning_ && self.library.presets.count > 0;
    return YES;
}
- (void)updateLibraryStatus {
    if (scanning_) { self.libraryStatus.stringValue = @"Loading collection…"; return; }
    NSString* count = [NSNumberFormatter localizedStringFromNumber:@(self.library.presets.count) numberStyle:NSNumberFormatterDecimalStyle];
    NSString* playback = @"paused";
    if (self.automatic && self.library.presets.count > 1) {
        NSInteger seconds = MAX(0, (NSInteger)ceil(deadline_ - NSProcessInfo.processInfo.systemUptime));
        playback = [NSString stringWithFormat:@"next in %lds", (long)seconds];
    }
    self.libraryStatus.stringValue = [NSString stringWithFormat:@"%@ presets · %@", count, playback];
    self.libraryStatus.toolTip = self.library.root;
}
- (void)restartInterval {
    deadline_ = NSProcessInfo.processInfo.systemUptime + self.interval;
    [self updateLibraryStatus];
}
- (void)tick {
    if (scanning_) return;
    if (self.window.miniaturized || self.window.attachedSheet || self.browser.window.isKeyWindow) { [self restartInterval]; return; }
    if (self.automatic && self.library.presets.count > 1 && NSProcessInfo.processInfo.systemUptime >= deadline_) [self nextPreset:nil];
    [self updateLibraryStatus];
}
- (void)toggleAutomatic:(id)sender {
    self.automatic = !self.automatic;
    self.autoButton.state = self.automatic ? NSControlStateValueOn : NSControlStateValueOff;
    [NSUserDefaults.standardUserDefaults setBool:self.automatic forKey:@"ShuffleEnabled"];
    [self restartInterval];
}
- (void)changeInterval:(id)sender {
    self.interval = self.intervalButton.selectedItem.tag;
    [NSUserDefaults.standardUserDefaults setInteger:self.interval forKey:@"ShuffleInterval"];
    [self restartInterval];
}
- (BOOL)selectIndex:(NSUInteger)index manual:(BOOL)manual {
    if (index >= self.library.presets.count) return NO;
    MDPreset* preset = self.library.presets[index];
    if (![self.visualizer loadPreset:preset.path smooth:self.presetIndex != NSNotFound]) {
        [self.failedPresets addObject:preset.path];
        return NO;
    }
    self.presetIndex = index;
    self.browser.currentPath = preset.path;
    if (manual) shuffle_.reset(self.library.presets.count, index);
    [self restartInterval];
    return YES;
}
- (void)nextPreset:(id)sender {
    if (scanning_ || !self.library.presets.count) return;
    NSUInteger attempts = 0;
    for (NSUInteger visited = 0; visited < self.library.presets.count; ++visited) {
        auto current = self.presetIndex == NSNotFound ? std::optional<std::size_t>{} : std::optional<std::size_t>{self.presetIndex};
        auto index = shuffle_.next(current);
        if (!index) return;
        if ([self.failedPresets containsObject:self.library.presets[*index].path]) continue;
        if ([self selectIndex:*index manual:NO]) return;
        if (++attempts == 8) break; // Avoid blocking the UI on a run of bad shaders.
    }
    self.automatic = NO;
    self.autoButton.state = NSControlStateValueOff;
    self.status.stringValue = @"Shuffle paused after preset load errors. Choose another collection or preset.";
    [self updateLibraryStatus];
}
- (void)loadLibrary:(NSString*)folder remember:(BOOL)remember {
    const NSUInteger generation = ++scanGeneration_;
    scanning_ = YES;
    [self updateLibraryStatus];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError* error = nil;
        MDPresetLibrary* library = [MDPresetLibrary scanFolder:folder error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self->scanGeneration_) return;
            self->scanning_ = NO;
            if (!library.presets.count) {
                NSAlert* alert = [NSAlert new];
                alert.messageText = @"No .milk presets found";
                alert.informativeText = error.localizedDescription ?: @"Choose a folder of classic .milk presets. To install Cream of the Crop, run scripts/install-assets.sh from the project folder.";
                [alert beginSheetModalForWindow:self.window completionHandler:nil];
                [self restartInterval];
                return;
            }
            self.library = library;
            self.visualizer.collectionRoot = library.root;
            self.presetIndex = NSNotFound;
            [self.failedPresets removeAllObjects];
            self->shuffle_.reset(library.presets.count);
            if (remember) [NSUserDefaults.standardUserDefaults setObject:folder forKey:@"PresetFolder"];
            [self nextPreset:nil];
            self.browser.library = library;
            [self.browser refresh];
            if (error) self.status.stringValue = [@"Some folders could not be read: " stringByAppendingString:error.localizedDescription];
        });
    });
}
- (void)showBrowser:(id)sender {
    if (!self.browser) {
        self.browser = [MDPresetBrowser new];
        __weak AppDelegate* weakSelf = self;
        self.browser.choosePreset = ^(MDPreset* preset) {
            AppDelegate* owner = weakSelf;
            NSUInteger index = [owner.library.presets indexOfObjectIdenticalTo:preset];
            if (index != NSNotFound) [owner selectIndex:index manual:YES];
        };
    }
    self.browser.library = self.library;
    self.browser.currentPath = self.visualizer.presetPath;
    [self.browser showWindow:sender];
}
- (void)windowWillClose:(NSNotification*)notification {
    if (notification.object == self.window) [NSApp terminate:nil];
}
- (void)toggleAudio:(id)sender { [self.visualizer toggleAudio]; }
- (void)openPreset:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"milk"]];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK) return;
        for (NSUInteger i = 0; i < self.library.presets.count; ++i) {
            if ([self.library.presets[i].path isEqualToString:panel.URL.path]) { [self selectIndex:i manual:YES]; return; }
        }
        [self.visualizer loadPreset:panel.URL.path smooth:YES];
        self.presetIndex = NSNotFound;
        [self restartInterval];
    }];
}
- (void)openPresetFolder:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO; panel.canChooseDirectories = YES;
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSModalResponseOK) [self loadLibrary:panel.URL.path remember:YES];
    }];
}
- (void)useInstalledCollection:(id)sender { [self loadLibrary:MDInstalledCollection() remember:YES]; }
- (void)chooseTextures:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO; panel.canChooseDirectories = YES;
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK) return;
        self.visualizer.customTexturePath = panel.URL.path;
        [NSUserDefaults.standardUserDefaults setObject:panel.URL.path forKey:@"TextureFolder"];
        [self.visualizer loadPreset:self.visualizer.presetPath smooth:NO];
        [self restartInterval];
    }];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender { return YES; }
- (void)applicationWillTerminate:(NSNotification*)notification {
    [self.playbackTimer invalidate];
    ++scanGeneration_;
    [self.visualizer shutdown];
}
@end

int main(int argc, const char* argv[]) {
    @autoreleasepool {
        for (int i = 1; i < argc; ++i) {
            if (strcmp(argv[i], "--smoke-test") == 0 && i+1 < argc) smokeOutput = [NSString stringWithUTF8String:argv[++i]];
            else if (strcmp(argv[i], "--preset") == 0 && i+1 < argc) initialPreset = [NSString stringWithUTF8String:argv[++i]];
            else { fprintf(stderr, "Usage: MilkDropMac [--preset file.milk] [--smoke-test screenshot.png]\n"); return 2; }
        }
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        AppDelegate* delegate = [AppDelegate new];
        NSApp.delegate = delegate;
        [NSApp run];
    }
    return 0;
}
