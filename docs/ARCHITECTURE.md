# Sift architecture

## Runtime boundary

Sift is a local-first macOS application. SwiftUI renders the primary window; AppKit is reserved for window/notch integration. Network use exists only in explicitly configured mail providers. Message content, scores, summaries, and preferences stay on device. OAuth refresh/access credentials belong in Keychain, never SwiftData, logs, files, or analytics.

## Modules

- **App:** scene setup, dependency assembly, menu bar extra, settings and demo-mode entry.
- **Core:** value models, priority tiers, explainable scoring protocol, date/address helpers.
- **Mail:** `MailProvider` boundary; Gmail and IMAP/SMTP implementations; retry/backoff and incremental cursors.
- **Storage:** SwiftData local cache and migration policy; account secrets remain behind a Keychain service.
- **Intelligence:** heuristic classifier always available; optional Foundation Models adapter checks availability and supported language at runtime.
- **DesignSystem:** semantic tokens, priority chip, avatars, glass control wrappers, shortcut hints, Design Gallery.
- **Features:** Inbox, Reader, Composer, Triage, Daily Brief, Cleanup, Settings.
- **NotchKit:** AppKit nonactivating panel, screen geometry, and SwiftUI alert content.

## Data flow

Provider sync fetches a bounded page, normalizes it into local message models, then the scoring actor computes tier, score, and explanation. Storage persists the normalized message and cursor transactionally. The UI observes local storage only. Optional on-device generation can enrich the deterministic result, but cannot prevent inbox display or sync.

Gmail desktop OAuth uses Authorization Code + PKCE through a loopback callback and incremental `history.list` polling. Gmail's Pub/Sub watch path requires Pub/Sub infrastructure and is not suitable for a no-backend default. IMAP/SMTP uses OAuth2/XOAUTH2 where available. Secrets are stored in Keychain; local database fields should be protected at rest by the platform and excluded from diagnostics.

## Concurrency and failure handling

Use Swift concurrency and actors around sync, ranking, persistence, and Keychain operations. Provider protocols permit deterministic fakes in tests. Retry transient network failures with bounded exponential backoff and expose actionable offline/account errors. Cancellation must stop in-flight sync and model generation. Strict concurrency is enabled. Avoid force unwraps and redact message bodies, addresses, tokens, and OAuth callbacks from logs.

## Security and privacy

Enable App Sandbox with only outbound network client and Keychain access. WKWebView must disable remote content by default and intercept navigation; attachment previews use Quick Look. Never load tracking pixels. Never send message content to third-party AI services. Export/delete-all should be explicit and local. No telemetry.

## Verification boundaries

The repository includes unit coverage for deterministic priority scoring and a CI workflow for macOS build/tests/package creation. MIME parsing, live Gmail/IMAP OAuth, notch hit testing, multi-display geometry, accessibility settings, and visual screenshots require macOS integration testing. Keep these limitations explicit in README until verified on hardware.

## Outlook implementation (November 2026)

The first live provider is Microsoft Graph for Outlook.com and Microsoft 365. A public-client device authorization flow opens Microsoft's browser sign-in; no password or client secret enters Sift. Tokens live in a per-account Keychain item. A maintainer may distribute a public application ID through Info.plist; advanced users can configure their own registration. Delegated User.Read, Mail.ReadWrite, Mail.Send and offline_access permissions are requested. Tenant policies can require administrator approval or prohibit device authorization.

Inbox delta pages and deletions are applied to a versioned local cache together with the final delta cursor. Initial sync and cursor recovery never notify for historical messages. Each account has an independent cursor, token, and local message identity. Failed remote mutations leave local messages intact. Plain-text bodies are requested from Graph; no HTML, images, scripts, or remote tracking resources are rendered. Snooze and sender preferences are local to Sift.

References checked: [device authorization](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code), [message delta](https://learn.microsoft.com/en-us/graph/api/message-delta), [move](https://learn.microsoft.com/en-us/graph/api/message-move), [delegated permissions](https://learn.microsoft.com/en-us/graph/permissions-reference). The system is polled while Sift runs; it cannot receive mail while the process is quit.
