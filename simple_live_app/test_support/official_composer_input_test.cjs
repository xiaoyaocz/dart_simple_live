// Native Chromium input against local HTML only; no public chat submissions.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright-core');
const source=fs.readFileSync(path.join(__dirname,'../lib/services/official_composer_transport.dart'),'utf8').match(/static const submit = r'''([\s\S]*?)''';/)[1];
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 try {
  for(const rich of [false,true]) {
   const page=await browser.newPage({viewport:{width:375,height:400}});
   await page.setContent((rich?'<div contenteditable="true">旧草稿</div>':'<textarea>旧草稿</textarea>')+'<button>发送</button>');
   let edits=0;
   const cdp=await page.context().newCDPSession(page);
   await page.exposeFunction('nativeInput',async args=>{
    if(args.action==='edit') {edits++;await cdp.send('Input.insertText',{text:'统一输入[微笑] 👋'});}
    else for(const type of ['mousePressed','mouseReleased']) await cdp.send('Input.dispatchMouseEvent',{type,x:args.x,y:args.y,button:'left',clickCount:1});
    return true;
   });
   await page.evaluate(()=>{
    const input=document.querySelector('textarea,[contenteditable]'),button=document.querySelector('button');
    window.sends=[];
    button.onclick=event=>sends.push({trusted:event.isTrusted,text:input.value??input.textContent});
    window.editorReady=false;setTimeout(()=>window.editorReady=true,150);
    window.__simpleLiveOfficialEditor={inspect:()=>({status:window.editorReady?'ready':'loading'}),composerInput:()=>input,composerButton:()=>button};
    window.flutter_inappwebview={callHandler:(_,args)=>window.nativeInput(args)};
   });
   const submit=()=>page.evaluate(source=>new (Object.getPrototypeOf(async function(){}).constructor)('text','handler',source)('统一输入[微笑] 👋','fixture'),source);
   assert.equal((await submit()).status,'submitted');
   assert.deepEqual(await page.evaluate(()=>sends),[{trusted:true,text:'统一输入[微笑] 👋'}]);
   await page.locator('button').evaluate(e=>e.disabled=true);
   assert.equal((await submit()).status,'rejected');
   assert.equal(await page.evaluate(()=>sends.length),1);
   await page.clock.install();
   await page.evaluate(()=>window.editorReady=false);
   const editsBefore=edits;
   const blocked=submit();
   await page.clock.fastForward(12100);
   assert.equal((await blocked).status,'not_ready');
   assert.equal(edits,editsBefore,'never edit a draft while the page is not ready');
   assert.equal(await page.evaluate(()=>sends.length),1,'readiness timeout must not submit');
   await page.close();
  }
  console.log('PASS shared Flutter draft -> trusted textarea/contenteditable input and native submit; disabled control never submits');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
