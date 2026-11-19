// Real WebAssembly controls and full delivery/recovery/replay on each layout.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
(async()=>{
 const results=[];
 for(const [width,height,touch] of [[360,640,true],[844,390,true],[768,1024,true],[1280,720,false]]){
  const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl']});
  try{
   const context=await browser.newContext({viewport:{width,height},hasTouch:touch});
   const page=await context.newPage();const errors=[];
   page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   await page.goto((process.argv[2]||'http://127.0.0.1:8766/')+'?qa=arcade');
   await page.waitForFunction(()=>window.fedupQA,null,{timeout:90000});
   await page.waitForTimeout(500); // Let the loading artwork finish its fade.
   const state=()=>page.evaluate(()=>window.fedupQA);
   const command=async c=>{await page.evaluate(v=>window.fedupQACommand=v,c);await page.waitForTimeout(350);};
   const wait=async(fn,label)=>{try{await page.waitForFunction(fn,null,{timeout:18000});}catch(e){await page.screenshot({path:`docs/arcade-failure-${width}x${height}.png`});throw Error(label+' '+JSON.stringify(await state()));}};
   const check=(ok,label)=>{if(!ok)throw Error(label);};
   const cdp=await context.newCDPSession(page);let points=[];
   const down=async(id,key,dy=0)=>{const r=(await state()).regions[key];points.push({id,x:(r[0]+r[2]*.5)*width,y:(r[1]+r[3]*(.5+dy))*height});await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:points});};
   const up=async id=>{points=points.filter(p=>p.id!==id);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:points});};
   check((await state()).arcade&&(await state()).cars===10&&(await state()).citizens===16,'Compact population missing');
   const bearing=(await state()).view_rotation;
   const fixedAngle=async label=>{
    const current=(await state()).view_rotation;
    check(Array.isArray(bearing)&&bearing.length===3&&Array.isArray(current)&&current.length===3&&current.every((angle,i)=>Math.abs(Math.atan2(Math.sin(angle-bearing[i]),Math.cos(angle-bearing[i])))<.001),label+' '+JSON.stringify({bearing,current}));
   };
   await page.screenshot({path:`docs/arcade-start-${width}x${height}.png`});
   // Measure the populated frame before isolating deterministic mission checks.
   const performance=await page.evaluate(()=>new Promise(resolve=>{let last;const times=[];function sample(t){if(last)times.push(t-last);last=t;if(times.length===90){times.sort((a,b)=>a-b);resolve({fps:90000/times.reduce((a,b)=>a+b,0),p95_ms:times[85]});}else requestAnimationFrame(sample);}requestAnimationFrame(sample);}));
   await command('quiet');await command('drive');
   if(touch){
    await down(1,'gas');await wait(()=>window.fedupQA.speed>1,'Touch gas');
    // A real second finger crosses clear world space while gas stays held.
    points.push({id:3,x:width*.43,y:height*.42});await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:points});
    const worldFinger=points.find(point=>point.id===3);worldFinger.x=width*.65;worldFinger.y=height*.52;
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:points});await page.waitForTimeout(250);await up(3);await page.waitForTimeout(250);
    await fixedAngle('Touch world swipe changed fixed camera');check((await state()).speed>1,'World swipe stole held gas');
    await down(2,'stick',.36);await wait(()=>window.fedupQA.speed< -1,'Held-gas reverse');await up(2);await up(1);
   }else{
    await page.keyboard.down('w');await wait(()=>window.fedupQA.speed>1,'Keyboard gas');
    for(const button of ['left','right']){await page.mouse.move(width*.45,height*.42);await page.mouse.down({button});await page.mouse.move(width*.65,height*.54,{steps:5});await page.mouse.up({button});}
    await page.mouse.wheel(0,250);await page.mouse.wheel(0,-250);await page.waitForTimeout(350);await fixedAngle('Mouse drag or wheel changed fixed camera');
    await page.keyboard.up('w');await page.keyboard.down('s');await wait(()=>window.fedupQA.speed< -1,'Keyboard reverse');await page.keyboard.up('s');
   }
   await command('park');
   check((await state()).view_preset===0,'Initial fixed camera preset');
   if(touch){await down(8,'camera');await up(8);}else await page.keyboard.press('c');
   await wait(()=>window.fedupQA.view_preset===1,'VIEW did not select overview');await fixedAngle('Overview rotated fixed camera');
   if(touch){await down(8,'camera');await page.waitForTimeout(700);await up(8);}else await page.keyboard.press('g');
   await wait(()=>window.fedupQA.view_preset===0,'Hold VIEW / G did not restore default');await fixedAngle('Recenter rotated fixed camera');
   await page.screenshot({path:`docs/fixed-camera-drive-${width}x${height}.png`});
   await command('park');await command('bay');await page.waitForTimeout(1500);check(!(await state()).complete,'Early bay skipped route');
   await command('wrong_gate');check((await state()).route===0,'Out-of-order gate counted');
   for(let gate=1;gate<=4;gate++){await command('gate');await page.waitForFunction(expected=>window.fedupQA.route===expected,gate,{timeout:6000});}
   await command('bay');await wait(()=>window.fedupQA.complete,'Clean delivery');check((await state()).spawned===0,'Clean cargo spilled');
   await page.screenshot({path:`docs/arcade-report-${width}x${height}.png`});
   const replay=async()=>{
    if(touch){await down(9,'replay');await up(9);}else{const r=(await state()).regions.replay;await page.mouse.click((r[0]+r[2]/2)*width,(r[1]+r[3]/2)*height);}
    await wait(()=>!window.fedupQA.complete&&window.fedupQA.route===0,'Report replay');
   };
   await replay();await command('spill');await wait(()=>window.fedupQA.on_foot,'Disabled exit');
   check((await state()).spawned===12&&(await state()).energy===0,'Fixed manifest spill failed');await command('line');
   if(touch)await down(4,'stick',-.36);else await page.keyboard.down('w');
   await wait(()=>window.fedupQA.collected===12&&window.fedupQA.restored,'Automatic walk-over collection');
   if(touch)await up(4);else await page.keyboard.up('w');
   await page.waitForTimeout(250);await fixedAngle('Walking or truck exit changed fixed camera');
   await page.screenshot({path:`docs/arcade-collected-${width}x${height}.png`});
   await page.screenshot({path:`docs/fixed-camera-foot-${width}x${height}.png`});
   await command('enter');check(!(await state()).on_foot,'Re-entry failed');await fixedAngle('Truck re-entry changed fixed camera');
   for(let gate=1;gate<=4;gate++){await command('gate');await page.waitForFunction(expected=>window.fedupQA.route===expected,gate,{timeout:6000});}
   await command('bay');await wait(()=>window.fedupQA.complete,'Recovered delivery');await replay();
   check((await state()).spawned===0&&(await state()).collected===0&&(await state()).energy===1,'Recovery replay reset');
   if(errors.length)throw Error(errors.join('\n'));
   await fixedAngle('Replay changed fixed camera');
   results.push({width,height,touch,performance,fixed_camera:{view_rotation:(await state()).view_rotation,preset:(await state()).view_preset,cutaways:(await state()).cutaways},draw_calls:(await state()).draw_calls,physics_ms:(await state()).physics_ms,errors});
   console.log(`PASS ${width}x${height}: fixed camera, VIEW/recenter, reverse, clean route, twelve walk-over pickups, recovery, report replay`,performance);
  }finally{await browser.close();}
 }
 fs.writeFileSync('docs/arcade-smoke.json',JSON.stringify(results,null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});
