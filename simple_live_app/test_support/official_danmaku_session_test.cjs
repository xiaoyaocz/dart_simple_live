// Real Chromium, deterministic local protocol fixtures; not live-send evidence.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || 'playwright-core');
const source = fs.readFileSync(path.join(__dirname, '../lib/services/official_danmaku_session.dart'), 'utf8').match(/static const install = r'''([\s\S]*?)''';/)[1];
(async () => {
  const browser = await chromium.launch({headless:true, executablePath:process.env.CHROME_EXE || 'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  try {
    async function pageFor(site) {
      const page = await browser.newPage();
      await page.route('https://www.huya.com/691406', r=>r.fulfill({body:'<textarea></textarea>'}));
      await page.goto('https://www.huya.com/691406');
      await page.evaluate(() => {
        window.reports=[];
        window.flutter_inappwebview={callHandler:(name,data)=>{window.reports.push(data);return Promise.resolve();}};
        window.sdk={sendWup2:function(service,method,req,callback){window.pending={req,callback};}};
        window.TTP={ready:callback=>callback(window.sdk)};
      });
      await page.evaluate(({source,site}) => new Function('site','expectedRoomIds',source)(site,['691406','123']), {source,site});
      return page;
    }
    const p=await pageFor('huya');
    assert.equal(await p.evaluate(()=>window.__simpleLiveSendSession.begin('hello')),true);
    assert.equal(await p.evaluate(()=>window.reports.some(r=>r.status==='sent')),false,'intent is not delivery');
    assert.equal(await p.evaluate(()=>window.__simpleLiveSendSession.begin('second')),false,'single flight');
    await p.evaluate(()=>sdk.sendWup2('liveui','sendMessage',{sContent:'hello',lTid:1,lSid:2},()=>window.forwarded=true));
    await p.evaluate(()=>pending.callback({iStatus:0,tNotice:{sContent:'hello',lTid:1,lSid:2}}));
    assert.equal(await p.evaluate(()=>window.reports.at(-1).status),'sent');
    assert.equal(await p.evaluate(()=>window.forwarded),true,'original callback preserved');
    await p.evaluate(()=>window.__simpleLiveSendSession.begin('filtered'));
    await p.evaluate(()=>sdk.sendWup2('liveui','sendMessage',{sContent:'filtered',lTid:1,lSid:2},()=>{}));
    await p.evaluate(()=>pending.callback({iStatus:100,tNotice:{sContent:'filtered'},sToast:''}));
    assert.equal(await p.evaluate(()=>window.reports.at(-1).status),'rejected','empty toast must not make nonzero status succeed');
    await p.evaluate(()=>window.__simpleLiveSendSession.begin('wrong'));
    await p.evaluate(()=>sdk.sendWup2('liveui','sendMessage',{sContent:'wrong',lTid:1,lSid:2},()=>{}));
    await p.evaluate(()=>pending.callback({iStatus:0,tNotice:{sContent:'other',lTid:1,lSid:2}}));
    assert.notEqual(await p.evaluate(()=>window.reports.at(-1).status),'sent','wrong text ignored');
    await p.evaluate(()=>window.__simpleLiveSendSession.close());
    await p.evaluate(()=>pending.callback({iStatus:0,tNotice:{sContent:'wrong',lTid:1,lSid:2}}));
    assert.notEqual(await p.evaluate(()=>window.reports.at(-1).status),'sent','late callback after navigation ignored');
    await p.close();
    console.log('PASS Huya exact SDK callback, strict status, single flight, late completion');
    const delayed=await pageFor('douyin');
    await delayed.clock.install();
    await delayed.evaluate(({source})=>{
      delete window.__simpleLiveSendSession;
      delete window.TTP;
      window.HUYA_MAIN_APP_WEBPACK_JSONP=[];
      HUYA_MAIN_APP_WEBPACK_JSONP.push=()=>{throw new Error('must not initialize platform modules');};
      new Function('site','expectedRoomIds',source)('huya',['691406']);
    },{source});
    assert.equal(await delayed.evaluate(()=>window.__simpleLiveSendSession.isReady()),false);
    await delayed.evaluate(()=>{window.TTP={ready:callback=>{window.sdkReady=callback;}};});
    await delayed.clock.fastForward(501);
    assert.equal(await delayed.evaluate(()=>window.__simpleLiveSendSession.isReady()),false,'published module is not yet a connected SDK');
    await delayed.evaluate(()=>window.sdkReady(window.sdk));
    assert.equal(await delayed.evaluate(()=>window.__simpleLiveSendSession.begin('after delayed startup')),true,'observe public TTP after platform startup without requiring modules');
    await delayed.close();
    console.log('PASS Huya delayed public TTP and SDK readiness without eager module initialization');

    for (const site of ['douyin']) {
      const p=await pageFor(site);
      const endpoint=site==='bilibili'?'https://api.live.bilibili.com/msg/send':'https://live.douyin.com/webcast/room/chat/';
      let response={}; let status=200; let fail=false;
      await p.route(endpoint, r=>fail?r.abort():r.fulfill({status,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:JSON.stringify(response)}));
      const post=()=>p.evaluate(async({endpoint,site})=>{
        const data=site==='bilibili'?{msg:'hello',roomid:'123'}:{content:'hello',room_id:'123'};
        try{await fetch(endpoint,{method:'POST',body:new URLSearchParams(data)});}catch(_){}
      },{endpoint,site});
      response=site==='bilibili'?{code:0,msg:'被屏蔽'}:{status_code:2,status_msg:'频率限制'};
      await p.evaluate(()=>window.__simpleLiveSendSession.begin('hello')); await post();
      await p.waitForFunction(()=>window.reports.at(-1).status==='rejected');
      response=site==='bilibili'?{code:0,msg:''}:{status_code:0};
      await p.evaluate(()=>window.__simpleLiveSendSession.begin('hello')); await post();
      await p.waitForFunction(()=>window.reports.at(-1).status==='sent');
      fail=true;
      await p.evaluate(()=>window.__simpleLiveSendSession.begin('hello')); await post();
      await p.waitForFunction(()=>window.reports.at(-1).status==='unknown');
      assert.equal(await p.evaluate(()=>window.__simpleLiveSendSession.begin('hello')),false,'uncertain send must not be resubmitted');
      await p.close();
    }
    console.log('PASS platform-isolated HTTP acknowledgement, filtering, network failure, uncertain duplicate guard');
    const timed=await pageFor('huya');
    await timed.clock.install();
    await timed.evaluate(()=>window.__simpleLiveSendSession.begin('uncertain'));
    await timed.clock.fastForward(10001);
    assert.equal(await timed.evaluate(()=>window.reports.at(-1).status),'unknown');
    assert.equal(await timed.evaluate(()=>window.__simpleLiveSendSession.begin('uncertain')),false);
    await timed.close();
    const unsupported=await pageFor('unverified');
    assert.equal(await unsupported.evaluate(()=>window.__simpleLiveSendSession.begin('hello')),false);
    assert.equal(await unsupported.evaluate(()=>window.reports.at(-1).status),'unsupported');
    await unsupported.close();
    const query=await pageFor('douyin');
    await query.route('https://live.douyin.com/webcast/room/chat/**',r=>r.fulfill({contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:'{"status_code":0}'}));
    await query.evaluate(async()=>{
      window.__simpleLiveSendSession.begin('query');
      await fetch('https://live.douyin.com/webcast/room/chat/?room_id=123&content=query',{method:'POST',body:''});
    });
    await query.waitForFunction(()=>window.reports.at(-1).status==='sent');
    await query.close();
    console.log('PASS timeout, unsupported protocol, Douyin query parameters with empty POST body');
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exitCode=1;});
