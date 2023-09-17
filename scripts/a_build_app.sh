#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)"
source "$PROJECT_ROOT/scripts/common.sh"

echo $PROJECT

xcodebuild -version
clang -v
rm -rf "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"


xcodebuild clean -project "$PROJECT" -scheme "$TARGET" -configuration Release  || { echo "clean Failed"; exit 1; }

PRODUCT_SETTINGS_PATH="$PROJECT_ROOT/Fire/Info.plist"
version=$(git describe --tags `git rev-list --tags --max-count=1`)
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" $PRODUCT_SETTINGS_PATH
vv=`date "+%Y%m%d%H%M%S"`
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $vv" $PRODUCT_SETTINGS_PATH

echo "version"
echo $version
echo $vv

xcodebuild archive -project "$PROJECT" -scheme Fire -archivePath "$EXPORT_ARCHIVE" -configuration Release $BUILD_FLAG || { echo "Archive Failed:"; exit 1; }

if [[ $USE_CODE_SIGN == "disable" ]]
then
  echo "export without code signing"
  ditto "$EXPORT_ARCHIVE/Products/Applications/$TARGET.app" "$EXPORT_APP"
  ls "$EXPORT_PATH"
else
  /usr/bin/xcodebuild -exportArchive -archivePath "$EXPORT_ARCHIVE" -exportOptionsPlist "$PROJECT_ROOT/scripts/ExportOptions.plist" -exportPath "$EXPORT_PATH" $BUILD_FLAG || { echo "Export Archive Failed : xcodebuild exportArchive action failed"; exit 1; }

  ditto -c -k --sequesterRsrc --keepParent "$EXPORT_APP" "$EXPORT_ZIP"
fi
