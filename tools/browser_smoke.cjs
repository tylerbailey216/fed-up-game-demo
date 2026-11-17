// Run with the locally installed Playwright package; no browser downloads needed.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
let activeBrowser;
(async()=>{
 const hardware=process.argv.includes('--hardware');
 const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:hardware?['--enable-webgl']:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 activeBrowser=browser;
 const errors=[];
 const page=await browser.newPage({viewport:{width:360,height:640},hasTouch:true,deviceScaleFactor:1});
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{console.log(m.type()+': '+m.text());if(m.type()==='error')errors.push(m.text());});
 let releaseEngine;
 const engineGate=new Promise(resolve=>releaseEngine=resolve);
 await page.route('**/game-*.js',async route=>{await engineGate;await route.continue();});
 const response=await page.goto(process.argv.find((arg,i)=>i>1&&/^https?:/.test(arg))||'http://127.0.0.1:8765/',{waitUntil:'commit'});
 if(!response.ok())throw new Error('HTTP '+response.status()+' at '+page.url());
 await page.locator('.illustration img').waitFor();
 await page.waitForFunction(()=>document.querySelector('.illustration img').complete);
 await page.evaluate(()=>document.fonts.ready);
 for(const [width,height] of [[360,640],[1280,720],[844,390]]){
  await page.setViewportSize({width,height});
  await page.screenshot({path:`docs/web-loading-${width}x${height}.png`});
  const fits=await page.evaluate(()=>[...document.querySelectorAll('.identity,.illustration,.loading-area')].every(e=>{const r=e.getBoundingClientRect();return r.x>=0&&r.y>=0&&r.right<=innerWidth&&r.bottom<=innerHeight;}));
  if(!fits)throw new Error(`Loading artwork overflows ${width}x${height}`);
 }
 releaseEngine();await page.waitForLoadState('domcontentloaded');await page.unroute('**/game-*.js');
 await page.setViewportSize({width:360,height:640});
 await page.locator('#canvas').waitFor();
 try{await page.waitForFunction(()=>!document.querySelector('#loading'),null,{timeout:90000});}
 catch(e){await page.screenshot({path:'docs/web-load-failure.png'});console.log(await page.locator('body').innerText());await browser.close();throw e;}
 await page.screenshot({path:'docs/web-phone-menu.png'});
 await page.keyboard.press('Enter');
 await page.waitForTimeout(3000);
 await page.screenshot({path:'docs/web-phone-drive.png'});
 const cdp=await page.context().newCDPSession(page);
 // Hold BRAKE / REV from rest: rendered reverse gear and touch geometry QA.
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:311,y:606,id:3}]});
 await page.waitForTimeout(2500);
 await page.screenshot({path:'docs/web-phone-reverse.png'});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:94,y:575,id:1},{x:310,y:554,id:2}]});
 await page.waitForTimeout(750);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await page.screenshot({path:'docs/web-phone-multitouch.png'});
 // Stop, leave the cab, and sample the new walk through actual mobile input.
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:184,y:601,id:5}]});
 await page.waitForTimeout(900);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:138,y:129,id:6}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await page.waitForTimeout(250);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:64,y:539,id:7}]});
 for(let frame=0;frame<3;frame++){
  await page.waitForTimeout(100);
  await page.screenshot({path:`docs/web-phone-worker-frame${frame}.png`});
 }
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:138,y:129,id:8}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await page.setViewportSize({width:844,height:390});
 await page.waitForTimeout(1500);
 await page.screenshot({path:'docs/web-phone-landscape.png'});
 await page.setViewportSize({width:1024,height:768});
 await page.waitForTimeout(1500);
 await page.screenshot({path:'docs/web-tablet-drive.png'});
 console.log('tablet metrics',await page.evaluate(()=>({inner:[innerWidth,innerHeight],canvas:[document.querySelector('canvas').width,document.querySelector('canvas').height],rect:document.querySelector('canvas').getBoundingClientRect().toJSON()})));
 await page.setViewportSize({width:1280,height:720});
 await page.waitForTimeout(1500);
 await page.screenshot({path:'docs/web-desktop-drive.png'});
 const renderer=await page.evaluate(()=>{const gl=document.querySelector('canvas').getContext('webgl2');const info=gl.getExtension('WEBGL_debug_renderer_info');return info?gl.getParameter(info.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER);});
 const frameTimes=await page.evaluate(()=>new Promise(resolve=>{const values=[];let last;function sample(now){if(last)values.push(now-last);last=now;if(values.length===120){values.sort((a,b)=>a-b);resolve({p95_ms:values[113],worst_ms:values[119],fps:120000/values.reduce((a,b)=>a+b,0)});}else requestAnimationFrame(sample);}requestAnimationFrame(sample);}));
 fs.writeFileSync('docs/browser-smoke.json',JSON.stringify({url:page.url(),errors,renderer,frameTimes},null,2));
 console.log({renderer,frameTimes});
 console.log(JSON.stringify({url:page.url(),errors}));
 await browser.close();
 if(errors.length)process.exitCode=1;
})().catch(async e=>{console.error(e);if(activeBrowser)await activeBrowser.close();process.exitCode=1});
