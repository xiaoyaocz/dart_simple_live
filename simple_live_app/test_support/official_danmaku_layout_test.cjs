// Real Chromium + local-only original-page fixtures. Never sends public chat.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright-core');
const dart = fs.readFileSync(path.join(__dirname, '../lib/services/official_danmaku_layout.dart'), 'utf8');
// Layout fixtures isolate presentation from the separately tested transport.
const source = 'window.__simpleLiveSendSession={begin:()=>true,close:()=>{}};'+dart.match(/static const install = r'''([\s\S]*?)''';/)[1];
const sites = {
  huya: '<div class="chat-room__ft"><button id="J_inputEmot" title="表情">☺</button><textarea id="pub_msg_input"></textarea><button id="msg_send_bt">发送</button></div>',
  douyin: '<div data-e2e="chat-input"><button title="表情">☺</button><div contenteditable="true"></div><button data-e2e="chat-send-btn">发送</button></div>',
};
(async () => {
  const browser = await chromium.launch({headless: true, executablePath: process.env.CHROME_EXE || 'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  try {
    const aligned=await browser.newPage({viewport:{width:375,height:376}});
    await aligned.setContent('<style>svg{width:24px;height:24px}button{padding:0;border:0}button:last-child{padding-top:14px}</style><div data-e2e="chat-input"><div contenteditable="true" data-placeholder="与大家互动一下…"></div><button aria-label="表情"><svg><circle cx="12" cy="12" r="10"/></svg></button><button aria-label="发送"><svg><circle cx="12" cy="12" r="10"/></svg></button></div>');
    await aligned.evaluate(({source})=>new Function('site',source)('douyin'),{source});
    const geometry=await aligned.evaluate(()=>{const root=document.querySelector('[data-sl-official-editor-root]').getBoundingClientRect();return {x:root.x,right:root.right,height:root.height,bottom:root.bottom,centers:[...document.querySelectorAll('svg')].map(e=>{const r=e.getBoundingClientRect();return (r.top+r.bottom)/2})}});
    assert.deepEqual([geometry.x,geometry.right,geometry.height,geometry.bottom],[8,367,44,370],'Douyin matches the inset native row, not a full-bleed oversized box');
    geometry.centers.forEach(c=>assert(Math.abs(c-348)<=1,'both original SVG icons share the input/caret center line'));
    await aligned.screenshot({path:'C:/Temp/douyin-native-inset-alignment-local.png'});await aligned.close();
    const richDraft=await browser.newPage({viewport:{width:350,height:400}});
    await richDraft.setContent('<div data-e2e="chat-input"><div contenteditable="true"><div class="ace-line" data-node="true"><span data-string="true" data-leaf="true">SimpleLive草稿[微笑]</span><span data-string="true" data-enter="true" data-leaf="true">\u200b</span></div></div><button data-e2e="chat-send-btn">发送</button></div>');
    await richDraft.evaluate(({source})=>new Function('site','expectedRoomIds',source)('douyin',[]),{source});
    assert.equal(await richDraft.evaluate(()=>window.__simpleLiveOfficialEditor.composerDraft()),'SimpleLive草稿[微笑]','native editor structural sentinel is not submitted text');
    await richDraft.evaluate(()=>{const input=document.querySelector('[contenteditable]');input.querySelector('[data-leaf]').textContent+='\u200b';window.attempts=[];window.__simpleLiveSendSession={begin:text=>{attempts.push(text);return true}};});
    await richDraft.locator('button').click();
    assert.deepEqual(await richDraft.evaluate(()=>attempts),['SimpleLive草稿[微笑]\u200b'],'preserve authored zero-width text while excluding only native data-enter markers');
    await richDraft.close();
    const dynamicSend=await browser.newPage({viewport:{width:350,height:400}});
    await dynamicSend.setContent('<div data-e2e="chat-input"><div contenteditable="true"></div><button title="表情">☺</button></div>');
    await dynamicSend.evaluate(({source})=>new Function('site','expectedRoomIds',source)('douyin',[]),{source});
    assert.equal(await dynamicSend.evaluate(()=>{const button=document.createElement('button');button.setAttribute('data-e2e','chat-send-btn');button.textContent='发送';document.querySelector('[data-e2e="chat-input"]').appendChild(button);return window.__simpleLiveOfficialEditor.composerButton()===button;}),true,'a native send button created after input must be discoverable immediately, not after the 120ms mutation debounce');
    await dynamicSend.close();
    const sweeps=await browser.newPage({viewport:{width:350,height:400}});
    await sweeps.clock.install();
    await sweeps.setContent(sites.huya);
    await sweeps.evaluate(()=>{
      const later=window.setTimeout, cancel=window.clearTimeout;
      window.layoutTimers=new Set();
      window.setTimeout=(fn,ms,...args)=>{
        let id=later(()=>{layoutTimers.delete(id);fn(...args)},ms);
        if(ms===120) layoutTimers.add(id);
        return id;
      };
      window.clearTimeout=id=>{layoutTimers.delete(id);cancel(id)};
    });
    await sweeps.evaluate(({source})=>new Function('site','expectedRoomIds',source)('huya',[]),{source});
    const pendingSweeps=await sweeps.evaluate(async()=>{
      for(let i=0;i<20;i++) {
        document.querySelector('#pub_msg_input').className='revision'+i;
        await Promise.resolve();
        window.__simpleLiveOfficialEditor.composerButton();
        await Promise.resolve();
      }
      return layoutTimers.size;
    });
    assert(pendingSweeps<=1,`synchronous send refresh must coalesce layout timers, got ${pendingSweeps}`);
    console.log(`PASS 20 synchronous send-control refreshes: ${pendingSweeps} pending layout timer(s)`);
    await sweeps.close();
    const currentDouyin=await browser.newPage({viewport:{width:350,height:400}});
    await currentDouyin.setContent('<div id="chatInput" class="webcast-chatroom___input-container"><div class="webcast-chatroom___emoji-icon"><svg width="36" height="36"></svg></div><div data-e2e="live-chatting"><div contenteditable="true"><div class="ace-line"><span data-leaf="true">测试[微笑]</span><span data-enter="true" data-leaf="true">\u200b</span></div></div></div><svg type="button" class="webcast-chatroom___send-btn btn-icon" width="36" height="36"></svg></div>');
    await currentDouyin.evaluate(({source})=>new Function('site','expectedRoomIds',source)('douyin',[]),{source});
    assert.equal(await currentDouyin.evaluate(()=>window.__simpleLiveOfficialEditor.composerButton()?.matches('.webcast-chatroom___send-btn')),true,'actual Douyin emoji is BEFORE input; the send SVG AFTER input must never become the emoji control');
    assert.equal(await currentDouyin.locator('.webcast-chatroom___emoji-icon').getAttribute('data-sl-official-control'),'emoji');
    await currentDouyin.close();
    console.log('PASS real Douyin editor-kit structure: draft validation and send correlation exclude structural markers, preserving authored text');
    const protocol=await browser.newPage({viewport:{width:350,height:400}});
    await protocol.setContent('<div class="chat-room__ft"><textarea id="pub_msg_input"></textarea><button id="msg_send_bt">发送</button></div>');
    await protocol.evaluate(({source})=>{
      window.protocolReady=false;
      const guarded=source.replace('window.__simpleLiveSendSession={begin:()=>true,close:()=>{}};', 'window.__simpleLiveSendSession={begin:()=>true,isReady:()=>window.protocolReady,close:()=>{}};');
      new Function('site','expectedRoomIds',guarded)('huya',[]);
    },{source});
    assert.equal(await protocol.evaluate(()=>window.__simpleLiveOfficialEditor.inspect().status),'loading','DOM controls alone do not make a platform send-ready');
    await protocol.evaluate(()=>{window.protocolReady=true;window.dispatchEvent(new Event('simplelive-protocol-ready'));});
    await protocol.waitForFunction(()=>window.__simpleLiveOfficialEditor.inspect().status==='ready');
    await protocol.close();
    console.log('PASS composer readiness waits for SDK attachment, including delayed readiness without DOM mutations');
    for (const [site, html] of Object.entries(sites)) {
      const page = await browser.newPage({viewport: {width: 320, height: 180}});
      await page.setContent(`<html><head><style>body{min-width:1200px;margin:0}.offscreen{position:absolute;left:900px;top:600px;width:300px;transform:translate(10px)}textarea,[contenteditable]{height:36px;width:180px}button{height:30px}</style></head><body><header>Full room header</header><div role="dialog" style="visibility:hidden">旧登录弹层</div><div class="offscreen">${html}</div></body></html>`);
      await page.evaluate(() => {
        window.reports = []; window.sends = []; window.trusted = [];
        window.flutter_inappwebview = {callHandler: (_, value) => { window.reports.push(value); return Promise.resolve(); }};
        const editor = document.querySelector('textarea,[contenteditable]');
        window.originalEditor = editor;
        const submit = event => { window.sends.push(editor.value ?? editor.innerText); window.trusted.push(event.isTrusted); };
        editor.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); submit(e); } });
        document.querySelectorAll('button')[1].addEventListener('click', submit);
        document.querySelector('[title="表情"]').addEventListener('click', () => {
          const emoji = document.createElement('button'); emoji.textContent = '🙂'; emoji.id = 'official-emoji';
          emoji.onclick = () => { if ('value' in editor) editor.value += '[微笑]'; else editor.innerText += '[微笑]'; };
          const popup=document.createElement('div');popup.className='chat-emot Emotion-wrap emoticons-panel';
          popup.innerHTML='<div>全部表情</div><div>小表情</div><button>🙂</button><button>🙂</button><button>🙂</button>';
          popup.appendChild(emoji);editor.parentElement.appendChild(popup);
        });
      });
      await page.evaluate(({source, site}) => new Function('site', source)(site), {source, site});
      const input = page.locator('textarea,[contenteditable]');
      await assert.doesNotReject(() => input.waitFor({state: 'visible', timeout: 1500}));
      const rect = await input.boundingBox();
      assert(rect.x >= 0 && rect.y >= 0 && rect.x + rect.width <= 320 && rect.y + rect.height <= 180, `${site}: official editor stays offscreen instead of inline`);
      assert.equal(await page.locator('header').isVisible(), false);
      assert.deepEqual(await page.evaluate(() => window.sends), []);
      assert.equal(await page.evaluate(() => window.originalEditor === document.querySelector('textarea,[contenteditable]')), true);
      await input.fill('本地验证'); await input.press('Enter');
      assert.deepEqual(await page.evaluate(() => window.sends), ['本地验证']);
      assert.deepEqual(await page.evaluate(() => window.trusted), [true]);
      await page.locator('[title="表情"]').click();
      await page.waitForTimeout(180);
      await page.locator('#official-emoji').click();
      await page.evaluate(() => window.__simpleLiveOfficialEditor.setExpanded(false));
      await input.fill('再发一次');
      await page.locator('button').filter({hasText: /^发送$/}).click();
      assert.deepEqual(await page.evaluate(() => window.sends), ['本地验证', '再发一次']);
      await page.evaluate(() => window.__simpleLiveOfficialEditor.setExpanded(true));
      assert.equal(await page.locator('header').isVisible(), true);
      await page.evaluate(() => window.__simpleLiveOfficialEditor.setExpanded(false));
      assert.equal(await page.evaluate(() => window.originalEditor === document.querySelector('textarea,[contenteditable]')), true);
      // A framework replaces its editor subtree; adapt without moving its nodes.
      await page.evaluate(() => {
        const old = document.querySelector('[data-sl-official-editor-root]');
        const next = old.cloneNode(true); old.replaceWith(next);
      });
      await page.waitForTimeout(300);
      assert.equal(await page.locator('textarea,[contenteditable]').isVisible(), true);
      // A real native click can open a login/captcha portal outside the root.
      await page.evaluate(() => { const modal = document.createElement('div'); modal.setAttribute('role','dialog'); modal.textContent='登录验证'; document.body.appendChild(modal); });
      await page.waitForTimeout(300);
      assert.equal(await page.locator('[role=dialog]:not([style])').isVisible(), false);
      assert.equal(await page.evaluate(() => window.reports.some(r => r.status === 'requires_login')), true);
      console.log(`PASS ${site}: compact visible, original trusted input/send, emoji, expand, replacement and login; zero public submissions`);
      await page.close();
    }
    for (const site of Object.keys(sites)) {
      const stable=await browser.newPage({viewport:{width:375,height:56}});
      await stable.setContent(`<body><header>Full room must never flash</header>${sites[site]}<div role="dialog" style="display:none">隐藏验证</div><section id="live-feed"></section></body>`);
      await stable.evaluate(()=>{window.disabledWrites=0;const original=document.createElement.bind(document);document.createElement=(name,...args)=>{const el=original(name,...args);if(name==='style'){const native=Object.getOwnPropertyDescriptor(HTMLStyleElement.prototype,'disabled');Object.defineProperty(el,'disabled',{get(){return native.get.call(this)},set(value){window.disabledWrites++;native.set.call(this,value)}})}return el;};});
      await stable.evaluate(({source,site})=>new Function('site',source)(site),{source,site});
      await stable.locator('textarea,[contenteditable]').fill('稳定草稿');
      await stable.waitForTimeout(250);
      await stable.evaluate(()=>{window.markerWrites=0;window.disabledWrites=0;window.originalInput=document.querySelector('textarea,[contenteditable]');new MutationObserver(records=>{window.markerWrites+=records.filter(r=>r.type==='attributes'&&r.attributeName.startsWith('data-sl-')).length}).observe(document.documentElement,{subtree:true,attributes:true});});
      for(let i=0;i<8;i++){await stable.evaluate(()=>{const item=document.createElement('div');item.textContent='新消息';document.querySelector('#live-feed').append(item)});await stable.waitForTimeout(140);}
      const activity=await stable.evaluate(()=>({disabled:window.disabledWrites,markers:window.markerWrites,same:window.originalInput===document.querySelector('textarea,[contenteditable]'),text:window.originalInput.value??window.originalInput.innerText}));
      assert.equal(activity.disabled,0,`${site}: live updates must never disable the compact stylesheet`);
      assert.equal(activity.markers,0,`${site}: unchanged input nodes must not be unmarked/re-marked every sweep`);
      assert.equal(activity.same,true);assert.equal(activity.text,'稳定草稿');
      assert.equal(await stable.locator('header').isVisible(),false);
      await stable.close();
    }
    console.log('PASS official-platform live-update stability: zero stylesheet toggles or marker churn; same native draft');
    // Match WebView2's lifecycle: DOMContentLoaded fires while an image keeps
    // window.load pending indefinitely. The adapter must already be active.
    const early = await browser.newPage({viewport:{width:375,height:160}});
    let held;
    await early.route('https://layout-fixture.invalid/**', route => {
      if(route.request().url().endsWith('/held.png')) { held=route; return; }
      return route.fulfill({contentType:'text/html',body:'<html><body><header id="early-header">主播信息和礼物栏</header>'+sites.douyin+'<img src="/held.png"><script>window.loadFinished=false;window.addEventListener("load",()=>window.loadFinished=true)</script></body></html>'});
    });
    const bootstrap = dart.match(/static const bootstrap = r'''([\s\S]*?)''';/)?.[1];
    await early.addInitScript(({source,bootstrap})=>{
      const install=new Function('site','expectedRoomIds',source);
      if(bootstrap) new Function('site','expectedRoomIds','install',bootstrap)('douyin',[],install);
      else window.addEventListener('load',()=>install('douyin',[]));
    },{source,bootstrap});
    await early.goto('https://layout-fixture.invalid/1',{waitUntil:'domcontentloaded'});
    assert.equal(await early.evaluate(()=>window.loadFinished),false);
    assert.equal(await early.locator('#early-header').isVisible(),false,'adapter must run before window.load, not after pending room resources');
    assert.equal(await early.locator('[contenteditable]').isVisible(),true);
    console.log('PASS document-start: compact editor works while room resources keep window.load pending');
    await held.abort();await early.close();
    // Douyin's small viewport must never expose the cropped room/gift shelf
    // while its asynchronous editor is missing or its desktop rows stay wide.
    const compact = await browser.newPage({viewport:{width:375,height:160}});
    await compact.setContent('<html><body><header id="anchor">主播信息</header><aside id="gifts">礼物栏</aside></body></html>');
    await compact.evaluate(({source}) => new Function('site',source)('douyin'), {source});
    assert.equal(await compact.locator('#anchor').isVisible(), false, 'missing Douyin editor must not reveal cropped full room');
    assert.equal(await compact.locator('#gifts').isVisible(), false);
    assert.equal(await compact.evaluate(() => window.__simpleLiveOfficialEditor.inspect().status), 'loading');
    await compact.evaluate(() => {
      const root=document.createElement('section');
      root.innerHTML='<div class="row" style="display:flex;width:640px;min-width:640px;padding:8px;gap:8px"><div style="width:550px;min-width:550px"><div contenteditable="true" data-placeholder="说点什么，和主播聊聊" style="width:500px;min-width:500px;height:36px;border:1px solid"></div></div><button style="flex-shrink:0">发送</button></div>';
      document.body.appendChild(root);
      const input=root.querySelector('[contenteditable]'); window.editor=input;window.sends=[];
      root.querySelector('button').onclick=e=>window.sends.push({draft:input.innerText,trusted:e.isTrusted});
    });
    await compact.waitForTimeout(350);
    const input=compact.locator('[contenteditable]');
    for(const width of [300,375,760]) {
      await compact.setViewportSize({width,height:160});
      const r=await input.boundingBox();
      const send=await compact.locator('button').boundingBox();
      assert(r && r.x>=0 && r.y>=0 && r.x+r.width<=width && r.y+r.height<=160, 'Douyin input must fit narrow viewport');
      assert(send && send.x>=0 && send.x+send.width<=width, 'Douyin native send control must not be clipped');
      assert.equal(await compact.locator('#anchor').isVisible(),false);
    }
    await input.fill('本地草稿'); await compact.locator('button').click();
    assert.deepEqual(await compact.evaluate(()=>window.sends),[{draft:'本地草稿',trusted:true}]);
    await compact.evaluate(()=>window.__simpleLiveOfficialEditor.setExpanded(true));
    assert.equal(await compact.locator('#anchor').isVisible(),true);
    await compact.evaluate(()=>window.__simpleLiveOfficialEditor.setExpanded(false));
    assert.equal(await compact.evaluate(()=>window.editor===document.querySelector('[contenteditable]')),true);
    assert.equal(await input.innerText(),'本地草稿');
    console.log('PASS Douyin: missing-editor hides cropped page; delayed native input/send fits 300/375/760 widths without replacing DOM');
    await compact.close();
    const nativeRow=await browser.newPage({viewport:{width:375,height:56}});
    await nativeRow.setContent('<html><head><style>body{margin:0;background:#161616}.native-row{display:flex;align-items:center;height:56px;background:rgb(56,56,56);border-radius:10px}.text{flex:1;min-width:0}.native-row button{width:36px;height:36px;background:transparent;border:0;color:#888}svg{width:24px;height:24px}</style></head><body><aside>礼物和聊天不显示</aside><div class="native-row"><div class="text"><div data-e2e="chat-input" contenteditable="true" data-placeholder="与大家互动一下…"></div></div><button aria-label="表情"><svg></svg></button><button aria-label="发送"><svg></svg></button></div></body></html>');
    await nativeRow.evaluate(()=>{window.originalInput=document.querySelector('[contenteditable]');window.originalEmoji=document.querySelector('[aria-label="表情"]');window.originalSend=document.querySelector('[aria-label="发送"]');window.sent=[];window.originalSend.onclick=e=>window.sent.push({text:window.originalInput.innerText,trusted:e.isTrusted});});
    await nativeRow.evaluate(({source})=>new Function('site',source)('douyin'),{source});
    assert.equal(await nativeRow.locator('[aria-label="表情"]').isVisible(),true,'native emoji sibling must remain in composer row');
    assert.equal(await nativeRow.locator('[aria-label="发送"]').isVisible(),true,'native send sibling must remain in composer row');
    assert.equal(await nativeRow.locator('aside').isVisible(),false);
    for(const width of [300,375,500]){
      await nativeRow.setViewportSize({width,height:56});
      for(const selector of ['[contenteditable]','[aria-label="表情"]','[aria-label="发送"]']){const r=await nativeRow.locator(selector).boundingBox();assert(r&&r.x>=0&&r.y>=0&&r.x+r.width<=width&&r.y+r.height<=56,'entire original composer row must fit 56px without clipping');}
    }
    await nativeRow.locator('[contenteditable]').fill('原生单行草稿');await nativeRow.locator('[aria-label="发送"]').click();
    assert.deepEqual(await nativeRow.evaluate(()=>window.sent),[{text:'原生单行草稿',trusted:true}]);
    assert.equal(await nativeRow.evaluate(()=>window.originalInput===document.querySelector('[contenteditable]')&&window.originalEmoji===document.querySelector('[aria-label="表情"]')&&window.originalSend===document.querySelector('[aria-label="发送"]')),true);
    await nativeRow.screenshot({path:'C:/Temp/douyin-single-native-row-local.png'});
    await nativeRow.evaluate(()=>{window.emojiClicks=0;window.originalEmoji.onclick=()=>{window.emojiClicks++;const popup=document.createElement('div');popup.id='native-emoji-popup';popup.setAttribute('role','dialog');popup.style.cssText='position:absolute;left:900px;top:600px;width:300px;height:280px;background:#292929';popup.innerHTML='<div>最常使用</div><div>全部表情</div>'+Array.from({length:12},()=>'<button>😀</button>').join('')+'<div>小表情</div>';popup.querySelectorAll('button').forEach(b=>b.onclick=()=>{window.originalInput.innerText+='😀';popup.remove();});document.body.appendChild(popup);};window.originalEmoji.removeAttribute('aria-label');window.originalSend.removeAttribute('aria-label');});
    await nativeRow.locator('svg').first().click();
    await nativeRow.waitForTimeout(150);
    assert.equal(await nativeRow.evaluate(()=>getComputedStyle(window.originalSend).visibility),'visible','unlabelled native SVG send arrow must survive compact layout');
    const order=await nativeRow.evaluate(()=>[window.originalInput,window.originalEmoji,window.originalSend].map(e=>e.getBoundingClientRect().x));
    assert(order[0]<order[1]&&order[1]<order[2],'Douyin preserves native text, emoji, send order');
    assert.equal(await nativeRow.evaluate(()=>window.emojiClicks),1);
    await nativeRow.waitForTimeout(150);
    assert.equal(await nativeRow.evaluate(()=>window.__simpleLiveOfficialEditor.inspect().expanded),false,'emoji must never expand the complete room');
    assert.equal(await nativeRow.evaluate(()=>window.__simpleLiveOfficialEditor.inspect().emojiOpen),true);
    await nativeRow.setViewportSize({width:375,height:376});await nativeRow.waitForTimeout(200);
    const popup=nativeRow.locator('#native-emoji-popup');assert.equal(await popup.isVisible(),true);
    const pr=await popup.boundingBox();assert(pr.x>=0&&pr.y>=0&&pr.x+pr.width<=375&&pr.y+pr.height<=320,'only the native emoji popup fits above the bar');
    assert.equal(await nativeRow.locator('aside').isVisible(),false,'room/gifts remain hidden while picking an emoji');
    await nativeRow.screenshot({path:'C:/Temp/douyin-emoji-popup-only-local.png'});
    await popup.locator('button').first().click();await nativeRow.waitForTimeout(200);
    assert.equal(await nativeRow.evaluate(()=>window.__simpleLiveOfficialEditor.inspect().emojiOpen),false);
    assert.equal(await nativeRow.locator('[contenteditable]').innerText(),'原生单行草稿😀');
    await nativeRow.close();console.log('PASS Douyin single native row: original emoji/send siblings preserved, no gift area, fits 56px at three widths');
    for (const site of ['huya','douyin']) {
      const page=await browser.newPage({viewport:{width:375,height:site==='huya'?158:56}});
      const input={huya:'<textarea id="pub_msg_input"></textarea>',douyu:'<div class="ChatSend-txt" contenteditable="true"></div>',bilibili:'<textarea class="chat-input"></textarea>',douyin:'<div contenteditable="true" data-e2e="chat-input"></div>'}[site];
      const row=site==='huya'?`<div class="chat-room__ft"><div class="chat-emot" style="display:none"></div><div><button id="J_inputEmot" title="表情">表情</button></div>${input}<button id="msg_send_bt">发送</button></div>`:`<div class="row">${input}<button title="表情">表情</button><button data-e2e="chat-send-btn">发送</button></div>`;
      const nativeRow=site==='douyu'?`<div class="Chat"><button title="表情">表情</button>${input}<button class="ChatSend-button">发送</button></div>`:site==='bilibili'?`<div class="chat-control-panel"><button title="表情">表情</button><div class="chat-input-ctnr">${input}<button class="send-btn">发送</button></div></div>`:row;
      await page.setContent(`<style>body{margin:0}.row{display:flex;height:56px}textarea{height:60px}.popup{position:absolute;width:360px;bottom:100%;background:#333;color:white}.grid{height:400px;overflow:hidden;display:flex;flex-wrap:wrap}.grid button{flex:0 0 50px;height:40px}.tabs{height:32px}</style><body><header>完整网页不应出现</header>${nativeRow}</body>`);
      await page.evaluate(site=>{document.querySelector('[title="表情"]').onclick=()=>{const popup=site==='huya'?document.querySelector('.chat-emot'):document.createElement('div');popup.classList.add('popup');if(site==='douyu')popup.classList.add('Emotion-wrap');if(site==='bilibili')popup.classList.add('emoticons-panel');popup.style.display='block';popup.innerHTML='<div>最常使用</div><div>全部表情</div><div class="grid">'+Array.from({length:90},(_,i)=>`<button data-index="${i}">表情${i}</button>`).join('')+'</div><div class="tabs">小表情　会员表情</div>';popup.querySelectorAll('button').forEach(b=>b.onclick=()=>{window.picked=b.dataset.index;popup.remove()});if(site==='huya'){const dashboard=document.createElement('div');dashboard.className='Dashboard--fixture';dashboard.style.cssText='position:absolute;bottom:100%;left:140px;width:400px';dashboard.append(...popup.childNodes);popup.appendChild(dashboard);}if(site!=='huya')document.body.append(popup);}},site);
      await page.evaluate(({site,source})=>new Function('site',source)(site),{site,source});
      await page.waitForFunction(()=>window.__simpleLiveOfficialEditor.inspect().status==='ready');
      await page.locator('[title="表情"]').click();await page.waitForTimeout(250);
      assert.equal(await page.evaluate(()=>window.__simpleLiveOfficialEditor.inspect().expanded),false,`${site} emoji must not expand the entire page`);
      assert.equal(await page.evaluate(()=>window.__simpleLiveOfficialEditor.inspect().emojiOpen),true,site+' popup opens');
      await page.setViewportSize({width:375,height:376});await page.waitForTimeout(250);
      const popup=page.locator('[data-sl-official-popup]'),box=await popup.boundingBox();
      assert(box&&box.y>=0&&box.x>=0&&box.x+box.width<=375,'complete popup must fit the native viewport');
      await page.evaluate(()=>{window.popupMarkerWrites=0;new MutationObserver(records=>{window.popupMarkerWrites+=records.filter(r=>r.type==='attributes'&&r.attributeName.startsWith('data-sl-')).length}).observe(document.documentElement,{subtree:true,attributes:true});});
      for(let i=0;i<4;i++){await page.evaluate(()=>document.body.appendChild(document.createElement('aside')));await page.waitForTimeout(140);}
      assert.equal(await page.evaluate(()=>window.popupMarkerWrites),0,`${site}: an open native popup must not be unmarked/re-marked by incoming messages`);
      const grid=page.locator('.grid');await grid.hover();await page.mouse.wheel(0,1600);await page.waitForTimeout(250);
      assert(await grid.evaluate(e=>e.scrollTop>0),`${site} native emoji grid must accept real mouse wheel scrolling`);
      await grid.evaluate(e=>e.scrollTop=e.scrollHeight);await popup.locator('[data-index="89"]').click();
      assert.equal(await page.evaluate(()=>window.picked),'89','last original emoji remains clickable');
      assert.equal(await page.locator('header').isVisible(),false);
      await page.waitForTimeout(250);
      assert.equal(await page.evaluate(()=>window.__simpleLiveOfficialEditor.inspect().emojiOpen),false,'closing native popup returns to the single bar');
      await page.locator('[title="表情"]').evaluate(e=>e.onclick=()=>{});
      await page.locator('[title="表情"]').click();await page.waitForTimeout(250);
      assert.equal(await page.evaluate(()=>window.__simpleLiveOfficialEditor.inspect().emojiOpen),false,'missing native popup must not allocate a blank expanded panel');
      await page.close();
    }
    console.log('PASS Official-platform native popup: bounded full shell, real wheel scrolling, last emoji native click');
    for(const [site,html] of Object.entries(sites)) {
      const toggle=await browser.newPage({viewport:{width:375,height:376}});
      await toggle.setContent(`<style>.hidden{display:none}.shell{position:absolute}.popup{width:300px;height:200px}</style>${html}<div class="shell hidden"><div class="popup ${ {huya:'chat-emot',douyu:'Emotion-wrap',bilibili:'emoticons-panel',douyin:''}[site] }"><span>全部表情</span><button>😀</button><button>😁</button><button>😂</button><button>😃</button><span>小表情</span></div></div>`);
      await toggle.evaluate(()=>{window.open=false;const button=document.querySelector('[title="表情"]');button.parentElement.append(document.querySelector('.shell'));button.onclick=()=>{window.open=!window.open;document.querySelector('.shell').classList.toggle('hidden',!window.open);};});
      await toggle.evaluate(({site,source})=>new Function('site',source)(site),{site,source});
      await toggle.evaluate(()=>{
        window.barFrames=[];window.sampleBar=true;
        const sample=()=>{
          if(!window.sampleBar)return;
          window.barFrames.push(Array.from(document.querySelectorAll('[data-sl-official-control]')).map(e=>{
            const r=e.getBoundingClientRect(),css=getComputedStyle(e);
            return [r.x,r.y,r.width,r.height,css.visibility,css.opacity,css.display];
          }));requestAnimationFrame(sample);
        };sample();
      });
      for(let i=0;i<3;i++) {
        await toggle.locator('[title="表情"]').click();await toggle.waitForTimeout(260);
        assert.equal(await toggle.evaluate(()=>window.__simpleLiveOfficialEditor.inspect().emojiOpen),true,`${site}: native open`);
        await toggle.locator('[title="表情"]').click();await toggle.waitForTimeout(260);
        for(let j=0;j<3;j++) {
          await toggle.evaluate(()=>document.body.append(document.createElement('aside')));await toggle.waitForTimeout(150);
          assert.equal(await toggle.evaluate(()=>window.__simpleLiveOfficialEditor.inspect().emojiOpen),false,`${site}: second click closes retained native popup without reopening on mutation`);
        }
      }
      const frames=await toggle.evaluate(()=>{window.sampleBar=false;return window.barFrames});
      assert(frames.length>20,`${site}: sample open and close rendering frames`);
      frames.forEach(frame=>assert.deepEqual(frame,frames[0],`${site}: native input/emoji/send geometry and visibility must stay still on every sampled frame`));
      await toggle.close();
    }
    console.log('PASS official-platform repeated native emoji open/close, retained class-hidden panels and message mutations');
    const focusRow = await browser.newPage({viewport:{width:375,height:56}});
    await focusRow.setContent(`<html><head><style>
      body{margin:0}.row{display:flex;align-items:center;height:56px}.text{flex:1;min-width:0}
      button{width:36px;height:36px;border:0;background:transparent;color:#888}svg{width:24px;height:24px}
      .row:focus-within .text{display:flex;flex-direction:column;justify-content:center}
      [contenteditable]:focus:empty::before{content:attr(data-placeholder);display:block;position:absolute;left:50%;top:12px;transform:translateX(-50%);width:90px;white-space:normal}
    </style></head><body><div class="row"><div class="text"><div data-e2e="chat-input" contenteditable="true" data-placeholder="与大家互动一下…"></div></div><button aria-label="表情"><svg></svg></button><button aria-label="发送"><svg></svg></button></div></body></html>`);
    await focusRow.evaluate(({source})=>new Function('site',source)('douyin'),{source});
    for(const width of [300,375,500]) {
      await focusRow.setViewportSize({width,height:56});
      const input=focusRow.locator('[contenteditable]');
      await input.evaluate(e=>e.replaceChildren());
      await input.click();
      const focused=await input.evaluate(e=>{const p=getComputedStyle(e,'::before');return {position:p.position,wrap:p.whiteSpace,scroll:e.scrollHeight,height:e.clientHeight};});
      assert.equal(focused.position,'static','focus placeholder must not move to the center of a narrow floating box');
      assert.equal(focused.wrap,'nowrap','focus placeholder must stay on one line');
      assert(focused.scroll<=focused.height,'empty focus must not introduce vertical scrolling');
      await input.fill('测试文字很长也不能把输入框撑成两行'.repeat(4));
      assert(await input.evaluate(e=>e.scrollHeight<=e.clientHeight),'long draft stays a single scrollable line');
      for(const selector of ['[contenteditable]','[aria-label="表情"]','[aria-label="发送"]']) {
        const r=await focusRow.locator(selector).boundingBox();
        assert(r&&r.x>=0&&r.y>=0&&r.x+r.width<=width&&r.y+r.height<=56,'focus must preserve the complete row and its original actions');
      }
      await input.fill('');await focusRow.locator('[aria-label="发送"]').click();
      await input.click();
    }
    await focusRow.setViewportSize({width:375,height:56});
    // Native rich editors keep paragraph/BR nodes after clearing a draft.
    // Their margins/padding must not move the actual caret line off center.
    for (const markup of ['字','<p style="margin:12px 0;padding:6px 0">字</p>', '<p style="margin:12px 0;padding:6px 0"><span>字</span></p>', '<br>', '<p style="margin:12px 0;padding:6px 0"><br></p>']) {
      const caret=await focusRow.locator('[contenteditable]').evaluate((e,markup)=>{
        e.innerHTML=markup;e.focus();
        const walker=document.createTreeWalker(e,NodeFilter.SHOW_TEXT);
        const text=walker.nextNode();const range=document.createRange();
        if(text){range.setStart(text,0);range.setEnd(text,1);}
        else range.selectNode(e.querySelector('br'));
        const line=range.getBoundingClientRect(),box=e.getBoundingClientRect();
        document.getSelection().collapse(text||e.querySelector('br').parentNode,0);
        return {lineCenter:(line.top+line.bottom)/2,boxCenter:(box.top+box.bottom)/2,height:line.height};
      },markup);
      assert(caret.height>0&&Math.abs(caret.lineCenter-caret.boxCenter)<=2,`Douyin caret line must be vertically centered for native rich nodes: ${JSON.stringify(caret)}`);
    }
    await focusRow.locator('[contenteditable]').evaluate(e=>e.replaceChildren());
    await focusRow.locator('[contenteditable]').click();
    await focusRow.screenshot({path:'C:/Temp/douyin-focus-row-local.png'});
    await focusRow.close();console.log('PASS Douyin focus: single-line placeholder/draft, stable native action geometry at three widths');
    const readable = await browser.newPage({viewport:{width:375,height:128}});
    await readable.setContent('<html><head><style>body{margin:0;background:#161616}.tall{min-height:320px}.inner{position:relative;height:260px;padding-top:120px}.native{position:absolute;bottom:0;width:500px;height:200px;line-height:180px;font-size:11px;background:#171717;color:#606060}.native:empty:before{content:attr(data-placeholder);color:#555}button{height:30px}</style></head><body><section class="tall" data-e2e="chat-input"><div class="inner"><div class="native" contenteditable="true" data-placeholder="与大家互动一下…"></div></div><div><button data-e2e="chat-send-btn">发送</button></div></section></body></html>');
    await readable.evaluate(({source}) => new Function('site',source)('douyin'),{source});
    const editable=readable.locator('[contenteditable]');
    const box=await editable.boundingBox();
    assert(box && box.y>=0 && box.y+box.height<=128,'native editor text must not sit below/cross viewport edge');
    const css=await editable.evaluate(e=>({font:parseFloat(getComputedStyle(e).fontSize),line:parseFloat(getComputedStyle(e).lineHeight),fg:getComputedStyle(e).color,bg:getComputedStyle(e).backgroundColor,placeholder:getComputedStyle(e,'::before').color}));
    assert(css.font>=16 && css.line>=24,'Douyin typing must use legible 16px text and 24px line height');
    assert.equal(css.fg,'rgb(184, 186, 192)');assert.equal(css.bg,'rgba(0, 0, 0, 0)');
    await editable.fill('清晰可读的本地草稿');
    const line=await editable.evaluate(e=>{const r=document.createRange();r.selectNodeContents(e);const b=r.getBoundingClientRect();return {y:b.y,bottom:b.bottom}});
    assert(line.y>=0 && line.bottom<=128,'actual text line must be fully visible');
    await readable.screenshot({path:'C:/Temp/douyin-editor-readable-local.png'});
    console.log('PASS Douyin readability: tall native editor reset, full text line visible at 375x128, high-contrast 16px typing');
    await readable.close();
    for (const [site,host,wrong] of [['huya','www.huya.com','2'],['douyin','live.douyin.com','2']]) {
    const guarded = await browser.newPage();
    await guarded.route(`https://${host}/**`, route => route.fulfill({contentType: 'text/html',
      body: `<body>${sites[site]}<script>window.sends=0;document.querySelector('textarea,[contenteditable]').onkeydown=e=>{if(e.key==='Enter')window.sends++}</script></body>`}));
    await guarded.goto(`https://${host}/1`);
    await guarded.evaluate(({source,site}) => new Function('site','expectedRoomIds',source)(site,['1']), {source,site});
    await guarded.locator('textarea,[contenteditable]').focus();
    await guarded.evaluate(wrong => history.pushState({}, '', '/' + wrong), wrong);
    await guarded.keyboard.press('Enter');
    assert.equal(await guarded.evaluate(() => window.sends), 0);
    assert.equal(await guarded.locator('textarea,[contenteditable]').isVisible(), false);
    assert.equal(await guarded.evaluate(() => document.documentElement.hasAttribute('data-sl-official-blocked')), true);
    console.log('PASS SPA wrong-room navigation blocks editor and keyboard before official send handlers');
    await guarded.close();
    }
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
