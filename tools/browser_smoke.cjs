// Run with the locally installed Playwright package; no browser downloads needed.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const errors=[];
 const page=await browser.newPage({viewport:{width:720,height:1280},hasTouch:true,deviceScaleFactor:1});
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{console.log(m.type()+': '+m.text());if(m.type()==='error')errors.push(m.text());});
 await page.goto(process.argv[2]||'http://127.0.0.1:8765/');
 try{await page.waitForFunction(()=>!document.querySelector('#loading'),null,{timeout:90000});}
 catch(e){await page.screenshot({path:'docs/web-load-failure.png'});console.log(await page.locator('body').innerText());await browser.close();throw e;}
 await page.screenshot({path:'docs/web-phone-menu.png'});
 await page.touchscreen.tap(235,295);
 await page.waitForTimeout(3000);
 await page.screenshot({path:'docs/web-phone-drive.png'});
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
})().catch(e=>{console.error(e);process.exitCode=1});
