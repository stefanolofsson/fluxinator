#!/usr/bin/env bash
#
# Fluxinator — macOS release: arkiv → export → notarisering → häftning → DMG
#
# Förutsätter en notarytool-profil i nyckelringen. Skapa den en gång med:
#   xcrun notarytool store-credentials "fluxinator-notary" \
#       --apple-id "stefan@olofsson.org" --team-id "YB7SHN8MDM"
#
set -euo pipefail

# ---------------------------------------------------------------- konfiguration
PROJECT="Fluxinator.xcodeproj"
SCHEME="Fluxinator"
APP_NAME="Fluxinator"
TEAM_ID="YB7SHN8MDM"
SIGN_ID="Developer ID Application: Stefan Olofsson (${TEAM_ID})"
NOTARY_PROFILE="fluxinator-notary"

cd "$(dirname "$0")/.."
BUILD="build"
LOGS="${BUILD}/logs"

DO_DMG=1
DO_NOTARIZE=1
DO_BUMP=0

# ----------------------------------------------------------------------- flaggor
usage() {
    cat <<EOF
Användning: scripts/release-macos.sh [flaggor]

  --no-dmg          hoppa över DMG-paketeringen
  --skip-notarize   bygg och signera bara, skicka inte in
  --bump            räkna upp build-numret (CURRENT_PROJECT_VERSION) först
  -h, --help        visa detta

Resultatet hamnar i ${BUILD}/, som är gitignorerat.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --no-dmg)        DO_DMG=0 ;;
        --skip-notarize) DO_NOTARIZE=0 ;;
        --bump)          DO_BUMP=1 ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "Okänd flagga: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# ------------------------------------------------------------------- hjälpare
