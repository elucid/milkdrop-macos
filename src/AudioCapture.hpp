#pragma once
#include "AudioPipeline.hpp"
#include <CoreAudio/CoreAudio.h>
#include <string>

class AudioCapture {
public:
    ~AudioCapture() { stop(); }
    // Lifecycle methods are used only on the main thread. Returns an error, or empty on success.
    std::string start();
    void stop();
    bool running() const { return running_; }
    std::size_t read(float* output, std::size_t frames) { return ring_.pop(output, frames); }
    float takePeak() { return peak_.exchange(0, std::memory_order_relaxed); }
    std::uint64_t received() const { return received_.load(std::memory_order_relaxed); }
    double sampleRate() const { return format_.mSampleRate; }
    std::uint64_t dropped() const { return ring_.dropped(); }
private:
    static OSStatus callback(AudioObjectID, const AudioTimeStamp*, const AudioBufferList*,
                             const AudioTimeStamp*, AudioBufferList*, const AudioTimeStamp*, void*);
    void consume(const AudioBufferList*);
    AudioObjectID tap_ = kAudioObjectUnknown;
    AudioObjectID device_ = kAudioObjectUnknown;
    AudioDeviceIOProcID io_ = nullptr;
    AudioStreamBasicDescription format_{};
    bool running_ = false;
    AudioRing<> ring_;
    AudioResampler resampler_;
    std::atomic<float> peak_{0};
    std::atomic<std::uint64_t> received_{0};
};
