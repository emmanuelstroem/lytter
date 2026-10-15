#!/bin/bash
# make build — a clean build-for-testing of every platform, side by side, each in its own
# derived data. Fails if one does not build, or on any compiler warning: the build is
# warning-free, and only a clean build shows them all — an incremental one reports only
# the files it recompiles, and tvOS-only files never appear in an iOS build (AGENTS.md).
#
#   PLATFORMS   which to build (default: iOS tvOS macOS visionOS)

source "$(dirname "$0")/common.sh"
PLATFORMS=${PLATFORMS:-iOS tvOS macOS visionOS}
mkdir -p "$OUT/logs"

destination() {
    case $1 in
        macOS) echo 'platform=macOS' ;;
        *) echo "generic/platform=$1 Simulator" ;;
    esac
}

say "building $PLATFORMS with $(xcodebuild -version | head -1); logs in build/logs"
for p in $PLATFORMS; do
    limit 1800 xcodebuild clean build-for-testing -scheme lytter -destination "$(destination "$p")" \
        -derivedDataPath "$OUT/DerivedData/$p" > "$OUT/logs/build-$p.log" 2>&1 &
done
wait

failed=0
for p in $PLATFORMS; do
    log="$OUT/logs/build-$p.log"
    # The App Intents tool notes that test bundles have no intents to extract. Not a
    # compiler warning, and there on every build.
    warnings=$(grep -E '(^|: )warning: ' "$log" \
        | grep -v -E 'appintentsmetadataprocessor|Metadata extraction skipped' | sort -u)
    if ! grep -q '\*\* TEST BUILD SUCCEEDED \*\*' "$log"; then
        say "$p: FAILED — $log"
        grep -E 'error: ' "$log" | sort -u | head -5
        failed=1
    elif [ -n "$warnings" ]; then
        say "$p: built, with warnings —"
        printf '%s\n' "$warnings" | head -10
        failed=1
    else
        say "$p: built, no warnings"
    fi
done
exit $failed
