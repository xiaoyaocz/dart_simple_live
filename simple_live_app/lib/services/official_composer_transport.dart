import 'danmaku_sender.dart';

/// A room-scoped binding to the official page, not another platform protocol.
class OfficialComposerTransport implements DanmakuSender {
  Object? _owner;
  Future<DanmakuSendResult> Function(String)? _send;
  bool _closed = false;
  void bind(Object owner, Future<DanmakuSendResult> Function(String) send) {
    if (_closed) return;
    _owner = owner;
    _send = send;
  }

  void unbind(Object owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    _send = null;
  }

  @override
  void prepare() {} // The mounted official host already loads its own session.
  @override
  Future<DanmakuSendResult> send(String text) async {
    if (_closed) return const DanmakuSendResult('closed', '直播间已切换');
    final send = _send;
    if (send == null)
      return const DanmakuSendResult('not_ready', '平台发送连接尚未就绪，请稍后重试');
    return send(text);
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    _send = null;
    _owner = null;
  }

  static const submit = r'''
// Connecting is not a failed submission. Wait for the actual page, not the
// Flutter status mirror; no draft edit or click is attempted during this wait.
let editor;
const deadline=performance.now()+12000;
for (;;) {
  editor=window.__simpleLiveOfficialEditor;
  const state=editor?.inspect();
  if (state?.status==='ready') break;
  if (performance.now()>=deadline) {
    const message=state?.protocolStatus==='sdk' ? '平台官方连接仍未就绪，本次未提交，请稍后重试' :
      state?.protocolStatus==='module' ? '平台发送组件仍在加载，本次未提交，请稍后重试' :
      '平台输入区未就绪，本次未提交，请在搜索网页检查登录或验证';
    return {status:'not_ready',message};
  }
  await new Promise(resolve=>setTimeout(resolve,100));
}
const input = editor.composerInput();
if (!input?.isConnected || input.disabled || input.readOnly) return {status:'login',message:'请在搜索网页中登录当前平台'};
input.focus({preventScroll:true});
if (input instanceof HTMLInputElement || input instanceof HTMLTextAreaElement) input.select();
else {
  const range=document.createRange();range.selectNodeContents(input);
  const selection=window.getSelection();selection.removeAllRanges();selection.addRange(range);
}
const bridge=window.flutter_inappwebview;
if (!bridge?.callHandler || await bridge.callHandler(handler,{action:'edit'}) !== true) return {status:'rejected',message:'平台输入失败，本次未发送'};
await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
if (!input.isConnected || (editor.composerDraft ? editor.composerDraft() : (input.value ?? input.textContent)) !== text) return {status:'rejected',message:'平台未接收完整草稿，本次未发送'};
const button=editor.composerButton();
if (button?.disabled || button?.getAttribute('aria-disabled')==='true') return {status:'rejected',message:'平台暂不允许发言，请在搜索网页检查限制'};
let submitted;
if (button) {
  const r=button.getBoundingClientRect();
  const x=r.x+r.width/2,y=r.y+r.height/2;
  if (!r.width || !r.height || x<0 || y<0 || x>=innerWidth || y>=innerHeight) return {status:'not_ready',message:'平台发送控件尚未就绪'};
  submitted=await bridge.callHandler(handler,{action:'submit',x,y});
} else submitted=await bridge.callHandler(handler,{action:'submit',enter:true});
return submitted===true ? {status:'submitted'} : {status:'unknown',message:'平台提交结果未确认，请先查看聊天'};
''';
}
