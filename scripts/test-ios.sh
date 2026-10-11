#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
simulator_id=$(xcrun simctl list devices available -j | python3 -c 'import sys,json; d=json.load(sys.stdin); print(next(v["udid"] for k,vs in d["devices"].items() if "iOS" in k for v in vs if v["name"].startswith("iPhone")))')
xcodebuild -project FollowUp.xcodeproj -scheme FollowUp \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath build/TestDerivedData CODE_SIGNING_ALLOWED=NO test
