#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "$BASH_SOURCE")/.."; pwd)"
source "$PROJECT_ROOT/scripts/common.sh"

INSTALLER_ROOT="$EXPORT_PATH/installer"

BUNDLE_IDENTIFIER='com.qwertyyb.inputmethod.Fire'
INSTALL_LOCATION='/Library/Input Methods'
Version=`date "+%Y%m%d%H%M%S"`

if [[ $EXPORT_PATH == "" ]]
then
    echo "No Export Path Specificy"
    exit 1
fi
if [[ $INSTALLER_ROOT == "" ]]
then
    echo "No Installer Root Path Specificy"
    exit 1
fi

rm "$EXPORT_PATH/${TARGET}.pkg"
rm -rf "${INSTALLER_ROOT}"
mkdir -p "${INSTALLER_ROOT}"
cp -R "$EXPORT_PATH/${TARGET}.app" "${INSTALLER_ROOT}"
echo $INSTALLER_ROOT

pkgbuild \
    --info "${PROJECT_ROOT}/package/PackageInfo" \
    --root "${INSTALLER_ROOT}" \
    --component-plist "${PROJECT_ROOT}/package/component.plist" \
    --identifier "${BUNDLE_IDENTIFIER}" \
    --version "${Version}" \
    --install-location "${INSTALL_LOCATION}" \
    --scripts "${PROJECT_ROOT}/package/scripts" \
    --sign "Developer ID Installer: Yongbang Yang" \
    "$EXPORT_INSTALLER"

# pack zip for update
zip "$EXPORT_INSTALLER_ZIP" "$EXPORT_INSTALLER"

rm -rf "${ROOT_DIR}"