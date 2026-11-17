// Exported WebAssembly: actual Cleveland curb geometry, shared PC/touch physics.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
(async()=>{
 const results=[];let browser;
 try{
  for(const [width,height,touch] of [[360,640,true],[844,390,true],[1280,720,false]]){
   browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl']});
   const context=await browser.newContext({viewport:{width,height},hasTouch:touch,deviceScaleFactor:1});
   const page=await context.newPage(),errors=[];
   page.on('pageerror',e=>errors.push(e.message));
   page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   const base=process.argv[2]||'http://127.0.0.1:8766/';
   await page.goto(base+'?qa=controls');
   await page.waitForFunction(()=>window.fedupQA,null,{timeout:90000});
   const state=()=>page.evaluate(()=>window.fedupQA);
   const command=async value=>{
    await page.evaluate(v=>window.fedupQACommand=v,value);
    await page.waitForFunction(()=>!window.fedupQACommand,null,{timeout:10000});
   };
   await command('curb_prepare');await page.waitForTimeout(600);
   const before=await state();await command('curb_jump');
   await page.waitForFunction(n=>window.fedupQA.jump_launches>n&&window.fedupQA.jump_active,before.jump_launches,{timeout:12000});
   let peak=0;
   for(let i=0;i<6;i++){
    const q=await state();peak=Math.max(peak,q.jump_height);
    if(q.recovery_visible)throw new Error('Ordinary flight exposed rollover recovery');
    if(i===1)await page.screenshot({path:`docs/stunt-browser-air-${width}x${height}.png`});
    await page.waitForTimeout(80);
   }
   await page.waitForFunction(()=>!window.fedupQA.jump_active,null,{timeout:18000});
   const q=await state();
   if(q.jump_launches!==before.jump_launches+1||q.jump_airtime<.25||q.jump_landings<=before.jump_landings||peak<.45||q.overturned||q.on_foot||!Number.isFinite(q.speed))throw new Error('Unexpected curb result: '+JSON.stringify(q));
   if(errors.length)throw new Error(errors.join('\n'));
   await page.screenshot({path:`docs/stunt-browser-land-${width}x${height}.png`});
   results.push({width,height,touch,build:q.build,peak,airtime:q.jump_airtime,landing_speed:q.jump_closing,speed_after:q.speed,errors});
   console.log('PASS',width,height,JSON.stringify(results.at(-1)));
   await context.close();await browser.close();browser=null;
  }
  fs.writeFileSync('docs/stunt-smoke.json',JSON.stringify(results,null,2));
 }finally{if(browser)await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
