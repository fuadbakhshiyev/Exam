#!/bin/sh
# Prints the project.yml snippet that registers Google Sign-In's URL scheme
# (REVERSED_CLIENT_ID from GoogleService-Info.plist). Does not edit any file.
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="${1:-$DIR/Imtahan/Resources/GoogleService-Info.plist}"

if [ ! -f "$PLIST" ]; then
  echo "Tapılmadı: $PLIST" >&2
  echo "GoogleService-Info.plist faylını ios/Imtahan/Resources/ qovluğuna qoyun (bax: ios/SETUP_FIREBASE.md)." >&2
  exit 1
fi

REVERSED=$(/usr/libexec/PlistBuddy -c "Print :REVERSED_CLIENT_ID" "$PLIST" 2>/dev/null || true)
if [ -z "$REVERSED" ]; then
  echo "REVERSED_CLIENT_ID plist-də yoxdur. Firebase-də Google sign-in aktiv olduqdan sonra plist-i yenidən yükləyin." >&2
  exit 1
fi

cat <<EOF
# project.yml → targets → Imtahan → info → properties altına əlavə edin:
        CFBundleURLTypes:
          - CFBundleURLName: google-signin
            CFBundleURLSchemes: [$REVERSED]
EOF
