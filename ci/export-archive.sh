#!/usr/bin/env bash
# Exports an archive for App Store Connect, uploading it when UPLOAD=true (used by testflight.yml).
#   ci/export-archive.sh <archive-path> <export-path>
# iOS archives export an .ipa, Mac Catalyst archives a .pkg.
# Env: ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID, UPLOAD (true = upload, anything else = export only).
set -euo pipefail

archive="${1:?usage: export-archive.sh <archive-path> <export-path>}"
export_path="${2:?usage: export-archive.sh <archive-path> <export-path>}"
name=$(basename "$archive" .xcarchive)

options="build/ExportOptions-$name.plist"
cp ci/ExportOptions.plist "$options"
if [[ "${UPLOAD:-}" == "true" ]]; then
  /usr/libexec/PlistBuddy -c "Set :destination upload" "$options"
  echo "Exporting $name and uploading to App Store Connect"
else
  echo "Dry run: exporting $name only"
fi

xcodebuild -exportArchive \
  -archivePath "$archive" \
  -exportOptionsPlist "$options" \
  -exportPath "$export_path" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  | tee "build/xcodebuild-export-$name.log"
