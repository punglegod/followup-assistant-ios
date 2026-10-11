#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
if [ -e build/TestResults.xcresult ]; then
  mv build/TestResults.xcresult "build/TestResults-$(date +%Y%m%d-%H%M%S).xcresult"
fi
simulator_id=$(xcrun simctl list devices available -j | python3 -c 'import sys,json; d=json.load(sys.stdin); groups=sorted(((k,vs) for k,vs in d["devices"].items() if "iOS" in k),reverse=True); print(next(v["udid"] for k,vs in groups for v in vs if v["name"].startswith("iPhone")))')
test_options=(-parallel-testing-enabled NO)
if [ -n "${IOS_TEST_FILTER:-}" ]; then test_options+=("-only-testing:$IOS_TEST_FILTER"); fi
set +e
xcodebuild -project FollowUp.xcodeproj -scheme FollowUp \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath build/TestDerivedData -resultBundlePath build/TestResults.xcresult \
  "${test_options[@]}" CODE_SIGNING_ALLOWED=NO test
test_status=$?
set -e
if [ -d build/TestResults.xcresult ]; then
  xcrun xcresulttool export attachments --path build/TestResults.xcresult --output-path build/screenshots
fi
if [ "$test_status" -ne 0 ]; then exit "$test_status"; fi
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl install "$simulator_id" build/TestDerivedData/Build/Products/Debug-iphonesimulator/FollowUp.app
xcrun simctl launch "$simulator_id" com.sunway.followup
sleep 2
xcrun simctl io "$simulator_id" screenshot build/preview.png
