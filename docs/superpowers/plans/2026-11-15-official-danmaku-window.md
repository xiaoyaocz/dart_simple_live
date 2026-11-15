# Visible official danmaku window

**Goal:** Replace the failing custom send path with direct interaction with the platform's visible, official room page on Windows.

**User decision:** After proposing an official webpage input instead of credential export/native requests/hidden-page automation, the user requested a GitHub checkpoint first, then continuation. Checkpoint c624718 is pushed and verified against origin/master.

**Design:** Enter or the chat area's button opens a transparent-backdrop window over the still-running player. The window contains the actual official room webpage, not a replicated input field. Users type, select platform emoji and send using the website's own UI. No scripts submit messages and no success toast is fabricated. The official page remains complete so login, verification and errors are visible. A widen button exposes the full page when desktop layouts do not fit. Reuse the active same-platform search environment; otherwise use the remembered platform profile. Do not copy cookies. Mute only webpage media to avoid duplicate audio.

**Tradeoffs:** A complete webpage takes more space and initially loads slower than a small native input. This deliberately favors direct user-visible behavior over maintaining fragile selectors/signatures. Closing the window unloads its webpage; persistent profile storage keeps the account. No APK changes.

**Architecture:** Add one stateful official browser window widget. Replace the controller's sending/prewarm/composer wiring with opening this route; close it on room change/shutdown. Replace the inline custom composer with a button. Keep former transport modules as checkpointed code, but do not call them from the live room. Existing media player, reading danmaku, follow and fullscreen functions stay unchanged.

**Tech stack:** Existing Flutter dialog, InAppWebView/WebView2, SearchWebSession; no additional dependencies.

## Tasks
- [x] Replace the custom sender/prewarm wiring; test official room routing, transparent dialog, safe close/reopen and view creation settings. The old native-prewarm assertion went red before removal of this intentionally retired behavior.
- [x] Verify browser keyboard ownership, environment failure/retry and async close races. Run full tests and review the diff.
- [x] Rebuild the main application, package a distinct Windows installer and verify payload hashes. Distinguish the initial GitHub checkpoint from the subsequent implementation and distinguish fixture verification from actual public message delivery.

## Constraints
- No background or automated public messages during verification.
- No credential export, custom HTTP/WebSocket send, DOM input or click automation in the new route.
- Preserve unrelated untracked docs, experiments and local configuration; do not upload probe executables or local browser data.
- Platform login behavior and public delivery are not proven by fixture tests; state that limitation explicitly.

## Verification
- Full application suite: 528 passed, 2 skipped (`C:/Temp/official-final-full-tests.log`).
- Five focused official-window tests: four platform room URLs, exact borrowed environment, mute-only script (no sends), resize preserving the browser, owned/borrowed cleanup, retry after creation failure, close before late creation and Enter ownership.
- A fresh read-only review found a retry of an already-failed borrowed Future. Added a regression and changed the next retry to create an independent environment using the remembered platform profile; focused suite passed (`C:/Temp/official-borrowed-green2.log`).
- Targeted analyzer on new widget/tests: no issues found. Existing controller brace-style info outside the feature remains unchanged.
- Production target `lib/main.dart` built successfully (`C:/Temp/official-final-build.log`); pre-existing WebView CMake development warning remains.
- Installer `dist/SimpleLive-2.0.24-official-danmaku-window-20261115/SimpleLive-2.0.24-windows-x64-setup.exe`: embedded main exe, Flutter dll, WebView plugin dll and app.so match Release SHA-256; no probe executable included.
- No real public message was sent. Tests validate the application's window/profile/lifecycle wiring, not a claim that all four live websites' editors or delivery were manually verified.
- GitHub tracking: https://github.com/xiaofeng3539/dart_simple_live/issues/1 (left open for real account delivery feedback).
