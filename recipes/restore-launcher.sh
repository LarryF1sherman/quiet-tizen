#!/bin/sh
# SNAPSHOT_NAME ORIGINAL_MAIN_OPERATION_APP ORIGINAL_HOME_APP ORIGINAL_STARTUP_APP
# Read all three original IDs from that TV's saved records; do not guess them.
set -eu
test "$(id -u)" = 0
name=${1:?}; operation=${2:?}; home=${3:?}; startup=${4:?}
case "$name" in ''|*[!A-Za-z0-9_-]*) exit 1;; esac
for app in "$operation" "$home" "$startup"; do
    case "$app" in ''|*[!A-Za-z0-9_.-]*) exit 1;; esac
done
D=/opt/usr/share/quiet-tizen-backups/$name
if [ -s "$D/launcher-container.txt" ]; then
    app=$(sed -n 1p "$D/launcher-container.txt"); assembly=$(sed -n 2p "$D/launcher-container.txt")
    label=$(sed -n 3p "$D/launcher-container.txt"); original=$D/home-original.dll
    test "$(sha256sum "$original" | cut -d ' ' -f 1)" = "$(cut -d ' ' -f 1 "$D/home-original.sha256")"
else
    # Layout written by the first U8000F release.
    app=com.samsung.tv.bixby-promotion; assembly=BixbyPromotion
    label=User::Pkg::$app::RO; original=$D/bixby-promotion-original/bin/BixbyPromotion.dll
fi
for value in "$app" "$assembly"; do
    case "$value" in ''|.*|*[!A-Za-z0-9_.-]*) exit 1;; esac
done
A=/opt/usr/apps/$app
test -s "$D/Probe.dll"
test -s "$original"
test -s "$D/.pkgmgr_parser.db"
sha256sum -c "$D/installed-home.sha256"
/usr/bin/dotnet "$D/Probe.dll" set-home "$operation"
vconftool set -f -t string db/appfw/home_appid "$home"
vconftool set -f -t string db/appfw/startup_appid "$startup"
app_launcher -u 5001 -k "$app" || true
cp -a "$original" "$A/bin/$assembly.dll"
chsmack -a "$label" "$A/bin/$assembly.dll"
if [ -d "$D/home-native-image" ]; then
    test ! -e "$A/bin/.native_image"
    cp -a "$D/home-native-image" "$A/bin/.native_image"
fi
sqlite3 -bail /opt/dbspace/.pkgmgr_parser.db <<SQL
ATTACH '$D/.pkgmgr_parser.db' AS before;
BEGIN IMMEDIATE;
CREATE TEMP TABLE guard(ok INTEGER CHECK(ok=1));
INSERT INTO guard SELECT count(*)=1 FROM before.package_app_info WHERE app_id='$app';
INSERT INTO guard SELECT count(*)=1 FROM package_app_info WHERE app_id='$app';
UPDATE package_app_info SET
app_disable=(SELECT app_disable FROM before.package_app_info WHERE app_id='$app'),
app_onboot=(SELECT app_onboot FROM before.package_app_info WHERE app_id='$app'),
app_autorestart=(SELECT app_autorestart FROM before.package_app_info WHERE app_id='$app')
WHERE app_id='$app';
DROP TABLE guard;
COMMIT;
SQL
app_launcher -u 5001 -s "$home"
echo 'Original launcher routing and assembly restored. Extra Quiet Home resources remain inert for recovery.'
