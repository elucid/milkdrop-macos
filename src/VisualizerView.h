#pragma once
#import <AppKit/AppKit.h>
#include <projectM-4/projectM.h>
#include "SyntheticAudio.hpp"
#include "AudioCapture.hpp"
#include <vector>

@interface VisualizerView : NSOpenGLView {
    projectm_handle renderer_;
    SyntheticAudio synth_;
    NSTimer* timer_;
    NSUInteger frame_;
    std::vector<unsigned char> previousPixels_;
    AudioCapture capture_;
    BOOL presetFailed_;
    NSArray<NSString*>* texturePaths_;
}
@property(nonatomic, copy) NSString* presetPath;
@property(nonatomic, copy) NSString* collectionRoot;
@property(nonatomic, copy) NSString* customTexturePath;
@property(nonatomic, copy) NSString* smokeOutput;
@property(nonatomic, copy) void (^report)(NSString*);
- (BOOL)loadPreset:(NSString*)path smooth:(BOOL)smooth;
- (void)shutdown;
- (void)toggleAudio;
- (void)updateAudioStatus;
- (void)markPresetFailed;
@end
