# Lytter's everyday commands. Each one is a script in Tools/; docs/RELEASING.md has the
# whole release, from raising the build number to picking the build in App Store Connect.
#
#   make test                 unit tests on iPhone, iPad, Vision Pro and Mac; iPhone and
#                             tvOS UI tests
#   make build                clean build of every platform; fails on a compiler warning
#   make bump                 raise the build number by one in every target
#   make release              archive every platform and upload it to App Store Connect
#
# Narrow a run with variables, e.g.
#   make test PLATFORMS=iphone ONLY=lytterTests/AudioSessionPolicyTests
#   make release PLATFORMS=tvOS

.DEFAULT_GOAL := help
.PHONY: help test build bump archive release

help: ## List the commands
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

test: ## Unit tests on iPhone, iPad, Vision Pro and Mac; iPhone and tvOS UI tests
	@Tools/test.sh

build: ## Clean build of every platform; fails on a compiler warning
	@Tools/build.sh

bump: ## Raise the build number by one in every target
	@Tools/bump-build.sh

archive: ## Archive every platform with the release Xcode, without uploading
	@UPLOAD=0 Tools/release.sh

release: ## Archive every platform and upload it to App Store Connect
	@Tools/release.sh
