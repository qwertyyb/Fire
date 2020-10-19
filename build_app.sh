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

xcodebuild archive -workspace Fire.xcworkspace -scheme Fire -archivePath ./archive -configuration Release

cp -a ./archive.xcarchive/Products/Applications/*.app "${BUILD_DIR}"

rm -rf ./archive.xcarchive
