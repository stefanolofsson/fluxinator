#!/usr/bin/env bash
#
# Fluxinator — iOS/watchOS release: arkiv → export → verifiering → TestFlight
#
# Till skillnad från macOS-vägen används automatisk signering med
# -allowProvisioningUpdates. Distributionscertifikatet är molnhanterat av Xcode
# och ligger inte i nyckelringen, så det går inte att peka ut en identitet.
#
# Uppladdning kräver en App Store Connect API-nyckel:
#   1. App Store Connect → Användare och åtkomst → Integrationer → App Store
#      Connect API → generera nyckel med rollen App Manager
#   2. mkdir -p ~/.appstoreconnect/private_keys
#      mv ~/Downloads/AuthKey_*.p8 ~/.appstoreconnect/private_keys/
#   3. cp scripts/.asc-credentials.example scripts/.asc-credentials
#      och fyll i Key ID och Issuer ID (inga hemligheter — nyckelfilen är
#      hemligheten och läses direkt från katalogen ovan)
#
set -euo pipefail

# ---------------------------------------------------------------- konfiguration
PROJECT="Fluxinator.xcodeproj"
SCHEME="Fluxinator"
APP_NAME="Fluxinator"
TEAM_ID="YB7SHN8MDM"
BUNDLE_ID="com.stefanolofsson.Fluxinator"

cd "$(dirname "$0")/.."
BUILD="build"
LOGS="${BUILD}/logs"
CREDS="scripts/.asc-credentials"

DO_UPLOAD=1
DO_BUMP=0

# ----------------------------------------------------------------------- flaggor
usage() {
    cat <<EOF
Användning: scripts/release-ios.sh [flaggor]

  --skip-upload   bygg, exportera och verifiera, ladda inte upp
  --bump          räkna upp build-numret först (krävs för varje ny uppladdning,
                  App Store Connect avvisar ett build-nummer som redan finns)
  -h, --help      visa detta

Resultatet hamnar i ${BUILD}/, som är gitignorerat.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-upload) DO_UPLOAD=0 ;;
        --bump)        DO_BUMP=1 ;;
        -h|--help)     usage; exit 0 ;;
        *) echo "Okänd flagga: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# ------------------------------------------------------------------- hjälpare
