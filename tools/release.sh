#!/bin/zsh
# Archives Dawnfold and uploads it to App Store Connect, signing with an App Store Connect API key.
#
#   ASC_KEY_ID=… ASC_ISSUER_ID=… tools/release.sh [build number]
#
# The key file is read from ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8 (or ASC_KEY_PATH).
# The build number defaults to a timestamp so every upload is unique.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
key_path=${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}
build=${1:-$(date +%Y%m%d%H%M)}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

auth=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$key_path"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

echo "Archiving build $build…"
xcodebuild -project Firstlight.xcodeproj -scheme Firstlight -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$work/Dawnfold.xcarchive" \
  CURRENT_PROJECT_VERSION="$build" "${auth[@]}" archive -quiet

cat > "$work/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>upload</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>2TWQYRZUDF</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
</dict>
</plist>
PLIST

echo "Uploading…"
xcodebuild -exportArchive -archivePath "$work/Dawnfold.xcarchive" \
  -exportOptionsPlist "$work/ExportOptions.plist" -exportPath "$work/export" "${auth[@]}"
echo "Uploaded build $build. It appears in App Store Connect › TestFlight after processing."
