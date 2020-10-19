#!/bin/bash

cd "$(dirname $0)"
PROJECT_ROOT=$(cd ..; pwd)

BUNDLE_IDENTIFIER='com.qwertyyb.inputmethod.Fire'
INSTALL_LOCATION='/Library/Input Methods'
BUILD_DIR="${PROJECT_ROOT}"
TARGET='Fire'
Version=`date "+%Y%m%d%H%M%S"`
ROOT_DIR="${PROJECT_ROOT}/apps/root/"

rm "${PROJECT_ROOT}/package/${TARGET}-*.pkg"
rm -rf "${ROOT_DIR}"
mkdir -p "${ROOT_DIR}"
cp -R "${PROJECT_ROOT}/apps/${TARGET}.app" "${ROOT_DIR}"
echo $ROOT_DIR

pkgbuild \
    --info "${PROJECT_ROOT}/package/PackageInfo" \
    --root "${ROOT_DIR}" \
    --identifier "${BUNDLE_IDENTIFIER}" \
    --version "${Version}" \
    --install-location "${INSTALL_LOCATION}" \
    --scripts "${PROJECT_ROOT}/package/scripts" \
    "${PROJECT_ROOT}/apps/FireInstaller.pkg"

# clean

rm -rf "${ROOT_DIR}"