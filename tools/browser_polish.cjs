// Phase 1 visual fixtures plus real curb-return and package walking controls.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
(async()=>{
 const baseline=process.argv.includes('--baseline');
 const requested=process.argv.find(a=>a.startsWith('--layout='))?.slice(9);
 const results=[];
 for(const [width,height,touch] of [[360,640,true],[844,390,true],[768,1024,true],[1280,720,false]].filter(([w,h])=>!requested||requested===`${w}x${h}`)){
  const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl']});
  try{
   const context=await browser.newContext({viewport:{width,height},hasTouch:touch});const page=await context.newPage();const errors=[];
   page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   await page.goto((process.argv[2]||'http://127.0.0.1:8766/')+'?qa=arcade');
   await page.waitForFunction(()=>window.fedupQA,null,{timeout:90000});
   await page.locator('#loading').waitFor({state:'hidden',timeout:20000});
   const state=()=>page.evaluate(()=>window.fedupQA);
   const check=(ok,label)=>{if(!ok)throw Error(label);};
   const wait=async(fn,label,timeout=20000,arg=null)=>{try{await page.waitForFunction(fn,arg,{timeout});}catch(e){throw Error(label+' '+JSON.stringify({state:await state(),errors}));}};
   const command=async (value,delay=350)=>{await page.evaluate(v=>window.fedupQACommand=v,value);await page.waitForTimeout(delay);};
   const shot=async label=>page.screenshot({path:`docs/polish-${baseline?'before':'after'}-${label}-${width}x${height}.png`});
   const cdp=await context.newCDPSession(page);let touched=false;let keys=[];
   const release=async()=>{if(touched){await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});touched=false;}for(const key of keys)await page.keyboard.up(key);keys=[];};
   const direction=async(x,y)=>{
    if(touch){const r=(await state()).regions.stick;const p={id:1,x:(r[0]+r[2]*.5)*width+x*r[2]*width*.4,y:(r[1]+r[3]*.5)*height+y*r[2]*width*.4};await cdp.send('Input.dispatchTouchEvent',{type:touched?'touchMove':'touchStart',touchPoints:[p]});touched=true;}
    else{await release();await page.locator('canvas').focus();keys=x<0?['a']:x>0?['d']:y<0?['w']:['s'];for(const key of keys)await page.keyboard.down(key);}
   };
   const replay=async()=>{const r=(await state()).regions.replay;await page.mouse.click((r[0]+r[2]/2)*width,(r[1]+r[3]/2)*height);await wait(()=>!window.fedupQA.complete,'Replay did not reset');};
   await page.mouse.click(width*.5,height*.4);await command('quiet');
   const performance=await page.evaluate(()=>new Promise(resolve=>{let last;const dt=[];function frame(t){if(last)dt.push(t-last);last=t;if(dt.length<90)return requestAnimationFrame(frame);const sorted=[...dt].sort((a,b)=>a-b);resolve({fps:90000/dt.reduce((a,b)=>a+b),p95_ms:sorted[85]});}requestAnimationFrame(frame);}));
   if(!baseline){
    const previousReset=(await state()).resets;await command('curb');
    await wait(n=>{const s=window.fedupQA;return s.resets>n&&Math.abs(s.truck[0]+47)<.1&&Math.abs(s.truck[2]-25)<.1&&s.truck[1]<.01&&s.speed<.05;},'Fixture did not reset and settle on the road',10000,previousReset);
    const start=await state();
    await page.evaluate(()=>{window.curbTrace=[];window.curbTraceTimer=setInterval(()=>{const s=window.fedupQA;window.curbTrace.push({at:s.truck,speed:s.speed,crashes:s.crashes,energy:s.energy});},80);});
    await direction(-.65,0);
    await wait(()=>window.fedupQA.truck[0]<-60,'Road to grass crossing failed');await release();await wait(()=>window.fedupQA.speed<.15,'Grass stop');
    await shot('grass');await direction(.65,0);await wait(()=>window.fedupQA.truck[0]>-48,'Stopped grass to same road failed');await release();await wait(()=>window.fedupQA.speed<.15,'Road stop');
    const end=await state();const trace=await page.evaluate(()=>{clearInterval(window.curbTraceTimer);return window.curbTrace;});fs.writeFileSync(`docs/polish-curb-trace-${width}x${height}.json`,JSON.stringify({start,end,trace},null,2));await shot('curb-return');check(end.crashes===start.crashes&&end.energy===start.energy&&end.offroad===start.offroad,'Ordinary curb crossing damaged or recovered the truck '+JSON.stringify({width,height,start,end,trace}));
    await command('park');await command('impact',0);await wait(()=>window.fedupQA.feedback.live>0,'Visible impact burst missing');await shot('impact');await page.waitForTimeout(600);check((await state()).feedback.live===0,'Impact burst lingered');
   }
   // Fixtures isolate feedback/report states. The existing arcade suite owns
   // continuous route-driving acceptance; these positions do not replace it.
   for(let gate=1;gate<=4;gate++){await command('gate');await wait(n=>window.fedupQA.route===n,'Route marker did not clear',6000,gate);}
   await command('bay');await wait(()=>window.fedupQA.complete,'Collection finish');await page.waitForTimeout(700);await shot('report');
   if(!baseline){const s=await state();check(s.feedback.checkpoints===4&&s.feedback.completions===1,'Duplicate/missing checkpoint or finish feedback');check(s.report.progress===1&&s.report.manifest===12,'Animated report did not settle at exact results');}
   await replay();await command('quiet');await command('spill');await wait(()=>window.fedupQA.on_foot,'Disabled exit');await command('line');await direction(0,-.8);
   await wait(()=>window.fedupQA.collected>=1,'First walk-over pickup');await shot('pickup');
   await wait(()=>window.fedupQA.collected===12&&window.fedupQA.restored,'All automatic pickups',30000);await release();await page.waitForTimeout(300);await shot('collected');
   const end=await state();
   if(!baseline){check(end.feedback.pickups===12&&end.spawned===12,'Pickup effects changed fixed manifest credit');check(end.feedback.peak_live<=end.feedback.capacity,'Feedback pool exceeded its budget');check(end.feedback.audio.package_pickup>0,'Pickup cue missing');}
   if(errors.length)throw Error(errors.join('\n'));
   results.push({width,height,touch,baseline,performance,feedback:end.feedback||null,errors});console.log(`PASS POLISH ${baseline?'BEFORE':'AFTER'} ${width}x${height}`,performance);
  }finally{await browser.close();}
 }
 fs.writeFileSync(`docs/polish-${baseline?'before':'after'}-smoke.json`,JSON.stringify(results,null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});
