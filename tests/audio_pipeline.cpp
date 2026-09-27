#include "AudioPipeline.hpp"
#include <cstdio>
#include <cstdlib>
#include <limits>
#include <thread>
#include <vector>

#define CHECK(condition) do { if (!(condition)) { std::fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); std::exit(1); } } while (0)

int main() {
    AudioRing<3> ring;
    float output[8]{};
    CHECK(ring.pop(output, 4) == 0);
    CHECK(ring.push({1, -1})); CHECK(ring.push({2, -2})); CHECK(ring.push({3, -3}));
    CHECK(!ring.push({4, -4})); CHECK(ring.dropped() == 1);
    CHECK(ring.pop(output, 2) == 2); CHECK(output[0] == 1 && output[3] == -2);
    CHECK(ring.push({4, -4})); CHECK(ring.push({5, -5}));
    CHECK(ring.pop(output, 4) == 3); CHECK(output[0] == 3 && output[5] == -5);
    ring.reset(); CHECK(ring.pop(output, 4) == 0 && ring.dropped() == 0);

    float stereo[] = {0.1f, 0.2f, 0.3f, 0.4f};
    auto frame = readFloatFrame(stereo, stereo+1, 1, 2, 2, false);
    CHECK(frame.left == 0.3f && frame.right == 0.4f);
    frame = readFloatFrame(stereo, nullptr, 1, 1, 1, true);
    CHECK(frame.left == 0.2f && frame.right == 0.2f);
    frame = readFloatFrame(stereo, stereo+2, 1, 1, 1, false);
    CHECK(frame.left == 0.2f && frame.right == 0.4f);
    frame = readFloatFrame(nullptr, nullptr, 10, 2, 2, false);
    CHECK(frame.left == 0 && frame.right == 0);
    CHECK(safeSample(std::numeric_limits<float>::quiet_NaN()) == 0);
    CHECK(safeSample(2) == 1 && safeSample(-2) == -1);

    for (double rate : {22050.0, 44100.0, 48000.0, 96000.0, 192000.0}) {
        AudioResampler resampler;
        resampler.reset(rate);
        std::vector<StereoFrame> samples;
        for (int i = 0; i < (int)rate; ++i) {
            float value = float(i/rate);
            resampler.feed({value, -value}, [&](StereoFrame s) { samples.push_back(s); });
        }
        CHECK(std::abs((int)samples.size() - 44100) <= 2);
        // A ramp exposes interpolation, phase and stereo channel mistakes.
        for (std::size_t i = 0; i < samples.size(); ++i) {
            CHECK(std::abs(samples[i].left - float(i/44100.0)) < 0.00001f);
            CHECK(samples[i].left == -samples[i].right);
        }
    }
    AudioRing<64> concurrent;
    constexpr int count = 100000;
    std::thread producer([&] {
        for (int i = 0; i < count; ++i)
            while (!concurrent.push({float(i), -float(i)})) std::this_thread::yield();
    });
    int next = 0;
    while (next < count) {
        float buffer[34];
        auto n = concurrent.pop(buffer, 17);
        for (std::size_t i = 0; i < n; ++i, ++next) {
            CHECK(buffer[2*i] == float(next)); CHECK(buffer[2*i+1] == -float(next));
        }
        if (!n) std::this_thread::yield();
    }
    producer.join();
    std::puts("PASS: audio ring overflow/wrap/concurrency, channels/silence, sanitization and resampling at five rates");
}
