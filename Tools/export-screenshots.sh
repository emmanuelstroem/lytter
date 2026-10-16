#!/bin/bash
#
# The App Store screenshots, from the showcase fixtures, in Danish and English:
#
#   screenshots/<locale>/<display type>/NN-<screen>.png
#
# Usage: Tools/export-screenshots.sh [iphone-6.9] [ipad-13] [apple-tv] [vision-pro]
# With no arguments it makes all four. Locales are da and en-US, App Store Connect's names.
# Not the Mac yet: its UI tests cannot run (ISSUES.md B8).
#
# AppStoreScreenshotsUITests walks the screens and, at each, writes the screenshot's name
# into a request file; this script, watching for it, takes the screenshot with `simctl io`
# and deletes the request. The visionOS simulator cannot take a screenshot from inside a
# test (B12); `simctl io` can on every platform, at the store's size.
#
# Builds with whichever Xcode `xcode-select` points at; DEVELOPER_DIR overrides it.

set -euo pipefail
cd "$(dirname "$0")/.."

OUT="screenshots"
LOCALES="da en-US"
WORK="$(mktemp -d -t lytter-screenshots)"
TIMEOUT=900
failures=0

log() { printf '\n== %s\n' "$*"; }

# The simulator named $1 on the newest runtime that has one.
udid_for() {
    xcrun simctl list devices available -j | /usr/bin/python3 -I -c '
import json, sys
name = sys.argv[1]
found = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    version = tuple(int(p) for p in runtime.rsplit(".", 1)[-1].split("-")[1:] if p.isdigit())
    found += [(version, d["udid"]) for d in devices if d["name"] == name]
print(max(found)[1] if found else "")
' "$1"
}

# Runs $@ for at most $TIMEOUT seconds. xcodebuild can sit for minutes after a failure.
with_timeout() {
    "$@" & local pid=$!
    ( sleep "$TIMEOUT"; kill "$pid" ) 2>/dev/null & local watchdog=$!
    disown "$watchdog"
    local status=0
    wait "$pid" || status=$?
    pkill -P "$watchdog" sleep 2>/dev/null || true
    return "$status"
}

# Takes a screenshot whenever the test asks for one, until killed.
serve_requests() {
    local udid=$1 requests=$2 folder=$3
    while true; do
        if [ -f "$requests/request" ]; then
            local name
            name="$(cat "$requests/request")"
            xcrun simctl io "$udid" screenshot --type=png "$folder/$name.png" >/dev/null 2>&1
            echo "   $folder/$name.png ($(sips -g pixelWidth -g pixelHeight "$folder/$name.png" \
                | awk '/pixel/ { printf "%s%s", sep, $2; sep = "×" }'))"
            rm -f "$requests/request"
        fi
        sleep 0.2
    done
}

# Boots simulator $1, dark, with full bars and battery. The clock is left alone: the
# schedule's times are real ones, and a 9:41 over a programme at 14.00 would not add up.
boot() {
    xcrun simctl boot "$1" 2>/dev/null || true
    xcrun simctl bootstatus "$1" -b >/dev/null
    xcrun simctl ui "$1" appearance dark 2>/dev/null || true
    # iOS and iPadOS only; elsewhere it fails, and nothing needs it.
    xcrun simctl status_bar "$1" override --dataNetwork wifi --wifiBars 3 \
        --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 \
        2>/dev/null || true
}

simulator() {
    local folder=$1 device=$2 test=$3
    local udid
    udid="$(udid_for "$device")"
    if [ -z "$udid" ]; then
        echo "No simulator named \"$device\"; create one in Xcode → Window → Devices." >&2
        failures=$((failures + 1)); return
    fi

    log "$folder: $device ($udid)"
    boot "$udid"

    local derived="$WORK/derived-$folder"
    echo "   building"
    if ! with_timeout xcodebuild build-for-testing -scheme lytter -destination "id=$udid" \
            -derivedDataPath "$derived" > "$WORK/$folder-build.log" 2>&1; then
        echo "   the build failed; see $WORK/$folder-build.log" >&2
        failures=$((failures + 1)); return
    fi

    for locale in $LOCALES; do
        local requests="$WORK/requests-$folder-$locale" shots="$OUT/$locale/$folder"
        rm -rf "$requests" "$shots"
        mkdir -p "$requests" "$shots"
        echo "   $locale"
        serve_requests "$udid" "$requests" "$shots" & local server=$!
        # Twice at most, restarting the simulator in between. The visionOS simulator gets
        # through one UI test session after it boots; at the next, the runner times out
        # waiting for accessibility before the test has started.
        local status attempt
        for attempt in 1 2; do
            status=0
            TEST_RUNNER_LYTTER_SCREENSHOT_DIR="$requests" \
            TEST_RUNNER_LYTTER_SCREENSHOT_LOCALE="${locale%%-*}" \
                with_timeout xcodebuild test-without-building -scheme lytter \
                    -destination "id=$udid" -derivedDataPath "$derived" \
                    -only-testing:"lytterUITests/AppStoreScreenshotsUITests/$test" \
                    -parallel-testing-enabled NO -collect-test-diagnostics never \
                    -resultBundlePath "$WORK/$folder-$locale-$attempt.xcresult" \
                    > "$WORK/$folder-$locale-$attempt.log" 2>&1 || status=$?
            [ "$status" -eq 0 ] && break
            echo "   the test failed; see $WORK/$folder-$locale-$attempt.log" >&2
            if [ "$attempt" -eq 1 ]; then
                echo "   restarting the simulator"
                xcrun simctl shutdown "$udid" 2>/dev/null || true
                boot "$udid"
            fi
        done
        kill "$server" 2>/dev/null || true
        wait "$server" 2>/dev/null || true
        [ "$status" -eq 0 ] || failures=$((failures + 1))
    done
    xcrun simctl status_bar "$udid" clear 2>/dev/null || true
}

targets="${*:-iphone-6.9 ipad-13 apple-tv vision-pro}"
for target in $targets; do
    case "$target" in
        iphone-6.9) simulator iphone-6.9 "iPhone 17 Pro Max" testPhoneAndPad ;;
        ipad-13) simulator ipad-13 "iPad Pro 13-inch (M5)" testPhoneAndPad ;;
        apple-tv) simulator apple-tv "Apple TV 4K (3rd generation) (at 1080p)" testAppleTV ;;
        vision-pro) simulator vision-pro "Apple Vision Pro" testVisionPro ;;
        *) echo "Unknown display type: $target" >&2; exit 2 ;;
    esac
done

log "done: $OUT/ (logs in $WORK)"
[ "$failures" -eq 0 ] || { echo "$failures step(s) failed" >&2; exit 1; }