step() { printf '\n\033[1;36m▸ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\n\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

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

command -v xcodebuild >/dev/null || die "xcodebuild saknas"
[ -d "$PROJECT" ]             || die "hittar inte $PROJECT (kör scriptet från repot)"
ok "projektet hittat"

if [ "$DO_UPLOAD" -eq 1 ]; then
    [ -f "$CREDS" ] || die "$CREDS saknas — kopiera ${CREDS}.example och fyll i Key ID och Issuer ID"
    # shellcheck source=/dev/null
    . "$CREDS"
    : "${ASC_KEY_ID:?ASC_KEY_ID är inte satt i $CREDS}"
    : "${ASC_ISSUER_ID:?ASC_ISSUER_ID är inte satt i $CREDS}"

    KEYFILE=""
    for d in "$HOME/.appstoreconnect/private_keys" "$HOME/private_keys" "$HOME/.private_keys" "./private_keys"; do
        if [ -f "${d}/AuthKey_${ASC_KEY_ID}.p8" ]; then KEYFILE="${d}/AuthKey_${ASC_KEY_ID}.p8"; break; fi
    done
    [ -n "$KEYFILE" ] || die "hittar inte AuthKey_${ASC_KEY_ID}.p8 i ~/.appstoreconnect/private_keys/"
    ok "API-nyckel ${ASC_KEY_ID} hittad"
fi

# ------------------------------------------------------------- versionsuppräkning
if [ "$DO_BUMP" -eq 1 ]; then
    step "Räknar upp build-numret"
    CUR=$(grep -m1 -oE 'CURRENT_PROJECT_VERSION = [0-9]+;' "${PROJECT}/project.pbxproj" | grep -oE '[0-9]+') \
        || die "kunde inte läsa CURRENT_PROJECT_VERSION"
    NEXT=$((CUR + 1))
    sed -i '' "s/CURRENT_PROJECT_VERSION = ${CUR};/CURRENT_PROJECT_VERSION = ${NEXT};/g" \
        "${PROJECT}/project.pbxproj"
    ok "build ${CUR} → ${NEXT} (alla targets)"
fi

# ------------------------------------------------------------------ läs version
read_setting() {
    xcodebuild -showBuildSettings -project "$PROJECT" -scheme "$SCHEME" \
        -configuration Release -destination 'generic/platform=iOS' 2>/dev/null \
        | awk -v k="$1" '$1==k {print $3; exit}'
}
VERSION=$(read_setting MARKETING_VERSION)
BUILDNUM=$(read_setting CURRENT_PROJECT_VERSION)
[ -n "$VERSION" ] || die "kunde inte läsa MARKETING_VERSION"

TAG="${VERSION}-${BUILDNUM}"
ARCHIVE="${BUILD}/${APP_NAME}-iOS.xcarchive"
EXPORT_DIR="${BUILD}/export-ios"
IPA="${EXPORT_DIR}/${APP_NAME}.ipa"

printf '\n  \033[1m%s %s (build %s) → TestFlight\033[0m\n' "$APP_NAME" "$VERSION" "$BUILDNUM"

# ------------------------------------------------------------------------ städa
step "Rensar tidigare bygge"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p "$LOGS"
ok "$ARCHIVE och $EXPORT_DIR rensade"

# ------------------------------------------------------------------------ arkiv
step "Arkiverar (Release, iOS + watchOS)"
run_logged "${LOGS}/ios-archive.log" \
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        -archivePath "$ARCHIVE" \
        -allowProvisioningUpdates \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="$TEAM_ID"
ok "$ARCHIVE"

# ----------------------------------------------------------------------- export
step "Exporterar för App Store Connect"
cat > "${BUILD}/ExportOptions-iOS.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>        <string>app-store-connect</string>
    <key>destination</key>   <string>export</string>
    <key>teamID</key>        <string>${TEAM_ID}</string>
    <key>signingStyle</key>  <string>automatic</string>
    <key>uploadSymbols</key> <true/>
</dict>
</plist>
PLIST

run_logged "${LOGS}/ios-export.log" \
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE" \
        -exportOptionsPlist "${BUILD}/ExportOptions-iOS.plist" \
        -exportPath "$EXPORT_DIR" \
        -allowProvisioningUpdates
[ -f "$IPA" ] || die "exporten gav ingen $IPA"
ok "$IPA ($(du -h "$IPA" | cut -f1))"

# ------------------------------------------------------------------ verifiering
step "Verifierar paketet"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
unzip -q "$IPA" -d "$WORK"
APP="${WORK}/Payload/${APP_NAME}.app"
[ -d "$APP" ] || die "ingen Payload/${APP_NAME}.app i ipa:n"

# Distributionscertifikat, inte utvecklingscertifikat.
SIGINFO=$(codesign -dv --verbose=2 "$APP" 2>&1) \
    || die "codesign kunde inte läsa $APP:
$SIGINFO"
grep -q 'Authority=Apple Distribution' <<<"$SIGINFO" \
    || die "appen är inte signerad med Apple Distribution — App Store Connect avvisar den.
  Hittade istället: $(grep -m1 '^Authority=' <<<"$SIGINFO" || echo 'ingen Authority-rad alls')"

# En utvecklingsprofil har get-task-allow = true och kan inte laddas upp.
security cms -D -i "${APP}/embedded.mobileprovision" > "${WORK}/profile.plist" 2>/dev/null \
    || die "kunde inte läsa embedded.mobileprovision"
GTA=$(plutil -extract Entitlements.get-task-allow raw "${WORK}/profile.plist" 2>/dev/null || echo "okänd")
[ "$GTA" = "false" ] \
    || die "profilen har get-task-allow = ${GTA} — det är en utvecklingsprofil och kan inte laddas upp"
PROF_NAME=$(plutil -extract Name raw "${WORK}/profile.plist" 2>/dev/null || echo "?")

# Klockappen måste följa med, annars är det bara iPhone-halvan som släpps.
[ -d "${APP}/Watch" ] && [ -n "$(ls -A "${APP}/Watch" 2>/dev/null)" ] \
    || die "klockappen är inte inbäddad i ${APP_NAME}.app/Watch"
WSIG=$(codesign -dv --verbose=2 "${APP}/Watch/"*.app 2>&1) \
    || die "codesign kunde inte läsa klockappen:
$WSIG"
grep -q 'Authority=Apple Distribution' <<<"$WSIG" \
    || die "klockappen är inte signerad med Apple Distribution.
  Hittade istället: $(grep -m1 '^Authority=' <<<"$WSIG" || echo 'ingen Authority-rad alls')"

# Utan den här nyckeln hålls bygget i "Missing Compliance" och TestFlight-
# distributionen blockeras tills frågan besvaras manuellt.
/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "${APP}/Info.plist" >/dev/null 2>&1 \
    || die "ITSAppUsesNonExemptEncryption saknas i Info.plist — TestFlight blockeras på Missing Compliance"

IPA_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${APP}/Info.plist")
[ "$IPA_ID" = "$BUNDLE_ID" ] || die "bundle-ID är $IPA_ID, förväntade $BUNDLE_ID"

ok "Apple Distribution, \"${PROF_NAME}\", klockapp inbäddad, exportkrav besvarat"

if [ "$DO_UPLOAD" -eq 0 ]; then
    step "Klart (uppladdning överhoppad)"
    printf '  %s\n\n' "$IPA"
    exit 0
fi

# ------------------------------------------------------------------ uppladdning
step "Laddar upp till App Store Connect"
warn "app-posten för $BUNDLE_ID måste finnas i App Store Connect"

if ! xcrun altool --upload-app -f "$IPA" -t ios \
        --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" \
        2>&1 | tee "${LOGS}/ios-upload.log"; then
    if grep -qi 'bundle version must be higher\|already exists' "${LOGS}/ios-upload.log"; then
        die "build ${BUILDNUM} finns redan i App Store Connect — kör om med --bump"
    fi
    die "uppladdningen misslyckades — se ${LOGS}/ios-upload.log"
fi
ok "uppladdad"

step "Klart — ${APP_NAME} ${VERSION} (build ${BUILDNUM})"
cat <<EOF
  $IPA

  Apple bearbetar bygget i 5–30 minuter innan det syns i TestFlight.
  Extern testning kräver dessutom en granskningsomgång hos Apple.
  Nästa uppladdning måste ha ett högre build-nummer: kör med --bump.

EOF
