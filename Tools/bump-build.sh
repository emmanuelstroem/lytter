#!/bin/bash
# make bump — raises the build number (CURRENT_PROJECT_VERSION) by one in every target, or
# to BUILD=n. App Store Connect takes a version and build once, so every upload needs a new
# one. Only edits the project; commit it on a release branch (docs/RELEASING.md).

source "$(dirname "$0")/common.sh"
version=$(setting MARKETING_VERSION) || exit 1
old=$(setting CURRENT_PROJECT_VERSION) || exit 1
[[ $old =~ ^[0-9]+$ ]] || die "the build number is \"$old\", not a whole number"
new=${BUILD:-$((old + 1))}
[[ $new =~ ^[0-9]+$ ]] && [ "$new" -gt "$old" ] || die "build $new is not above $old"

sed -i '' -E "s/(CURRENT_PROJECT_VERSION = )$old;/\1$new;/" lytter.xcodeproj/project.pbxproj
[ "$(setting CURRENT_PROJECT_VERSION)" = "$new" ] || die "not every target took build $new"
say "$version ($old) → $version ($new) in $(grep -c "CURRENT_PROJECT_VERSION = $new;" \
    lytter.xcodeproj/project.pbxproj) build configurations"
