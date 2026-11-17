/// Native editor layout and intent guard; the website owns message submission.
class OfficialDanmakuLayout {
  // WebView2 maps AT_DOCUMENT_END to window.load, which can wait indefinitely
  // on live-page resources. Start as soon as <html> exists, before first paint.
  static const bootstrap = r'''
const begin = () => {
  if (!document.documentElement) return false;
  install(site, expectedRoomIds);
  return true;
};
if (!begin()) {
  const pending = new MutationObserver(() => {
    if (begin()) pending.disconnect();
  });
  pending.observe(document, {childList:true, subtree:true});
}
''';

  static const install = r'''
if (window.__simpleLiveOfficialEditor) return window.__simpleLiveOfficialEditor.inspect();
const adapters = {
  huya: {root: '.chat-room__ft', input: '#pub_msg_input, #J_RoomChatSpeaker [contenteditable], #J_RoomChatSpeaker textarea', button: '#msg_send_bt'},
  douyu: {root: '.Chat', input: '.ChatSend-txt', button: '.ChatSend-button', hideUntilReady: true, completeControls: true},
  bilibili: {root: '#chat-control-panel-vm, .chat-control-panel', input: 'textarea.chat-input, textarea.chat-input-new, .chat-input-ctnr [contenteditable]', button: '.chat-input-ctnr .send-btn, #chat-control-panel-vm .send-btn', hideUntilReady: true},
  douyin: {root: '[data-e2e="chat-input"]', input: '[data-e2e="live-chatting"] [contenteditable], [data-e2e="chat-input"] [contenteditable], [data-e2e="chat-input"][contenteditable], textarea[placeholder*="互动"], textarea[placeholder*="说点"], textarea[placeholder*="输入评论"], [contenteditable="true"][data-placeholder*="互动"], [contenteditable="true"][data-placeholder*="说点"], [contenteditable="true"][data-placeholder*="弹幕"], [contenteditable="plaintext-only"]', button: '.webcast-chatroom___send-btn, [data-e2e="chat-send-btn"], [data-e2e="chat-send-button"]', hideUntilReady: true}
};
const adapter = adapters[site];
if (!adapter) return {status: 'unsupported'};
const allowed = new Set(typeof expectedRoomIds === 'undefined' ? [] : expectedRoomIds);
const currentRoom = () => {
  const host = location.hostname;
  const expectedHost = {huya:'www.huya.com',douyu:'www.douyu.com',bilibili:'live.bilibili.com',douyin:'live.douyin.com'}[site];
  if (host !== expectedHost) return null; // Login/verification hosts are allowed.
  const parts = location.pathname.split('/').filter(Boolean);
  if (site === 'douyu' && parts[0] === 'topic') return new URL(location.href).searchParams.get('rid');
  const id = site === 'bilibili' && ['h5','blanc'].includes(parts[0]) && parts.length === 2 ? parts[1] : parts.length === 1 ? parts[0] : null;
  if (!id) return null;
  if (site === 'douyu') {
    if (id.startsWith('g_') || ['search','topic','directory','category'].includes(id)) return null;
    return /^[a-zA-Z0-9_-]+$/.test(id) ? id : null;
  }
  return site === 'huya' || /^\d+$/.test(id) ? id : null;
};
const state = {ready: false, emojiRequested: false, controls: [], controlPaths: [], root: null, input: null, expanded: false, emojiOpen: false, popup: null, popupPaths: [], popupScrolls: [], emojiDeadline: 0, pendingFocus: false, path: [], inputPath: [], last: '', timer: null};
const report = (status, extra = {}) => {
  const data = {status, ...extra};
  const key = JSON.stringify(data);
  if (key === state.last) return;
  state.last = key;
  try { window.flutter_inappwebview?.callHandler('simpleLiveOfficialEditor', data)?.catch(() => {}); } catch (_) {}
};
const mark = (element, name, value = '') => {
  if (element.getAttribute(name) !== value) element.setAttribute(name, value);
};
const syncMarks = (previous, next, name) => {
  const keep = new Set(next);
  previous.forEach(e => { if (!keep.has(e)) e.removeAttribute(name); });
  next.forEach(e => mark(e, name));
  return next;
};
const style = document.createElement('style');
document.documentElement.setAttribute('data-sl-official-site', site);
style.textContent = `
html[data-sl-official-blocked] body { visibility:hidden!important; pointer-events:none!important; }
html[data-sl-official-blocked][data-sl-official-blocked][data-sl-official-blocked][data-sl-official-blocked] body * { visibility:hidden!important; }
html[data-sl-official-mode="compact"], html[data-sl-official-mode="compact"] body {
  min-width:0!important; width:100%!important; height:100%!important; overflow:hidden!important;
}
html[data-sl-official-mode="compact"] body * { visibility:hidden!important; }
html[data-sl-official-mode="compact"] [data-sl-official-editor-path] {
  transform:none!important; perspective:none!important; filter:none!important;
  backdrop-filter:none!important; -webkit-backdrop-filter:none!important;
  will-change:auto!important; contain:none!important;
  overflow:visible!important; min-width:0!important; display:block!important;
}
html[data-sl-official-mode="compact"] body [data-sl-official-editor-root] { visibility:visible!important; }
html[data-sl-official-mode="compact"] body [data-sl-official-editor-root] {
  position:fixed!important; inset:auto 0 0 0!important; width:100vw!important; min-width:0!important;
  max-width:none!important; height:auto!important; max-height:100vh!important; margin:0!important;
  box-sizing:border-box!important; transform:none!important; filter:none!important;
  backdrop-filter:none!important; -webkit-backdrop-filter:none!important;
  will-change:auto!important; contain:none!important; z-index:2147483000!important;
}
html[data-sl-official-mode="compact"] [data-sl-official-editor-root] textarea,
html[data-sl-official-mode="compact"] [data-sl-official-editor-root] [contenteditable] {
  max-width:100%!important; min-width:0!important; box-sizing:border-box!important;
}
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] [data-sl-official-editor-root] * {
  min-width:0!important; max-width:100%!important; box-sizing:border-box!important;
}
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] body {
  margin:0!important; padding:0!important; background:#25252f!important;
}
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] [data-sl-official-input] * {
  font-size:inherit!important; line-height:inherit!important; color:inherit!important;
}
/* Clearing a native rich draft can leave a P/DIV with desktop paragraph
   spacing. Its caret must share the same centered 24px line as plain text. */
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] [data-sl-official-input] p,
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] [data-sl-official-input] div {
  margin:0!important; padding:0!important; height:auto!important; min-height:0!important;
}
/* Native focus styles can absolutely position and narrow the empty hint.
   Keep it in the same single-line flow as the unmodified native editable. */
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] [data-sl-official-input]::before {
  position:static!important; inset:auto!important; transform:none!important;
  display:inline!important; width:auto!important; min-width:0!important; max-width:none!important;
  height:auto!important; margin:0!important; padding:0!important;
  white-space:nowrap!important; overflow-wrap:normal!important; word-break:normal!important;
  pointer-events:none!important;
}
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] [data-sl-official-input]::before,
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] [data-sl-official-input]::placeholder {
  font-size:15px!important; line-height:24px!important; color:#b8bac0!important;
  -webkit-text-fill-color:#b8bac0!important; opacity:1!important;
}
html[data-sl-official-mode="compact"] [data-sl-official-popup-path] {
  transform:none!important; filter:none!important; backdrop-filter:none!important;
  -webkit-backdrop-filter:none!important; will-change:auto!important;
  perspective:none!important; contain:none!important; overflow:visible!important;
}
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-popup],
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-popup] * {
  visibility:visible!important; pointer-events:auto!important;
}
html[data-sl-official-mode="compact"] [data-sl-official-popup] {
  position:fixed!important; inset:auto 0 var(--sl-official-composer-height,56px) 0!important; transform:none!important;
  width:100vw!important; max-width:100vw!important; min-width:0!important; height:auto!important;
  max-height:min(320px,calc(100vh - var(--sl-official-composer-height,56px)))!important; margin:0!important;
  box-sizing:border-box!important; overflow:auto!important; opacity:1!important; z-index:2147483001!important;
}
html[data-sl-official-mode="compact"] [data-sl-official-popup-scroll] {
  min-height:0!important; max-height:min(240px,calc(100vh - var(--sl-official-composer-height,56px) - 72px))!important;
  overflow-y:auto!important; overscroll-behavior:contain!important;
}

/* All four composers expose only the original input, emoji and send nodes.
   Ancestors keep their event tree but contribute no old desktop toolbar layout. */
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-editor-root] {
  inset:auto 0 0 0!important; width:100vw!important; height:56px!important;
  min-height:56px!important; max-height:56px!important; padding:0!important; overflow:visible!important;
}
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-editor-root] *:not([data-sl-official-control]):not([data-sl-official-control] *):not([data-sl-official-control-path]):not([data-sl-official-popup]):not([data-sl-official-popup] *):not([data-sl-official-popup-path]) {
  visibility:hidden!important;
}
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control-path] {
  display:contents!important; transform:none!important; filter:none!important;
  backdrop-filter:none!important; -webkit-backdrop-filter:none!important;
  will-change:auto!important; contain:none!important;
}
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control] {
  position:fixed!important; transform:none!important; box-sizing:border-box!important;
  min-width:0!important; min-height:0!important; max-height:40px!important; z-index:2147483002!important;
}
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="input"] {
  display:block!important; inset:auto 72px 9px 46px!important; margin:0!important;
  width:calc(100vw - 118px)!important; height:38px!important; max-height:38px!important;
  padding:7px 10px!important; font-size:15px!important; line-height:24px!important;
  white-space:pre!important; overflow-x:auto!important; overflow-y:hidden!important;
}
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="emoji"] {
  display:flex!important; align-items:center!important; justify-content:center!important;
  inset:auto auto 12px 8px!important; margin:0!important; width:32px!important; height:32px!important;
  max-height:32px!important; padding:0!important; line-height:1!important; overflow:visible!important;
}
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="send"] {
  display:flex!important; align-items:center!important; justify-content:center!important;
  inset:auto 8px 10px auto!important; margin:0!important; width:56px!important; height:36px!important;
  max-height:36px!important; padding:0!important; line-height:1!important;
  text-align:center!important; text-indent:0!important; white-space:nowrap!important;
}
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="send"] * {
  margin:0!important; padding:0!important; height:auto!important; min-height:0!important;
  line-height:1!important; position:static!important; transform:none!important;
}
html[data-sl-official-site="huya"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="send"] {
  border-radius:6px!important; font-size:14px!important;
}
/* One inset Douyin row. Override native absolute positioning once, rather than
   stacking toolbar variants whose dimensions depend on the full room page. */
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] {
  inset:auto 8px 6px 8px!important; width:calc(100vw - 16px)!important;
  height:44px!important; min-height:44px!important; max-height:44px!important;
  padding:0!important; margin:0!important;
  background:#3f404a!important; border:0!important; border-radius:8px!important;
  box-sizing:border-box!important; overflow:visible!important;
}
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="input"] {
  inset:auto 80px 8px 12px!important; margin:0!important;
  width:calc(100vw - 92px)!important; height:40px!important; min-height:40px!important; max-height:40px!important;
  padding:8px 4px!important; font-size:16px!important; line-height:24px!important; text-align:left!important;
  color:#b8bac0!important; -webkit-text-fill-color:#b8bac0!important; caret-color:#fff!important;
  background:transparent!important; border:0!important; border-radius:0!important; outline:0!important;
  overflow-x:auto!important; overflow-y:hidden!important; white-space:pre!important;
  overflow-wrap:normal!important; word-break:normal!important; opacity:1!important;
}
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="emoji"],
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="send"] {
  width:28px!important; height:28px!important;
  min-width:28px!important; min-height:28px!important; max-width:28px!important; max-height:28px!important;
  display:flex!important; align-items:center!important; justify-content:center!important;
  padding:0!important; margin:0!important; border:0!important; background:transparent!important; line-height:0!important;
}
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="emoji"] {
  inset:auto 42px 14px auto!important;
}
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="send"] {
  inset:auto 8px 14px auto!important;
}
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="emoji"] *,
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="send"] * {
  position:static!important; inset:auto!important; transform:none!important; margin:0!important; padding:0!important;
}
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] svg[data-sl-official-control],
html[data-sl-official-site="douyin"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control] svg {
  display:block!important; width:24px!important; height:24px!important;
  min-width:24px!important; min-height:24px!important; max-width:24px!important; max-height:24px!important;
  flex:0 0 24px!important;
}
/* Only a compact native composer is shown, not a progressively loaded room
   skin. Late Douyu skin CSS must not repaint this already-visible strip. */
html[data-sl-official-site="douyu"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] {
  background:#f7f8fa!important; border:0!important;
}
html[data-sl-official-site="douyu"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="input"] {
  background:transparent!important; border:0!important; outline:0!important; color:#333!important; text-align:left!important;
}
html[data-sl-official-site="douyu"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="emoji"][data-sl-official-emoji-fallback] {
  background:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Ccircle cx='12' cy='12' r='10' fill='%23c4c7ce'/%3E%3Ccircle cx='9' cy='10' r='1.5' fill='%23fff'/%3E%3Ccircle cx='15' cy='10' r='1.5' fill='%23fff'/%3E%3Cpath d='M8.5 14c.8 2 2.1 3 3.5 3s2.7-1 3.5-3' fill='%23fff'/%3E%3C/svg%3E") no-repeat center / 24px 24px!important;
}
html[data-sl-official-site="douyu"][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-control="send"] {
  background:#ff5d23!important; color:#fff!important; border-radius:18px!important; font-size:14px!important; border:0!important;
}
html[data-sl-official-site][data-sl-official-mode="compact"] [data-sl-official-popup] {
  min-height:0!important;
}
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-editor-root] [data-sl-official-popup-path] {
  transform:none!important; filter:none!important; backdrop-filter:none!important;
  -webkit-backdrop-filter:none!important; will-change:auto!important;
  perspective:none!important; contain:none!important; overflow:visible!important;
}
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-control],
html[data-sl-official-site][data-sl-official-mode="compact"] body [data-sl-official-control] * {
  visibility:visible!important;
}
`;
(document.head || document.documentElement).appendChild(style);
const setExpanded = expanded => {
  state.expanded = !!expanded;
  if (!state.expanded && !state.root?.isConnected && !adapter.hideUntilReady) {
    document.documentElement.removeAttribute('data-sl-official-mode');
  } else {
    mark(document.documentElement, 'data-sl-official-mode', state.expanded ? 'full' : 'compact');
  }
};
const focus = () => {
  if (guardRoom()) return false;
  const input = state.input;
  if (!input?.isConnected || input.disabled || input.readOnly) { state.pendingFocus = true; return false; }
  input.focus({preventScroll: true});
  state.pendingFocus = false;
  return document.activeElement === input;
};
const inspect = () => ({status: state.ready && state.input?.isConnected ? 'ready' : 'loading', expanded: state.expanded, emojiOpen: state.emojiOpen,
  protocolStatus:window.__simpleLiveSendSession?.getStatus?.()});
const readDraft = input => {
  if (!input) return '';
  if (typeof input.value === 'string') return input.value;
  // Douyin editor-kit appends a data-enter leaf containing U+200B. It is a
  // structural caret marker, not content. Never strip authored zero-width text.
  const copy = input.cloneNode(true);
  for (const marker of site === 'douyin' ? copy.querySelectorAll('span[data-enter="true"][data-leaf="true"]') : []) {
    if (marker.textContent === '\u200b') marker.remove();
  }
  return copy.textContent || '';
};
const guardRoom = () => {
  const id = currentRoom();
  if (!allowed.size || !id || allowed.has(id)) return false;
  document.documentElement.setAttribute('data-sl-official-blocked', '');
  window.__simpleLiveSendSession?.close();
  if (document.activeElement instanceof HTMLElement) document.activeElement.blur();
  report('wrong_room');
  return true;
};
const originallyVisible = element => {
  // Never disable compact CSS. Native display/aria/inline visibility still
  // identify open popups; our own visibility mask is intentionally ignored.
  for (let e = element; e; e = e.parentElement) {
    if (e.hidden || e.getAttribute('aria-hidden') === 'true' ||
        e.style.display === 'none' || e.style.visibility === 'hidden' ||
        getComputedStyle(e).display === 'none') return false;
  }
  return element.isConnected && element.getClientRects().length && getComputedStyle(element).opacity !== '0';
};
const keepComposerControls = () => {
  if (!state.root || !state.input) return;
  const nextControls = [], nextPaths = [];
  const known = {douyin:'.webcast-chatroom___emoji-icon', huya:'#J_inputEmot', douyu:'.EmotionSwitcher', bilibili:'.emoticons, .emoji-btn, .emoticon'};
  const iconControl = svg => {
    if (!svg) return null;
    const btn = svg.closest('button,[role="button"]');
    if (btn && state.root.contains(btn) && !btn.contains(state.input) && btn.querySelectorAll('svg').length === 1) return btn;
    const parent = svg.parentElement;
    if (parent && parent !== state.root && !parent.contains(state.input) && parent.querySelectorAll('svg').length === 1) return parent;
    return svg;
  };
  let emoji = known[site] && state.root.querySelector(known[site]);
  if (!emoji) emoji = state.root.querySelector('[title*="表情"], [aria-label*="表情"], [title*="emoji"], [aria-label*="emoji"]');
  const douyinSvgs = site === 'douyin' ? Array.from(state.root.querySelectorAll('svg')).filter(e => !state.input.contains(e)) : [];
  const afterInputSvgs = douyinSvgs.filter(e => state.input.compareDocumentPosition(e) & Node.DOCUMENT_POSITION_FOLLOWING);
  const candidateSvgs = afterInputSvgs.length ? afterInputSvgs : douyinSvgs;
  if (!emoji && site === 'douyin') {
    emoji = iconControl(candidateSvgs[0]);
  }
  let send = state.root.querySelector(adapter.button) || Array.from(state.root.querySelectorAll('button,[role="button"]')).find(e => /^(发送|发言)$/.test((e.getAttribute('aria-label') || e.textContent).trim()));
  if (!send && site === 'douyin') {
    const rest = candidateSvgs.filter(e => !emoji || (e !== emoji && !emoji.contains(e)));
    send = iconControl(rest.at(-1));
  }
  for (const [node, role] of [[state.input,'input'],[emoji,'emoji'],[send,'send']]) {
    if (!node) continue;
    mark(node, 'data-sl-official-control',role); nextControls.push(node);
    for (let e=node.parentElement; e && e!==state.root; e=e.parentElement) {
      nextPaths.push(e);
    }
  }
  state.controls.forEach(e => { if (!nextControls.includes(e)) e.removeAttribute('data-sl-official-control'); });
  state.controls = nextControls;
  state.controlPaths = syncMarks(state.controlPaths, nextPaths, 'data-sl-official-control-path');
};
const updateEmojiPopup = () => {
  if (!state.emojiRequested && !state.emojiOpen) return;
  const isValidPopup = e => e && e !== state.root && e !== document.body && !e.contains(state.root) &&
    !state.controls.some(c => e === c || e.contains(c)) && originallyVisible(e);
  const selectors = {
    huya: '.chat-emot [class*="Dashboard--"], .chat-emot, .chat-emotLnk',
    douyu: '.Emotion-wrap',
    bilibili: '.emoticons-panel, .emoji-panel, .emoticon-panel, [class*="emoticons-panel"], [class*="emoticon-panel"], [class*="emoji-panel"], .bili-emoji-panel, .chat-emoticon-panel'
  };
  let popup = selectors[site] ? Array.from(document.querySelectorAll(selectors[site])).find(e => e.querySelector('img,button,[data-id],canvas,span[style*="background"]') && isValidPopup(e) && !(site === 'huya' && e.matches('.chat-emot') && e.querySelector('[class*="Dashboard--"]'))) || null : null;
  // Only scan while the user has opened emoji. Native labels survive hashed
  // class names; keep the original grid/handlers rather than rebuilding it.
  const texts = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  for (let text = texts.nextNode(); text && !popup; text = texts.nextNode()) {
    if (!/^(最常使用|常用表情|全部表情|小表情|会员表情|通用表情|房间表情|装扮表情|官方表情|大表情|颜文字|热词|最近使用|收藏|小黄脸)$/.test(text.textContent.trim())) continue;
    for (let e = text.parentElement, depth = 0; e && e !== document.body && depth < 8; e = e.parentElement, depth++) {
      if (e === state.root || e === document.body || e.contains(state.root) || state.controls.some(c => e === c || e.contains(c))) break;
      if (e.querySelectorAll('img,button,[role="button"],svg').length >= 4 && isValidPopup(e)) {
        if (!popup) popup = e;
        // Keep the footer tabs with the grid, not just the first inner group.
        if (/小表情|会员表情|通用表情|房间表情|官方表情|大表情/.test(e.textContent)) { popup = e; break; }
      }
    }
  }
  if (!popup && state.emojiRequested) {
    const scope = Array.from(document.querySelectorAll(`${state.root ? '[data-sl-official-editor-root] *, ' : ''}[class*="emoticon"], [class*="emoji"], [role="dialog"], [role="tooltip"]`));
    let bestArea = 0;
    for (const e of scope) {
      if (!isValidPopup(e)) continue;
      const imgs = Array.from(e.querySelectorAll('img')).filter(img => {
        const r = img.getBoundingClientRect();
        return r.width > 0 && r.width <= 64 && r.height > 0 && r.height <= 64;
      });
      if (imgs.length < 6) continue;
      const r = e.getBoundingClientRect();
      const area = r.width * r.height;
      if (area > bestArea) { popup = e; bestArea = area; }
    }
  }
  if (!popup && !state.popup && performance.now() < state.emojiDeadline) return;
  if (state.popup !== popup) state.popup?.removeAttribute('data-sl-official-popup');
  const nextPaths = [];
  let nextScrolls = [];
  if (popup) {
    // Native grids can have their own hidden/auto viewport. Clamping only
    // the portal leaves those grids clipped and unable to scroll.
    nextScrolls = Array.from(popup.querySelectorAll('*')).filter(e =>
      e.clientHeight > 0 && e.scrollHeight > e.clientHeight + 1 &&
      /auto|scroll|hidden/.test(getComputedStyle(e).overflowY));
    mark(popup, 'data-sl-official-popup');
    state.emojiOpen = true;
    mark(document.documentElement, 'data-sl-official-emoji');
    for (let e = popup.parentElement; e && e !== document.documentElement; e = e.parentElement) {
      nextPaths.push(e);
    }
  } else {
    state.emojiOpen = false; state.emojiRequested = false;
    document.documentElement.removeAttribute('data-sl-official-emoji');
  }
  state.popupPaths = syncMarks(state.popupPaths, nextPaths, 'data-sl-official-popup-path');
  state.popupScrolls = syncMarks(state.popupScrolls, nextScrolls, 'data-sl-official-popup-scroll');
  state.popup = popup;
};
const validSelfName = raw => {
  const clean = String(raw || '').trim();
  if (!clean || clean.length > 40) return '';
  if (/^(登录|注册|未登录|请登录|立即登录|抖音|直播|头像|logo|下载|游客)$/i.test(clean)) return '';
  return clean;
};
const findNickInObject = (obj, depth = 0) => {
  if (!obj || typeof obj !== 'object' || depth > 3) return '';
  for (const key of ['nickname', 'nickName', 'uname', 'user_name', 'nick']) {
    if (typeof obj[key] === 'string') {
      const hit = validSelfName(obj[key]);
      if (hit) return hit;
    }
  }
  for (const [k, v] of Object.entries(obj)) {
    if (/anchor|owner|room|streamer|author|liver/i.test(k)) continue;
    if (v && typeof v === 'object') {
      const nested = findNickInObject(v, depth + 1);
      if (nested) return nested;
    }
  }
  return '';
};
const detectSelfName = () => {
  if (site === 'huya') {
    const winNick = validSelfName(window.TT_USER_INFO?.nick || window.hy_user_info?.nick);
    if (winNick) return winNick;
  }
  const selfSelectors = {
    bilibili: '.header-entry-mini .user-name, .bili-header .nickname, .user-panel-ctnr .user-name, .v-popover-wrap .user-name',
    douyin: '[data-e2e="user-info"] [class*="name"], [data-e2e="live-user-info"] [class*="name"], [data-e2e="douyin-header"] [class*="avatar"] img[alt], [data-e2e="user-avatar"] img[alt], header [data-e2e*="avatar"] img[alt], header img[alt]',
    douyu: '.UserInfo-nickname, .Header-UserInfo-nickName, .Header-UserInfo-name, .UserName, [class*="UserInfo"] [class*="nick"]',
    huya: '.udb-nick, #J_userName, .header-user-name, .hy-nav-user-name, .nav-user-name, #J_duyaHeaderRight .user-name, [class*="Header"] [class*="nick"], [class*="header"] [class*="nick"]'
  };
  const sel = selfSelectors[site];
  if (sel) {
    for (const el of document.querySelectorAll(sel)) {
      if (state.root?.contains(el)) continue;
      const hit = validSelfName(el.getAttribute('alt') || el.textContent);
      if (hit) return hit;
    }
  }
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i) || '';
      if (!/user|account|login|profile|passport|auth/i.test(k) || /anchor|owner|room|streamer/i.test(k)) continue;
      const raw = localStorage.getItem(k);
      if (!raw || raw.length > 32768 || raw[0] !== '{') continue;
      try {
        const hit = findNickInObject(JSON.parse(raw));
        if (hit) return hit;
      } catch (_) {}
    }
  } catch (_) {}
  if (site === 'douyin') {
    try {
      const renderEl = document.getElementById('RENDER_DATA');
      if (renderEl?.textContent) {
        const data = JSON.parse(decodeURIComponent(renderEl.textContent));
        const hit = findNickInObject(data?.userStore || data?.app?.userInfo || data?.userInfo);
        if (hit) return hit;
      }
    } catch (_) {}
  }
  return '';
};
const sweep = () => {
  // composerButton also refreshes synchronously. Consume an already scheduled
  // sweep instead of orphaning its timer and rescanning the DOM again later.
  clearTimeout(state.timer);
  state.timer = null;
  if (guardRoom()) return;
  if (!style.isConnected) (document.head || document.documentElement).appendChild(style);
  // Throttled layout observation only; never poll an endpoint or edit a draft.
  const input = document.querySelector(adapter.input);
  const button = document.querySelector(adapter.button);
  let root = input?.closest(adapter.root) || document.querySelector(adapter.root);
  if (!root && input && button) {
    root = input.parentElement;
    while (root && !root.contains(button)) root = root.parentElement;
  }
  if (!root && input && site === 'douyin') {
    // Alternate native editor variants lack data-e2e send markers. Search only
    // nearby containers, never choose the full room (header/gift shelf).
    root = input.parentElement;
    for (let e = root, depth = 0; e && e !== document.body && depth < 3; e = e.parentElement, depth++) {
      if (Array.from(e.querySelectorAll('button,[role="button"]')).some(b => /^(发送|发言)$/.test(b.textContent.trim()))) {
        root = e; break;
      }
    }
  }
  if (site === 'douyin' && input) {
    // chat-input may mark only the editable, with native emoji/send as siblings.
    // Keep their smallest shared row, never the surrounding gift/chat panel.
    for (let e = input.parentElement, depth = 0; e && e !== document.body && depth < 4; e = e.parentElement, depth++) {
      const icons = Array.from(e.querySelectorAll('svg')).filter(n => !input.contains(n));
      const controls = Array.from(e.querySelectorAll('button,[role="button"],[aria-label],[title]')).filter(n => !input.contains(n));
      const emoji = controls.some(n => /表情|emoji/i.test((n.getAttribute('aria-label') || '') + (n.getAttribute('title') || '')));
      const send = (button && e.contains(button)) || controls.some(n => /^(发送|发言)$/.test((n.getAttribute('aria-label') || n.textContent).trim()));
      if (e.getBoundingClientRect().height <= 140 && ((emoji && send) || icons.length >= 2)) { root = e; break; }
    }
  }
  if (root === document.body || root === document.documentElement) root = null;
  if (root !== state.root) {
    state.root?.removeAttribute('data-sl-official-editor-root');
    state.path.forEach(e => e.removeAttribute('data-sl-official-editor-path'));
    state.path = [];
    state.root = root;
    if (root) {
      root.setAttribute('data-sl-official-editor-root', '');
      for (let e = root.parentElement; e && e !== document.documentElement; e = e.parentElement) {
        e.setAttribute('data-sl-official-editor-path', ''); state.path.push(e);
      }
    }
  }
  const editor = input || root?.querySelector('textarea, [contenteditable]');
  if (state.input !== editor) state.input?.removeAttribute('data-sl-official-input');
  state.input = editor;
  if (site === 'douyin') {
    const nextInputPath = [];
    if (state.input) mark(state.input, 'data-sl-official-input');
    for (let e = state.input?.parentElement; e && e !== root && root?.contains(e); e = e.parentElement) {
      nextInputPath.push(e);
    }
    state.inputPath = syncMarks(state.inputPath, nextInputPath, 'data-sl-official-input-path');
  }
  keepComposerControls();
  let douyuPainted = true;
  if (site === 'douyu' && root && state.input) {
    const emojiEl = state.controls.find(e => e.getAttribute('data-sl-official-control') === 'emoji');
    const hasEmojiVisual = !!emojiEl && (
      !!emojiEl.querySelector('svg, img') ||
      getComputedStyle(emojiEl).backgroundImage !== 'none' ||
      Array.from(emojiEl.querySelectorAll('*')).some(c => getComputedStyle(c).backgroundImage !== 'none')
    );
    if (emojiEl) {
      if (hasEmojiVisual) emojiEl.removeAttribute('data-sl-official-emoji-fallback');
      else {
        if (!state.douyuSeenAt) state.douyuSeenAt = performance.now();
        if (performance.now() - state.douyuSeenAt < 2500) {
          douyuPainted = false;
          setTimeout(schedule, 150);
        } else {
          mark(emojiEl, 'data-sl-official-emoji-fallback');
        }
      }
    }
  }
  state.ready = !!(root && state.input && douyuPainted && window.__simpleLiveSendSession?.isReady?.() !== false && (!adapter.completeControls ||
    ['emoji','send'].every(role => state.controls.some(e => e.getAttribute('data-sl-official-control') === role))));
  if (state.ready) {
    if (!state.expanded) setExpanded(false);
    const composerHeight = '56px';
    if (document.documentElement.style.getPropertyValue('--sl-official-composer-height') !== composerHeight) {
      document.documentElement.style.setProperty('--sl-official-composer-height', composerHeight);
    }
    updateEmojiPopup();
    const selfName = detectSelfName();
    report('ready', {focused: document.hasFocus() && document.activeElement === state.input, emojiOpen: state.emojiOpen, ...(selfName ? {selfName} : {})});
    if (state.pendingFocus) focus();
  } else {
    // Douyin loads its editor asynchronously. Do not flash a cropped full room
    // into the compact slot; explicit expansion still exposes login/verification.
    if (adapter.hideUntilReady) setExpanded(state.expanded);
    else document.documentElement.removeAttribute('data-sl-official-mode');
    report('loading', {protocolStatus:window.__simpleLiveSendSession?.getStatus?.()});
  }
  if (!state.expanded) {
    const modal = Array.from(document.querySelectorAll('[role="dialog"], .geetest_panel, .captcha_verify_container, .bili-mini-mask, .hy-login-box'))
      .find(e => {
        // Native emoji portals may also be dialogs, not login/verification.
        const popup = state.popup;
        return !(popup && (e === popup || popup.contains(e) || e.contains(popup))) && originallyVisible(e);
      });
    if (modal) report('requires_login');
  }
};
const schedule = () => { if (!state.timer) state.timer = setTimeout(sweep, 120); };
const observer = new MutationObserver(schedule);
observer.observe(document.documentElement, {subtree:true, childList:true, attributes:true, attributeFilter:['style','class','aria-hidden']});
window.addEventListener('simplelive-protocol-ready', schedule);
document.addEventListener('focusin', () => {
  const focused = !!state.root?.contains(document.activeElement);
  report('focus', {focused});
});
document.addEventListener('focusout', () => setTimeout(() => report('focus', {focused: document.hasFocus() && !!state.root?.contains(document.activeElement)}), 0));
window.addEventListener('blur', () => report('focus', {focused:false}));
for (const evt of ['mouseleave', 'mouseout', 'pointerleave', 'pointerout']) {
  document.addEventListener(evt, event => {
    if (!state.emojiOpen && !state.emojiRequested) return;
    if (event.target instanceof Element &&
        (state.popup?.contains(event.target) ||
         state.root?.contains(event.target) ||
         (state.popup && event.target.contains(state.popup)) ||
         event.target.closest('[data-sl-official-popup], [data-sl-official-control="emoji"]'))) {
      event.stopImmediatePropagation();
    }
  }, true);
}
document.addEventListener('click', event => {
  if (guardRoom()) { event.preventDefault(); event.stopImmediatePropagation(); return; }
  if (!(event.target instanceof Element)) return;
  if (state.popup?.contains(event.target) || event.target.closest('[data-sl-official-popup]')) {
    schedule();
    return;
  }
  if (!state.root?.contains(event.target)) return;
  const markedEmoji = event.target.closest('[data-sl-official-control="emoji"]');
  const control = event.target.closest('[title], [aria-label], button, [role="button"], #J_inputEmot');
  const emojiIcon = site === 'douyin' ? Array.from(state.root.querySelectorAll('svg')).find(n => !state.input?.contains(n)) : null;
  const emojiButton = emojiIcon && (emojiIcon.closest('button,[role="button"]') || emojiIcon.parentElement);
  const sendButton = event.target.closest('[data-sl-official-control="send"]');
  if (sendButton) {
    const text = readDraft(state.input);
    if (!window.__simpleLiveSendSession?.begin(text)) {
      event.preventDefault(); event.stopImmediatePropagation(); return;
    }
  }
  if (markedEmoji || emojiButton?.contains(event.target) || (control && /表情|emoji|emot/i.test(`${control.getAttribute('title') || ''} ${control.getAttribute('aria-label') || ''} ${control.id} ${control.className}`))) {
    // Track the user's toggle, not just popup DOM existence. Native sites can
    // retain a class-hidden portal or show hover history after closing it.
    // Our layout marks must not turn either into another open request.
    if (state.emojiRequested || state.emojiOpen) {
      state.emojiRequested = false;
      state.emojiOpen = false;
      state.emojiDeadline = 0;
      state.popup?.removeAttribute('data-sl-official-popup');
      state.popup = null;
      state.popupPaths = syncMarks(state.popupPaths, [], 'data-sl-official-popup-path');
      state.popupScrolls = syncMarks(state.popupScrolls, [], 'data-sl-official-popup-scroll');
      document.documentElement.removeAttribute('data-sl-official-emoji');
    } else {
      state.emojiRequested = true;
      state.emojiDeadline = performance.now() + 15000;
      setTimeout(schedule, 15100);
    }
    // The native handler runs unmodified before this deferred layout sweep.
    schedule();
  }
}, true);
document.addEventListener('keydown', event => {
  if (guardRoom()) { event.preventDefault(); event.stopImmediatePropagation(); return; }
  if (event.key === 'Enter' && !event.shiftKey && !event.ctrlKey && state.input && (event.target === state.input || state.input.contains(event.target))) {
    // Candidate confirmation must not reach platform handlers that ignore IME.
    if (event.isComposing || event.keyCode === 229 || event.repeat ||
        !window.__simpleLiveSendSession?.begin(readDraft(state.input))) {
      event.preventDefault(); event.stopImmediatePropagation();
    }
  }
}, true);
for (const name of ['pushState', 'replaceState']) {
  const original = history[name];
  history[name] = function(...args) {
    const value = original.apply(this, args);
    guardRoom();
    return value;
  };
}
window.addEventListener('popstate', guardRoom);
const mute = e => { if (e instanceof HTMLMediaElement && !e.muted) e.muted = true; };
document.addEventListener('play', e => mute(e.target), true);
document.addEventListener('volumechange', e => mute(e.target), true);
document.querySelectorAll('video,audio').forEach(mute);
window.__simpleLiveOfficialEditor = {setExpanded, focus, inspect,
  composerInput:()=>state.input,
  composerDraft:()=>readDraft(state.input),
  composerButton:()=>{sweep();return state.controls.find(e=>e.getAttribute('data-sl-official-control')==='send');}};
sweep();
return inspect();
''';
}
