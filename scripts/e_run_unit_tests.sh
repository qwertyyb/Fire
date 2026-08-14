#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)"
source "$PROJECT_ROOT/scripts/common.sh"

set -euo pipefail

echo "Running unit tests for $TARGET"

xcodebuild -version

xcodebuild test \
  -project "$PROJECT" \
  -scheme "$TARGET" \
  -configuration Debug \
  -destination 'platform=macOS' \
  $BUILD_FLAG \
  || { echo "Unit tests failed"; exit 1; }

echo "Unit tests passed"
