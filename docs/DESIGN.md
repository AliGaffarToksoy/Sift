# Sift design system

Research checked 15 November 2026 against Apple Developer documentation and WWDC25 sessions. Sift targets macOS 26. Its central rule is that Liquid Glass belongs to the floating navigation and control layer; messages and reading surfaces remain solid for comfortable reading.

## Platform findings

- Apple describes Liquid Glass as an adaptive material for controls and navigation that should sit above content. It adapts to surroundings and accessibility settings; avoid applying it to large content surfaces. See [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Color](https://developer.apple.com/design/human-interface-guidelines/color), [Meet Liquid Glass, WWDC25](https://developer.apple.com/videos/play/wwdc2025/219/), and [Build a SwiftUI app with the new design, WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/).
- Current SwiftUI documentation lists `glassEffect(_:in:)`, `GlassEffectContainer`, `glassEffectID(_:in:)`, `backgroundExtensionEffect()`, `scrollEdgeEffectStyle(_:for:)`, `ToolbarSpacer`, and `ConcentricRectangle` (with `containerShape(_:)` for custom container geometry). `Glass` includes `.regular` and `.identity`; button styles include `.glass` and `.glassProminent`. Prefer system toolbar/sidebar glass and group custom adjacent glass effects in one container. `glassEffectID` plus a shared `@Namespace` can coordinate morphing. Confirm availability against the exact Xcode SDK before adding API calls; the deployment target here is macOS 26. References: [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui), [ConcentricRectangle](https://developer.apple.com/documentation/swiftui/concentricrectangle), [glass prominent button style](https://developer.apple.com/documentation/swiftui/glassprominentbuttonstyle).
- AppKit provides `NSGlassEffectView` and `NSGlassEffectContainerView` for custom AppKit content. The WWDC25 AppKit session recommends using glass for the top-level controls and letting the glass view host its content. See [NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview) and [Build an AppKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/310/).
- Apple HIG guidance informs the layout: use the system sidebar and toolbar, preserve standard window behavior, use semantic system colors and text styles, animate only to communicate state, and preserve keyboard and assistive-technology access. References: [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [Windows](https://developer.apple.com/design/human-interface-guidelines/windows), [Motion](https://developer.apple.com/design/human-interface-guidelines/motion), [Typography](https://developer.apple.com/design/human-interface-guidelines/typography), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).
- `NSScreen.safeAreaInsets` includes the camera-housing top inset on supported Macs. `auxiliaryTopLeftArea` and `auxiliaryTopRightArea` describe unobscured regions beside the housing in global screen coordinates. Use these properties together (and re-read on display changes); do not infer notch width from a hard-coded Mac model. On screens without a top inset, center a floating pill. Sources: [NSScreen.safeAreaInsets](https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets), [auxiliaryTopRightArea](https://developer.apple.com/documentation/appkit/nsscreen/auxiliarytoprightarea-gr2n).
- Foundation Models provides local generation through `SystemLanguageModel`, `LanguageModelSession`, and guided generation with `@Generable` on supported Apple Intelligence configurations. Availability/readiness and supported languages must be checked at runtime; classification must have a deterministic local fallback. NaturalLanguage offers language identification and tokenization. No email content is sent to a remote model. Sources: [Foundation Models](https://developer.apple.com/documentation/foundationmodels), [NaturalLanguage](https://developer.apple.com/documentation/naturallanguage), [Meet the Foundation Models framework, WWDC25](https://developer.apple.com/videos/play/wwdc2025/302/).
- Google's installed desktop OAuth flow supports loopback redirects; use a random high-entropy PKCE verifier/challenge, state validation, and a short-lived localhost listener. Google Gmail push uses Cloud Pub/Sub and a backend delivery path; for a personal installed client, Google recommends poll-based synchronization. Sift therefore plans incremental polling with Gmail `history.list`, not a cloud push dependency. Sources: [OAuth 2.0 for desktop apps](https://developers.google.com/identity/protocols/oauth2/native-app), [OAuth loopback migration guide](https://developers.google.com/identity/protocols/oauth2/resources/loopback-migration), [Gmail synchronization](https://developers.google.com/workspace/gmail/api/guides/sync), [Gmail push](https://developers.google.com/workspace/gmail/api/guides/push).
- IMAP/SMTP OAuth2 uses SASL XOAUTH2 bearer tokens. Treat refresh tokens as secrets and store them only in Keychain. References: [Google XOAUTH2 protocol](https://developers.google.com/gmail/imap/xoauth2-protocol), [RFC 7628](https://www.rfc-editor.org/rfc/rfc7628).
- GitHub's current hosted-runner documentation lists `macos-26` and `xcode-27`; workflow uses `macos-26` and records the selected Xcode version to make future image changes visible. Source: [GitHub runner selection](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job).

## Tokens

Spacing follows an 8-point rhythm: 4 for optical adjustments, then 8, 16, 24, 32, 48. Prefer system text styles (`.largeTitle`, `.title`, `.headline`, `.body`, `.callout`, `.caption`) and system rounded shapes only where appropriate. Use semantic colors and keep priority colors supplemental to text and symbols:

| Tier | Accent | Meaning |
|---|---|---|
| Critical | system red-orange | Requires attention now |
| Important | system amber | Likely needs action today |
| Normal | secondary label | Routine correspondence |
| Low | tertiary label | Can wait |
| Noise | quaternary label | Bulk or low-signal mail |

Use concentric continuous rounded rectangles for nested cards and controls. Keep reading panes and message rows on solid window/background colors. Place no glass panel behind another glass panel.

## Component specifications

- **Window:** three-column `NavigationSplitView`; sidebar for smart mailboxes/accounts, ranked list, solid reader. Allow columns to resize and collapse naturally.
- **Toolbar:** system toolbar glass with grouped actions, search/command access, sparse tint on the primary action only.
- **PriorityChip:** short text plus a distinct symbol/shape; never communicate tier by color alone.
- **MessageRow:** sender, subject, preview, timestamp, and priority explanation; selection and unread state remain legible in both appearances.
- **GlassCard:** reserved for transient controls and navigation surfaces, grouped in `GlassEffectContainer` where multiple custom effects touch.
- **Avatar:** initials or locally generated palette, never requires remote image fetching.
- **ShortcutHint:** visible key equivalents and VoiceOver descriptions for every primary action.
- **Empty/loading/error:** quiet solid surfaces, concise next action, skeletons that respect Reduce Motion.

## Motion and interaction

Use short spring transitions for selection and triage, tuned to feel responsive without overshoot. Use matched geometry/glass IDs only when controls genuinely move between related states. Every action has hover, pressed, focused, selected, disabled, and keyboard states. Honor Reduce Motion by replacing movement with a brief opacity/state change; never rely on haptics or sound.

## Accessibility and appearance

Use semantic foreground/background colors, scalable system styles, descriptive labels, focus order, and full keyboard navigation. Test Increase Contrast, Reduce Transparency, Reduce Motion, VoiceOver, and Differentiation Without Color. The default palette must remain readable over busy desktop imagery because system glass adapts to its environment. Any non-macOS-26 fallback should use a standard material on controls only; the shipping target remains macOS 26.

## Design Gallery

The app includes a local gallery of priority, glass, row, chip, and shortcut states. Check its light/dark appearances, keyboard focus, and accessibility settings before release. Screenshots are intentionally left as README placeholders until captured on a Tahoe Mac.

## Outlook and notch continuation

Use NotchLingo's proven geometry strategy: prefer the built-in notched screen, reserve the camera inset, and mount one persistent SwiftUI tree in a nonactivating NSPanel. Use safeAreaInsets and both auxiliary areas, remeasure on screen changes, and use a floating pill on other displays. Hidden panels are ordered out; showing a notification never activates Sift. Camera-safe content begins below the top inset. Peek expands on hover, respects Reduce Motion, and collapses after a configurable interval. Quiet hours and a manual pause prevent interruptions; Focus status is used only when the OS shares it, with its limitation visible in Settings.

Mail stays on quiet solid surfaces, with glass reserved for grouped controls. Every account shows its own connection state. Setup distinguishes a missing Microsoft application registration from account consent. There are no preconfigured personal accounts, passwords, or sample credentials.
