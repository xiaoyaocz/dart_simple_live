import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/services/search_web_session.dart';

// Reads official editor state. Replaces the official submission methods with
// no-op counters BEFORE testing input/clicks. Never submits public chat.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();runApp(const SizedBox());
  final log=File(args.single);
  void record(Object? x)=>log.writeAsStringSync('$x\n',mode:FileMode.append);
  Timer(const Duration(seconds:100),(){record('FAIL timeout');exit(1);});
  final support=await getApplicationSupportDirectory();
  final temp=await Directory.systemTemp.createTemp('simple-live-editor-settings-');
  await File('${support.path}/localstorage.hive').copy('${temp.path}/localstorage.hive');
  final settings=await Hive.openBox<dynamic>('localstorage',path:temp.path);
  for(final pair in {'douyu':'https://www.douyu.com/475252','bilibili':'https://live.bilibili.com/13914640'}.entries) {
    record('SITE ${pair.key}');
    WebViewEnvironment? env;HeadlessInAppWebView? browser;InAppWebViewController? view;
    try {
      env=await SearchWebSession.create(siteId:pair.key,direct:settings.get('SearchWebProfile_${pair.key}',defaultValue:false)==true);
      browser=HeadlessInAppWebView(webViewEnvironment:env,initialSize:const Size(1280,800),
        initialUrlRequest:URLRequest(url:WebUri(pair.value)),onWebViewCreated:(v)=>view=v);
      await browser.run();await Future<void>.delayed(const Duration(seconds:15));
      await view!.resume();record('resume OK');
      final setup=await view!.callAsyncJavaScript(functionBody:r'''
        const input=document.querySelector(site==='douyu'?'.ChatSend-txt':'textarea.chat-input,textarea.chat-input-new');
        const button=document.querySelector(site==='douyu'?'.ChatSend-button':'#chat-control-panel-vm .send-btn');
        if(!input||!button)return {guard:false,reason:'no_editor'};
        const state=window.__editorProbe={calls:0,service:null};
        if(site==='douyu') {
          const key=Object.keys(button).find(k=>/^__react(?:Fiber|InternalInstance)\$/.test(k));
          let fiber=button[key];
          for(let n=0;fiber&&n<60;n++,fiber=fiber.return) {
            const service=fiber.stateNode?.chatSendServices;
            if(service?.sendMsg) {
              state.service=service;
              service.sendMsg=()=>{state.calls++;};
              if(service.sendRoleMsg)service.sendRoleMsg=()=>{state.calls++;};
              break;
            }
          }
          if(!state.service)return {guard:false,reason:'no_service'};
        } else {
          const player=window.livePlayer||window.EmbedPlayer?.instance;
          if(!player?.sendDanmaku)return {guard:false,reason:'no_player'};
          player.sendDanmaku=data=>{state.calls++;state.msgMatches=data?.msg==='draft-only-check';return Promise.resolve({response:{code:-1,message:'probe blocked'}});};
        }
        state.input=input;state.button=button;
        input.scrollIntoView({block:'center'});input.focus();
        if(input.select)input.select();else{const range=document.createRange();range.selectNodeContents(input);getSelection().removeAllRanges();getSelection().addRange(range);}
        return {guard:true,disabled:button.disabled,cls:button.className,viewport:[innerWidth,innerHeight]};
      ''',arguments:{'site':pair.key});
      record('SETUP ${setup?.value}');
      if(setup?.value is! Map||setup!.value['guard']!=true)continue;
      await view!.callDevToolsProtocolMethod(methodName:'Input.insertText',parameters:{'text':'draft-only-check'});
      await Future<void>.delayed(const Duration(milliseconds:300));
      final target=await view!.evaluateJavascript(source:r'''(()=>{const s=window.__editorProbe,r=s.button.getBoundingClientRect(),hit=document.elementFromPoint(r.left+r.width/2,r.top+r.height/2);return {x:r.left+r.width/2,y:r.top+r.height/2,hit:s.button===hit||s.button.contains(hit),draftMatches:(s.input.value||s.input.innerText)==='draft-only-check',focus:document.activeElement===s.input,serviceDraftMatches:s.service? s.service.sendInput?.innerText==='draft-only-check':null};})()''');
      record('TARGET $target');
      if(target is Map&&target['hit']==true) {
        for(final t in ['mousePressed','mouseReleased']) {
          await view!.callDevToolsProtocolMethod(methodName:'Input.dispatchMouseEvent',parameters:{'type':t,'x':target['x'],'y':target['y'],'button':'left','clickCount':1});
        }
        await Future<void>.delayed(const Duration(milliseconds:300));
        record('NATIVE ${await view!.evaluateJavascript(source:'window.__editorProbe.calls')}');
      }
      await view!.evaluateJavascript(source:'window.__editorProbe.button.click()');
      await Future<void>.delayed(const Duration(milliseconds:300));
      record('DOM ${await view!.evaluateJavascript(source:'window.__editorProbe.calls')}');
    } catch(e) {record('ERROR ${e.runtimeType} code=${e is PlatformException?e.code:"none"}');}
    finally {await browser?.dispose();await env?.dispose();}
  }
  await settings.close();record('DONE 0 public chat submissions');exit(0);
}
