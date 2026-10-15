#!/bin/bash
# make release — archives each platform with the release Xcode and uploads it to App Store
# Connect, one platform after another. make archive stops after the archives.
#
# Run it from your own Terminal. Signing and the upload use the Apple account in Xcode →
# Settings → Accounts, which a sandboxed shell cannot read from the keychain. Adding the
# build to each platform's version and submitting it are left to App Store Connect.
# docs/RELEASING.md has the whole release.
#
#   PLATFORMS   which to do (default: iOS tvOS visionOS macOS)
#   XCODE       the Xcode to archive with (default: /Applications/Xcode.app). Not a beta:
#               the App Store does not take what a beta Xcode builds
#   FORCE=1     go ahead with uncommitted changes, off origin/main, or a build already archived
#   UPLOAD=0    archive only

source "$(dirname "$0")/common.sh"
PLATFORMS=${PLATFORMS:-iOS tvOS visionOS macOS}
XCODE=${XCODE:-/Applications/Xcode.app}
FORCE=${FORCE:-0}
UPLOAD=${UPLOAD:-1}
export DEVELOPER_DIR="$XCODE/Contents/Developer"
[ -d "$DEVELOPER_DIR" ] || die "no Xcode at $XCODE"
version=$(setting MARKETING_VERSION) || exit 1
build=$(setting CURRENT_PROJECT_VERSION) || exit 1
archives="$HOME/Library/Developer/Xcode/Archives"

refuse() {
    if [ "$FORCE" = 1 ]; then say "warning: $* — going ahead (FORCE=1)"
    else die "$*. FORCE=1 goes ahead anyway"; fi
}

# What is uploaded is what is committed, and what is on main.
[ -z "$(git status --porcelain)" ] || refuse "there are uncommitted changes"
GIT_SSH_COMMAND="ssh -o ConnectTimeout=15 -o ServerAliveInterval=5 -o ServerAliveCountMax=3" \
    limit 60 git fetch -q origin main \
    || say "warning: could not fetch; comparing with the origin/main fetched last"
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || refuse "HEAD is not origin/main"

# App Store Connect refuses a version and build it already has: an archive of this one
# means it most likely went up before.
for p in $PLATFORMS; do
    existing=$(find "$archives" -maxdepth 2 -name "lytter-$p-$version-$build.xcarchive" 2>/dev/null | head -1)
    [ -z "$existing" ] || refuse "$p $version ($build) is already archived, at $existing; make bump first"
done

dir="$OUT/release/$version-$build"
day="$archives/$(date +%F)"   # where Xcode's Organizer finds them
mkdir -p "$dir" "$day"
say "Lytter $version ($build) at $(git rev-parse --short HEAD), $(xcodebuild -version | head -1); logs in build/release/$version-$build"

failed=""
for p in $PLATFORMS; do
    archive="$day/lytter-$p-$version-$build.xcarchive"
    say "$p: archiving"
    limit 1800 xcodebuild archive -scheme lytter -configuration Release \
        -destination "generic/platform=$p" -archivePath "$archive" -allowProvisioningUpdates \
        > "$dir/archive-$p.log" 2>&1
    if ! grep -q '\*\* ARCHIVE SUCCEEDED \*\*' "$dir/archive-$p.log"; then
        say "$p: archive FAILED — $dir/archive-$p.log"
        grep -E 'error: ' "$dir/archive-$p.log" | sort -u | head -5
        failed="$failed $p"
        continue
    fi
    if [ "$UPLOAD" != 1 ]; then say "$p: archived"; continue; fi

    say "$p: uploading"
    rm -rf "$dir/export-$p"
    # The system's tools only: Homebrew's rsync, first on PATH, fails the IPA step.
    PATH=/usr/bin:/bin:/usr/sbin:/sbin limit 1800 xcodebuild -exportArchive -archivePath "$archive" \
        -exportOptionsPlist "$ROOT/Tools/ExportOptions.plist" -exportPath "$dir/export-$p" \
        -allowProvisioningUpdates > "$dir/upload-$p.log" 2>&1
    if grep -q '\*\* EXPORT SUCCEEDED \*\*' "$dir/upload-$p.log"; then
        say "$p: uploaded"
    else
        say "$p: upload FAILED — $dir/upload-$p.log"
        grep -E 'error' "$dir/upload-$p.log" | sort -u | head -5
        failed="$failed $p"
    fi
done

[ -z "$failed" ] || die "not done:$failed. PLATFORMS=\"${failed# }\" FORCE=1 retries just those"
if [ "$UPLOAD" = 1 ]; then
    say "done. Once App Store Connect has processed it, pick $version ($build) on each platform's version page"
else
    say "done; archives in $day"
fi
