#!/bin/sh
# Replace an installed Quiet Home with a new local build, or roll one update back.
# Input: apply|rollback HOME_SNAPSHOT_NAME UPDATE_NAME
# apply: stage .local/package.tar.gz as quiet-tizen/package.tar.gz first.
# Samsung's original assembly in the home snapshot is never touched here.
set -eu
test "$(id -u)" = 0
action=${1:?apply or rollback}; name=${2:?Home snapshot name required}; update=${3:?Update name required}
for value in "$name" "$update"; do
    case "$value" in ''|*[!A-Za-z0-9_-]*) exit 1;; esac
done
D=/opt/usr/share/quiet-tizen-backups/$name
U=$D/updates/$update
S=/home/owner/share/tmp/sdk_tools/quiet-tizen
test -s "$D/launcher-container.txt"
app=$(sed -n 1p "$D/launcher-container.txt"); assembly=$(sed -n 2p "$D/launcher-container.txt"); label=$(sed -n 3p "$D/launcher-container.txt")
for value in "$app" "$assembly"; do
    case "$value" in ''|.*|*[!A-Za-z0-9_.-]*) exit 1;; esac
done
test "$label" = "User::Pkg::$app::RO"
A=/opt/usr/apps/$app
E=$A/bin/$assembly.dll
# Stop if anything else (for example a vendor app update) replaced the installed launcher.
sha256sum -c "$D/installed-home.sha256"
test -d "$A/res/quiet-home"
test ! -e "$A/bin/.native_image"
label_tree() {
    chown 201:0 "$E"; chmod 644 "$E"; chsmack -a "$label" "$E"
    find "$A/res/quiet-home" -type d -exec chmod 755 {} \;
    find "$A/res/quiet-home" -type f -exec chmod 644 {} \;
    find "$A/res/quiet-home" -exec chown 201:0 {} \;
    find "$A/res/quiet-home" -exec chsmack -a "$label" {} \;
}
case "$action" in
apply)
    test ! -e "$U"
    test -s "$S/package.tar.gz"
    test ! -e "$S/unpacked"
    mkdir "$S/unpacked"
    tar -xzf "$S/package.tar.gz" -C "$S/unpacked"
    test "$(cat "$S/unpacked/container.txt")" = "$(printf '%s\n%s' "$app" "$assembly")"
    test -s "$S/unpacked/$assembly.dll"
    test -s "$S/unpacked/quiet-home/apps.json"
    test -s "$S/unpacked/quiet-home/home.json"
    mkdir -p "$U"
    cp -a "$E" "$U/previous.dll"
    cp "$D/installed-home.sha256" "$U/previous-installed-home.sha256"
    app_launcher -u 5001 -k "$app" || true
    mv "$A/res/quiet-home" "$U/previous-quiet-home"
    cp -R "$S/unpacked/quiet-home" "$A/res/"
    cp "$S/unpacked/$assembly.dll" "$E"
    label_tree
    sha256sum "$E" > "$D/installed-home.sha256"
    rm -rf "$S/unpacked"
    ;;
rollback)
    test -s "$U/previous.dll"
    test -d "$U/previous-quiet-home"
    test -s "$U/previous-installed-home.sha256"
    test ! -e "$U/rolled-back-quiet-home"
    app_launcher -u 5001 -k "$app" || true
    mv "$A/res/quiet-home" "$U/rolled-back-quiet-home"
    mv "$U/previous-quiet-home" "$A/res/quiet-home"
    cp -a "$U/previous.dll" "$E"
    label_tree
    cp "$U/previous-installed-home.sha256" "$D/installed-home.sha256"
    sha256sum -c "$D/installed-home.sha256"
    ;;
*) exit 1;;
esac
app_launcher -u 5001 -s "$app"
echo "Quiet Home $action complete ($update). Previous version kept in $U"
