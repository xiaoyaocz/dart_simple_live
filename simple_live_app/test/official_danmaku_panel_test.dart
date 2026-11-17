import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:simple_live_app/modules/live_room/official_danmaku_panel.dart';
import 'package:simple_live_app/modules/live_room/api_danmaku_panel.dart';
import 'package:simple_live_app/modules/live_room/danmaku_composer.dart';
import 'package:simple_live_app/services/official_composer_transport.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_app/modules/live_room/live_room_page.dart';
import 'package:simple_live_app/modules/live_room/player/player_controls.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_app/widgets/danmaku/canvas_danmaku.dart';

class _Room extends LiveRoomController {
  _Room({String site = 'huya'}) : super(pSite: Sites.allSites[site]!, pRoomId: '1');
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  // ignore: must_call_super
  void onClose() {}
}

class _StoppingPlayer implements Player {
  final stopped=Completer<void>();
  @override
  Future<void> stop()=>stopped.future;
  @override
  dynamic noSuchMethod(Invocation invocation)=>super.noSuchMethod(invocation);
}
class _SwitchingRoom extends _Room {
  _SwitchingRoom():super(site:'bilibili');
  final fake=_StoppingPlayer();
  @override
  Player get player=>fake;
  @override
  void loadData({bool reusePrefetch=false}) {}
}

class _Paths extends PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async =>
      '${Directory.current.path}/build/official_window_test';
}

class _Environment extends PlatformWebViewEnvironment {
  _Environment(this.owner)
      : super.implementation(const PlatformWebViewEnvironmentCreationParams());
  final _Platform owner;
  int disposals = 0;
  @override
  String get id => 'fixture';
  @override
  Future<PlatformWebViewEnvironment> create(
      {WebViewEnvironmentSettings? settings}) async {
    if (owner.creationError != null) throw owner.creationError!;
    if (owner.fail) throw StateError('Environment creation failed');
    final result = _Environment(owner);
    owner.created.add(result);
    await owner.gate?.future;
    return result;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class _Controller extends PlatformInAppWebViewController {
  _Controller()
      : super.implementation(
            const PlatformInAppWebViewControllerCreationParams(id: 'fixture'));
  int reloads = 0;
  final navigations = <String>[];
  bool simulateComposer=false;
  final nativeCalls=<String>[];
  @override
  Future<Map<String,dynamic>?> callDevToolsProtocolMethod({required String methodName,Map<String,dynamic>? parameters}) async {
    nativeCalls.add(methodName);return null;
  }
  @override
  Future<void> loadUrl(
      {required URLRequest urlRequest,
      Uri? iosAllowingReadAccessTo,
      WebUri? allowingReadAccessTo}) async {
    navigations.add(urlRequest.url.toString());
  }

  final handlers = <String, JavaScriptHandlerCallback>{};
  @override
  JavaScriptHandlerCallback? removeJavaScriptHandler({required String handlerName}) =>
      handlers.remove(handlerName);
  @override
  void addJavaScriptHandler(
      {required String handlerName,
      required JavaScriptHandlerCallback callback}) {
    handlers[handlerName] = callback;
  }

  @override
  Future<CallAsyncJavaScriptResult?> callAsyncJavaScript(
          {required String functionBody,
          Map<String, dynamic> arguments = const {},
          ContentWorld? contentWorld}) async {
    if(simulateComposer && functionBody==OfficialComposerTransport.submit) {
      final bridge=handlers[arguments['handler']]!;
      expect(await bridge([{'action':'edit'}]),isTrue);
      expect(await bridge([{'action':'submit','x':10,'y':10}]),isTrue);
      final state=handlers['simpleLiveDanmakuState']!;
      state([{'status':'sending','message':'发送中','documentId':'fixture','id':1}]);
      state([{'status':'sent','message':'平台已确认发送','documentId':'fixture','id':1,'text':arguments['text'],'userId':'123'}]);
      return CallAsyncJavaScriptResult(value:{'status':'submitted'});
    }
    return CallAsyncJavaScriptResult(value: {'status': 'ready'});
  }
  @override
  Future<dynamic> evaluateJavascript(
          {required String source, ContentWorld? contentWorld}) async =>
      true;
  @override
  Future<void> reload() async {
    reloads++;
  }
}

class _View extends PlatformInAppWebViewWidget {
  _View(super.params) : super.implementation();
  final controller = _Controller();
  bool initialized = false;
  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;
  @override
  Widget build(BuildContext context) {
    if (!initialized) {
      initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        params.onWebViewCreated?.call(controllerFromPlatform(controller));
      });
    }
    return const ColoredBox(
        color: Colors.white,
        child: TextField(key: ValueKey('official-page-input')));
  }

