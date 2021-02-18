#!/bin/bash

AC_USERNAME="qwertyyb@qq.com"
AC_PASSWORD="ijrn-znsz-qpzt-jqse"

PROJECT_ROOT="$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)"
source "$PROJECT_ROOT/scripts/common.sh"

PRODUCT_BUNDLE_IDENTIFIER="com.qwertyyb.inputmethod.Fire"

# Submit the finished deliverables for notarization. The "--primary-bundle-id" 
# argument is only used for the response email. 
echo "notarize app"

notarize_response=`xcrun altool --notarize-app --primary-bundle-id ${PRODUCT_BUNDLE_IDENTIFIER}.pkg -u "$AC_USERNAME" -p "$AC_PASSWORD" -f "$EXPORT_INSTALLER"`

echo "$notarize_response"

uuid=`echo $notarize_response | grep -Eo '\w{8}-(\w{4}-){3}\w{12}$'`
echo "uuid=$uuid"

while true; do
    echo "checking for notarization..."
 
    r=`xcrun altool --notarization-info "$uuid" --username "$AC_USERNAME" --password "$AC_PASSWORD"`
    t=`echo "$r" | grep "success"`
    f=`echo "$r" | grep "invalid"`
    if [[ "$t" != "" ]]; then
        echo "notarization done!"
        xcrun stapler staple "$EXPORT_APP"
        xcrun stapler staple "$EXPORT_INSTALLER"
        echo "stapler done!"
        break
    fi
    if [[ "$f" != "" ]]; then
        echo "$r"
        exit 1
    fi
    echo "not finish yet, sleep 2m then check again..."
    sleep 120
done