#import <AppKit/AppKit.h>
#import <OpenGL/gl3.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <projectM-4/projectM.h>
#include "SyntheticAudio.hpp"
#include "AudioCapture.hpp"
#include <algorithm>
#include <cstdio>
#include <exception>
#include <vector>

static NSString* smokeOutput;
static NSString* initialPreset;
static BOOL smokeFailed = NO;

@interface VisualizerView : NSOpenGLView {
    projectm_handle renderer_;
    SyntheticAudio synth_;
    NSTimer* timer_;
    NSUInteger frame_;
    std::vector<unsigned char> previousPixels_;
    AudioCapture capture_;
    BOOL presetFailed_;
}
@property(nonatomic, copy) NSString* presetPath;
@property(nonatomic, copy) void (^report)(NSString*);
- (void)loadPreset:(NSString*)path;
- (void)shutdown;
- (void)toggleAudio;
- (void)updateAudioStatus;
- (void)markPresetFailed;
@end

static void presetFailure(const char* file, const char* message, void* context) {
    VisualizerView* view = (__bridge VisualizerView*)context;
    NSString* error = [NSString stringWithFormat:@"Preset failed: %s", message ?: "unknown error"];
    fprintf(stderr, "%s: %s\n", file ?: "preset", error.UTF8String);
    smokeFailed = YES;
    [view markPresetFailed];
    if (view.report) view.report(error);
}

