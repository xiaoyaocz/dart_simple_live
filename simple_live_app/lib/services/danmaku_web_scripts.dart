/// Runs inside the original platform page. No endpoint signing or credential export.
class DanmakuWebScripts {
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
  /// Install before platform bundles cache fetch/XHR. No responses are retained
  /// and no credentials/message bodies leave the original page.
  static const transport = r'''
(() => {
  if (window.__simpleLiveTransportInstalled) return;
  window.__simpleLiveTransportInstalled = true;
  const endpoint = /\/msg\/send(?:\?|$)|\/webcast\/room\/chat\/|\/(?:interactive|interactnc)\/.*sendmsg|\/danmu\/send/i;
  let sequence = 0;
  const report = detail => window.dispatchEvent(new CustomEvent('simpleLiveDanmakuTransport', {detail}));
  // Douyu submits through its official binary WebSocket, not an HTTP endpoint.
  // Observe only; never construct a request or retain data outside this page.
  if (/(^|\.)douyu\.com$/.test(location.hostname) && window.WebSocket) {
    const sendSocket = WebSocket.prototype.send;
    const sockets = new WeakMap();
    const unescape = value => value.replace(/@S/g, '/').replace(/@A/g, '@');
    const decode = (bytes, callback) => {
      let offset = 0;
      while (offset + 12 <= bytes.length) {
        const view = new DataView(bytes.buffer, bytes.byteOffset + offset, bytes.length - offset);
        const length = view.getUint32(0, true) + 4;
        if (length < 13 || length > 2 * 1024 * 1024 || view.getUint32(4, true) + 4 !== length) return new Uint8Array();
        if (offset + length > bytes.length) break;
        const text = new TextDecoder().decode(bytes.subarray(offset + 12, offset + length)).replace(/\0$/, '');
        const fields = {};
        for (const field of text.split('/')) {
          const index = field.indexOf('@=');
          if (index >= 0) fields[field.slice(0, index)] = unescape(field.slice(index + 2));
        }
        callback(fields);
        offset += length;
      }
      return bytes.slice(offset);
    };
    const asBytes = async data => {
      if (data instanceof Blob) data = await data.arrayBuffer();
      if (data instanceof ArrayBuffer) return new Uint8Array(data);
      if (ArrayBuffer.isView(data)) return new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
      return new Uint8Array();
    };
    WebSocket.prototype.send = function(data) {
      let state = sockets.get(this);
      if (!state) {
        state = {id: ++sequence, pending: new Uint8Array(), incoming: Promise.resolve()};
        sockets.set(this, state);
        this.addEventListener('message', event => {
          state.incoming = state.incoming.then(async () => {
            const next = await asBytes(event.data);
            if (state.pending.length + next.length > 2 * 1024 * 1024) { state.pending = new Uint8Array(); return; }
            const combined = new Uint8Array(state.pending.length + next.length);
            combined.set(state.pending); combined.set(next, state.pending.length);
            state.pending = decode(combined, fields => {
              if (fields.type === 'chatmsg') report({kind:'socket_echo',id:state.id,fields});
            });
          }).catch(() => { state.pending = new Uint8Array(); });
        });
      }
      // Normal platform sends use ArrayBuffer; Blob decoding must not delay send().
      if (data instanceof ArrayBuffer || ArrayBuffer.isView(data)) {
        const bytes = data instanceof ArrayBuffer ? new Uint8Array(data) : new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
        decode(bytes, fields => {
          if (fields.type === 'chatmessage') report({kind:'socket_start',id:state.id,fields});
        });
      }
      return sendSocket.apply(this, arguments);
    };
  }
  const originalFetch = window.fetch;
  window.fetch = async function(resource, init) {
    const url = typeof resource === 'string' ? resource : resource.url || String(resource);
    let body = init?.body;
    if (body == null && resource instanceof Request && endpoint.test(url)) {
      try { body = await resource.clone().text(); } catch (_) {}
    }
    const id = ++sequence;
    if (endpoint.test(url)) report({kind:'start',id,url,body});
    let response;
    try { response = await originalFetch.apply(this, arguments); }
    catch (error) { if (endpoint.test(url)) report({kind:'error',id,url,body}); throw error; }
    if (endpoint.test(url)) response.clone().text().then(value =>
      report({kind:'response',id,url,body,response:value,httpStatus:response.status})).catch(() => {});
    return response;
  };
  const open = XMLHttpRequest.prototype.open;
  const send = XMLHttpRequest.prototype.send;
  const urls = new WeakMap();
  XMLHttpRequest.prototype.open = function(method, url) {
    urls.set(this, String(url)); return open.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function(body) {
    const url = urls.get(this) || '';
    if (endpoint.test(url)) {
      const id = ++sequence;
      report({kind:'start',id,url,body});
      const failed = () => report({kind:'error',id,url,body});
      for (const name of ['error','timeout','abort']) this.addEventListener(name, failed, {once:true});
      this.addEventListener('loadend', () => {
        for (const name of ['error','timeout','abort']) this.removeEventListener(name, failed);
      }, {once:true});
      this.addEventListener('load', () => {
        let response;
        try { response = this.responseType === 'json' ? this.response : this.responseText; } catch (_) { return; }
        report({kind:'response',id,url,body,response,httpStatus:this.status});
      }, {once:true});
    }
    return send.apply(this, arguments);
  };
})();
''';
  static const silence = r'''
(() => {
  const play = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function () {
    this.muted = true;
    // Bilibili/Douyu attach chat/session initialization to their real player.
    // Suppress audio, not playback or the original Promise/events.
    return play.apply(this, arguments);
  };
})();
''';

