# Sift

A native, local-first Outlook / Microsoft 365 inbox for macOS 26+, with explainable priority ranking and camera-safe notch alerts. SwiftUI + AppKit, Swift 6, no backend, telemetry, or external AI service.

**Status:** Outlook implementation ready for integration testing. Live sign-in requires a Microsoft public-client application registration. Do not describe this build as production-verified until the live-account and hardware checklist below passes.

## What works in this version

- Separate Outlook.com / Microsoft 365 accounts with browser device-code sign-in; tokens stored only in macOS Keychain.
- Inbox delta synchronization, pagination, deleted/moved-message reconciliation, expired-cursor recovery, bounded read retries and offline cache. Changes and the sync cursor are written together in an atomic local file.
- Unified inbox, priority, today, probable needs-reply, newsletters, VIP and locally snoozed mailboxes; local search and daily brief.
- Server-backed archive and mark-read, plain-text replies with a cancellable ten-second send delay, local one-hour snooze and sender preferences.
- Notch peek and expanded actions, camera-safe geometry derived from NSScreen, external-display fallback, burst grouping, auto-dismiss, Reduce Motion/Transparency support, private previews, threshold and quiet-hour settings. Control–Option–S toggles the panel.
- Separate Turkish/English sample data, a design gallery and a safe notch preview. Demo actions do not send mail.

Only the Inbox is synchronized. HTML, attachments, other folders, new-message composition, Gmail/IMAP, local language-model summaries, full triage mode and natural-language search are **not implemented**. The displayed summary is a plain-text excerpt. The current UI is primarily Turkish; full localization remains to be completed.

## Download and open — no Xcode needed

Download `Sift-macOS-arm64.dmg` or `.zip` from a successful [Actions run](https://github.com/AliGaffarToksoy/Sift/actions) (GitHub sign-in is needed for workflow artifacts), or from [Releases](https://github.com/AliGaffarToksoy/Sift/releases) after a version tag is published. A pull request artifact is a development build, not a stable release.

Open the DMG and drag Sift to Applications. The app is ad-hoc signed, not notarized by Apple. Approve first launch in System Settings → Privacy & Security; depending on macOS version, Finder → right-click → Open is also available. For a build you trust, `xattr -cr /Applications/Sift.app` removes the download quarantine. Apple Silicon and macOS 26+ are required.

## Connect Outlook

See [the step-by-step setup guide](docs/OUTLOOK-SETUP.md). A maintainer registers Sift once for organizational **and personal** Microsoft accounts, enables public client flows, and sets the repository variable `MICROSOFT_CLIENT_ID`. CI embeds this public identifier in the downloadable app; users then sign in with their own account. The identifier is not an account, password or secret.

Without a bundled identifier, advanced users can enter their own Application (client) ID in Accounts. No private credentials are included in the repository. Organizational policies may require administrator approval or block the device flow.

Sift polls while running, approximately every 60 seconds. Initial sync and cursor recovery do not alert for old messages. Sleep, throttling and network failures can delay mail. macOS Focus is respected only when the system shares its status; otherwise use quiet hours or Pause. Notch preview intentionally bypasses suppression.

## Privacy

Mail content and preferences are stored in a versioned local Application Support cache inside the app sandbox. Access and refresh tokens are separate per-account Keychain items. Plain-text rendering makes no remote-image requests. Only Microsoft identity and Graph endpoints receive authentication/mail traffic. See [Privacy](docs/PRIVACY.md).

Removing an account deletes its cache and Keychain entry on this Mac; it does not delete mail from Microsoft. Revoke application consent separately from your Microsoft account if desired. Ad-hoc upgrades may require Keychain authorization or reconnecting the account.

## Build and verify

A compatible Xcode with the macOS 26+ SDK is recommended for the full test suite:

```sh
swift build
swift test
bash Scripts/package.sh
```

GitHub Actions uses the documented `macos-26` runner, prints the selected toolchain, runs unit tests, then packages an ad-hoc signed app, ZIP, DMG and checksums. Failed tests prevent packaging. Version tags publish release assets. No Xcode project needs to be opened.

Core tests cover scoring, Turkish signals, Graph decoding, HTML fallback, account-scoped delta reconciliation, stable identity/snooze preservation, duplicate changes, quiet-hour boundaries, safe Graph links and cache round trips.

## Needs manual verification before a stable release

- Microsoft sign-in with both Outlook.com and a work/school account, rejection/cancellation, expired refresh tokens, Keychain access after an ad-hoc upgrade, and multiple-account isolation.
- Large-inbox and incremental synchronization with live Graph, pagination, expired cursors, externally moved/read mail and offline recovery. API failure scenarios currently lack an injected-network integration test suite.
- Archive/read mutations and real reply delivery; cancel during the ten-second delay; ambiguous send failures must be checked in Sent Items before retrying.
- Notch positioning and pointer behavior on an M3 Pro MacBook, display scaling, external monitors, full-screen Spaces, Focus sharing, accessibility settings and keyboard navigation.
- Screenshot review in light/dark mode; screen reader audit. Do not claim pixel-perfect hardware verification from unit tests.
- No full production claim: attachment support, richer provider coverage, complete localization and signed/notarized distribution remain future work.

See [Design](docs/DESIGN.md), [Architecture](docs/ARCHITECTURE.md), and [Contributing](CONTRIBUTING.md). MIT license.
