#!/bin/bash
# Compile and run Tunnelbar's pure-logic tests with swiftc.
# (SwiftPM's manifest API is broken in bare Command Line Tools, so we don't use
# `swift test`; these tests compile the Foundation-only sources + Tests/main.swift.)
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build
echo "==> Compiling tests…"
swiftc -o build/run-tests \
  Sources/Tunnelbar/CommandParser.swift \
  Sources/Tunnelbar/Models.swift \
  Tests/main.swift

echo "==> Running tests…"
./build/run-tests
