#!/bin/bash

TARGET='Fire'
WORKSPACE="${TARGET}.xcworkspace"
BUILD_DIR="./apps"

xcodebuild -version
clang -v
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
rm -rf ./archive.xcarchive


xcodebuild clean -workspace "${WORKSPACE}" -scheme "${TARGET}"

if [[ $? == 0 ]]; then
    echo "Clean Success"
else
    echo "Clean Failed"
    exit $?
fi


PRODUCT_SETTINGS_PATH='./Fire/Info.plist'
version=$(git describe --tags `git rev-list --tags --max-count=1`)
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" $PRODUCT_SETTINGS_PATH
vv=`date "+%Y%m%d%H%M%S"`
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $vv" $PRODUCT_SETTINGS_PATH

echo $version
echo $vv

xcodebuild archive -workspace Fire.xcworkspace -scheme Fire -archivePath ./archive -configuration Release

if [[ $? == 0 ]]; then
    echo "Build Success"
else
    echo "Build Failed"
    exit $?
fi

cp -a ./archive.xcarchive/Products/Applications/*.app "${BUILD_DIR}"

ditto -c -k --sequesterRsrc --keepParent "${BUILD_DIR}/Fire.app" "${BUILD_DIR}/Fire.zip"

rm -rf ./archive.xcarchive
