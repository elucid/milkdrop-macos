#pragma once
#include <algorithm>
#include <cstddef>
#include <numeric>
#include <optional>
#include <random>
#include <vector>

// Each cycle visits every entry once; don't immediately repeat the last entry
// at a cycle boundary. Selecting a preset manually starts a new cycle.
class ShuffleBag {
public:
    explicit ShuffleBag(unsigned seed = std::random_device{}()) : random_(seed) {}
    void reset(std::size_t count, std::optional<std::size_t> current = {}) {
        count_ = count;
        bag_.clear();
        for (std::size_t i = 0; i < count; ++i) if (!current || i != *current) bag_.push_back(i);
        std::shuffle(bag_.begin(), bag_.end(), random_);
    }
    std::optional<std::size_t> next(std::optional<std::size_t> current = {}) {
        if (!count_) return {};
        if (bag_.empty()) {
            bag_.resize(count_);
            std::iota(bag_.begin(), bag_.end(), 0);
            std::shuffle(bag_.begin(), bag_.end(), random_);
            if (count_ > 1 && current && bag_.back() == *current) std::swap(bag_.front(), bag_.back());
        }
        auto next = bag_.back();
        bag_.pop_back();
        return next;
    }
private:
    std::size_t count_ = 0;
    std::vector<std::size_t> bag_;
    std::mt19937 random_;
};
