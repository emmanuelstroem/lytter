#!/bin/bash
# make test — the unit tests (lytterTests) on an iPhone, an iPad, a Vision Pro and the Mac,
# and the tvOS scrolling UI tests on an Apple TV: lytterTests does not run on tvOS, and on
# tvOS a list that does not scroll under the remote is the bug that has shipped (AGENTS.md).
# The platforms run side by side; iPhone and iPad share one build.
#
#   PLATFORMS   which to run, from: iphone ipad vision mac tv (default: all five)
#   ONLY        what to run instead, as -only-testing takes it, space-separated:
#               ONLY=lytterTests/AudioSessionPolicyTests
#   IPHONE, IPAD, VISION, TV   simulator names, on the newest runtime that has them

source "$(dirname "$0")/common.sh"
PLATFORMS=${PLATFORMS:-iphone ipad vision mac tv}
ONLY=${ONLY:-}
# A regular iPhone, not a Pro Max: the widest screen has room for text that a regular one
# truncates, so a test there passes over what most people will see.
IPHONE=${IPHONE:-iPhone 17}
IPAD=${IPAD:-iPad Pro 13-inch (M5)}
VISION=${VISION:-Apple Vision Pro}
TV=${TV:-Apple TV 4K (3rd generation) (at 1080p)}
stamp=$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT/logs" "$OUT/test-results"

wants() { [[ " $PLATFORMS " == *" $1 "* ]]; }

# One xcodebuild per build: its name, then its arguments.
run() {
    local name=$1 default=$2; shift 2
    local filters=()
    for t in ${ONLY:-$default}; do filters+=("-only-testing:$t"); done
    say "$name: testing"
    limit 2400 xcodebuild test -scheme lytter "$@" "${filters[@]}" \
        -derivedDataPath "$OUT/DerivedData/$name" -collect-test-diagnostics never \
        -resultBundlePath "$OUT/test-results/$name-$stamp.xcresult" \
        > "$OUT/logs/test-$name.log" 2>&1
}

ran=()
ios=()
wants iphone && ios+=(-destination "platform=iOS Simulator,name=$IPHONE,OS=latest")
wants ipad && ios+=(-destination "platform=iOS Simulator,name=$IPAD,OS=latest")
if [ ${#ios[@]} -gt 0 ]; then run iOS lytterTests "${ios[@]}" & ran+=(iOS); fi
if wants vision; then
    run visionOS lytterTests -destination "platform=visionOS Simulator,name=$VISION,OS=latest" &
    ran+=(visionOS)
fi
if wants mac; then run macOS lytterTests -destination 'platform=macOS' & ran+=(macOS); fi
if wants tv; then
    # One at a time: the remote drives a single focused app.
    run tvOS lytterUITests/TVScrollingUITests -parallel-testing-enabled NO \
        -destination "platform=tvOS Simulator,name=$TV,OS=latest" &
    ran+=(tvOS)
fi
[ ${#ran[@]} -gt 0 ] || die "PLATFORMS names none of: iphone ipad vision mac tv"
wait

failed=0
for name in "${ran[@]}"; do
    log="$OUT/logs/test-$name.log"
    passed=$(grep -c -E "^Test [Cc]ase .*' passed" "$log")
    if grep -q '\*\* TEST SUCCEEDED \*\*' "$log"; then
        say "$name: passed ($passed)"
    else
        say "$name: FAILED — $log"
        grep -E "^Test [Cc]ase .*' failed|xcodebuild: error|error: " "$log" | sort -u | head -10
        failed=1
    fi
done
[ $failed = 0 ] || say "result bundles, with each failure's screenshot: build/test-results"
exit $failed
