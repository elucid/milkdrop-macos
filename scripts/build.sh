#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -f vendor/projectm/vendor/projectm-eval/CMakeLists.txt ]]; then
  git submodule update --init --recursive
fi
nix develop -c bash -e -c '
  cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
  cmake --build build -j 8
  ctest --test-dir build --output-on-failure
'