@implementation VisualizerView
- (void)markPresetFailed { presetFailed_ = YES; }
- (void)updateAudioStatus {
    if (presetFailed_) return;
    NSString* preset = self.presetPath.lastPathComponent.stringByDeletingPathExtension ?: @"No preset";
    NSString* source = @"Demo audio";
    if (capture_.running()) {
        float peak = capture_.takePeak();
        source = capture_.received() == 0 ? @"Waiting for system audio — check recording permission" :
            [NSString stringWithFormat:@"System audio · %.0f kHz · level %.0f%%", capture_.sampleRate()/1000, peak*100];
    }
    if (self.report) self.report([NSString stringWithFormat:@"%@ · %@", source, preset]);
}
- (void)toggleAudio {
    if (capture_.running()) {
        capture_.stop();
    } else {
        std::string error = capture_.start();
        if (!error.empty()) {
            NSAlert* alert = [NSAlert new];
            alert.messageText = @"System audio could not start";
            alert.informativeText = [NSString stringWithUTF8String:error.c_str()];
            [alert beginSheetModalForWindow:self.window completionHandler:nil];
        }
    }
    [self updateAudioStatus];
}
- (instancetype)initWithFrame:(NSRect)frame {
    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core,
        NSOpenGLPFAColorSize, 24, NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADoubleBuffer, NSOpenGLPFAAccelerated, 0
    };
    NSOpenGLPixelFormat* format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    if (!format) return nil;
    self = [super initWithFrame:frame pixelFormat:format];
    if (self) self.wantsBestResolutionOpenGLSurface = YES;
    return self;
}
- (void)prepareOpenGL {
    [super prepareOpenGL];
    [self.openGLContext makeCurrentContext];
    GLint swap = 1;
    [self.openGLContext setValues:&swap forParameter:NSOpenGLContextParameterSwapInterval];
    try { renderer_ = projectm_create(); }
    catch (const std::exception& error) { fprintf(stderr, "projectM: %s\n", error.what()); }
    if (!renderer_) {
        if (self.report) self.report(@"Could not initialize the OpenGL renderer.");
        if (smokeOutput) std::exit(1);
        return;
    }
    fprintf(stderr, "OpenGL: %s | %s\n", glGetString(GL_VERSION), glGetString(GL_RENDERER));
    projectm_set_preset_locked(renderer_, true);
    projectm_set_fps(renderer_, 60);
    projectm_set_mesh_size(renderer_, 64, 48);
    projectm_set_preset_switch_failed_event_callback(renderer_, presetFailure, (__bridge void*)self);
    [self reshape];
    [self loadPreset:self.presetPath];
    __weak VisualizerView* weakSelf = self;
    timer_ = [NSTimer timerWithTimeInterval:1.0/60 repeats:YES block:^(NSTimer*) {
        [weakSelf setNeedsDisplay:YES];
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer_ forMode:NSRunLoopCommonModes];
}
- (void)reshape {
    [super reshape];
    [self.openGLContext makeCurrentContext];
    NSRect pixels = [self convertRectToBacking:self.bounds];
    if (renderer_) projectm_set_window_size(renderer_, std::max(1, (int)pixels.size.width), std::max(1, (int)pixels.size.height));
}
- (void)loadPreset:(NSString*)path {
    self.presetPath = path;
    if (!renderer_ || !path) return;
    [self.openGLContext makeCurrentContext];
    NSString* directory = path.stringByDeletingLastPathComponent;
    NSString* textures = [directory stringByAppendingPathComponent:@"textures"];
    const char* paths[] = {directory.fileSystemRepresentation, textures.fileSystemRepresentation};
    projectm_set_texture_search_paths(renderer_, paths, 2);
    projectm_reset_textures(renderer_);
    smokeFailed = NO;
    presetFailed_ = NO;
    try { projectm_load_preset_file(renderer_, path.fileSystemRepresentation, false); }
    catch (const std::exception& error) { presetFailure(path.UTF8String, error.what(), (__bridge void*)self); }
    if (!smokeFailed) [self updateAudioStatus];
}
- (std::vector<unsigned char>)readPixels {
    NSRect bounds = [self convertRectToBacking:self.bounds];
    int width = (int)bounds.size.width, height = (int)bounds.size.height;
    std::vector<unsigned char> pixels((size_t)width * height * 4);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
    glReadBuffer(GL_BACK);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());
    return pixels;
}
- (void)finishSmokeTest {
    auto pixels = [self readPixels];
    size_t lit = 0, changed = 0;
    for (size_t i = 0; i < pixels.size(); i += 4) {
        if (std::max({pixels[i], pixels[i+1], pixels[i+2]}) > 12) ++lit;
        if (previousPixels_.size() == pixels.size() &&
            (pixels[i] != previousPixels_[i] || pixels[i+1] != previousPixels_[i+1] || pixels[i+2] != previousPixels_[i+2])) ++changed;
    }
    NSRect bounds = [self convertRectToBacking:self.bounds];
    NSInteger w = (NSInteger)bounds.size.width, h = (NSInteger)bounds.size.height;
    NSBitmapImageRep* bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nullptr pixelsWide:w pixelsHigh:h bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:w*4 bitsPerPixel:32];
    for (NSInteger row = 0; row < h; ++row) memcpy(bitmap.bitmapData + row*w*4, pixels.data() + (h-row-1)*w*4, (size_t)w*4);
    BOOL written = [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:smokeOutput atomically:YES];
    GLenum error = glGetError();
    bool ok = !smokeFailed && written && lit > pixels.size()/400 && changed > pixels.size()/400 && error == GL_NO_ERROR;
    fprintf(stderr, "%s: %ldx%ld, %zu lit pixels, %zu changed pixels, GL error=%u, screenshot=%s\n", ok ? "PASS" : "FAIL", (long)w, (long)h, lit, changed, error, smokeOutput.fileSystemRepresentation);
    [self shutdown];
    std::exit(ok ? 0 : 1);
}
- (void)drawRect:(NSRect)dirtyRect {
    if (!renderer_) return;
    [self.openGLContext makeCurrentContext];
    float audio[1024*2]{};
    if (capture_.running()) {
        bool received = false;
        // Bound the work even if audio arrives faster than rendering.
        for (int block = 0; block < 8; ++block) {
            auto count = capture_.read(audio, std::min(1024u, projectm_pcm_get_max_samples()));
            if (!count) break;
            projectm_pcm_add_float(renderer_, audio, (unsigned)count, PROJECTM_STEREO);
            received = true;
        }
        if (!received) projectm_pcm_add_float(renderer_, audio, 735, PROJECTM_STEREO);
    } else {
        synth_.fill(audio, 735);
        projectm_pcm_add_float(renderer_, audio, 735, PROJECTM_STEREO);
    }
    try { projectm_opengl_render_frame(renderer_); }
    catch (const std::exception& error) {
        fprintf(stderr, "Render failed: %s\n", error.what());
        [self shutdown];
        if (smokeOutput) std::exit(1);
        if (self.report) self.report(@"Rendering failed. Restart the application.");
        return;
    }
    ++frame_;
    if (frame_ % 15 == 0) [self updateAudioStatus];
    if (smokeOutput && frame_ == 60) previousPixels_ = [self readPixels];
    if (smokeOutput && frame_ == 120) [self finishSmokeTest];
    [self.openGLContext flushBuffer];
}
- (void)shutdown {
    capture_.stop();
    [timer_ invalidate];
    timer_ = nil;
    if (renderer_) {
        [self.openGLContext makeCurrentContext];
        projectm_destroy(renderer_);
        renderer_ = nullptr;
    }
}
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property NSWindow* window;
@property VisualizerView* visualizer;
@property NSTextField* status;
@property NSArray<NSString*>* presets;
@property NSUInteger presetIndex;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    NSString* presetDirectory = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"presets"];
    self.presets = @[[presetDirectory stringByAppendingPathComponent:@"Aurora.milk"], [presetDirectory stringByAppendingPathComponent:@"Prism.milk"]];
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 680) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"MilkDrop macOS";
    self.window.minSize = NSMakeSize(800, 360);
    self.window.delegate = self;
    self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    NSView* content = self.window.contentView;
    self.visualizer = [[VisualizerView alloc] initWithFrame:NSMakeRect(0, 42, 1000, 638)];
    if (!self.visualizer) { fprintf(stderr, "No OpenGL 4.1 pixel format available\n"); std::exit(1); }
    self.visualizer.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    self.visualizer.presetPath = initialPreset ?: self.presets.firstObject;
    __weak AppDelegate* weakSelf = self;
    self.visualizer.report = ^(NSString* text) { weakSelf.status.stringValue = text; };
    [content addSubview:self.visualizer];
    self.status = [NSTextField labelWithString:@"Starting renderer…"];
    self.status.frame = NSMakeRect(16, 12, 620, 20);
    self.status.autoresizingMask = NSViewWidthSizable;
    [content addSubview:self.status];
    NSButton* next = [NSButton buttonWithTitle:@"Next preset →" target:self action:@selector(nextPreset:)];
    next.frame = NSMakeRect(840, 7, 140, 28);
    next.autoresizingMask = NSViewMinXMargin;
    [content addSubview:next];
    NSButton* audio = [NSButton buttonWithTitle:@"Demo / System Audio" target:self action:@selector(toggleAudio:)];
    audio.frame = NSMakeRect(645, 7, 190, 28);
    audio.autoresizingMask = NSViewMinXMargin;
    [content addSubview:audio];
    self.status.frame = NSMakeRect(16, 12, 610, 20);
    self.status.lineBreakMode = NSLineBreakByTruncatingTail;
    [self createMenus];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    if (smokeOutput) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        fprintf(stderr, "FAIL: render smoke test timed out\n");
        std::exit(1);
    });
}
- (void)createMenus {
    NSMenu* bar = [NSMenu new];
    NSMenuItem* app = [NSMenuItem new];
    NSMenu* appMenu = [NSMenu new];
    [appMenu addItemWithTitle:@"Quit MilkDrop macOS" action:@selector(terminate:) keyEquivalent:@"q"];
    app.submenu = appMenu; [bar addItem:app];
    NSMenuItem* file = [NSMenuItem new];
    NSMenu* fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    NSMenuItem* open = [fileMenu addItemWithTitle:@"Open Preset…" action:@selector(openPreset:) keyEquivalent:@"o"]; open.target = self;
    NSMenuItem* folder = [fileMenu addItemWithTitle:@"Open Preset Folder…" action:@selector(openPresetFolder:) keyEquivalent:@"O"]; folder.target = self;
    NSMenuItem* next = [fileMenu addItemWithTitle:@"Next Preset" action:@selector(nextPreset:) keyEquivalent:@"n"]; next.target = self;
    file.submenu = fileMenu; [bar addItem:file];
    NSMenuItem* audio = [NSMenuItem new];
    NSMenu* audioMenu = [[NSMenu alloc] initWithTitle:@"Audio"];
    NSMenuItem* toggle = [audioMenu addItemWithTitle:@"Switch Demo / System Audio" action:@selector(toggleAudio:) keyEquivalent:@"a"];
    toggle.target = self;
    audio.submenu = audioMenu; [bar addItem:audio];
    NSMenuItem* view = [NSMenuItem new];
    NSMenu* viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    NSMenuItem* fullscreen = [viewMenu addItemWithTitle:@"Toggle Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
    fullscreen.keyEquivalentModifierMask = NSEventModifierFlagControl|NSEventModifierFlagCommand;
    view.submenu = viewMenu; [bar addItem:view];
    NSApp.mainMenu = bar;
}
- (void)nextPreset:(id)sender {
    self.presetIndex = (self.presetIndex + 1) % self.presets.count;
    [self.visualizer loadPreset:self.presets[self.presetIndex]];
}
- (void)toggleAudio:(id)sender { [self.visualizer toggleAudio]; }
- (void)openPreset:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"milk"]];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSModalResponseOK) [self.visualizer loadPreset:panel.URL.path];
    }];
}
- (void)openPresetFolder:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = NO;
    panel.canChooseDirectories = YES;
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK) return;
        NSURL* folder = panel.URL;
        self.status.stringValue = @"Scanning presets…";
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSMutableArray<NSString*>* paths = [NSMutableArray new];
            NSDirectoryEnumerator* files = [NSFileManager.defaultManager enumeratorAtURL:folder includingPropertiesForKeys:@[NSURLIsRegularFileKey] options:NSDirectoryEnumerationSkipsHiddenFiles|NSDirectoryEnumerationSkipsPackageDescendants errorHandler:nil];
            for (NSURL* url in files) {
                if ([url.pathExtension.lowercaseString isEqualToString:@"milk"]) {
                    NSNumber* regular;
                    [url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
                    if (regular.boolValue) [paths addObject:url.path];
                }
            }
            [paths sortUsingSelector:@selector(localizedStandardCompare:)];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!paths.count) {
                    NSAlert* alert = [NSAlert new];
                    alert.messageText = @"No .milk presets found";
                    alert.informativeText = @"Choose a folder containing classic MilkDrop presets. Double presets (.milk2) are not supported yet.";
                    [alert beginSheetModalForWindow:self.window completionHandler:nil];
                    return;
                }
                self.presets = paths;
                self.presetIndex = 0;
                [self.visualizer loadPreset:self.presets.firstObject];
            });
        });
    }];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender { return YES; }
- (void)applicationWillTerminate:(NSNotification*)notification { [self.visualizer shutdown]; }
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
