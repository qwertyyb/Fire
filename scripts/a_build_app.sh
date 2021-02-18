#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)"
source "$PROJECT_ROOT/scripts/common.sh"

echo $WORKSPACE
echo $EXPORT_PATH

xcodebuild -version
clang -v
rm -rf "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"


xcodebuild clean -workspace "${WORKSPACE}" -scheme "${TARGET}" || { echo "clean Failed"; exit 1; }


PRODUCT_SETTINGS_PATH="$PROJECT_ROOT/Fire/Info.plist"
version=$(git describe --tags `git rev-list --tags --max-count=1`)
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" $PRODUCT_SETTINGS_PATH
vv=`date "+%Y%m%d%H%M%S"`
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $vv" $PRODUCT_SETTINGS_PATH

echo $version
echo $vv

xcodebuild archive -workspace "$WORKSPACE" -scheme Fire -archivePath "$EXPORT_ARCHIVE" -configuration Release || { echo "Archive Failed:"; exit 1; }

# # cp -a ./archive.xcarchive/Products/Applications/*.app "${BUILD_DIR}"

# # rm -rf ./archive.xcarchive

/usr/bin/xcodebuild -exportArchive -archivePath "$EXPORT_ARCHIVE" -exportOptionsPlist "$PROJECT_ROOT/scripts/ExportOptions.plist" -exportPath "$EXPORT_PATH" || { echo "Export Archive Failed : xcodebuild exportArchive action failed"; exit 1; }

ditto -c -k --sequesterRsrc --keepParent "$EXPORT_APP" "$EXPORT_ZIP"
