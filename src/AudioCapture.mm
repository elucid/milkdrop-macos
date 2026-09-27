#import <Foundation/Foundation.h>
#import <CoreAudio/CATapDescription.h>
#import <CoreAudio/AudioHardwareTapping.h>
#include "AudioCapture.hpp"
#include <limits>

static_assert(std::atomic<float>::is_always_lock_free);

std::string AudioCapture::start() {
    stop();
    ring_.reset();
    peak_ = 0;
    received_ = 0;
    auto fail = [this](const char* operation, OSStatus status) {
        stop();
        return std::string(operation) + " failed (Core Audio " + std::to_string(status) +
            "). Check System Settings → Privacy & Security → Screen & System Audio Recording, then retry.";
    };
    CATapDescription* description = [[CATapDescription alloc] initStereoGlobalTapButExcludeProcesses:@[]];
    description.name = @"MilkDrop macOS system audio";
    description.privateTap = YES;
    description.muteBehavior = CATapUnmuted;
    OSStatus status = AudioHardwareCreateProcessTap(description, &tap_);
    if (status != noErr) return fail("Create system audio tap", status);
    AudioObjectPropertyAddress address{kAudioTapPropertyFormat, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
    UInt32 size = sizeof(format_);
    status = AudioObjectGetPropertyData(tap_, &address, 0, nullptr, &size, &format_);
    if (status != noErr) return fail("Read tap format", status);
    if (format_.mFormatID != kAudioFormatLinearPCM ||
        !(format_.mFormatFlags & kAudioFormatFlagIsFloat) ||
        !(format_.mFormatFlags & kAudioFormatFlagIsPacked) ||
        (format_.mFormatFlags & kAudioFormatFlagIsBigEndian) ||
        format_.mBitsPerChannel != 32 ||
        format_.mChannelsPerFrame < 1 || format_.mChannelsPerFrame > 2 ||
        !std::isfinite(format_.mSampleRate) || format_.mSampleRate < 8000 || format_.mSampleRate > 384000) {
        stop();
        return "Unsupported audio tap format; expected mono/stereo, packed Float32 PCM at 8–384 kHz.";
    }
    resampler_.reset(format_.mSampleRate);
    NSDictionary* tap = @{@kAudioSubTapUIDKey:description.UUID.UUIDString,
                           @kAudioSubTapDriftCompensationKey:@YES};
    NSDictionary* aggregate = @{
        @kAudioAggregateDeviceNameKey:@"MilkDrop macOS capture",
        @kAudioAggregateDeviceUIDKey:NSUUID.UUID.UUIDString,
        @kAudioAggregateDeviceIsPrivateKey:@YES,
        @kAudioAggregateDeviceTapAutoStartKey:@YES,
        @kAudioAggregateDeviceTapListKey:@[tap]
    };
    status = AudioHardwareCreateAggregateDevice((__bridge CFDictionaryRef)aggregate, &device_);
    if (status != noErr) return fail("Create private capture device", status);
    status = AudioDeviceCreateIOProcID(device_, callback, this, &io_);
    if (status != noErr) return fail("Create audio callback", status);
    status = AudioDeviceStart(device_, io_);
    if (status != noErr) return fail("Start audio capture", status);
    running_ = true;
    return {};
}

void AudioCapture::stop() {
    if (device_ != kAudioObjectUnknown && io_) {
        AudioDeviceStop(device_, io_);
        AudioDeviceDestroyIOProcID(device_, io_);
        io_ = nullptr;
    }
    if (device_ != kAudioObjectUnknown) {
        AudioHardwareDestroyAggregateDevice(device_);
        device_ = kAudioObjectUnknown;
    }
    if (tap_ != kAudioObjectUnknown) {
        AudioHardwareDestroyProcessTap(tap_);
        tap_ = kAudioObjectUnknown;
    }
    running_ = false;
}

OSStatus AudioCapture::callback(AudioObjectID, const AudioTimeStamp*, const AudioBufferList* input,
                               const AudioTimeStamp*, AudioBufferList*, const AudioTimeStamp*, void* context) {
    static_cast<AudioCapture*>(context)->consume(input);
    return noErr;
}

void AudioCapture::consume(const AudioBufferList* input) {
    if (!input || input->mNumberBuffers == 0) return;
    const AudioBuffer& first = input->mBuffers[0];
    const bool mono = format_.mChannelsPerFrame == 1;
    const bool planar = (format_.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    const float* left = static_cast<const float*>(first.mData);
    const float* right = nullptr;
    std::size_t frames = 0, leftStride = 1, rightStride = 1;
    if (planar) {
        if (first.mNumberChannels != 1 || (!mono && input->mNumberBuffers < 2)) return;
        frames = first.mDataByteSize / sizeof(float);
        if (!mono) {
            const AudioBuffer& second = input->mBuffers[1];
            if (second.mNumberChannels != 1) return;
            right = static_cast<const float*>(second.mData);
            frames = std::min(frames, second.mDataByteSize / sizeof(float));
        }
    } else {
        if (first.mNumberChannels != format_.mChannelsPerFrame) return;
        leftStride = rightStride = first.mNumberChannels;
        frames = first.mDataByteSize / (sizeof(float) * leftStride);
        if (!mono && left) right = left + 1;
    }
    float blockPeak = 0;
    for (std::size_t i = 0; i < frames; ++i) {
        resampler_.feed(readFloatFrame(left, right, i, leftStride, rightStride, mono), [this, &blockPeak](StereoFrame frame) {
            ring_.push(frame);
            blockPeak = std::max({blockPeak, std::abs(frame.left), std::abs(frame.right)});
        });
    }
    // Only one producer writes a positive peak; the main thread exchanges it with zero.
    float old = peak_.load(std::memory_order_relaxed);
    while (old < blockPeak && !peak_.compare_exchange_weak(old, blockPeak, std::memory_order_relaxed)) {}
    received_.fetch_add(frames, std::memory_order_relaxed);
}
