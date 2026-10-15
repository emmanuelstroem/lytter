# Shared by the scripts behind the Makefile: test.sh, build.sh, bump-build.sh, release.sh.
# Sourced, not run.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
# Logs, derived data, result bundles and exports. Gitignored.
OUT="$ROOT/build"

say() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { echo "error: $*" >&2; exit 1; }

# Runs a command with a time limit in seconds; macOS has no timeout(1). A test run that
# fails can otherwise sit for ten minutes collecting diagnostics, which looks like a hang.
limit() { local seconds=$1; shift; perl -e 'alarm shift; exec @ARGV' "$seconds" "$@"; }

# The value a build setting has in every target of the app's project. Fails if the targets
# disagree, as a build number raised in some targets and not others would.
setting() {
    local values
    values=$(grep -E "^[[:space:]]*$1 = " lytter.xcodeproj/project.pbxproj \
        | sed -E "s/.*$1 = \"?([^\";]*)\"?;.*/\1/" | sort -u)
    [ -n "$values" ] || { echo "error: no $1 in the project" >&2; return 1; }
    [ "$(printf '%s\n' "$values" | wc -l | tr -d ' ')" = 1 ] \
        || { echo "error: $1 differs between targets:" $values >&2; return 1; }
    printf '%s' "$values"
}
