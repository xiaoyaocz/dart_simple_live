import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/search/search_web_navigation.dart';

void main() {
  test('执行网页脚本捕获四平台链接、新窗口与 SPA 导航，不改变网页行为', () async {
    final directory = await Directory.systemTemp.createTemp('search-bridge-');
    final source = File('${directory.path}/bridge.js');
    addTearDown(() async {
      if (await source.exists()) await source.delete();
      await directory.delete();
    });
    await source.writeAsString(SearchWebNavigation.script);
    final result = await Process.run('node', [
      '-e',
      r'''
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const reports = [], clicks = [], events = {};
let originalOpenCalls = 0;
const window = {
  location: {href:'https://live.douyin.com/'},
  addEventListener(name, callback) { events[name] = callback; },
  open() { originalOpenCalls++; return 'original-window'; },
  history: {}
};
for (const name of ['pushState','replaceState']) window.history[name] = function (_,__,url) {
  window.location.href = new URL(url,window.location.href).href;
  return 'original-history';
};
const context = {window, URL, document:{addEventListener(name, callback) { if(name==='click') clicks.push(callback); }}};
const script = fs.readFileSync(process.argv[1],'utf8');
vm.runInNewContext(script,context);
vm.runInNewContext(script,context);
assert.equal(clicks.length,1);
window.flutter_inappwebview = {callHandler(name,url) { reports.push([name,url]); return Promise.resolve(); }};
events.flutterInAppWebViewPlatformReady();
const urls = ['https://live.bilibili.com/h5/12345','https://m.huya.com/abc123',
  'https://m.douyu.com/67890','https://www.douyin.com/root/live/921169302662'];
for (const href of urls) clicks[0]({target:{nodeType:1,closest:()=>({href})}});
// 点击文字节点也应找到父链接。
clicks[0]({target:{nodeType:3,parentElement:{closest:()=>({href:urls[1]})}}});
assert.equal(window.open(urls[2],'_blank'),'original-window');
assert.equal(originalOpenCalls,1);
assert.equal(window.history.pushState(null,'','/123'),'original-history');
assert.equal(window.history.replaceState(null,'','/456'),'original-history');
events.popstate();
events.hashchange();
const count = reports.length;
window.open('javascript:alert(1)');
clicks[0]({target:{nodeType:1,closest:()=>null}});
assert.equal(reports.length,count);
console.log(JSON.stringify(reports));
''',
      source.path
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    final reports = jsonDecode(result.stdout as String) as List;
    expect(
        reports.every((entry) => entry[0] == SearchWebNavigation.handlerName),
        isTrue);
    expect(reports.map((entry) => entry[1]).toList(), [
      'https://live.douyin.com/',
      'https://live.bilibili.com/h5/12345',
      'https://m.huya.com/abc123',
      'https://m.douyu.com/67890',
      'https://www.douyin.com/root/live/921169302662',
      'https://m.huya.com/abc123',
      'https://m.douyu.com/67890',
      'https://live.douyin.com/123',
      'https://live.douyin.com/456',
      'https://live.douyin.com/456',
      'https://live.douyin.com/456',
    ]);
  });
}
