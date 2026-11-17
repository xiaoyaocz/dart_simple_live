/// Runs inside the original platform page. No endpoint signing or credential export.
class SearchWebMedia {
  /// Keep the original logged-in room alive behind the native player, without
  /// its audio. Suspending the WebView would also suspend native chat handlers.
  static const holdMedia = r'''
(() => {
  if (window.__simpleLiveHeldMedia) return;
  const media = new Map();
  const mute = () => document.querySelectorAll('video,audio').forEach(element => {
    if (!media.has(element)) media.set(element, element.muted);
    element.muted = true;
  });
  const observer = new MutationObserver(mute);
  observer.observe(document.documentElement, {childList:true,subtree:true});
  window.__simpleLiveHeldMedia = {media,observer};
  mute();
})();
''';
  static const restoreMedia = r'''
(() => {
  const state = window.__simpleLiveHeldMedia;
  if (!state) return;
  state.observer.disconnect();
  state.media.forEach((muted, element) => { if (element.isConnected) element.muted = muted; });
  delete window.__simpleLiveHeldMedia;
})();
''';
}
