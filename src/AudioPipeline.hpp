#pragma once
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>

struct StereoFrame { float left = 0, right = 0; };

// Single producer (Core Audio) / single consumer (render thread). No allocation or locks.
template<std::size_t Capacity = 8192>
class AudioRing {
    static_assert(Capacity > 0);
    static_assert(std::atomic<std::uint64_t>::is_always_lock_free);
public:
    bool push(StereoFrame frame) {
        const auto write = write_.load(std::memory_order_relaxed);
        if (write - read_.load(std::memory_order_acquire) >= Capacity) {
            dropped_.fetch_add(1, std::memory_order_relaxed);
            return false;
        }
        frames_[write % Capacity] = frame;
        write_.store(write + 1, std::memory_order_release);
        return true;
    }
    std::size_t pop(float* output, std::size_t capacity) {
        const auto read = read_.load(std::memory_order_relaxed);
        const auto count = std::min<std::uint64_t>(capacity, write_.load(std::memory_order_acquire) - read);
        for (std::size_t i = 0; i < count; ++i) {
            const auto frame = frames_[(read + i) % Capacity];
            output[2*i] = frame.left;
            output[2*i+1] = frame.right;
        }
        read_.store(read + count, std::memory_order_release);
        return count;
    }
    // Call only after both producer and consumer have stopped.
    void reset() { read_ = 0; write_ = 0; dropped_ = 0; }
    std::uint64_t dropped() const { return dropped_.load(std::memory_order_relaxed); }
private:
    std::array<StereoFrame, Capacity> frames_{};
    alignas(64) std::atomic<std::uint64_t> read_{0};
    alignas(64) std::atomic<std::uint64_t> write_{0};
    std::atomic<std::uint64_t> dropped_{0};
};

inline float safeSample(float value) {
    return std::isfinite(value) ? std::clamp(value, -1.0f, 1.0f) : 0.0f;
}

// Streaming linear resampling for visualization (not for playback). Preserves phase
// across callback boundaries. projectM's analysis assumes a 44.1 kHz input stream.
class AudioResampler {
public:
    void reset(double sourceRate) {
        step_ = sourceRate / 44100.0;
        next_ = step_;
        ready_ = false;
    }
    template<class Sink>
    void feed(StereoFrame frame, Sink&& emit) {
        frame = {safeSample(frame.left), safeSample(frame.right)};
        if (!ready_) { previous_ = frame; ready_ = true; emit(frame); return; }
        while (next_ <= 1.0) {
            const float fraction = static_cast<float>(next_);
            emit(StereoFrame{previous_.left + (frame.left - previous_.left)*fraction,
                             previous_.right + (frame.right - previous_.right)*fraction});
            next_ += step_;
        }
        next_ -= 1.0;
        previous_ = frame;
    }
private:
    double step_ = 1, next_ = 1;
    bool ready_ = false;
    StereoFrame previous_{};
};

// A null channel pointer means silence. Mono duplicates the left channel.
inline StereoFrame readFloatFrame(const float* left, const float* right,
                                  std::size_t index, std::size_t leftStride,
                                  std::size_t rightStride, bool mono) {
    const float l = left ? left[index * leftStride] : 0.0f;
    return {l, mono ? l : (right ? right[index * rightStride] : 0.0f)};
}
