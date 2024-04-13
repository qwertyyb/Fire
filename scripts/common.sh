#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)"
TARGET="Fire"
PROJECT="$PROJECT_ROOT/${TARGET}.xcodeproj"
APP_NAME="业火输入法"

BUNDLE_IDENTIFIER="com.qwertyyb.inputmethod.Fire"
INSTALL_LOCATION="/Library/Input Methods"

EXPORT_PATH="$PROJECT_ROOT/dist"
EXPORT_ARCHIVE="$EXPORT_PATH/archive.xcarchive"
EXPORT_APP="$EXPORT_PATH/$TARGET.app"
EXPORT_ZIP="$EXPORT_PATH/$TARGET.zip"
EXPORT_INSTALLER="$EXPORT_PATH/FireInstaller.pkg"
EXPORT_INSTALLER_ZIP="$EXPORT_PATH/FireInstaller.zip"

if [[ $USE_CODE_SIGN == "enable" ]]
then
    echo "enable code sign"
    BUILD_FLAG=''
elif [[ $USE_CODE_SIGN == "disable" ]]
then
    echo "disable code sign"
    BUILD_FLAG='CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO'
fi

echo "BUILD_FLAG=$BUILD_FLAG"
echo "PROJECT_ROOT=$PROJECT_ROOT"
echo "EXPORT_PATH=$EXPORT_PATH"
echo "USE_CODE_SIGN=$USE_CODE_SIGN"