step()  { printf '\n\033[1;36m▸ %s\033[0m\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
die()   { printf '\n\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# Kör ett kommando tyst, visa slutet av loggen bara om det går fel.
run_logged() {
    local log="$1"; shift
    if ! "$@" >"$log" 2>&1; then
        printf '\n\033[1;31m✗ %s misslyckades — sista 30 rader av %s:\033[0m\n' "$1" "$log" >&2
        tail -30 "$log" >&2
        exit 1
    fi
}

# --------------------------------------------------------------------- preflight
step "Förhandskontroll"

command -v xcodebuild >/dev/null || die "xcodebuild saknas — är Xcode installerat och valt med xcode-select?"
[ -d "$PROJECT" ]             || die "hittar inte $PROJECT (kör scriptet från repot)"

security find-identity -v -p codesigning 2>/dev/null | grep -qF "$SIGN_ID" \
    || die "certifikatet saknas i nyckelringen: $SIGN_ID"
ok "signeringsidentitet finns"

if [ "$DO_NOTARIZE" -eq 1 ]; then
    # Det finns ingen pålitlig lokal koll på att profilen existerar — notarytool
    # lagrar den på ett sätt som inte går att slå upp med security(1). Den
    # validerar sig själv vid insändning och ger ett tydligt fel om den saknas.
    ok "notariserar med profilen \"$NOTARY_PROFILE\""
fi

# ------------------------------------------------------------- versionsuppräkning
if [ "$DO_BUMP" -eq 1 ]; then
    step "Räknar upp build-numret"
    CUR=$(grep -m1 -oE 'CURRENT_PROJECT_VERSION = [0-9]+;' "${PROJECT}/project.pbxproj" \
          | grep -oE '[0-9]+') || die "kunde inte läsa CURRENT_PROJECT_VERSION"
    NEXT=$((CUR + 1))
    sed -i '' "s/CURRENT_PROJECT_VERSION = ${CUR};/CURRENT_PROJECT_VERSION = ${NEXT};/g" \
        "${PROJECT}/project.pbxproj"
    ok "build ${CUR} → ${NEXT} (alla targets)"
fi

# ------------------------------------------------------------------ läs version
read_setting() {
    xcodebuild -showBuildSettings -project "$PROJECT" -scheme "$SCHEME" \
        -configuration Release -destination 'generic/platform=macOS' 2>/dev/null \
        | awk -v k="$1" '$1==k {print $3; exit}'
}
VERSION=$(read_setting MARKETING_VERSION)
BUILDNUM=$(read_setting CURRENT_PROJECT_VERSION)
[ -n "$VERSION" ] || die "kunde inte läsa MARKETING_VERSION"

TAG="${VERSION}-${BUILDNUM}"
ARCHIVE="${BUILD}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD}/export"
APP="${EXPORT_DIR}/${APP_NAME}.app"
ZIP="${BUILD}/${APP_NAME}-${TAG}.zip"
DMG="${BUILD}/${APP_NAME}-${TAG}.dmg"

printf '\n  \033[1m%s %s (build %s)\033[0m\n' "$APP_NAME" "$VERSION" "$BUILDNUM"

# ------------------------------------------------------------------------ städa
step "Rensar tidigare bygge"
rm -rf "$ARCHIVE" "$EXPORT_DIR" "$ZIP" "$DMG"
mkdir -p "$LOGS"
ok "$BUILD rensat"

# ------------------------------------------------------------------------ arkiv
step "Arkiverar (Release, macOS)"
run_logged "${LOGS}/archive.log" \
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination 'generic/platform=macOS' \
        -archivePath "$ARCHIVE" \
        CODE_SIGN_STYLE=Manual \
        CODE_SIGN_IDENTITY="$SIGN_ID" \
        PROVISIONING_PROFILE_SPECIFIER="" \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        OTHER_CODE_SIGN_FLAGS="--timestamp"
ok "$ARCHIVE"

# ----------------------------------------------------------------------- export
step "Exporterar med Developer ID"
cat > "${BUILD}/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>            <string>developer-id</string>
    <key>destination</key>       <string>export</string>
    <key>teamID</key>            <string>${TEAM_ID}</string>
    <key>signingStyle</key>      <string>manual</string>
    <key>signingCertificate</key><string>${SIGN_ID}</string>
</dict>
</plist>
PLIST

run_logged "${LOGS}/export.log" \
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportOptionsPlist "${BUILD}/ExportOptions.plist" \
        -exportPath "$EXPORT_DIR"
[ -d "$APP" ] || die "exporten gav ingen $APP"
ok "$APP"

# ------------------------------------------------------------------ verifiering
step "Verifierar signaturen"
SIGINFO=$(codesign -dv --verbose=4 "$APP" 2>&1)

grep -q 'flags=.*runtime'          <<<"$SIGINFO" || die "hardened runtime är inte påslaget — notarisering kommer att avslås"
grep -qF "Authority=${SIGN_ID}"    <<<"$SIGINFO" || die "appen är inte signerad med Developer ID"
grep -q '^Timestamp='              <<<"$SIGINFO" || die "säker tidsstämpel saknas"
codesign --verify --deep --strict "$APP" 2>/dev/null || die "codesign --verify underkände bundlen"

grep -q 'com.apple.security.device.bluetooth' \
    <(codesign -d --entitlements - "$APP" 2>/dev/null) \
    || die "entitlementet com.apple.security.device.bluetooth saknas — CoreBluetooth blir blockerat av sandboxen"

ok "Developer ID, hardened runtime, tidsstämpel, bluetooth-entitlement"

if [ "$DO_NOTARIZE" -eq 0 ]; then
    step "Klart (notarisering överhoppad)"
    printf '  %s\n\n' "$APP"
    exit 0
fi

# -------------------------------------------------------------- notarisera appen
step "Notariserar appen"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
ok "$(du -h "$ZIP" | cut -f1) → Apple"

if ! xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait \
        2>&1 | tee "${LOGS}/notarize-app.log"; then
    die "insändningen misslyckades — se ${LOGS}/notarize-app.log"
fi
grep -q 'status: Accepted' "${LOGS}/notarize-app.log" || {
    SUB=$(grep -m1 -oE 'id: [0-9a-f-]{36}' "${LOGS}/notarize-app.log" | head -1 | cut -d' ' -f2 || true)
    [ -n "$SUB" ] && xcrun notarytool log "$SUB" --keychain-profile "$NOTARY_PROFILE" >&2 || true
    die "Apple godkände inte bygget"
}
ok "godkänt"

step "Häftar biljetten på appen"
xcrun stapler staple "$APP" >"${LOGS}/staple-app.log" 2>&1 || {
    tail -10 "${LOGS}/staple-app.log" >&2; die "stapler misslyckades"
}
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"      # zip om, nu med biljett
ok "$ZIP"

# ------------------------------------------------------------------------- DMG
if [ "$DO_DMG" -eq 1 ]; then
    step "Paketerar DMG"
    STAGE=$(mktemp -d)
    trap 'rm -rf "$STAGE"' EXIT
    /usr/bin/ditto "$APP" "${STAGE}/${APP_NAME}.app"
    ln -s /Applications "${STAGE}/Applications"

    run_logged "${LOGS}/dmg.log" \
        hdiutil create -volname "${APP_NAME} ${VERSION}" -srcfolder "$STAGE" \
            -ov -format UDZO -fs HFS+ "$DMG"
    codesign --sign "$SIGN_ID" --timestamp "$DMG" 2>>"${LOGS}/dmg.log" \
        || die "kunde inte signera DMG:n"
    ok "$DMG signerad"

    step "Notariserar DMG:n"
    if ! xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait \
            2>&1 | tee "${LOGS}/notarize-dmg.log"; then
        die "insändningen av DMG:n misslyckades"
    fi
    grep -q 'status: Accepted' "${LOGS}/notarize-dmg.log" || die "Apple godkände inte DMG:n"
    xcrun stapler staple "$DMG" >>"${LOGS}/dmg.log" 2>&1 || die "kunde inte häfta DMG:n"
    ok "DMG notariserad och häftad"
fi

# --------------------------------------------------------------- slutkontroller
step "Slutkontroll mot Gatekeeper"
spctl -a -t exec -vvv "$APP" 2>&1 | sed 's/^/  /'
xcrun stapler validate "$APP" >/dev/null 2>&1 && ok "biljetten sitter på appen"
if [ "$DO_DMG" -eq 1 ]; then
    xcrun stapler validate "$DMG" >/dev/null 2>&1 && ok "biljetten sitter på DMG:n"
fi

step "Klart — ${APP_NAME} ${VERSION} (build ${BUILDNUM})"
printf '  %s\n' "$APP" "$ZIP"
[ "$DO_DMG" -eq 1 ] && printf '  %s\n' "$DMG"
printf '\n'
