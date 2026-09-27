#import "VisualizerView.h"
#import "PresetLibrary.h"
#import <OpenGL/gl3.h>
#include <algorithm>
#include <cstdio>
#include <exception>


static void presetFailure(const char* file, const char* message, void* context) {
    VisualizerView* view = (__bridge VisualizerView*)context;
    NSString* error = [NSString stringWithFormat:@"Preset failed: %s", message ?: "unknown error"];
    fprintf(stderr, "%s: %s\n", file ?: "preset", error.UTF8String);
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
        if (self.smokeOutput) std::exit(1);
        return;
    }
    fprintf(stderr, "OpenGL: %s | %s\n", glGetString(GL_VERSION), glGetString(GL_RENDERER));
    projectm_set_preset_locked(renderer_, true);
    projectm_set_fps(renderer_, 60);
    projectm_set_soft_cut_duration(renderer_, 2.0);
    projectm_set_mesh_size(renderer_, 64, 48);
    projectm_set_preset_switch_failed_event_callback(renderer_, presetFailure, (__bridge void*)self);
    [self reshape];
    [self loadPreset:self.presetPath smooth:NO];
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
- (BOOL)loadPreset:(NSString*)path smooth:(BOOL)smooth {
    self.presetPath = path;
    if (!path) return NO;
    if (!renderer_) return YES;
    [self.openGLContext makeCurrentContext];
    NSArray<NSString*>* paths = MDTexturePaths(path, self.collectionRoot, self.customTexturePath);
    if (![texturePaths_ isEqualToArray:paths]) {
        std::vector<const char*> nativePaths;
        for (NSString* directory in paths) nativePaths.push_back(directory.fileSystemRepresentation);
        projectm_set_texture_search_paths(renderer_, nativePaths.data(), nativePaths.size());
        texturePaths_ = paths;
    }
    presetFailed_ = NO;
    try { projectm_load_preset_file(renderer_, path.fileSystemRepresentation, smooth); }
    catch (const std::exception& error) { presetFailure(path.UTF8String, error.what(), (__bridge void*)self); }
    if (!presetFailed_) [self updateAudioStatus];
    return !presetFailed_;
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
    BOOL written = [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:self.smokeOutput atomically:YES];
    GLenum error = glGetError();
    bool ok = !presetFailed_ && written && lit > pixels.size()/400 && changed > pixels.size()/400 && error == GL_NO_ERROR;
    fprintf(stderr, "%s: %ldx%ld, %zu lit pixels, %zu changed pixels, GL error=%u, screenshot=%s\n", ok ? "PASS" : "FAIL", (long)w, (long)h, lit, changed, error, self.smokeOutput.fileSystemRepresentation);
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
        if (self.smokeOutput) std::exit(1);
        if (self.report) self.report(@"Rendering failed. Restart the application.");
        return;
    }
    ++frame_;
    if (frame_ % 15 == 0) [self updateAudioStatus];
    if (self.smokeOutput && frame_ == 60) previousPixels_ = [self readPixels];
    if (self.smokeOutput && frame_ == 120) [self finishSmokeTest];
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

