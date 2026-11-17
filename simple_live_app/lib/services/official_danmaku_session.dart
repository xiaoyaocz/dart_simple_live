/// Observes the official page's own authenticated transport. Never constructs,
/// signs, retries or modifies a platform request, and never exports credentials.
class OfficialDanmakuSession {
  static const install = r'''
if (window.__simpleLiveSendSession) return;
const rooms = new Set(expectedRoomIds.map(String));
const supported = ['huya','douyin'].includes(site);
let pending = null, closed = false, huyaReady = false;
let huyaAttaching = false;
const documentId = crypto.randomUUID();
let nextId = 0;
const uncertain = new Set();
const emit = (status, message, extra = {}) => {
  try { window.flutter_inappwebview?.callHandler('simpleLiveDanmakuState', {status,message,documentId,...extra})?.catch(()=>{}); } catch (_) {}
};
const finish = (attempt, status, message) => {
  if (closed || pending !== attempt) return;
  clearTimeout(attempt.timer);
  pending = null;
  if (status === 'unknown') uncertain.add(attempt.text);
  emit(status,message,{id:attempt.id,...(status === 'sent' ? {text:attempt.text,
    ...(attempt.userId ? {userId:attempt.userId} : {}),...(attempt.userName ? {userName:attempt.userName} : {})} : {})});
};
const begin = text => {
  if (closed) return false;
  if (pending) { emit('busy','上一条弹幕仍在发送，请等待平台确认'); return false; }
  if (!supported || (site === 'huya' && !huyaReady)) {
    emit('unsupported','当前平台发送协议尚未就绪，请在搜索网页检查登录或刷新输入区'); return false;
  }
  if (!text.trim()) return false;
  if (uncertain.has(text) || uncertain.size >= 100) {
    emit('unknown','此弹幕发送结果未确认，请先查看聊天；刷新输入区后再决定是否重发'); return false;
  }
  const attempt = pending = {id:++nextId,text,submitted:false};
  attempt.timer = setTimeout(() => finish(attempt, 'unknown',
    '未取得平台确认，请检查登录或发言限制，并先查看聊天，避免重复发送'), 10000);
  emit('sending','正在等待平台确认…',{id:attempt.id});
  return true;
};
const close = () => {
  closed = true;
  if (pending) clearTimeout(pending.timer);
  pending = null;
  clearInterval(huyaPoll);
};
window.__simpleLiveSendSession = {begin,close,
  getStatus:()=>closed ? 'closed' : !supported ? 'unsupported' : site !== 'huya' || huyaReady ? 'ready' :
    typeof window.TTP?.ready !== 'function' ? 'module' : 'sdk',
  isReady:()=>!closed && supported && (site !== 'huya' || huyaReady)};
window.addEventListener('pagehide',close,{once:true});

// Exact per-platform endpoint, body and canonical room correlation. HTTP 200
// alone and a cleared draft are never acknowledgements.
const requestAttempt = (resource, body) => {
  const attempt = pending;
  if (!attempt || closed) return null;
  try {
    const url = new URL(typeof resource === 'string' ? resource : resource.url || String(resource),location.href);
    const match = site === 'douyin' && url.protocol === 'https:' && url.hostname === 'live.douyin.com' && url.pathname === '/webcast/room/chat/';
    if (!match) return null;
    let values = new URLSearchParams();
    if (body instanceof FormData || body instanceof URLSearchParams) values = body;
    else if (typeof body === 'string') values = new URLSearchParams(body);
    const text = values.get('content') ?? url.searchParams.get('content');
    const room = values.get('room_id') ?? url.searchParams.get('room_id');
    if (text !== attempt.text || !rooms.has(String(room))) return null;
    attempt.submitted = true;
    return attempt;
  } catch (_) { return null; }
};
const acknowledge = (attempt, response, httpStatus) => {
  if (pending !== attempt) return;
  if (httpStatus < 200 || httpStatus >= 300) {
    finish(attempt,httpStatus >= 500 ? 'unknown' : 'rejected',
      httpStatus >= 500 ? '平台服务异常，发送结果未确认，请先查看聊天' : '平台拒绝发送（HTTP '+httpStatus+'）'); return;
  }
  let data;
  try { data = typeof response === 'string' ? JSON.parse(response) : response; } catch (_) { return; }
  const code = data?.status_code;
  if (typeof code !== 'number' && typeof code !== 'string') return;
  if (code === 0 || code === '0') {
    // Use only account identity carried by the platform's own chat response.
    const user=data.data?.user;
    if(user?.id_str) attempt.userId=String(user.id_str);
    if(typeof user?.nickname==='string') attempt.userName=user.nickname;
    finish(attempt,'sent','平台已确认发送');
  }
  else {
    const login = [-101,-111,401].includes(Number(code));
    finish(attempt,login ? 'login' : 'rejected',login ? '登录已失效，请在搜索网页重新登录' :
      '平台拒绝或屏蔽了弹幕，请检查实名、禁言及发送频率（'+String(code).slice(0,16)+'）');
  }
};
if (site === 'douyin') {
  const originalFetch = window.fetch;
  window.fetch = async function(resource, init) {
    let body = init?.body;
    if (body == null && resource instanceof Request) {
      try { body = await resource.clone().text(); } catch (_) {}
    }
    const attempt = requestAttempt(resource,body);
    try {
      const response = await originalFetch.apply(this,arguments);
      if (attempt) response.clone().text().then(data=>acknowledge(attempt,data,response.status)).catch(()=>{});
      return response;
    } catch (error) {
      if (attempt) finish(attempt,'unknown','网络中断，发送结果未确认，请先查看聊天');
      throw error;
    }
  };
  const urls = new WeakMap();
  const originalOpen = XMLHttpRequest.prototype.open;
  const originalSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(method,url) { urls.set(this,String(url)); return originalOpen.apply(this,arguments); };
  XMLHttpRequest.prototype.send = function(body) {
    const attempt = requestAttempt(urls.get(this),body);
    if (attempt) {
      const failed = () => finish(attempt,'unknown','网络中断，发送结果未确认，请先查看聊天');
      for (const event of ['error','timeout','abort']) this.addEventListener(event,failed,{once:true});
      this.addEventListener('load',()=>{
        try { acknowledge(attempt,this.responseType === 'json' ? this.response : this.responseText,this.status); } catch (_) {}
      },{once:true});
      this.addEventListener('loadend',()=>{
        for (const event of ['error','timeout','abort']) this.removeEventListener(event,failed);
      },{once:true});
    }
    return originalSend.apply(this,arguments);
  };
}

// Huya's current published H5 room calls SDK.sendWup2('liveui','sendMessage',
// SendMessageReq, callback). Observe that callback, not RoomSendMessageSuccess:
// the latter also fires for nonzero iStatus when sToast is empty.
const attachHuya = () => {
  if (closed || site !== 'huya' || huyaReady || huyaAttaching) return;
  // Observe the instance initialized by the website. Requiring its module from
  // a webpack runtime callback can execute it before the site's main entry.
  const ttp = window.TTP;
  if (typeof ttp?.ready !== 'function') return;
    huyaAttaching = true;
    ttp.ready(sdk=>{
      if (closed || huyaReady) return;
      if (typeof sdk?.sendWup2 !== 'function') {huyaAttaching=false;return;}
      const send = sdk.sendWup2;
      sdk.sendWup2 = function(service,method,request,callback) {
        const attempt = !closed && pending && service === 'liveui' && method === 'sendMessage' && request?.sContent === pending.text ? pending : null;
        if (!attempt) return send.apply(this,arguments);
        attempt.submitted = true;
        if(request.tUserId?.lUid) {
          attempt.userId=String(request.tUserId.lUid);
          emit('identity','已识别当前发言账号',{userId:attempt.userId});
        }
        const args = Array.from(arguments);
        args[3] = function(response) {
          if (response?.iStatus === 0) {
            const notice = response.tNotice;
            if (notice?.sContent === attempt.text && String(notice.lTid) === String(request.lTid) && String(notice.lSid) === String(request.lSid)) {
              if(notice.tUserInfo?.lUid) attempt.userId=String(notice.tUserInfo.lUid);
              if(typeof notice.tUserInfo?.sNickName==='string') attempt.userName=notice.tUserInfo.sNickName;
              finish(attempt,'sent','平台已确认发送');
            }
          } else if (typeof response?.iStatus === 'number') {
            finish(attempt,'rejected','虎牙拒绝发送，请检查实名、禁言及频率限制（'+response.iStatus+'）');
          }
          return typeof callback === 'function' ? callback.apply(this,arguments) : undefined;
        };
        try { return send.apply(this,args); }
        catch (error) { finish(attempt,'unknown','虎牙连接中断，发送结果未确认'); throw error; }
      };
      huyaReady = true;
      window.dispatchEvent(new Event('simplelive-protocol-ready'));
    });
};
const huyaPoll = site === 'huya' ? setInterval(attachHuya,500) : null;
attachHuya();

''';
}
