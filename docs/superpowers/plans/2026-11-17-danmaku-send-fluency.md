# Danmaku send fluency implementation plan

**Goal:** Improve preparation latency and continuous manual composition without changing platform protocols or acknowledgement rules.

**Architecture:** Keep room-scoped senders and single-flight submission. Prepare on keyboard focus, permit emoji editing during confirmation, protect edited drafts with revisions, and cancel redundant scheduled official-page sweeps when synchronously refreshing controls.

**Choices:** User opted for direct implementation using manual next-message submission, not queued or automatic sends. Retain floating editor close-on-success behavior unless a new draft was edited.

## Tasks
- [x] Add failing composer tests for focus preparation, emoji during send, revised identical draft, and disposal during acknowledgement.
- [x] Implement minimal composer lifecycle changes; preserve IME guards, failed drafts and no duplicate submission.
- [x] Add browser fixture assertion for cancelling the pending sweep on synchronous refresh, then implement it.
- [x] Run targeted and full Flutter tests, Chromium fixtures, analysis and Windows release build.
- [x] Package to a new output directory, document evidence, limits and backup rollback.

## Constraints
No credential cache, no shorter platform acknowledgement timeout, no retries, no concurrent messages, no public-room load testing. Existing direct-network policy and receiving/playback code remain unchanged.
