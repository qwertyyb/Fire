#!/bin/bash

AC_USERNAME="$apple_id"
AC_PASSWORD="$apple_id_password"
TEAM_ID=$team_id"

if [[ $AC_USERNAME == "" ]]; then
  echo "error: no username"
  exit 1
fi

if [[ $AC_PASSWORD == "" ]]; then
  echo "error: no pass"
  exit 1
fi

if [[ $TEAM_ID == "" ]]; then
  echo "error: no team id"
  exit 1
fi



PROJECT_ROOT="$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)"
source "$PROJECT_ROOT/scripts/common.sh"

PRODUCT_BUNDLE_IDENTIFIER="com.qwertyyb.inputmethod.Fire"

# Submit the finished deliverables for notarization. The "--primary-bundle-id" 
# argument is only used for the response email. 
echo "notarize app"

notarize_response=`xcrun notarytool submit ${EXPORT_INSTALLER} --apple-id "$AC_USERNAME" --password "$AC_PASSWORD" --team-id "$TEAM_ID" --wait --progress`

echo "$notarize_response"

echo "check status"

t=`echo "$notarize_response" | grep "status: Accepted"`
f=`echo "$notarize_response" | grep "Invalid"`
if [[ "$t" != "" ]]; then
    echo "notarization done!"
    xcrun stapler staple "$EXPORT_APP"
    xcrun stapler staple "$EXPORT_INSTALLER"
    echo "stapler done!"
fi
if [[ "$f" != "" ]]; then
    echo "notarization failed"
    exit 1
fi