# Contributing

Thanks for helping improve Sift. Keep email content local, never add telemetry, and never commit credentials or real mailbox data.

## Development

- Use Swift 6 and the macOS 26 SDK.
- Build with `swift build` and run tests with `swift test` on a Tahoe-compatible Mac with Xcode installed.
- Keep provider and intelligence integrations behind protocols so the app works in offline demo mode.
- Add deterministic tests for ranking and parsing behavior. Do not log message bodies, addresses, tokens, or OAuth callback values.
- Follow the tokens and accessibility guidance in `docs/DESIGN.md`.

## Changes

Open a focused pull request with a concise description, screenshots for UI changes, test notes, and any remaining manual verification. Do not include screenshots containing personal mail.
