// Browser controls plus real drive-through scenery transitions; qa=zen only.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
(async()=>{
 const results=[];
	 const requested=process.argv.find(argument=>argument.startsWith('--layout='))?.split('=')[1];
	 const layouts=[[360,640,true],[844,390,true],[768,1024,true],[1280,720,false]].filter(([width,height])=>!requested||requested===`${width}x${height}`);
	 if(!layouts.length)throw Error('Unknown Zen layout: '+requested);
	 for(const [width,height,touch] of layouts){
  const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl']});
  try{
   const context=await browser.newContext({viewport:{width,height},hasTouch:touch});const page=await context.newPage();const errors=[];
   page.on('pageerror',error=>errors.push(error.message));page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
   await page.goto((process.argv[2]||'http://127.0.0.1:8766/')+'?qa=zen');
   await page.waitForFunction(()=>window.fedupQA?.mode==='zen',null,{timeout:120000});await page.waitForTimeout(500);
   const state=()=>page.evaluate(()=>window.fedupQA);
   const fail=async label=>{await page.screenshot({path:`docs/zen-failure-${width}x${height}.png`});throw Error(label+' '+JSON.stringify({state:await state(),errors}));};
   const wait=async(fn,label,timeout=20000,arg=null)=>{try{await page.waitForFunction(fn,arg,{timeout});}catch(error){await fail(label);}};
   const check=(value,label)=>{if(!value)throw Error(label);};
   const command=async value=>{await page.evaluate(command=>window.fedupQACommand=command,value);await page.waitForTimeout(400);};
   const cdp=await context.newCDPSession(page);let points=[];
   const down=async(id,key,menu=false)=>{const value=await state();const r=(menu?value.menu_regions:value.regions)[key];points.push({id,x:(r[0]+r[2]*.5)*width,y:(r[1]+r[3]*.5)*height});await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:points});};
   const up=async id=>{points=points.filter(point=>point.id!==id);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:points});};
   const button=async(key,menu=false)=>{if(touch){await down(8,key,menu);await up(8);}else{const value=await state();const r=(menu?value.menu_regions:value.regions)[key];await page.mouse.click((r[0]+r[2]*.5)*width,(r[1]+r[3]*.5)*height);}};
   const pedal=async(key,pressed)=>{if(touch){if(pressed)await down(1,key);else await up(1);}else{const code={gas:'w',brake:'s',hand:'Space'}[key];if(pressed)await page.keyboard.down(code);else await page.keyboard.up(code);}};
   const walking=async(upward,pressed)=>{
    if(touch){
     if(!pressed){await up(1);return;}
     await down(1,'stick');const r=(await state()).regions.stick;const finger=points.find(point=>point.id===1);finger.y+=(upward?-1:1)*r[3]*height*.35;
     await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:points});
    }else{const code=upward?'w':'s';if(pressed)await page.keyboard.down(code);else await page.keyboard.up(code);}
   };
   const initial=await state();check(initial.menu&&initial.menu_start.includes('Zen'),'Zen menu did not expose its start action');
   await page.screenshot({path:`docs/zen-menu-${width}x${height}.png`});await button('start',true);
   await wait(()=>window.fedupQA?.driving&&!window.fedupQA.menu,'Actual menu start did not begin Zen');
   const started=await state();check(started.mode==='zen'&&started.zone==='city'&&started.mission_empty&&started.cars>0&&started.citizens>0,'Zen city population or peaceful state missing');
   await page.screenshot({path:`docs/zen-city-${width}x${height}.png`});
   await command('quiet');await command('prepare');await pedal('gas',true);await wait(()=>window.fedupQA.speed>1,'Zen gas did not accelerate');
   const yaw=(await state()).camera_yaw;
   if(touch){
    points.push({id:7,x:width*.45,y:height*.43});await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:points});
	    const finger=points.find(point=>point.id===7);finger.x=width*.64;finger.y=height*.49;await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:points});await page.waitForTimeout(300);
   }else{
    await page.mouse.move(width*.45,height*.43);await page.mouse.down({button:'right'});await page.mouse.move(width*.64,height*.49,{steps:5});await page.mouse.up({button:'right'});await page.mouse.wheel(0,-100);
   }
   await wait(()=>Math.abs(window.fedupQA.camera_yaw)>0.2,'Zen camera orbit was lost');
	   check((await state()).inputs[0]>0,'Camera interaction released the active gas control');
	   // End both fingers together: partial CDP touchEnd can cancel the other
	   // synthetic pointer on Chromium, obscuring the actual held-input check.
	   if(touch){points=[];await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}else await pedal('gas',false);
   await pedal('brake',true);await wait(()=>window.fedupQA.speed< -1,'Zen brake did not stop then reverse');
   const reverseAt=(await state()).truck;await page.waitForTimeout(650);const reversed=(await state()).truck;
   check(Math.hypot(reversed[0]-reverseAt[0],reversed[2]-reverseAt[2])>.5,'Reverse changed the display without moving the truck');await pedal('brake',false);
   await pedal('hand',true);await wait(()=>Math.abs(window.fedupQA.speed)<.15,'Handbrake did not stop the Zen truck');await pedal('hand',false);
   const previousView=await state();if(touch)await button('camera');else await page.keyboard.press('c');await page.waitForTimeout(300);
   const changedView=await state();check(changedView.cockpit!==previousView.cockpit||changedView.camera_high!==previousView.camera_high,'VIEW did not cycle the simulator camera');
   if(touch)await button('exit');else await page.keyboard.press('x');await wait(()=>window.fedupQA.on_foot,'Zen exit/walk action failed');
   const actorAt=(await state()).actor;await walking(true,true);await page.waitForTimeout(450);await walking(true,false);await page.waitForTimeout(180);
   const walked=(await state()).actor;check(Math.hypot(walked[0]-actorAt[0],walked[2]-actorAt[2])>.2,'Worker did not respond to actual walking input');
   await page.screenshot({path:`docs/zen-foot-${width}x${height}.png`});
   if(!(await state()).can_enter){await walking(false,true);await wait(()=>window.fedupQA.can_enter,'Walk back beside the truck',5000);await walking(false,false);}
   if(touch)await button('exit');else await page.keyboard.press('x');await wait(()=>!window.fedupQA.on_foot,'Zen re-entry incorrectly required packages');
   check((await state()).mission_empty,'Walking created a mandatory mission');
   const transitions=[];
   for(const target of ['motorway','city']){
    await command('approach');await wait(()=>window.fedupQA.approached,'Mapped connection approach was not prepared');
	    await page.waitForTimeout(650); // Publish/settle the mapped road contact before gas.
    const before=await state();check(before.signed_exit< -20,'Connection fixture starts before the signed gateway');
    await pedal('gas',true);
    // From this point to the new scene, only actual gas input moves the truck.
    await wait(zone=>window.fedupQA?.zone===zone&&window.fedupQA?.driving,'Driving through the signed connection did not change scenery',90000,target);
    await pedal('gas',false);await page.waitForTimeout(300);const arrived=await state();
    check(arrived.instance!==before.instance&&arrived.mode==='zen'&&arrived.mission_empty&&arrived.cars>0,'Connection lost Zen state or population');
    check(arrived.fuel>0&&arrived.distance>before.distance,'Drive-through transfer lost vehicle travel state');
    transitions.push({from:before.zone,to:arrived.zone,distance:arrived.distance,fuel:arrived.fuel,cars:arrived.cars,citizens:arrived.citizens});
    await page.screenshot({path:`docs/zen-${target}-arrival-${width}x${height}.png`});
    await pedal('hand',true);await wait(()=>Math.abs(window.fedupQA.speed)<.15,'Stop after scenery transfer');await pedal('hand',false);
   }
   const final=await state();check(final.mode==='zen'&&final.zone==='city'&&final.mission_empty&&!final.complete&&final.spawned===0,'Return drive became a delivery stage');
   if(errors.length)throw Error(errors.join('\n'));
   results.push({width,height,touch,transitions,cars:final.cars,citizens:final.citizens,physics_ms:final.physics_ms,errors});
   console.log(`PASS ZEN ${width}x${height}: actual menu, gas/reverse, orbit, walk/re-entry, city -> motorway -> city`);
  }finally{await browser.close();}
 }
 const previous=requested&&fs.existsSync('docs/zen-smoke.json')?JSON.parse(fs.readFileSync('docs/zen-smoke.json','utf8')):[];
 fs.writeFileSync('docs/zen-smoke.json',JSON.stringify([...previous.filter(old=>!results.some(item=>item.width===old.width&&item.height===old.height)),...results],null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
