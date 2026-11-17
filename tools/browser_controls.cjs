// Actual WebAssembly gameplay assertions through browser keyboard/touch input.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
(async()=>{
 let browser;
 const results=[];
 try{
 for(const [width,height,touch,dpr] of [[360,640,true,2],[844,390,true,2],[768,1024,true,1],[1280,720,false,1]]){
  browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl']});
  const context=await browser.newContext({viewport:{width,height},hasTouch:touch,deviceScaleFactor:dpr});
  const page=await context.newPage();const errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error'){errors.push(m.text());console.log(m.text());}});
  const base=process.argv[2]||'http://127.0.0.1:8765/';
  await page.goto(base+(base.includes('?')?'&':'?')+'qa=controls');
  try{await page.waitForFunction(()=>window.fedupQA,null,{timeout:90000});}catch(e){await page.screenshot({path:'docs/controls-load-failure.png'});throw new Error('QA fixture failed: '+errors.join('\n')+' '+await page.locator('body').innerText());}
  const state=()=>page.evaluate(()=>window.fedupQA);
  const command=async value=>{await page.evaluate(v=>window.fedupQACommand=v,value);await page.waitForTimeout(250);};
  const cdp=await context.newCDPSession(page);
  let points=[];
  const coords=async(key,dx=0,dy=0)=>{const q=await state(),r=q.regions[key];return {x:(r[0]+r[2]*(.5+dx))*width,y:(r[1]+r[3]*(.5+dy))*height};};
  const down=async(id,key,dx=0,dy=0)=>{points.push({...await coords(key,dx,dy),id});await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:points});};
  const up=async id=>{points=points.filter(p=>p.id!==id);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:points});};
  const move=async(id,key,dx,dy)=>{const position=await coords(key,dx,dy);points=points.map(p=>p.id===id?{...position,id}:p);await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:points});};
  const wait=async(predicate,message)=>{try{await page.waitForFunction(predicate,null,{timeout:16000});}catch(e){throw new Error(message+' '+JSON.stringify(await state()));}};
  for(let i=0;i<5;i++)await command('light_hit');
  if(Math.abs((await state()).energy-.7)>.001||(await state()).on_foot)throw new Error('Five light bumps should preserve energy and cargo');
  await command('energy_reset');
  await command('camera');
  if(touch){
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:71,x:width*.5,y:height*.5}]});
   await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{id:71,x:width*.6,y:height*.56}]});
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  }else{
   await page.mouse.move(width*.5,height*.5);await page.mouse.down();await page.mouse.move(width*.6,height*.56,{steps:6});await page.mouse.up();
  }
  await wait(()=>Math.abs(window.fedupQA.camera_yaw)>.2&&window.fedupQA.camera_pitch>.05,'Driving orbit/tilt failed');
  await page.screenshot({path:`docs/controls-truck-orbit-${width}x${height}.png`});
  if(touch){await down(72,'camera');await page.waitForTimeout(750);await up(72);}else await page.keyboard.press('g');
  await wait(()=>window.fedupQA.camera_yaw===0&&window.fedupQA.camera_pitch===0,'Driving camera recenter failed');
  await command('ui_recovered');
  if((await state()).recovery_visible)throw new Error('Recovered truck retains the historical-flip overlay');
  await page.screenshot({path:`docs/controls-no-overlay-${width}x${height}.png`});
  await command('ui_recovery');
  const card=(await state()).recovery_rect;
  if(!(await state()).recovery_visible||card[2]*card[3]>.1||card[1]+card[3]>1)throw new Error('Recovery prompt is oversized or missing');
  await page.screenshot({path:`docs/controls-compact-recovery-${width}x${height}.png`});
  await command('ui_clear');await command('ui_message');
  await wait(()=>window.fedupQA.message.includes('12 PACKAGES LEFT'),'Compact mission count missing');
  await page.screenshot({path:`docs/controls-message-${width}x${height}.png`});
  await page.waitForTimeout(800);const remaining=(await state()).notification_time;await command('ui_message');
  if((await state()).notification_time>remaining+.1)throw new Error('Repeated message refreshed its lifetime');
  await wait(()=>window.fedupQA.notification_time===0,'Gameplay notification lingers');
  await command('ui_clear');
  if(touch){
   await down(1,'gas');await page.waitForTimeout(900);
   await down(2,'stick',.25,0);await move(2,'stick',0,.36);
   await wait(()=>window.fedupQA.speed< -1,'Held gas plus reverse stick failed');
   await up(2);await page.waitForTimeout(400);
   if((await state()).speed>=-1)throw new Error('Releasing stick lost selected reverse');
   await page.screenshot({path:`docs/controls-reverse-${width}x${height}.png`});await up(1);
   await down(3,'gear');await up(3);
   await down(4,'gas');await wait(()=>window.fedupQA.speed>1,'Forward gear failed');await up(4);
  }else{
   await page.keyboard.down('s');await wait(()=>window.fedupQA.speed< -1,'Desktop reverse failed');await page.keyboard.up('s');
  }
  await command('spill');await wait(()=>window.fedupQA.on_foot,'Spill did not enable walking');
  if((await state()).energy!==0)throw new Error('Energy-depleting impacts did not empty energy bar');
  if(touch)await down(5,'stick',0,-.36);else await page.keyboard.down('w');
  await wait(()=>window.fedupQA.collected>=1,'Walk-over contact did not collect');
  await page.screenshot({path:`docs/controls-auto-pickup-${width}x${height}.png`});
  await wait(()=>window.fedupQA.collected===12&&window.fedupQA.restored,'Walking route did not collect the full load');
  if(touch)await up(5);else await page.keyboard.up('w');
  const q=await state();
  if(!q.hands_empty||q.distance_to_truck<20)throw new Error('Pickup required carrying/returning to the truck');
  if(q.energy!==1)throw new Error('Recovered truck did not restore energy bar');
  if(q.cars!==30||q.citizens!==48)throw new Error('City population missing');
  if(q.build!==await page.evaluate(()=>document.documentElement.dataset.build))throw new Error('Loader/game build mismatch');
  await page.screenshot({path:`docs/controls-collected-${width}x${height}.png`});
  await command('city');await page.waitForTimeout(1200);
  await page.screenshot({path:`docs/controls-city-${width}x${height}.png`});
  const performance=await page.evaluate(()=>new Promise(resolve=>{let last;const times=[];function sample(t){if(last)times.push(t-last);last=t;if(times.length===120){times.sort((a,b)=>a-b);resolve({fps:120000/times.reduce((a,b)=>a+b,0),p95_ms:times[113]});}else requestAnimationFrame(sample);}requestAnimationFrame(sample);}));
  if(errors.length)throw new Error(errors.join('\n'));
  const city=await state();
  results.push({width,height,touch,dpr,build:q.build,collected:q.collected,distance:q.distance_to_truck,performance,physics_ms:city.physics_ms,process_ms:city.process_ms,draw_calls:city.draw_calls,primitives:city.primitives,active_citizens:city.active_citizens,errors});
  console.log(`PASS ${width}x${height}: compact/expiring prompts, driving camera gestures, reverse, twelve distant pickups`,performance);
  await context.close();
  await browser.close();browser=null;
 }
 fs.writeFileSync('docs/controls-smoke.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results,null,2));
 }finally{if(browser)await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
