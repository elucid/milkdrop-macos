#pragma once
#include <cmath>
#include <cstddef>
#include <cstdint>

// Deterministic input for demos and renderer diagnostics; never plays sound.
class SyntheticAudio {
public:
    void fill(float* interleaved, std::size_t frames) {
        constexpr double tau = 6.283185307179586;
        for (std::size_t i = 0; i < frames; ++i, ++sample_) {
            const double t = static_cast<double>(sample_) / 44100.0;
            const double beat = std::exp(-std::fmod(t, 0.5) * 16.0);
            interleaved[2 * i] = float(0.48 * beat * std::sin(tau * 65 * t) + 0.15 * std::sin(tau * 220 * t));
            interleaved[2 * i + 1] = float(0.48 * beat * std::sin(tau * 65 * t) + 0.15 * std::sin(tau * 330 * t));
        }
    }
private:
    std::uint64_t sample_ = 0;
};
