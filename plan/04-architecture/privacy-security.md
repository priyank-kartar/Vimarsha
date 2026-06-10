# Privacy & Security

> **Status:** Draft · **Last updated:** 2026-06-11
> Part of the [knowledge base](../README.md). Books are personal — reading history doubly
> so. The posture below is a product claim ([positioning](../02-market/positioning.md)),
> so it must stay verifiable, not aspirational.

## The claims (and what makes them true)

| Claim | Mechanism |
|---|---|
| **Your library lives on your device.** | EPUBs, narration caches, progress, memos, threads: app container + SwiftData only. No server-side library, ever ([ADR-001](../00-overview/decision-log.md#adr-001--two-tier-architecture-stateless-backend-client-re-uploads-the-epub)). |
| **Narration is transient processing.** | A chapter job uploads the EPUB, returns the bundle, and is purged (hosted: retention ≤ hours, written down — [hosted-backend](hosted-backend.md)). We never *store* books server-side; "we don't keep what you read." |
| **Conversations stay yours.** | Discuss threads persist on-device only; `/chat` calls carry the passage context transiently; nothing trains on user content. |
| **No tracking SDKs.** | No third-party analytics in v1; if product analytics ever land, they're aggregate, opt-in, and content-free (its own ADR first). |

The honest phrasing (mirrors what's defensible): **"your books and reading life stay on
your phone — narration is processed transiently and never stored."** NOT "nothing ever
leaves your device" — the GPU step exists and we say so plainly.

## Device-side security

- App-container storage with standard iOS data protection; SwiftData store +
  caches under `NSFileProtectionCompleteUntilFirstUserAuthentication` (default) — revisit
  per-file upgrades if a threat model demands it (not v1).
- Security-scoped bookmarks only during import; the original file handle is released after
  the container copy ([data-model](data-model.md)).
- No secrets in the client for local backend; hosted adds Sign in with Apple tokens in the
  Keychain (P7).

## Transport & service (hosted scope, P7)

TLS everywhere; signed short-lived result URLs; job logs carry ids/sizes/durations — never
titles, text, or audio; quota data is the *only* durable per-account record (minutes used,
not what they were used on).

## App Store privacy label (P10 prep)

Target: Data Not Collected for local-only use; hosted accounts add "identifiers (account)"
+ "usage (quota)" — drafted properly during P7 when the service exists. DRM stance (Q-DRM):
we read only what the user can already open; no circumvention.

## Open

Threat-model pass before P7 (who attacks a narration service and how); memo audio retention
on `/transcribe` (today: transient by design — verify and document alongside ADR for hosted).