  static const send = r'''
const adapters = {
  huya: {input: '#pub_msg_input', button: '#msg_send_bt', endpoint: null},
  douyu: {input: '.ChatSend-txt', button: '.ChatSend-button', endpoint: /\/(?:interactive|interactnc)\/.*sendmsg|\/danmu\/send/i},
  bilibili: {input: 'textarea.chat-input, textarea.chat-input-new, #chat-control-panel-vm textarea, .chat-input-ctnr textarea, .chat-input-ctnr [contenteditable="true"]', button: '.chat-input-ctnr .send-btn, .chat-input-ctnr .bl-button--primary, #chat-control-panel-vm .send-btn, #chat-control-panel-vm .bl-button--primary', endpoint: /\/msg\/send(?:\?|$)/},
  douyin: {input: '[data-e2e="live-chatting"] [contenteditable="true"], [data-e2e="chat-input"] [contenteditable], [data-e2e="chat-input"][contenteditable], textarea[placeholder*="互动"], textarea[placeholder="说点什么"], textarea[placeholder*="输入评论"], [contenteditable="true"][data-placeholder*="互动"], [contenteditable="plaintext-only"]', button: '[data-e2e="chat-send-btn"], [data-e2e="chat-send-button"]', endpoint: /\/webcast\/room\/chat\//}
};
const adapter = adapters[site];
const result = (status, message) => ({status, message});
if (!adapter || !text.trim()) return result('rejected', '请输入弹幕');
if (window.__simpleLiveSending) return result('busy', '上一条弹幕仍在发送');
const input = document.querySelector(adapter.input);
if (!input) return result('not_ready', '网页输入区尚未就绪，请稍后重试');
if (input.disabled || input.readOnly || /登录/.test(input.getAttribute('placeholder') || input.getAttribute('data-placeholder') || '')) {
  return result('login', '请在搜索网页中登录当前平台，或处理发言限制');
}
let button = document.querySelector(adapter.button);
if (!button && site === 'douyin') {
  const root = input.closest('[data-e2e="chat-input"]')?.parentElement || input.parentElement?.parentElement;
  button = root && Array.from(root.querySelectorAll('button, [role="button"]')).find(e => /^(发送|发言)$/.test(e.textContent.trim()));
}
if (!button && site !== 'douyin') return result('not_ready', '暂未找到平台发送按钮，请在搜索网页中检查');
if (typeof prepareOnly !== 'undefined' && prepareOnly) return result('ready', '发送区已就绪');
if (site === 'huya' && window.TT && typeof TT.getUserInfo === 'function') {
  const user = await Promise.race([new Promise(resolve => TT.getUserInfo(resolve)), new Promise(resolve => setTimeout(() => resolve(null), 1500))]);
  if (user && !Number(user.uid)) return result('login', '请在搜索网页中登录虎牙账号');
}
window.__simpleLiveSending = true;
return await new Promise(resolve => {
  let settled = false;
  let timer;
  let observer;
  const started = performance.now();
  let submitted = false;
  const cleanup = [];
  const finish = (status, message) => {
    if (settled) return;
    settled = true;
    clearTimeout(timer);
    if (observer) observer.disconnect();
    cleanup.forEach(fn => { try { fn(); } catch (_) {} });
    window.__simpleLiveSending = false;
    resolve({...result(status, message), submitted, elapsedMs: Math.round(performance.now() - started)});
  };
  const carriesText = (url, body) => {
    try {
      const u = new URL(url, location.href);
      for (const name of ['msg', 'content', 'message', 'text']) if (u.searchParams.get(name) === text) return true;
      if (body instanceof FormData || body instanceof URLSearchParams) {
        for (const name of ['msg', 'content', 'message', 'text']) if (body.get(name) === text) return true;
      }
      if (typeof body === 'string') {
        const form = new URLSearchParams(body);
        for (const name of ['msg', 'content', 'message', 'text']) if (form.get(name) === text) return true;
        try { const data = JSON.parse(body); return ['msg','content','message','text'].some(k => data[k] === text); } catch (_) {}
      }
    } catch (_) {}
    return false;
  };
  const acknowledge = (url, body, response, httpStatus) => {
    if (!adapter.endpoint || !adapter.endpoint.test(url) || !carriesText(url, body)) return;
    if (httpStatus >= 400) { finish('rejected', '平台拒绝发送（HTTP ' + httpStatus + '）'); return; }
    let data;
    try { data = typeof response === 'string' ? JSON.parse(response) : response; } catch (_) { return; }
    const key = site === 'douyin' ? 'status_code' : site === 'douyu' ? 'error' : 'code';
    if (!data || !Object.prototype.hasOwnProperty.call(data, key)) return;
    if (typeof data[key] !== 'number' && typeof data[key] !== 'string') return;
    if (data[key] === 0 || data[key] === '0') finish('sent', '发送成功');
    else finish('rejected', String(data.message || data.msg || data.status_msg || '平台拒绝发送，请检查登录或发言限制').slice(0, 180));
  };
  const activeRequests = new Set();
  let socketRequest;
  const transport = event => {
    const d = event.detail;
    if (site === 'douyu' && d?.kind === 'socket_start' && d.fields?.content === text && d.fields.sender) {
      socketRequest = {id:d.id, sender:String(d.fields.sender)};
      submitted = true;
      return;
    }
    if (site === 'douyu' && d?.kind === 'socket_echo' && socketRequest && d.id === socketRequest.id &&
        String(d.fields?.uid) === socketRequest.sender && d.fields?.txt === text) {
      finish('sent', '发送成功');
      return;
    }
    if (!d || !adapter.endpoint || !adapter.endpoint.test(d.url) || !carriesText(d.url, d.body)) return;
    if (d.kind === 'start') { activeRequests.add(d.id); submitted = true; }
    if (d.kind === 'response' && activeRequests.has(d.id)) acknowledge(d.url, d.body, d.response, d.httpStatus);
    if (d.kind === 'error' && activeRequests.has(d.id)) finish('unknown', '网络请求中断，发送结果未确认，请先查看聊天，避免重复发送');
  };
  window.addEventListener('simpleLiveDanmakuTransport', transport);
  cleanup.push(() => window.removeEventListener('simpleLiveDanmakuTransport', transport));
  // Current Bilibili room delegates to its player (possibly a worker/iframe).
  // Observe the exact native call's Promise instead of guessing from draft clear.
  const biliPlayer = site === 'bilibili' && (window.livePlayer || window.EmbedPlayer?.instance);
  if (biliPlayer && typeof biliPlayer.sendDanmaku === 'function') {
    const original = biliPlayer.sendDanmaku;
    const wrapped = function(data) {
      const pending = original.apply(this, arguments);
      if (data?.msg === text) {
        submitted = true;
        const confirm = value => {
          const response = value?.response || value;
          if (response && (typeof response.code === 'number' || typeof response.code === 'string')) {
            if (response.code === 0 || response.code === '0') finish('sent', '发送成功');
            else finish('rejected', String(response.message || response.msg || '平台拒绝发送').slice(0,180));
          }
        };
        Promise.resolve(pending).then(confirm, confirm);
      }
      return pending;
    };
    biliPlayer.sendDanmaku = wrapped;
    cleanup.push(() => { if (biliPlayer.sendDanmaku === wrapped) biliPlayer.sendDanmaku = original; });
  }
  if (adapter.endpoint) {
    const originalFetch = window.fetch;
    const wrappedFetch = async function(resource, init) {
      const url = typeof resource === 'string' ? resource : resource.url || String(resource);
      let body = init?.body;
      if (body == null && resource instanceof Request && adapter.endpoint.test(url)) {
        try { body = await resource.clone().text(); } catch (_) {}
      }
      const response = await originalFetch.apply(this, arguments);
      if (adapter.endpoint.test(url)) {
        response.clone().text().then(value => acknowledge(url, body, value, response.status)).catch(() => {});
      }
      return response;
    };
    window.fetch = wrappedFetch;
    cleanup.push(() => { if (window.fetch === wrappedFetch) window.fetch = originalFetch; });
    const originalOpen = XMLHttpRequest.prototype.open;
    const originalSend = XMLHttpRequest.prototype.send;
    const wrappedOpen = function(method, url) { this.__simpleLiveUrl = String(url); return originalOpen.apply(this, arguments); };
    const wrappedSend = function(body) {
      const url = this.__simpleLiveUrl || '';
      if (adapter.endpoint.test(url)) this.addEventListener('load', () => {
        let response;
        try { response = this.responseType === 'json' ? this.response : this.responseText; } catch (_) { return; }
        acknowledge(url, body, response, this.status);
      }, {once: true});
      return originalSend.apply(this, arguments);
    };
    XMLHttpRequest.prototype.open = wrappedOpen;
    XMLHttpRequest.prototype.send = wrappedSend;
    cleanup.push(() => {
      if (XMLHttpRequest.prototype.open === wrappedOpen) XMLHttpRequest.prototype.open = originalOpen;
      if (XMLHttpRequest.prototype.send === wrappedSend) XMLHttpRequest.prototype.send = originalSend;
    });
  }
  // Huya's current official room widget clears its own draft on this SDK event.
  if (site === 'huya' && window.TT?.event?.on && window.TT?.event?.off) {
    const success = () => { submitted = true; finish('sent', '发送成功'); };
    TT.event.on('RoomSendMessageSuccess', success);
    cleanup.push(() => TT.event.off('RoomSendMessageSuccess', success));
  }
  const feedback = '[role="alert"], .el-message, .ant-message-notice, .webcast-toast, .hy-popup, .chat-msg-tips, #pubNoticMe';
  const previousFeedback = new Set(Array.from(document.querySelectorAll(feedback)).map(e => e.textContent.trim()));
  observer = new MutationObserver(() => {
    for (const node of document.querySelectorAll(feedback)) {
      const message = node.textContent.trim();
      if (!message || previousFeedback.has(message)) continue;
      if (/发送成功/.test(message)) finish('sent', '发送成功');
      else if (/登录|验证码|实名认证|禁言|禁止发言|频繁|发送失败|发言限制|绑定手机|等级不足/.test(message)) finish('rejected', message.slice(0,180));
    }
  });
  observer.observe(document.body, {childList: true, subtree: true, characterData: true});
  timer = setTimeout(() => finish('unknown', '发送结果未确认，请先查看聊天，避免重复发送'), 8000);
  (async () => { try {
    const nativeInput = typeof nativeInputHandler === 'string' && nativeInputHandler;
    const bridge = window.flutter_inappwebview;
    if (nativeInput && !bridge?.callHandler) { finish('rejected', '原生网页输入连接尚未就绪，本次未发送'); return; }
    if (nativeInput) input.scrollIntoView?.({block:'center',inline:'nearest'});
    input.focus();
    let nativeEdit = false;
    if (input instanceof HTMLTextAreaElement || input instanceof HTMLInputElement) {
      if (nativeInput) input.select();
      else {
        const proto = input instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
        Object.getOwnPropertyDescriptor(proto, 'value').set.call(input, text);
      }
    } else {
      // Native editing updates contenteditable editor state (Draft/React),
      // whereas changing textContent alone can leave its internal draft stale.
      const selection = window.getSelection();
      const range = document.createRange();
      range.selectNodeContents(input);
      selection.removeAllRanges(); selection.addRange(range);
      if (!nativeInput) {
        nativeEdit = typeof document.execCommand === 'function' && document.execCommand('insertText', false, text);
        if (!nativeEdit) input.textContent = text;
      }
    }
    if (nativeInput) {
      if (await bridge.callHandler(nativeInput, {action:'edit'}) !== true) { finish('rejected','网页原生输入失败，本次未发送'); return; }
    } else {
      if (!nativeEdit) input.dispatchEvent(new InputEvent('input', {bubbles: true, inputType: 'insertText', data: text}));
      input.dispatchEvent(new Event('change', {bubbles: true}));
    }
    // React/Vue must commit the new draft before their click handler reads it.
    setTimeout(async () => { try {
      if (settled) return;
      if (button && (button.disabled || button.getAttribute('aria-disabled') === 'true')) finish('rejected', '平台暂不允许发言，请在搜索网页中查看原因');
      // Official buttons can be outside the viewport under desktop DPI/min-width
      // layouts. Calling their own handler works; clicking screen coordinates
      // can silently hit nothing (or an overlay) instead of submitting.
      else if (button) button.click();
      else if (nativeInput) {
        input.focus();
        if (await bridge.callHandler(nativeInput, {action:'submit',enter:true}) !== true) finish('unknown','网页原生提交未完成，请先查看聊天，避免重复发送');
      }
      else input.dispatchEvent(new KeyboardEvent('keydown', {key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true,cancelable:true}));
    } catch (_) { finish('unknown','网页原生提交异常，请先查看聊天，避免重复发送'); }
    }, 80);
  } catch (_) { finish('rejected', '网页发送操作失败，请在搜索网页中检查'); } })();
});
''';
}
