#!/usr/bin/env bash
set -euo pipefail

VERSION="$1"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid version: $VERSION" >&2
  exit 1
fi

PKG=packages/telnyx_webrtc
sed -i.bak -E "s/^version: .*/version: $VERSION/" "$PKG/pubspec.yaml"
sed -i.bak -E "s/(_sdkVersion = ')[^']+(';)/\1$VERSION\2/" "$PKG/lib/utils/version_utils.dart" lib/utils/version_utils.dart
rm -f "$PKG"/pubspec.yaml.bak "$PKG"/lib/utils/version_utils.dart.bak lib/utils/version_utils.dart.bak

grep -qxF "version: $VERSION" "$PKG/pubspec.yaml" || { echo "pubspec.yaml version not updated" >&2; exit 1; }
for f in "$PKG/lib/utils/version_utils.dart" lib/utils/version_utils.dart; do
  grep -qF "_sdkVersion = '$VERSION';" "$f" || { echo "$f version not updated" >&2; exit 1; }
done
