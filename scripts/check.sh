#!/bin/sh

set -eu

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_dir"

swift run GitAccountRouterTests
swift build -c release --product GitAccountRouter
swift build -c release --product git-account-status

if swift format --help >/dev/null 2>&1; then
  swift format lint --recursive --strict Package.swift Sources Tests
fi
