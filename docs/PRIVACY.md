# Sift privacy

Sift is a local mail client. It has no developer-operated backend, analytics or advertising SDK. Email content is not sent to an external AI service.

When you connect Microsoft, Sift contacts Microsoft identity endpoints to sign in and Microsoft Graph to read your Inbox and perform actions you request. Microsoft processes those requests under its own terms. The public application identifier identifies Sift, not your mailbox. Your Microsoft password is entered on Microsoft's website, never in Sift.

Mail bodies, sender addresses, subjects, local preferences and synchronization cursors are cached in the macOS sandbox's Application Support directory. The cache is a local file with owner-only permissions, not a separately encrypted database. Use macOS account protections and FileVault as appropriate. Refresh/access tokens are saved only in Keychain with device-only accessibility. No credentials are committed to this repository.

Archive and mark-read change your Microsoft mailbox. Replies are sent only after you press Send and the ten-second cancellation period ends. Snooze, priority and muted/VIP preferences are local. Plain-text mail rendering does not download tracking images or execute HTML.

Removing an account deletes its Sift cache and Keychain item on this Mac, but does not revoke Microsoft's server-side consent. You can revoke consent through your Microsoft account or organization. Uninstalling the app alone may leave macOS application data and Keychain items; remove accounts in Sift first.

For privacy bugs, use the repository's issue tracker with synthetic examples only. Never attach real email content, access tokens, authentication codes, local caches or account secrets.