  @override
  void dispose() {}
}

class _Platform extends InAppWebViewPlatform {
  final views = <_View>[];
  final created = <_Environment>[];
  Completer<void>? gate;
  bool fail = false;
  Object? creationError;
  @override
  PlatformWebViewEnvironment createPlatformWebViewEnvironmentStatic() =>
      _Environment(this);
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
      PlatformInAppWebViewWidgetCreationParams params) {
    final view = _View(params);
    views.add(view);
    return view;
  }
}

Future<void> _settleIO(WidgetTester tester) async {
  // Directory creation uses real I/O, outside Flutter's fake clock.
  for (var i = 0; i < 5; i++) {
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  }
  await tester.pumpAndSettle();
}

void main() {
  late _Platform platform;
  setUp(() {
    platform = _Platform();
    InAppWebViewPlatform.instance = platform;
    PathProviderPlatform.instance = _Paths();
  });

  testWidgets('common composer transport waits for SDK confirmation and carries identity', (tester) async {
    final transport=OfficialComposerTransport();
    await tester.pumpWidget(MaterialApp(home:OfficialDanmakuPanel(siteId:'huya',siteName:'虎牙',
      roomUri:Uri.https('www.huya.com','/1'),composerTransport:transport,
      searchEnvironment:Future.value(WebViewEnvironment.fromPlatform(platform:_Environment(platform))),
      expanded:false,focusRequest:0,onExpandedChanged:(_){},onFocusedChanged:(_){})));
    await tester.pumpAndSettle();
    final native=platform.views.single;
    native.controller.simulateComposer=true;
    final view=native.controllerFromPlatform<InAppWebViewController>(native.controller);
    native.params.onProgressChanged!(view,66);
    await tester.pumpAndSettle();
    final result=await transport.send('fixture text');
    expect(result.sent,isTrue);expect(result.userId,'123');
    expect(native.controller.nativeCalls,['Input.insertText','Input.dispatchMouseEvent','Input.dispatchMouseEvent']);
    await tester.pumpWidget(const SizedBox());
    expect((await transport.send('old room')).status,'not_ready');
    await transport.dispose();
    expect((await transport.send('old room')).status,'closed');
  });

  testWidgets('send can recover failed environment creation without a native page', (tester) async {
    platform.fail=true;
    final transport=OfficialComposerTransport();
    await tester.pumpWidget(MaterialApp(home:OfficialDanmakuPanel(siteId:'huya',siteName:'虎牙',
      roomUri:Uri.https('www.huya.com','/546540'),composerTransport:transport,
      expanded:false,focusRequest:0,onExpandedChanged:(_){},onFocusedChanged:(_){})));
    await _settleIO(tester);
    expect(platform.views,isEmpty);
    platform.fail=false;
    expect((await transport.send('not submitted while reconnecting')).sent,isFalse);
    await _settleIO(tester);
    expect(platform.views,hasLength(1));
    expect(platform.views.single.controller.nativeCalls,isEmpty);
    await tester.pumpWidget(const SizedBox());
    await transport.dispose();
  });

  testWidgets('late ready after startup deadline is verified in the page without reloading', (tester) async {
    final transport=OfficialComposerTransport();
    await tester.pumpWidget(MaterialApp(home:OfficialDanmakuPanel(siteId:'huya',siteName:'虎牙',
      roomUri:Uri.https('www.huya.com','/546540'),composerTransport:transport,
      searchEnvironment:Future.value(WebViewEnvironment.fromPlatform(platform:_Environment(platform))),
      expanded:false,focusRequest:0,onExpandedChanged:(_){},onFocusedChanged:(_){})));
    await tester.pumpAndSettle();
    final native=platform.views.single;
    native.controller.simulateComposer=true;
    // Platform readiness changes without a usable Flutter event. A loading
    // cache or an expired UI deadline must not reload a now-connected page.
    await tester.pump(const Duration(seconds:21));
    final result=await transport.send('late connected draft');
    expect(result.sent,isTrue);
    expect(native.controller.reloads,0);
    expect(native.controller.nativeCalls,hasLength(3));
    await tester.pumpWidget(const SizedBox());
    await transport.dispose();
  });

  testWidgets('late identity rebuilds existing floating bullets without replay, including paused bullets', (tester) async {
    final room = _Room(site:'douyin');
    await tester.pumpWidget(MaterialApp(home:DanmakuScreen(
      createdController:(c)=>room.danmakuController=c,
      option:const DanmakuOption(safeArea:false))));
    final canvas = room.danmakuController!;
    final own = LiveMessage(type:LiveMessageType.chat,userId:'123',userName:'本人',message:'相同正文',color:LiveMessageColor.white);
    final other = LiveMessage(type:LiveMessageType.chat,userId:'456',userName:'本人',message:'相同正文',color:LiveMessageColor.white);
    canvas.addDanmaku(DanmakuContentItem(own.message,extra:own));
    canvas.addDanmaku(DanmakuContentItem(other.message,extra:other,type:DanmakuItemType.top));
    await tester.pump();
    canvas.pause();
    final bullet = canvas.scrollDanmaku.single;
    final image = bullet.image;
    final x = bullet.xPosition;
    room.updateSelfIdentity('123','本人');
    await tester.pump();await tester.pump();
    expect(bullet.content.selfSend,isTrue);
    expect(bullet.image,isNot(same(image)));
    expect(bullet.xPosition,x);
    expect(canvas.staticDanmaku.single.content.selfSend,isFalse);
    expect(canvas.scrollDanmaku.length,1);
    room.updateOfficialSelfName('新昵称');
    expect(room.isSelfMessage(other),isFalse);
    expect(room.isSelfMessage(own),isTrue);
    room.updateSelfIdentity(null,null);
    await tester.pump();await tester.pump();
    expect(bullet.content.selfSend,isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  for(final site in ['bilibili','douyu','huya','douyin']) {
    testWidgets('$site identity confirmation refreshes already received messages without text guessing', (tester) async {
      final room = _Room(site:site);
      final own = LiveMessage(type:LiveMessageType.chat,userId:'123',userName:'本人',message:'相同正文',color:LiveMessageColor.white);
      final other = LiveMessage(type:LiveMessageType.chat,userId:'456',userName:'本人',message:'相同正文',color:LiveMessageColor.white);
      room.messages.addAll([own,other]);
      await tester.pumpWidget(MaterialApp(home:Obx(()=>Text(
        room.messages.map((m)=>room.isSelfMessage(m) ? '我' : '普通').join(',')))));
      expect(find.text('普通,普通'),findsOneWidget);
      room.updateSelfIdentity('123','本人');
      await tester.pump();
      expect(find.text('我,普通'),findsOneWidget);
      room.updateSelfIdentity(null,null);
      await tester.pump();
      expect(find.text('普通,普通'),findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for(final site in ['huya','douyin']) {
    testWidgets('$site uses the same Flutter input as Bilibili and Douyu', (tester) async {
      final room=Get.put<LiveRoomController>(_Room(site:site));
      addTearDown(Get.reset);
      room.detail.value=LiveRoomDetail(roomId:'1',title:'',cover:'',userName:'',userAvatar:'',online:0,status:true,url:'https://example.invalid/1');
      await tester.pumpWidget(GetMaterialApp(home:Scaffold(body:SizedBox(height:600,
        child:const LiveRoomPage().buildOfficialChatArea(const Text('聊天记录'))))));
      await _settleIO(tester);
      expect(find.byType(ApiDanmakuPanel),findsOneWidget);
      expect(find.descendant(of:find.byType(DanmakuComposer),matching:find.byType(TextField)),findsOneWidget);
      expect(find.byTooltip('发送弹幕（Enter）'),findsOneWidget);
      expect(find.byTooltip('表情'),findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('switching room hides stale canonical target before the player stops', (tester) async {
    final room=Get.put<LiveRoomController>(_SwitchingRoom());
    addTearDown(Get.reset);
    room.liveDanmaku=LiveDanmaku();
    room.updateSelfIdentity('123', '本人');
    room.detail.value=LiveRoomDetail(roomId:'7734200',title:'',cover:'',userName:'',userAvatar:'',online:0,status:true,url:'https://example.invalid/1');
    await tester.pumpWidget(GetMaterialApp(home:Scaffold(body:SizedBox(height:600,
      child:const LiveRoomPage().buildOfficialChatArea(const Text('聊天记录'))))));
    expect(find.byType(ApiDanmakuPanel),findsOneWidget);
    room.resetRoom(Sites.allSites['douyu']!,'24422');
    expect(room.isSelfMessage(LiveMessage(type:LiveMessageType.chat,userId:'123',userName:'本人',message:'旧房间',color:LiveMessageColor.white)),isFalse);
    expect(room.detail.value,isNull,reason:'Old canonical room must be invalidated synchronously');
    await tester.pump();
    expect(find.byType(ApiDanmakuPanel),findsNothing);
    (room as _SwitchingRoom).fake.stopped.complete();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('only a matching platform acknowledgement completes the pending send', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(MaterialApp(home: OfficialDanmakuPanel(
      siteId: 'huya', siteName: '虎牙', roomUri: Uri.https('www.huya.com','/691406'),
      searchEnvironment: Future.value(WebViewEnvironment.fromPlatform(platform: _Environment(platform))),
      expanded: false, focusRequest: 0, onExpandedChanged: (_) {},
      onFocusedChanged: (_) {}, onMessageSent: sent.add,
    )));
    await tester.pumpAndSettle();
    final native = platform.views.single;
    native.controller.handlers['simpleLiveOfficialEditor']!([{'status':'sent','text':'fake click'}]);
    expect(sent,isEmpty);
    final report = native.controller.handlers['simpleLiveDanmakuState']!;
    report([{'documentId':'test-doc','status':'sending','message':'正在等待平台确认…','id':1}]);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator),findsOneWidget);
    report([{'documentId':'test-doc','status':'sent','message':'平台已确认发送','text':'wrong','id':2}]);
    expect(sent,isEmpty);
    report([{'documentId':'old-doc','status':'sent','message':'平台已确认发送','text':'wrong','id':1}]);
    expect(sent,isEmpty);
    report([{'documentId':'test-doc','status':'sent','message':'平台已确认发送','text':'hello','id':1}]);
    report([{'documentId':'test-doc','status':'sent','message':'平台已确认发送','text':'hello','id':1}]);
    await tester.pump();
    expect(sent,['hello']);
    expect(find.text('平台已确认发送'),findsOneWidget);
    report([{'documentId':'test-doc','status':'sending','message':'正在等待平台确认…','id':2}]);
    final view=native.controllerFromPlatform<InAppWebViewController>(native.controller);
    native.params.onLoadStart!(view,WebUri('https://www.huya.com/691406'));
    report([{'documentId':'test-doc','status':'sent','message':'平台已确认发送','text':'stale','id':2}]);
    expect(sent,['hello']);
    await tester.pumpWidget(const SizedBox());
  });

  for (final site in ['bilibili','douyu']) {
    testWidgets('$site composer loads without creating an official room browser', (tester) async {
      final room = Get.put<LiveRoomController>(_Room(site:site));
      addTearDown(Get.reset);
      room.detail.value=LiveRoomDetail(roomId:'475252',title:'',cover:'',userName:'',userAvatar:'',online:0,status:true,url:'https://example.invalid/1');
      await tester.pumpWidget(GetMaterialApp(home:Scaffold(body:SizedBox(height:600,
        child:const LiveRoomPage().buildOfficialChatArea(const Text('聊天记录'))))));
      await tester.pumpAndSettle();
      expect(find.byType(ApiDanmakuPanel),findsOneWidget);
      expect(find.byType(TextField),findsOneWidget);
      expect(find.byType(OfficialDanmakuPanel),findsNothing);
      expect(platform.views,isEmpty);
      await room.openDanmakuComposer();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,isTrue);
      await tester.pumpWidget(const SizedBox());
      // Keyboard focus now starts read-only sender warmup. This fixture has no
      // native CookieManager reply; drain its bounded credential-read timeout.
      await tester.pump(const Duration(seconds: 5));
    });
  }

  test('Bilibili editor opens its desktop room directly instead of an iframe activity shell', () {
    final room = _Room(site: 'bilibili');
    room.detail.value = LiveRoomDetail(roomId: '7734200', title: '', cover: '',
        userName: '', userAvatar: '', online: 0, status: true,
        url: 'https://live.bilibili.com/6');
    expect(room.officialEditorRoomUri.toString(),
        'https://live.bilibili.com/blanc/7734200');
  });

  testWidgets(
      'other rooms are blocked while canonical aliases and login redirects remain valid',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: OfficialDanmakuPanel(
      siteId: 'douyu',
      siteName: '斗鱼',
      roomUri: Uri.https('www.douyu.com', '/85200'),
      allowedRoomIds: const ['475252'],
      expanded: false,
      focusRequest: 0,
      onExpandedChanged: (_) {},
      onFocusedChanged: (_) {},
      searchEnvironment: Future.value(
          WebViewEnvironment.fromPlatform(platform: _Environment(platform))),
    )));
    await tester.pumpAndSettle();
    final native = platform.views.single;
    final view = native
        .controllerFromPlatform<InAppWebViewController>(native.controller);
    Future<NavigationActionPolicy?> navigate(String url) =>
        native.params.shouldOverrideUrlLoading!(
            view,
            NavigationAction(
                request: URLRequest(url: WebUri(url)), isForMainFrame: true));
    expect(await navigate('https://www.douyu.com/475252'),
        NavigationActionPolicy.ALLOW);
    expect(await navigate('https://passport.douyu.com/login'),
        NavigationActionPolicy.ALLOW);
    expect(await navigate('https://www.douyu.com/999999'),
        NavigationActionPolicy.CANCEL);
    native.params.onUpdateVisitedHistory!(
        view, WebUri('https://www.douyu.com/999999'), false);
    native.params.onUpdateVisitedHistory!(
        view, WebUri('https://www.douyu.com/999999'), false);
    expect(native.controller.navigations, ['https://www.douyu.com/85200'],
        reason: 'Restore the player room once, not an endless reload loop');
    await tester.pumpAndSettle();
    expect(platform.views, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'inline panel keeps the native draft and browser on expand, resize and Enter',
      (tester) async {
    final room = Get.put<LiveRoomController>(_Room());
    addTearDown(Get.reset);
    room.detail.value = LiveRoomDetail(
        roomId: '1',
        title: '',
        cover: '',
        userName: '',
        userAvatar: '',
        online: 0,
        status: true,
        url: 'https://www.huya.com/1');
    await tester.pumpWidget(GetMaterialApp(
        home: Scaffold(
            body: SizedBox(
                height: 450,
                child: const LiveRoomPage()
                    .buildOfficialChatArea(const Text('聊天记录'))))));
    await _settleIO(tester);
    expect(platform.views, hasLength(1));
    final original = platform.views.single;
    await tester.enterText(find.descendant(of:find.byType(DanmakuComposer),matching:find.byType(TextField)), '保留原生草稿');
    room.officialEditorExpanded.value = true;
    await tester.pumpAndSettle();
    expect(platform.views.single, same(original));
    expect(find.text('保留原生草稿'), findsOneWidget);
    room.officialEditorExpanded.value = false;
    await room.openDanmakuComposer();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(platform.views.single, same(original));
    expect(find.text('保留原生草稿'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'native browser typing owns Enter even without a Flutter EditableText',
      (tester) async {
    var opens = 0;
    var nativeFocused = true;
    await tester.pumpWidget(MaterialApp(
        home: DesktopDanmakuShortcut(
            isEditing: () => nativeFocused,
            onCompose: () => opens++,
            child: const Scaffold(body: Text('视频')))));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opens, 0);
    nativeFocused = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opens, 1);
  });

  testWidgets(
      'all platforms open visible original room UI with the exact search environment',
      (tester) async {
    for (final (site, host) in [
      ('huya', 'www.huya.com'),
      ('douyu', 'www.douyu.com'),
      ('bilibili', 'live.bilibili.com'),
      ('douyin', 'live.douyin.com')
    ]) {
      final borrowed = _Environment(platform);
      await tester.pumpWidget(MaterialApp(
          home: OfficialDanmakuPanel(
        expanded: site == 'douyin',
        focusRequest: 0,
        onExpandedChanged: (_) {},
        onFocusedChanged: (_) {},
        key: ValueKey(site),
        siteId: site,
        siteName: site,
        roomUri: Uri.https(host, '/123'),
        searchEnvironment:
            Future.value(WebViewEnvironment.fromPlatform(platform: borrowed)),
      )));
      await tester.pumpAndSettle();
      final view = platform.views.last;
      expect(view.params.webViewEnvironment, same(borrowed));
      expect(
          view.params.initialUrlRequest!.url.toString(), 'https://$host/123');
      expect(view.params.initialSettings!.javaScriptCanOpenWindowsAutomatically,
          isTrue);
      expect(view.params.initialUserScripts, hasLength(2));
      final script = view.params.initialUserScripts!.last.source;
      expect(script, contains('HTMLMediaElement'));
      for (final forbidden in [
        'fetch(',
        'XMLHttpRequest',
        'WebSocket',
        '.click(',
        'insertText',
        'cookie'
      ]) {
        expect(script, isNot(contains(forbidden)));
      }
      expect(find.byTooltip('刷新官方输入区'), findsNothing);
      expect(find.textContaining('官方弹幕 ·'), findsNothing);
      expect(platform.views.last, same(view),
          reason: 'Expanding must not recreate the login/editor');
      expect(platform.created, isEmpty);
      await tester.pumpWidget(const SizedBox());
      expect(borrowed.disposals, 0);
      expect(tester.takeException(), isNull);
    }
  });

  for(final site in ['huya','douyin']) {
    testWidgets('$site hidden protocol host cannot intercept common input or resize chat', (tester) async {
      final room=Get.put<LiveRoomController>(_Room(site:site));addTearDown(Get.reset);
      room.detail.value=LiveRoomDetail(roomId:'1',title:'',cover:'',userName:'',userAvatar:'',online:0,status:true,url:'https://example.invalid/1');
      var taps=0;
      const key=ValueKey('messages');
      await tester.pumpWidget(GetMaterialApp(home:Scaffold(body:SizedBox(height:600,
        child:const LiveRoomPage().buildOfficialChatArea(GestureDetector(key:key,
          behavior:HitTestBehavior.opaque,onTap:()=>taps++,child:const SizedBox.expand()))))));
      await _settleIO(tester);
      final host=platform.views.single;
      final before=tester.getRect(find.byKey(key));
      await tester.tapAt(before.center);
      expect(taps,1);
      await room.openDanmakuComposer();await tester.pumpAndSettle();
      expect(platform.views.single,same(host));
      expect(tester.getRect(find.byKey(key)),before);
      final field=tester.widget<TextField>(find.descendant(of:find.byType(DanmakuComposer),matching:find.byType(TextField)));
      expect(field.focusNode!.hasFocus,isTrue);
      final hidden=tester.widget<Opacity>(find.ancestor(of:find.byType(OfficialDanmakuPanel),matching:find.byType(Opacity)).first);
      expect(hidden.opacity,0);
        final nativeInput = tester.element(find.byKey(const ValueKey('official-page-input')));
        expect(Focus.of(nativeInput).canRequestFocus,isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Douyin compact panel shows editor loading until native layout is ready',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: OfficialDanmakuPanel(
      expanded: false,
      focusRequest: 0,
      onExpandedChanged: (_) {},
      onFocusedChanged: (_) {},
      siteId: 'douyin',
      siteName: '抖音',
      roomUri: Uri.https('live.douyin.com', '/1'),
    )));
    await _settleIO(tester);
    expect(find.text('正在加载发言栏…'), findsOneWidget);
    final native = platform.views.single;
    expect(native.params.initialUserScripts!.last.injectionTime,
        UserScriptInjectionTime.AT_DOCUMENT_START);
    final cover = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('official-editor-loading-cover')));
    expect(cover.color.a, 1.0);
    final view = native.controllerFromPlatform<InAppWebViewController>(native.controller);
    // DOMContentLoaded must unlock the editor even if window.load never fires.
    native.params.onProgressChanged!(view, 66);
    await tester.pumpAndSettle();
    expect(find.text('正在加载发言栏…'), findsNothing);
    expect(platform.views, hasLength(1));
  });

  testWidgets('missing navigation-start events cannot leave the Bilibili bar loading forever', (tester) async {
    await tester.pumpWidget(MaterialApp(home: OfficialDanmakuPanel(
      siteId: 'bilibili', siteName: 'B站',
      roomUri: Uri.https('live.bilibili.com', '/blanc/7734200'),
      searchEnvironment: Future.value(WebViewEnvironment.fromPlatform(platform: _Environment(platform))),
      expanded: false, focusRequest: 0,
      onExpandedChanged: (_) {}, onFocusedChanged: (_) {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('正在加载发言栏…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 21));
    expect(find.text('发言栏未就绪，点击重试'), findsOneWidget);
    await tester.tap(find.text('发言栏未就绪，点击重试'));
    await tester.pump();
    expect(platform.views.single.controller.reloads, 1);
  });

  testWidgets('startup failure exposes native HRESULT instead of hiding it',
      (tester) async {
    platform.creationError = PlatformException(
        code: '-2147019873', message: 'Native environment initialization failed');
    await tester.pumpWidget(MaterialApp(
        home: OfficialDanmakuPanel(
      expanded: false,
      focusRequest: 0,
      onExpandedChanged: (_) {},
      onFocusedChanged: (_) {},
      siteId: 'huya',
      siteName: '虎牙',
      roomUri: Uri.https('www.huya.com', '/1'),
    )));
    await _settleIO(tester);
    expect(find.byTooltip('启动错误：0x8007139f'), findsOneWidget);
    expect(find.text('启动失败，点击重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'environment failure can retry; owned environment releases on close',
      (tester) async {
    platform.fail = true;
    await tester.pumpWidget(MaterialApp(
        home: OfficialDanmakuPanel(
      expanded: false,
      focusRequest: 0,
      onExpandedChanged: (_) {},
      onFocusedChanged: (_) {},
      siteId: 'douyu',
      siteName: '斗鱼',
      roomUri: Uri.https('www.douyu.com', '/1'),
    )));
    await _settleIO(tester);
    expect(find.text('启动失败，点击重试'), findsOneWidget);
    platform.fail = false;
    await tester.tap(find.text('启动失败，点击重试'));
    await _settleIO(tester);
    expect(platform.views, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(platform.created.single.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed borrowed environment can retry using the remembered profile',
      (tester) async {
    final search = Completer<WebViewEnvironment?>();
    await tester.pumpWidget(MaterialApp(
        home: OfficialDanmakuPanel(
      expanded: false,
      focusRequest: 0,
      onExpandedChanged: (_) {},
      onFocusedChanged: (_) {},
      siteId: 'douyu',
      siteName: '斗鱼',
      roomUri: Uri.https('www.douyu.com', '/1'),
      searchEnvironment: search.future,
    )));
    search.completeError(StateError('Search environment failed'));
    await tester.pumpAndSettle();
    expect(find.text('启动失败，点击重试'), findsOneWidget);
    await tester.tap(find.text('启动失败，点击重试'));
    await _settleIO(tester);
    expect(platform.views, hasLength(1));
    expect(platform.created, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(platform.created.single.disposals, 1);
  });

  testWidgets(
      'environment completing after close is released without creating a browser',
      (tester) async {
    platform.gate = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: OfficialDanmakuPanel(
      expanded: false,
      focusRequest: 0,
      onExpandedChanged: (_) {},
      onFocusedChanged: (_) {},
      siteId: 'douyu',
      siteName: '斗鱼',
      roomUri: Uri.https('www.douyu.com', '/1'),
    )));
    await _settleIO(tester);
    expect(platform.created, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    platform.gate!.complete();
    await tester.pumpAndSettle();
    expect(platform.created.single.disposals, 1);
    expect(platform.views, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
