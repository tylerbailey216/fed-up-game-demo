// Actual WebAssembly gameplay assertions through browser keyboard/touch input.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl']});
 const results=[];
 try{
 for(const [width,height,touch,dpr] of [[360,640,true,2],[844,390,true,2],[768,1024,true,1],[1280,720,false,1]]){
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
  if((await state()).energy!==0)throw new Error('Third crash did not empty energy bar');
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
  console.log(`PASS ${width}x${height}: reverse, twelve distant walk-over pickups, populated city`,performance);
  await context.close();
 }
 fs.writeFileSync('docs/controls-smoke.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results,null,2));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
