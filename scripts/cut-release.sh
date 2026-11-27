#!/usr/bin/env bash
# Tags the app for release. Its version is the major_version that manifest
# states on origin/main, so there is no bump to choose here: the tag is
# roku-v<major_version>, cut on origin/main once ci is green there, and
# pushing it starts release.yaml. `make deploy` runs this with the one
# component.
#
# Usage: cut-release.sh                  the version and its state
#        cut-release.sh roku             tag and push
#        cut-release.sh --check <tag>    fail unless HEAD states the tag's version
set -euo pipefail
cd "$(dirname "$0")/.."

COMPONENTS="roku"

die() { echo "error: $*" >&2; exit 1; }

# source_of <component>: the file that states its version.
source_of() {
    case "$1" in
        roku) echo manifest ;;
        *) die "unknown component '$1' (one of: $COMPONENTS)" ;;
    esac
}

# paths_of <component>: what ships in it.
paths_of() { echo manifest source components scripts/images.mjs; }

# version_at <component> <ref>
version_at() {
    local file v form='^[1-9][0-9]*$'
    file="$(source_of "$1")"
    v="$(git show "$2:$file" | sed -n 's/^major_version=//p')"
    [[ "$v" =~ $form ]] || die "$file at $2 states no version of the form $form (got '$v')"
    echo "$v"
}

# state_of <component>: one line saying whether it can be tagged. Returns 0
# when it can, 1 when there is nothing to release, 2 when its version must be
# put right first.
state_of() {
    local c="$1" v tag newest
    v="$(version_at "$c" origin/main)" || return 2
    tag="$c-v$v"
    if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
        # shellcheck disable=SC2046 # the paths are separate arguments
        if git diff --quiet "$tag" origin/main -- $(paths_of "$c"); then
            echo "$v is released and nothing in it has changed"
            return 1
        fi
        echo "changed since $tag but still says $v: raise the version in $(source_of "$c")"
        return 2
    fi
    newest="$(git tag --list "$c-v*" | sed "s/^$c-v//" | sort -V | tail -1)"
    if [ -n "$newest" ] && [ "$(printf '%s\n%s\n' "$newest" "$v" | sort -V | tail -1)" != "$v" ]; then
        echo "says $v, below the released $newest: raise the version in $(source_of "$c")"
        return 2
    fi
    echo "$v is ready: $tag"
}

if [ "${1:-}" = "--check" ]; then
    tag="${2:?usage: cut-release.sh --check <tag>}"
    c="${tag%%-v*}"
    [ "$tag" = "$c-v$(version_at "$c" HEAD)" ] || die "$tag is on a commit whose $(source_of "$c") says $(version_at "$c" HEAD)"
    exit 0
fi

confirmed=""
if [ "${!#}" = "--yes" ]; then
    confirmed=1
    set -- "${@:1:$#-1}"
fi

git fetch origin main --tags --quiet

if [ $# -eq 0 ]; then
    for c in $COMPONENTS; do
        printf '%-8s %s\n' "$c" "$(state_of "$c" || true)"
    done
    echo "usage: make deploy"
    exit 0
fi

if [ "$1" = all ]; then
    [ $# -eq 1 ] || die "usage: cut-release.sh all [--yes]"
    set --
    wrong=""
    for c in $COMPONENTS; do
        rc=0
        state="$(state_of "$c")" || rc=$?
        printf '%-8s %s\n' "$c" "$state"
        case "$rc" in
            0) set -- "$@" "$c" ;;
            2) wrong="$wrong $c" ;;
        esac
    done
    [ -z "$wrong" ] || die "nothing tagged: put right first:$wrong"
    [ $# -gt 0 ] || die "nothing is ready to release"
    [ -n "$confirmed" ] || die "nothing tagged: to tag $*, run: scripts/cut-release.sh all --yes"
fi

# Every component is checked before any tag exists, so a refusal leaves
# nothing half released.
tags=()
for c in "$@"; do
    state="$(state_of "$c")" || die "$c ${state:-states no usable version}"
    tags+=("${state##* }")
done
[ "$(printf '%s\n' "${tags[@]}" | sort -u | wc -l)" -eq ${#tags[@]} ] || die "a component is named twice"

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

# main can move while ci runs; the tags belong on the commit that run vouched for.
git fetch origin main --quiet
[ "$(git rev-parse origin/main)" = "$sha" ] || die "origin/main moved while ci ran; no tag created"

# One push per tag: GitHub starts no workflow for tags that arrive more than
# three to a push.
for tag in "${tags[@]}"; do
    git tag --annotate "$tag" --message "$tag" "$sha"
    git push origin "$tag"
    echo "pushed $tag"
done
