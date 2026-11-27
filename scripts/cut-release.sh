#!/usr/bin/env bash
# Tags the app for release. Its version is M.m.N: M.m is the
# major_version.minor_version that manifest states on origin/main, which only
# the owner raises, and N is the count of commits on origin/main, so there is
# no bump to choose here: the tag is v<version>, cut on origin/main once ci is
# green there, and pushing it starts release.yaml.
#
# Usage: cut-release.sh                  the version and its state
#        cut-release.sh --yes            tag and push
#        cut-release.sh --check <tag>    fail unless the tag is HEAD's version
set -euo pipefail
cd "$(dirname "$0")/.."

SOURCE=manifest
# What ships.
PATHS="manifest source components scripts/images.mjs"

die() { echo "error: $*" >&2; exit 1; }

# version_at <ref>
version_at() {
    local text v form='^[0-9]+\.[0-9]+$'
    [ "$(git rev-parse --is-shallow-repository)" = false ] ||
        die "a shallow clone cannot count commits; fetch the full history"
    text="$(git show "$1:$SOURCE")"
    v="$(sed -n 's/^major_version=//p' <<< "$text").$(sed -n 's/^minor_version=//p' <<< "$text")"
    [[ "$v" =~ $form ]] || die "$SOURCE at $1 states no major_version.minor_version of the form $form (got '$v')"
    echo "$v.$(git rev-list --count "$1")"
}

# state_of: one line saying whether origin/main can be tagged. Returns 0 when
# it can, 1 when there is nothing to release, 2 when the version must be put
# right first.
state_of() {
    local v tag newest
    v="$(version_at origin/main)" || return 2
    tag="v$v"
    if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
        echo "$v is released"
        return 1
    fi
    newest="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' | sed 's/^v//' | sort -V | tail -1)"
    if [ -n "$newest" ] && [ "$(printf '%s\n%s\n' "$newest" "$v" | sort -V | tail -1)" != "$v" ]; then
        echo "says $v, below the released $newest: the owner raises major_version or minor_version in $SOURCE"
        return 2
    fi
    # shellcheck disable=SC2086 # the paths are separate arguments
    if [ -n "$newest" ] && git diff --quiet "v$newest" origin/main -- $PATHS; then
        echo "nothing in the app has changed since v$newest"
        return 1
    fi
    echo "$v is ready: $tag"
}

if [ "${1:-}" = "--check" ]; then
    tag="${2:?usage: cut-release.sh --check <tag>}"
    v="$(version_at HEAD)"
    [ "$tag" = "v$v" ] || die "$tag is not v$v, the version of HEAD"
    exit 0
fi

confirmed=""
case "$*" in
    "") ;;
    --yes) confirmed=1 ;;
    *) die "usage: cut-release.sh [--yes] | --check <tag>" ;;
esac

git fetch origin main --tags --quiet

rc=0
state="$(state_of)" || rc=$?
[ -z "$state" ] || echo "$state"
case "$rc" in
    1) [ -z "$confirmed" ] || die "nothing is ready to release"; exit 0 ;;
    2) die "nothing tagged: put the version right first" ;;
esac
tag="${state##* }"
[ -n "$confirmed" ] || { echo "usage: make deploy"; exit 0; }

# A tag is a promise that its commit passed ci, so the check comes before
# the tag exists; release.yaml asserts it again and never waits, because a
# release job waiting on ci would hold a runner ci needs.
sha="$(git rev-parse origin/main)"
echo "tagging origin/main at ${sha:0:8}: $(git log -1 --format=%s "$sha")"
command -v gh >/dev/null 2>&1 || die "gh is required to verify ci before tagging (brew install gh)"

# A run record appears a beat after the push that created it.
deadline=$((SECONDS + 120))
while :; do
    run="$(gh run list --workflow ci.yaml --branch main --commit "$sha" --limit 1 \
        --json databaseId,status,conclusion,url \
        --jq '.[0] // empty | [.databaseId, .status, .conclusion // "pending", .url] | @tsv')" ||
        die "could not query ci runs; check 'gh auth status'"
    [ -n "$run" ] && break
    [ "$SECONDS" -lt "$deadline" ] || die "no ci run for ${sha:0:8} on main after 120s; is the commit pushed?"
    sleep 5
done
IFS=$'\t' read -r run_id run_status run_conclusion run_url <<< "$run"

if [ "$run_status" != "completed" ]; then
    echo "waiting for ci on ${sha:0:8}: $run_url"
    gh run watch "$run_id" --exit-status || die "ci failed; no tag created: $run_url"
elif [ "$run_conclusion" != "success" ]; then
    die "ci concluded '$run_conclusion'; no tag created: $run_url"
fi

# main can move while ci runs; the tag belongs on the commit that run vouched for.
git fetch origin main --quiet
[ "$(git rev-parse origin/main)" = "$sha" ] || die "origin/main moved while ci ran; no tag created"

git tag --annotate "$tag" --message "$tag" "$sha"
git push origin "$tag"
echo "pushed $tag"
