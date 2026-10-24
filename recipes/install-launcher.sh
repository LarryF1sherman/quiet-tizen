#!/bin/sh
# Install only. Home/startup routing is changed AFTER manual launch is verified.
# Input: SNAPSHOT_NAME CONTAINER_APP_ID ENTRY_ASSEMBLY (the profile's "launcher" values).
# Stage .local/package.tar.gz as quiet-tizen/package.tar.gz first.
set -eu
test "$(id -u)" = 0
name=${1:?Snapshot name required}; app=${2:?Container app ID required}; assembly=${3:?Entry assembly required}
case "$name" in ''|*[!A-Za-z0-9_-]*) exit 1;; esac
for value in "$app" "$assembly"; do
    case "$value" in ''|.*|*[!A-Za-z0-9_.-]*) exit 1;; esac
done
D=/opt/usr/share/quiet-tizen-backups/$name
A=/opt/usr/apps/$app
E=$A/bin/$assembly.dll
S=/home/owner/share/tmp/sdk_tools/quiet-tizen
test -s "$D/.pkgmgr_parser.db"
test -s "$S/package.tar.gz"
# The container must be the app whose registered entry point we replace.
test "$(sqlite3 -readonly /opt/dbspace/.pkgmgr_parser.db "SELECT count(*) FROM package_app_info WHERE app_id='$app' AND app_exec='$E';")" = 1
test -s "$E"
test "$(stat -c %u:%g "$E")" = 201:0
label=$(chsmack "$E" | sed -n 's/.* access="\([^"]*\)".*/\1/p')
test "$label" = "User::Pkg::$app::RO"
test ! -e "$D/launcher-container.txt"
test ! -e "$A/res/quiet-home" # First install only; do not silently overwrite an existing custom launcher.
test ! -e "$S/unpacked"
# The archive is generated from our local build, not downloaded from an unknown party.
mkdir "$S/unpacked"
tar -xzf "$S/package.tar.gz" -C "$S/unpacked"
test "$(cat "$S/unpacked/container.txt")" = "$(printf '%s\n%s' "$app" "$assembly")"
test -s "$S/unpacked/$assembly.dll"
test -s "$S/unpacked/Probe.dll"
test -s "$S/unpacked/quiet-home/apps.json"
# A copy left by an interrupted attempt is kept, never overwritten, if it still matches.
if [ ! -e "$D/home-original.dll" ]; then cp -a "$E" "$D/home-original.dll"; fi
test "$(sha256sum < "$E")" = "$(sha256sum < "$D/home-original.dll")"
sha256sum "$D/home-original.dll" > "$D/home-original.sha256"
printf '%s\n%s\n%s\n' "$app" "$assembly" "$label" > "$D/launcher-container.txt"
cp "$S/unpacked/Probe.dll" "$D/Probe.dll"
/usr/bin/dotnet "$D/Probe.dll" > "$D/operation-and-sources-before.txt"
app_launcher -u 5001 -k "$app" || true
if [ -d "$A/bin/.native_image" ]; then mv "$A/bin/.native_image" "$D/home-native-image"; fi
cp "$S/unpacked/$assembly.dll" "$E"
cp -R "$S/unpacked/quiet-home" "$A/res/"
chown 201:0 "$E"
chmod 644 "$E"
chsmack -a "$label" "$E"
sha256sum "$E" > "$D/installed-home.sha256"
find "$A/res/quiet-home" -type d -exec chmod 755 {} \;
find "$A/res/quiet-home" -type f -exec chmod 644 {} \;
find "$A/res/quiet-home" -exec chown 201:0 {} \;
find "$A/res/quiet-home" -exec chsmack -a "$label" {} \;
sqlite3 -bail /opt/dbspace/.pkgmgr_parser.db <<SQL
BEGIN IMMEDIATE;
CREATE TEMP TABLE guard(ok INTEGER CHECK(ok=1));
INSERT INTO guard SELECT count(*)=1 FROM package_app_info WHERE app_id='$app';
UPDATE package_app_info SET app_disable='false',app_onboot='false',app_autorestart='false' WHERE app_id='$app';
DROP TABLE guard;
COMMIT;
SQL
app_launcher -u 5001 -s "$app"
echo 'Installed and launch requested. Verify the visible UI, remote, sound, apps and HDMI before changing Home routing.'
echo "Original assembly and operation/source record: $D"
