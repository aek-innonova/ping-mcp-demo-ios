# Agentic Bank (iOS)

The maker-checker approver for the agentic-banking demo: an AI agent can
*request* money transfers via MCP but can never execute them. This app is
where the human approves — a push notification carries the transfer details
and an **Approve** action gated by Face ID, straight from the lock screen.

- SwiftUI, no dependencies; project generated in CI by XcodeGen from
  `project.yml` (no pbxproj in git)
- Built and uploaded to TestFlight by GitHub Actions (`testflight.yml`),
  cloud-signed via an App Store Connect API key
- Backend endpoints are injected from repo secrets at build time
  (`BANK_BASE_URL`) — this is a public repo

## Required repo secrets

| Secret | Content |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | ASC API key id |
| `APP_STORE_CONNECT_ISSUER_ID` | ASC issuer id |
| `APP_STORE_CONNECT_KEY` | the `.p8` key content |
| `BANK_BASE_URL` | `https://<bank-host>` |

## Push payload contract (sent by the bank server)

```json
{
  "aps": {
    "alert": { "title": "Transfer approval", "body": "alice → bob · €50 — Dinner" },
    "category": "TRANSFER_APPROVAL",
    "sound": "default"
  },
  "approveURL": "https://<bank-host>/approve/<capability-token>"
}
```

The app registers its APNs token at `POST /devices {token, user}`.
