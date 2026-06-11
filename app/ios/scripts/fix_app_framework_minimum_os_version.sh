#!/bin/sh
# Ensure App.framework Info.plist has MinimumOSVersion for App Store validation.
# Must match Flutter's App binary deployment target (currently 13.0), not the
# app's IPHONEOS_DEPLOYMENT_TARGET.
set -eu

APP_FRAMEWORK_PLIST="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/App.framework/Info.plist"
MIN_OS_VERSION="13.0"

if [ ! -f "$APP_FRAMEWORK_PLIST" ]; then
  exit 0
fi

CURRENT="$(/usr/libexec/PlistBuddy -c "Print:MinimumOSVersion" "$APP_FRAMEWORK_PLIST" 2>/dev/null || true)"
if [ -z "$CURRENT" ]; then
  /usr/libexec/PlistBuddy -c "Add:MinimumOSVersion string ${MIN_OS_VERSION}" "$APP_FRAMEWORK_PLIST"
else
  /usr/libexec/PlistBuddy -c "Set:MinimumOSVersion ${MIN_OS_VERSION}" "$APP_FRAMEWORK_PLIST"
fi
