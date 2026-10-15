# Testing, building and releasing Lytter

_Companion docs: [APP-STORE.md](APP-STORE.md) (the store record, its text, screenshots and
review) · [AGENTS.md](../AGENTS.md) (the working rules these commands follow)_

---

## 1. The commands

From the repository's root:

| Command | What it does | Takes |
| --- | --- | --- |
| `make test` | The unit tests on an iPhone, an iPad, a Vision Pro and the Mac; the tvOS scrolling UI tests on an Apple TV | About seven minutes |
| `make build` | A clean build of iOS, tvOS, macOS and visionOS, side by side; fails on any compiler warning | About a minute and a half |
| `make bump` | Raises the build number by one in every target | Instant |
| `make archive` | Archives every platform with the release Xcode, without uploading | A few minutes |
| `make release` | Archives every platform and uploads it to App Store Connect | A few minutes a platform |

`make` alone lists them. Each is a script in [`Tools/`](../Tools); logs, derived data,
result bundles and exports go to `build/`, which git ignores.

Variables narrow a run:

```bash
make test PLATFORMS="iphone mac" ONLY=lytterTests/AudioSessionPolicyTests
make build PLATFORMS=tvOS
make bump BUILD=7
make release PLATFORMS=visionOS
```

- `make test`: `PLATFORMS` from `iphone ipad vision mac tv`. `ONLY` takes what
  `-only-testing` takes, space-separated. `IPHONE`, `IPAD`, `VISION` and `TV` name other
  simulators; each runs on the newest runtime that has it.
- `make build`: `PLATFORMS` from `iOS tvOS macOS visionOS`.
- `make release`: `PLATFORMS` from `iOS tvOS visionOS macOS`. `XCODE` is the Xcode to
  archive with, `/Applications/Xcode.app` by default. `FORCE=1` goes past the checks in §3.

`make test` and `make build` use the selected Xcode (`xcode-select -p`), as development
does. `make archive` and `make release` always use the release Xcode: the App Store does
not take what a beta Xcode builds.

## 2. A release, from start to finish

1. **A new build number.** App Store Connect takes each version and build once.
   On a branch from `main`:
   ```bash
   git switch --no-track -c release/1.0-build-3 origin/main
   make bump
   ```
   Commit `lytter.xcodeproj/project.pbxproj` as `chore(release): build 1.0 (3)`, open a pull
   request, and squash-merge it. A new version rather than a new build is
   `MARKETING_VERSION`, changed in Xcode.
2. **Check main.** With `main` checked out, up to date and clean:
   ```bash
   make build
   make test
   ```
3. **Upload**, from your own Terminal:
   ```bash
   make release
   ```
   Your own Terminal because signing and the upload use the Apple account in Xcode →
   Settings → Accounts, which a sandboxed shell (an agent's, for one) cannot read from the
   keychain. Each platform is archived and uploaded in turn. The archives go to
   `~/Library/Developer/Xcode/Archives/<date>/lytter-<platform>-<version>-<build>.xcarchive`,
   where Xcode's Organizer shows them; the logs go to `build/release/<version>-<build>/`.
4. **In App Store Connect.** Each platform's build is processed, from a few minutes to an
   hour, and Apple emails when it is ready. Then pick it on that platform's version page,
   for TestFlight or the version itself. Submitting for review is in
   [APP-STORE.md](APP-STORE.md); no script does it.

## 3. What `make release` checks

It stops, unless `FORCE=1`, when:

- **there are uncommitted changes.** What is uploaded must be what is committed.
- **HEAD is not `origin/main`.** It fetches `main` first; if the fetch fails, it compares with
  the `origin/main` fetched last and says so.
- **this version and build is already archived for a platform.** App Store Connect refuses a
  build it already has, so an archive of it means it most likely went up before: `make bump`.

It also keeps the build number as it is. `Tools/ExportOptions.plist` turns off Xcode's
`manageAppVersionAndBuildNumber`, which would otherwise renumber a build whose number is
taken. The upload would then no longer match its archive.

## 4. When something goes wrong

- **One platform failed and the others went up.** The last line names the ones that
  failed: `make release PLATFORMS=tvOS FORCE=1` retries just those. `FORCE` because the
  failed platform may have been archived already.
- **"App Store Connect access for A9Q5VPE9WX is required".** The release Xcode is not
  signed in: Xcode → Settings → Accounts, then add the Apple account of team A9Q5VPE9WX.
- **"Copy failed" while exporting.** A tool from Homebrew was used in place of the system's.
  The script runs the export with `PATH` set to the system's directories only, so this
  means it was run some other way.
- **The build number is taken.** `make bump`, then the release from step 1.
- **A test failed.** `build/logs/test-<platform>.log` names it, and
  `build/test-results/` has the result bundle with its screenshot and UI hierarchy.
  Re-run just it with `ONLY=`.

## 5. Before the first release on a Mac

- The release Xcode at `/Applications/Xcode.app`, signed in as above, with the iOS, tvOS
  and visionOS platforms installed (Xcode → Settings → Components).
- For `make test`: the simulators an iPhone 17, an iPad Pro 13-inch (M5), an Apple
  Vision Pro and an Apple TV 4K (3rd generation) (at 1080p) — or others, named with the
  variables in §1. A regular iPhone on purpose, not a Pro Max: the widest screen has room
  for text that a regular one truncates.
