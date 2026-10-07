#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p ios-output
xcodebuild -version > ios-output/environment.txt
xcrun simctl list devices available --json > ios-output/simulators.json
device=$(python3 -c 'import json;d=json.load(open("ios-output/simulators.json"));print(next(v["udid"] for devices in d["devices"].values() for v in devices if v.get("isAvailable") and "iPhone" in v["name"]))')
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b
# Apple WebKit issue293831: Xcode16.4/iOS18.5 simulator overlay fails below18.4.
# This test-only override leaves the device archive minimum at iOS17.
xcodebuild -project ios/Harumoa.xcodeproj -scheme Harumoa -configuration Debug -destination "platform=iOS Simulator,id=$device" -derivedDataPath ios-derived -parallel-testing-enabled NO build-for-testing CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=18.4 2>&1 | tee ios-output/simulator-build.log
xcrun simctl install "$device" ios-derived/Build/Products/Debug-iphonesimulator/Harumoa.app
xcrun simctl privacy "$device" revoke microphone com.harumoa.app.iostest
xcodebuild -project ios/Harumoa.xcodeproj -scheme Harumoa -configuration Debug -destination "platform=iOS Simulator,id=$device" -derivedDataPath ios-derived -parallel-testing-enabled NO -only-testing:HarumoaTests/HarumoaTests/testNativePermissionDenialKeepsRetry -resultBundlePath ios-output/denial.xcresult test-without-building CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=18.4 2>&1 | tee ios-output/permission-denial.log
xcrun simctl privacy "$device" grant microphone com.harumoa.app.iostest
xcodebuild -project ios/Harumoa.xcodeproj -scheme Harumoa -configuration Debug -destination "platform=iOS Simulator,id=$device" -derivedDataPath ios-derived -parallel-testing-enabled NO -skip-testing:HarumoaTests/HarumoaTests/testNativePermissionDenialKeepsRetry -resultBundlePath ios-output/tests.xcresult test-without-building CODE_SIGNING_ALLOWED=NO IPHONEOS_DEPLOYMENT_TARGET=18.4 2>&1 | tee ios-output/simulator-test.log
xcrun simctl launch "$device" com.harumoa.app.iostest
xcrun simctl io "$device" screenshot ios-output/ios-simulator.png
xcodebuild -project ios/Harumoa.xcodeproj -scheme Harumoa -configuration Release -destination 'generic/platform=iOS' -archivePath ios-output/Harumoa.xcarchive archive CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO 2>&1 | tee ios-output/device-build.log
codesign --display --verbose=4 ios-output/Harumoa.xcarchive/Products/Applications/Harumoa.app > ios-output/signature.txt 2>&1 || true
file ios-output/Harumoa.xcarchive/Products/Applications/Harumoa.app/Harumoa > ios-output/device-binary.txt
python3 - <<'PY'
from pathlib import Path
import hashlib, json, plistlib, zipfile
out=Path('ios-output'); app=out/'Harumoa.xcarchive/Products/Applications/Harumoa.app'
with (app/'Info.plist').open('rb') as f: info=plistlib.load(f)
assert info['CFBundleIdentifier']=='com.harumoa.app.iostest'
assert not (app/'embedded.mobileprovision').exists(), 'Preview must not contain a provisioning profile'
ipa=out/'harumoa-v0.9.25-ios-UNSIGNED.ipa'
with zipfile.ZipFile(ipa,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(app.rglob('*')):
        if p.is_file(): z.write(p, 'Payload/Harumoa.app/'+p.relative_to(app).as_posix())
row={'artifact':ipa.name,'bytes':ipa.stat().st_size,'sha256':hashlib.sha256(ipa.read_bytes()).hexdigest(),'bundle_id':info['CFBundleIdentifier'],'version':info['CFBundleShortVersionString'],'build':info['CFBundleVersion'],'signed':False,'iphone_installable':False,'verification':'Actual Xcode device compilation and iOS simulator tests. No physical iPhone or live Google authorization.','pending':['Apple signing/provisioning','iOS Google OAuth client','native per-file family Picker','physical iPhone verification']}
(out/'build-result.json').write_text(json.dumps(row,indent=2))
(out/'INSTALLATION-ko.txt').write_text('이 IPA는 서명되지 않은 빌드입니다. 아이폰에 바로 설치할 수 없습니다. Apple 서명·기기 등록 또는 TestFlight 배포가 필요합니다. iOS Google 로그인 등록과 실제 아이폰 확인도 남아 있습니다.\n',encoding='utf-8')
print(json.dumps(row))
PY
xcrun simctl shutdown "$device"
