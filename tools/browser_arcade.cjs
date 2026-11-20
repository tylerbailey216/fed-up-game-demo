// Real WebAssembly direction controls and an uninterrupted delivery lap on four layouts.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
(async()=>{
 const results=[];
 const only=(process.argv.find(arg=>arg.startsWith('--layout='))||'').slice(9);
 for(const [width,height,touch] of [[360,640,true],[844,390,true],[768,1024,true],[1280,720,false]].filter(([w,h])=>!only||`${w}x${h}`===only)){
  const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl']});
  try{
   const context=await browser.newContext({viewport:{width,height},hasTouch:touch});
   const page=await context.newPage();const errors=[];
   page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   await page.goto((process.argv[2]||'http://127.0.0.1:8766/')+'?qa=arcade');
   await page.waitForFunction(()=>window.fedupQA,null,{timeout:90000});
   await page.waitForTimeout(500);
   const state=()=>page.evaluate(()=>window.fedupQA);
   const command=async c=>{await page.evaluate(v=>window.fedupQACommand=v,c);await page.waitForTimeout(350);};
   const fail=async label=>{await page.screenshot({path:`docs/arcade-failure-${width}x${height}.png`});throw Error(label+' '+JSON.stringify(await state()));};
   const wait=async(fn,label,timeout=18000)=>{try{await page.waitForFunction(fn,null,{timeout});}catch(e){await fail(label);}};
   const check=(ok,label)=>{if(!ok)throw Error(label);};
   const cdp=await context.newCDPSession(page);let points=[];const keyboardHeld=new Set();
   const down=async(id,key)=>{const r=(await state()).regions[key];points.push({id,x:(r[0]+r[2]*.5)*width,y:(r[1]+r[3]*.5)*height});await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:points});};
   const up=async id=>{points=points.filter(p=>p.id!==id);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:points});};
   const direction=async(x,y)=>{
    const length=Math.hypot(x,y);if(length>1){x/=length;y/=length;}
    if(touch){
     const r=(await state()).regions.stick;const reach=r[2]*width*.4;
     const value={id:1,x:(r[0]+r[2]*.5)*width+x*reach,y:(r[1]+r[3]*.5)*height+y*reach};
     const previous=points.find(p=>p.id===1);
     if(previous){Object.assign(previous,value);await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:points});}
     else{points.push(value);await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:points});}
    }else{
     const desired=new Set();if(x>.22)desired.add('d');if(x<-.22)desired.add('a');if(y>.22)desired.add('s');if(y<-.22)desired.add('w');
     for(const key of [...keyboardHeld])if(!desired.has(key)){await page.keyboard.up(key);keyboardHeld.delete(key);}
     for(const key of desired)if(!keyboardHeld.has(key)){await page.keyboard.down(key);keyboardHeld.add(key);}
    }
   };
   const release=async()=>{
    if(points.length){points=[];await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}
    for(const key of [...keyboardHeld]){await page.keyboard.up(key);keyboardHeld.delete(key);}
   };
   const initial=await state();check(initial.arcade&&initial.cars===10&&initial.citizens===16,'Compact population missing');
   check(touch? !['gas','brake','gear','hand'].some(key=>key in initial.regions):true,'Simulator controls remain on the Mayhem touchscreen');
   const bearing=initial.view_rotation;
   const fixedAngle=async label=>{
    const current=(await state()).view_rotation;
    check(Array.isArray(bearing)&&bearing.length===3&&Array.isArray(current)&&current.length===3&&current.every((angle,i)=>Math.abs(Math.atan2(Math.sin(angle-bearing[i]),Math.cos(angle-bearing[i])))<.001),label+' '+JSON.stringify({bearing,current}));
   };
   await page.screenshot({path:`docs/arcade-start-${width}x${height}.png`});
   const performance=await page.evaluate(()=>new Promise(resolve=>{let last;const times=[];function sample(t){if(last)times.push(t-last);last=t;if(times.length===90){times.sort((a,b)=>a-b);resolve({fps:90000/times.reduce((a,b)=>a+b,0),p95_ms:times[85]});}else requestAnimationFrame(sample);}requestAnimationFrame(sample);}));
   await command('quiet');await command('drive');await direction(1,0);
   await wait(()=>window.fedupQA.velocity[0]>1,'Direction alone did not autoaccelerate right');
   if(touch){
    points.push({id:3,x:width*.43,y:height*.42});await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:points});
    const worldFinger=points.find(point=>point.id===3);worldFinger.x=width*.65;worldFinger.y=height*.52;
    // Keep both contacts down through the assertion, then release them together
    // below. Partial touchEnd point lists differ across Chrome injection paths.
    await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:points});await page.waitForTimeout(500);
    const heldDirection=await state();
    if(heldDirection.move_input[0]<.9||heldDirection.stick[0]<.9||!Object.values(heldDirection.fingers).includes('stick'))await fail('World swipe canceled the held directional input');
   }else{
    for(const button of ['left','right']){await page.mouse.move(width*.45,height*.42);await page.mouse.down({button});await page.mouse.move(width*.65,height*.54,{steps:5});await page.mouse.up({button});}
    await page.mouse.wheel(0,250);await page.mouse.wheel(0,-250);await page.waitForTimeout(350);
   }
   await fixedAngle('World gestures changed the fixed camera');
   const brakeAt=(await state()).truck;await release();
   await wait(()=>window.fedupQA.speed<.15&&Math.hypot(...window.fedupQA.velocity)<.25,'Release did not brake the truck',6000);
   const stopped=(await state()).truck;check(Math.hypot(stopped[0]-brakeAt[0],stopped[2]-brakeAt[2])<6,'Release coasted too far');
   await direction(0,-1);await wait(()=>window.fedupQA.velocity[1]<-2,'UP did not request screen-up travel');
   await direction(0,1);await wait(()=>window.fedupQA.velocity[1]>2&&Math.cos(window.fedupQA.heading)<-.8,'DOWN did not perform a forward U-turn');
   check((await state()).speed>0,'Arcade DOWN incorrectly engaged simulator reverse');await release();
   await wait(()=>window.fedupQA.speed<.15,'U-turn release did not stop');
   await command('park');check((await state()).view_preset===0,'Initial fixed camera preset');
   if(touch){await down(8,'camera');await up(8);}else await page.keyboard.press('c');
   await wait(()=>window.fedupQA.view_preset===1,'VIEW did not select overview');await fixedAngle('Overview rotated fixed camera');
   if(touch){await down(8,'camera');await page.waitForTimeout(700);await up(8);}else await page.keyboard.press('g');
   await wait(()=>window.fedupQA.view_preset===0,'VIEW release / G did not restore play distance');await fixedAngle('Distance change rotated fixed camera');
   await page.screenshot({path:`docs/fixed-camera-drive-${width}x${height}.png`});
   // Negative gate cases remain separate from the real-input acceptance lap.
   await command('bay');await page.waitForTimeout(1500);check(!(await state()).complete,'Early bay skipped route');
   await command('wrong_gate');check((await state()).route===0,'Out-of-order gate counted');
   await command('lap');
   const lapStart=await state();const corners=lapStart.lap_corners;const targets=[...corners,lapStart.bay];
   check(corners.length===4&&Array.isArray(lapStart.truck),'Actual-lap fixture missing');
   const visited=corners.map(()=>false);const deadline=Date.now()+90000;let previous=lapStart.truck,distance=0,roadGap=0;
   for(let index=0;index<targets.length;index++){
    const target=targets[index];let arrived=false;
    while(Date.now()<deadline){
     const current=await state();const truck=current.truck;const dx=target[0]-truck[0],dz=target[1]-truck[2];
     const gap=Math.hypot(dx,dz);const radius=index===targets.length-1?2.5:6;
     distance+=Math.hypot(truck[0]-previous[0],truck[2]-previous[2]);previous=truck;
     roadGap=Math.max(roadGap,Math.min(Math.abs(truck[0]),Math.abs(truck[2]),Math.abs(Math.abs(truck[0])-46),Math.abs(Math.abs(truck[2])-51.5)));
     for(let corner=0;corner<corners.length;corner++)if(Math.hypot(truck[0]-corners[corner][0],truck[2]-corners[corner][1])<10)visited[corner]=true;
     if(current.on_foot||current.energy===0)await fail('Actual lap unexpectedly disabled truck');
     if(gap<radius){arrived=true;break;}
     await direction(dx/gap,dz/gap);await page.waitForTimeout(120);
    }
    if(!arrived)await fail(`Actual controls could not reach perimeter junction ${index+1}`);
   }
   await release();await wait(()=>window.fedupQA.complete,'Actual-input clean delivery did not stop at collection bay');
   const lapFinish=await state();
   check(visited.every(Boolean)&&distance>350&&roadGap<8.5,'Actual lap missed intersections or left the roads '+JSON.stringify({visited,distance,roadGap}));
   check(lapFinish.crashes===lapStart.crashes&&lapFinish.resets===lapStart.resets&&lapFinish.offroad===lapStart.offroad,'Actual lap required collision/recovery/reset');
   check(lapFinish.route===lapFinish.route_total&&lapFinish.spawned===0,'Actual route did not deliver the original load');
   await fixedAngle('Actual perimeter lap changed camera bearing');
   await page.screenshot({path:`docs/arcade-actual-lap-${width}x${height}.png`});await page.screenshot({path:`docs/arcade-report-${width}x${height}.png`});
   const replay=async()=>{
    if(touch){await down(9,'replay');await up(9);}else{const r=(await state()).regions.replay;await page.mouse.click((r[0]+r[2]/2)*width,(r[1]+r[3]/2)*height);}
    await wait(()=>!window.fedupQA.complete&&window.fedupQA.route===0,'Report replay');
   };
   await replay();await command('spill');await wait(()=>window.fedupQA.on_foot,'Disabled exit');
   check((await state()).spawned===12&&(await state()).energy===0,'Fixed manifest spill failed');await command('line');
   await direction(0,-1);await wait(()=>window.fedupQA.collected===12&&window.fedupQA.restored,'Automatic walk-over collection');await release();
   await page.waitForTimeout(250);await fixedAngle('Walking or truck exit changed fixed camera');
   await page.screenshot({path:`docs/arcade-collected-${width}x${height}.png`});await page.screenshot({path:`docs/fixed-camera-foot-${width}x${height}.png`});
   await command('enter');check(!(await state()).on_foot,'Re-entry failed');await fixedAngle('Truck re-entry changed fixed camera');
   // The clean lap above covers real driving. Isolate repaired-load gating here.
   for(let gate=1;gate<=4;gate++){await command('gate');await page.waitForFunction(expected=>window.fedupQA.route===expected,gate,{timeout:6000});}
   await command('bay');await wait(()=>window.fedupQA.complete,'Recovered delivery');await replay();
   const final=await state();check(final.spawned===0&&final.collected===0&&final.energy===1,'Recovery replay reset');
   if(errors.length)throw Error(errors.join('\n'));await fixedAngle('Replay changed fixed camera');
   results.push({width,height,touch,performance,actual_lap:{distance,road_gap:roadGap,corners:visited,crashes:lapFinish.crashes-lapStart.crashes},fixed_camera:{view_rotation:final.view_rotation,preset:final.view_preset,cutaways:final.cutaways},draw_calls:final.draw_calls,physics_ms:final.physics_ms,errors});
   console.log(`PASS ${width}x${height}: directional drive/release/U-turn, fixed views, actual four-corner lap, twelve pickups, recovery and replay`,performance);
  }finally{await browser.close();}
 }
 fs.writeFileSync(only?`docs/arcade-smoke-${only}.json`:'docs/arcade-smoke.json',JSON.stringify(results,null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});
