#!/usr/bin/env bash
# Archives a Release build and exports it for App Store Connect; uploads to TestFlight when UPLOAD=true.
# Used by bitrise.yml. Same signing as .github/workflows/testflight.yml: the archive is signed with the
# one stored Apple Development certificate (installed into the keychain beforehand by Bitrise's
# certificate-and-profile-installer step from the Code Signing tab), never a new one; export uses
# cloud-managed distribution signing through the App Store Connect API key.
#
# Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (raw .p8 text or base64), TEAM_ID,
#      BUILD_NUMBER (optional, empty = next free number on App Store Connect),
#      UPLOAD (true = upload to TestFlight, anything else = archive and export only).
set -euo pipefail
cd "$(dirname "$0")/.."

for name in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8 TEAM_ID; do
  [[ -n "${!name:-}" ]] || { echo "$name is not set"; exit 1; }
done

identities=$(security find-identity -v -p codesigning)
echo "$identities"
grep -q '"Apple Development' <<<"$identities" \
  || { echo "No Apple Development identity in the keychain: upload the stored .p12 to Bitrise's Code Signing tab"; exit 1; }

key_dir=$(mktemp -d)
key_path="$key_dir/AuthKey_${ASC_KEY_ID}.p8"
trap 'rm -rf "$key_dir"' EXIT
if [[ "$ASC_KEY_P8" == *"BEGIN PRIVATE KEY"* ]]; then
  printf '%s\n' "$ASC_KEY_P8" > "$key_path"
else
  echo "$ASC_KEY_P8" | base64 --decode > "$key_path"
fi
grep -q "BEGIN PRIVATE KEY" "$key_path" || { echo "ASC_KEY_P8 is not a valid .p8 key"; exit 1; }
export ASC_KEY_PATH="$key_path" # read by ci/next-build-number.rb
auth=(-allowProvisioningUpdates
      -authenticationKeyPath "$key_path"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

settings=$(xcodebuild -project Skarnik.xcodeproj -target Skarnik -configuration Release -showBuildSettings 2>/dev/null)
version=$(awk -F' = ' '/ MARKETING_VERSION = /{print $2; exit}' <<<"$settings")
project_build=$(awk -F' = ' '/ CURRENT_PROJECT_VERSION = /{print $2; exit}' <<<"$settings")
bundle_id=$(awk -F' = ' '/ PRODUCT_BUNDLE_IDENTIFIER = /{print $2; exit}' <<<"$settings")
build="${BUILD_NUMBER:-}"
if [[ -z "$build" ]]; then
  # Next free number on App Store Connect, never below the project's own build number.
  build=$(ruby ci/next-build-number.rb "$bundle_id" "$project_build")
fi
echo "Building Skarnik $version ($build)"

mkdir -p build
set -o pipefail
xcodebuild archive \
  -project Skarnik.xcodeproj \
  -scheme Skarnik \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Skarnik.xcarchive \
  -derivedDataPath build/DerivedData \
  -clonedSourcePackagesDirPath build/SourcePackages \
  "${auth[@]}" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_IDENTITY="Apple Development" \
  PROVISIONING_PROFILE_SPECIFIER= \
  CURRENT_PROJECT_VERSION="$build" \
  | tee build/xcodebuild-archive.log

cp ci/ExportOptions.plist build/ExportOptions.plist
if [[ "${UPLOAD:-}" == "true" ]]; then
  /usr/libexec/PlistBuddy -c "Set :destination upload" build/ExportOptions.plist
  echo "Exporting and uploading to App Store Connect"
else
  echo "Dry run: exporting the .ipa only"
fi
xcodebuild -exportArchive \
  -archivePath build/Skarnik.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export \
  "${auth[@]}" \
  | tee build/xcodebuild-export.log

if [[ "${UPLOAD:-}" == "true" ]]; then
  echo "Uploaded Skarnik $version ($build) to TestFlight. It shows up in App Store Connect after processing."
else
  echo "Dry run: archive and export of Skarnik $version ($build) succeeded, nothing uploaded."
fi
(cd build/Skarnik.xcarchive && zip -qry ../dSYMs.zip dSYMs)
