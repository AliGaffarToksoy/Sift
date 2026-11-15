# Sift

Sift is a native, local-first macOS mail triage prototype. The current build is a polished **Demo Mode** experience with a ranked sample inbox, reader, design gallery, menu bar peek, explainable heuristic scoring, and macOS CI packaging. It does not yet connect to real mail accounts. The app has no telemetry and the demo contains synthetic Turkish and English messages only.

## Preview

Screenshots will be added after capture on macOS Tahoe.

| Inbox | Reader | Design Gallery |
|---|---|---|
| _Screenshot placeholder_ | _Screenshot placeholder_ | _Screenshot placeholder_ |

## Build and run

Requires a Mac with Xcode 27 (or a compatible Xcode containing the macOS 26 SDK) and Swift 6:

```sh
swift build
swift run Sift
swift test
```

The main window opens in Demo Mode. ⌘E archives the selected sample; the toolbar button opens the Design Gallery. Sift also adds a menu bar peek.

## Download

Once this project is published, download `Sift-macOS.dmg` or `Sift-macOS.zip` from a tagged GitHub Release. CI ad-hoc signs the app; it is not notarized. On first launch, macOS may block it: in Finder, Control-click (or right-click) `Sift.app`, choose **Open**, then confirm **Open**. Alternatively, after moving the app into Applications, run `xattr -cr /Applications/Sift.app` in Terminal and open it. Only do this for a build you trust.

The Actions workflow also makes the same files available as downloadable artifacts for branch builds.

## Current scope

- Implemented: three-column demo inbox and reader, priority chips and explanations, search, basic archive action, Design Gallery, menu bar summary, sample data in Turkish and English, scoring tests, sandbox entitlements, macOS build/test/package workflow.
- Not implemented yet: Gmail/IMAP OAuth and sync, persistent mail cache, Keychain integration, Foundation Models adapter, secure HTML reader, attachments, composer, triage flow, daily brief, cleanup, command palette, notifications, settings, notch panel, app icon, MIME parsing, and their tests. Do not connect a real inbox to this prototype.

## Manual setup for a future Gmail integration

No OAuth setup is needed for Demo Mode. Before enabling Gmail support, a maintainer will need a Google Cloud project, Gmail API enabled, and an OAuth client configured for a desktop app. The app must implement Authorization Code with PKCE, state validation, a loopback callback, and Keychain-only token storage. Gmail synchronization should use incremental `history.list` polling; the Gmail Pub/Sub watch path requires Pub/Sub infrastructure and a delivery endpoint. Do not paste client secrets or refresh tokens into source control.

## CI and publishing

`.github/workflows/build.yml` uses GitHub's `macos-26` hosted runner, prints the selected Xcode version, builds and tests with SwiftPM, then creates an ad-hoc-signed `.app`, `.zip`, and `.dmg`. Tag `vX.Y.Z` to upload the archives to a GitHub Release. GitHub currently lists `macos-26` and Xcode 27 runner images; the image's exact patch version can change over time.

## Needs manual verification

- Build and launch on macOS 26 with Xcode 27. This environment has Swift 6 command-line tools but no Xcode installation, so the macOS SDK build and CI have not been verified here.
- Confirm SwiftUI Liquid Glass appearance, selection, keyboard navigation, VoiceOver, Reduce Motion, Reduce Transparency, Increased Contrast, and light/dark appearances on Tahoe.
- Capture real screenshots and inspect menu bar behavior on multiple display scales.
- Before implementing NotchKit, validate hit testing, panel level/collection behavior, focus behavior, safe-area geometry, resolution changes, full-screen Spaces, and external monitors on hardware. `NSScreen` exposes safe-area and auxiliary corner regions but macOS does not provide a supported generic Dynamic Island abstraction.
- Review and tighten sandbox entitlements during account integration. Release signing is ad hoc and therefore unsigned by Apple/not notarized.

## Research and design

See [docs/DESIGN.md](docs/DESIGN.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for API research, design tokens, system boundaries, and privacy rules.

## License

MIT. See [LICENSE](LICENSE).
