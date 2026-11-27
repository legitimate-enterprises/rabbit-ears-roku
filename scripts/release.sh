#!/usr/bin/env bash
# Signs the Roku app on the developer-mode Roku at ROKU_HOST and attaches the
# signed package to the tag's GitHub release, for the owner to upload in the
# Roku Developer Dashboard. The device holds the app's signing key and
# ROKU_SIGNING_PASSWORD is that key's password.
#
# CI only: it is what a release job for a roku-v<major_version> tag runs, with
# ROKU_HOST, ROKU_PASSWORD, ROKU_SIGNING_PASSWORD and GH_TOKEN in its
# environment.
#
#   release.sh roku-v<major_version>
set -euo pipefail
cd "$(dirname "$0")/.."

die() { echo "error: $*" >&2; exit 1; }

tag="${1:?usage: release.sh roku-v<major_version>}"
[ -n "${CI:-}" ] || die "releases are produced by CI only; cut one with: make deploy"
for var in ROKU_HOST ROKU_PASSWORD ROKU_SIGNING_PASSWORD GH_TOKEN; do
    [ -n "${!var:-}" ] || die "$var is not set"
done
version="${tag#roku-v}"
grep -qxF "major_version=$version" manifest || die "$tag is not the major_version that manifest states"

make --no-print-directory build

# quote <value>: the value as a double-quoted curl config string.
quote() {
    local v="${1//\\/\\\\}"
    printf '"%s"' "${v//\"/\\\"}"
}

page="$(mktemp)"
trap 'rm -f "$page"' EXIT

# device <curl args>: one request to the device's developer web server,
# answering its HTTP status and leaving the page in $page. Credentials go
# through a pipe, never the command line a process listing shows.
device() {
    curl --silent --show-error --digest --connect-timeout 10 --max-time 300 \
        --config <(printf 'user = %s\n' "$(quote "rokudev:$ROKU_PASSWORD")") \
        --output "$page" --write-out '%{http_code}' "$@" ||
        die "cannot reach the Roku at ROKU_HOST"
}

# failure <status>: why the device failed the request, or nothing when it
# did not. It answers most failures with 200 and a message in the page.
failure() {
    [ "$1" != 401 ] || { echo "the Roku refused ROKU_PASSWORD"; return; }
    grep -oE "(Install Failure|Failed): [^<\"']*" "$page" | head -1 || true
    [ "$1" = 200 ] || echo "HTTP $1"
}

# Wakes a Roku TV from standby through its remote-control port, which needs
# no password; a player ignores it.
curl --silent --max-time 5 -X POST "http://${ROKU_HOST%%:*}:8060/keypress/PowerOn" >/dev/null || true
# A TV woken just now drops connections to its developer web server for a
# few seconds; any answer, a 401 included, means it is up.
for _ in 1 2 3 4 5 6 7 8 9 10; do
    ! curl --silent --max-time 5 --output /dev/null "http://$ROKU_HOST/" || break
    sleep "${ROKU_WAKE_PAUSE:-3}"
done

# With no app sideloaded, any package the packager page links is one made
# from the zip installed below.
status="$(device -F mysubmit=Delete -F archive= "http://$ROKU_HOST/plugin_install")"
[ "$status" != 401 ] || die "$(failure "$status")"

status="$(device -F mysubmit=Install -F archive=@build/rabbit-ears.zip "http://$ROKU_HOST/plugin_install")"
reason="$(failure "$status")"
[ -z "$reason" ] || die "sideloading failed: $reason"

status="$(device --config <(printf 'form-string = %s\n' "$(quote "passwd=$ROKU_SIGNING_PASSWORD")") \
    -F mysubmit=Package -F "app_name=Rabbit Ears/$version" -F "pkg_time=$(date +%s)000" \
    "http://$ROKU_HOST/plugin_package")"
reason="$(failure "$status")"
[ -z "$reason" ] || die "packaging failed: $reason"
# The page's data names the package as pkgPath; a page without that data
# only links it. Several may be listed; the first is taken.
first() { grep -oE "$1" "$page" | head -1 | sed -E 's/.*"(pkgs\/[^"]+\.pkg)"$/\1/' || true; }
pkg="$(first '"pkgPath" *: *"pkgs/[^"]+\.pkg"')"
[ -n "$pkg" ] || pkg="$(first 'href="pkgs/[^"]+\.pkg"')"
[ -n "$pkg" ] || die "packaging failed: the packager page names no package"

status="$(device "http://$ROKU_HOST/$pkg")"
[ "$status" = 200 ] && [ -s "$page" ] || die "downloading the package failed: $(failure "$status")"
mv "$page" build/rabbit-ears.pkg
echo "signed build/rabbit-ears.pkg for $tag"

# A re-run finds the release its first attempt made.
notes="Upload rabbit-ears.pkg under App package in the Roku Developer Dashboard."
gh release create "$tag" build/rabbit-ears.pkg --verify-tag --title "Roku $version" --notes "$notes" ||
    gh release upload "$tag" build/rabbit-ears.pkg --clobber
