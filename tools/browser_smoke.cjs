// Run with the locally installed Playwright package; no browser downloads needed.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
let activeBrowser;
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 activeBrowser=browser;
 const errors=[];
 const page=await browser.newPage({viewport:{width:360,height:640},hasTouch:true,deviceScaleFactor:1});
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{console.log(m.type()+': '+m.text());if(m.type()==='error')errors.push(m.text());});
 const response=await page.goto(process.argv[2]||'http://127.0.0.1:8765/');
 if(!response.ok())throw new Error('HTTP '+response.status()+' at '+page.url());
 await page.locator('#canvas').waitFor();
 try{await page.waitForFunction(()=>!document.querySelector('#loading'),null,{timeout:90000});}
 catch(e){await page.screenshot({path:'docs/web-load-failure.png'});console.log(await page.locator('body').innerText());await browser.close();throw e;}
 await page.screenshot({path:'docs/web-phone-menu.png'});
 await page.touchscreen.tap(118,148);
 await page.waitForTimeout(3000);
 await page.screenshot({path:'docs/web-phone-drive.png'});
 const cdp=await page.context().newCDPSession(page);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:94,y:575,id:1},{x:310,y:554,id:2}]});
 await page.waitForTimeout(750);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await page.screenshot({path:'docs/web-phone-multitouch.png'});
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
 fs.writeFileSync('docs/browser-smoke.json',JSON.stringify({url:page.url(),errors},null,2));
 console.log(JSON.stringify({url:page.url(),errors}));
 await browser.close();
 if(errors.length)process.exitCode=1;
})().catch(async e=>{console.error(e);if(activeBrowser)await activeBrowser.close();process.exitCode=1});
