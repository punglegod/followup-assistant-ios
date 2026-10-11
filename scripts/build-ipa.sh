#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo '请先安装 XcodeGen：brew install xcodegen'; exit 1; }
xcodegen generate
xcodebuild -project FollowUp.xcodeproj -scheme FollowUp -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Payload" build
cp -R build/DerivedData/Build/Products/Release-iphoneos/FollowUp.app "$stage/Payload/"
output="$PWD/build/FollowUp-unsigned.ipa"
if [ -e "$output" ]; then mv "$output" "$PWD/build/FollowUp-unsigned-$(date +%Y%m%d-%H%M%S).ipa"; fi
(cd "$stage" && /usr/bin/zip -qry "$output" Payload)
echo "已生成待签名 IPA：$output"
