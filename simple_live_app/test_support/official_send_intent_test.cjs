const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright-core');
const source=fs.readFileSync(path.join(__dirname,'../lib/services/official_danmaku_layout.dart'),'utf8').match(/static const install = r'''([\s\S]*?)''';/)[1];
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try {
  const p=await browser.newPage();
  await p.setContent('<div class="chat-room__ft"><button id="J_inputEmot" title="表情">表情</button><textarea id="pub_msg_input"></textarea><button id="msg_send_bt">发送</button></div>');
  await p.evaluate(()=>{window.reports=[];window.flutter_inappwebview={callHandler:(_,d)=>{reports.push(d);return Promise.resolve();}};});
  await p.evaluate(source=>new Function('site','expectedRoomIds',source)('huya',[]),source);
  await p.locator('textarea').fill('not delivered');
  await p.locator('#msg_send_bt').click();
  await p.locator('textarea').press('Enter');
  assert.equal(await p.evaluate(()=>reports.some(d=>d.status==='sent')),false,'click/Enter without server response must never report sent');
  console.log('PASS click and Enter are intent, not platform confirmation');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
