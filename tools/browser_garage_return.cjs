// Reproduce the completed-semi -> report -> garage path, including retina phones.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
(async()=>{
 const requested=process.argv.find(a=>a.startsWith('--layout='))?.slice(9);const results=[];
 for(const [width,height,dpr] of [[390,680,3],[844,390,3],[768,1024,2],[1280,720,1]].filter(([w,h])=>!requested||requested===`${w}x${h}`)){
  const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl']});
  try{
   const page=await browser.newPage({viewport:{width,height},hasTouch:true,deviceScaleFactor:dpr});const errors=[];
   page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
   await page.goto((process.argv[2]||'http://127.0.0.1:8766/')+'?qa=fleet');
   await page.waitForFunction(()=>window.fedupFleet?.garage,null,{timeout:120000});await page.locator('#loading').waitFor({state:'hidden',timeout:30000});
   const state=()=>page.evaluate(()=>window.fedupFleet);
   const command=async value=>{await page.evaluate(v=>window.fedupFleetCommand=v,value);await page.waitForTimeout(400);};
   const tap=async point=>{const q=await state();const viewport=page.viewportSize();await page.touchscreen.tap(point[0]*viewport.width/q.viewport[0],point[1]*viewport.height/q.viewport[1]);await page.waitForTimeout(400);};
   const initial=await state();console.log('INITIAL',width,height,dpr,JSON.stringify(initial));
   if(initial.actions.some(r=>r[3]*height/initial.viewport[1]<43))throw Error('Retina touch target below 44 CSS pixels');
   await command('unlock');let q=await state();await tap([q.cards[1].x,q.cards[1].y]);await tap((await state()).confirm);
   await page.waitForFunction(()=>window.fedupFleet?.vehicle==='semi'&&window.fedupFleet.driving,null,{timeout:30000});
   await page.waitForTimeout(800);await command('complete');await page.waitForFunction(()=>window.fedupFleet.complete);
   await page.waitForTimeout(700);await tap((await state()).report_garage);await page.waitForFunction(()=>window.fedupFleet.garage);
   await page.waitForTimeout(500);q=await state();console.log('RETURNED',JSON.stringify(q));
   await page.screenshot({path:`docs/garage-return-${width}x${height}.png`});
   if(q.cards[0].rect[3]<initial.cards[0].rect[3]*.9)throw Error('Returning from Long Haul shrank vehicle illustrations');
   for(let cycle=0;cycle<2;cycle++){
    await command('resume');await page.waitForTimeout(300);await tap((await state()).report_garage);
    await page.waitForFunction(()=>window.fedupFleet.garage);await page.waitForTimeout(300);q=await state();
    if(q.card_min<initial.card_min*.9||q.deliveries!==6||q.vehicle!=='semi')throw Error('Repeated garage return changed layout or progress');
   }
   for(const viewport of [{width:height,height:width},{width,height}]){
    await page.setViewportSize(viewport);await page.waitForTimeout(700);q=await state();
    if(q.cards.some(c=>(c.rect[3]-104)*viewport.height/q.viewport[1]<30))throw Error('Artwork collapsed after rotation');
    if(q.actions.some(r=>r[1]+r[3]>q.viewport[1]+1))throw Error('Actions clipped after rotation');
    if(q.actions.some(r=>r[3]*viewport.height/q.viewport[1]<43))throw Error('Touch target shrank after rotation');
   }
   if(errors.length)throw Error(errors.join('\n'));results.push({width,height,dpr,passed:true});console.log(`PASS GARAGE RETURN ${width}x${height} DPR ${dpr}`);
  }finally{await browser.close();}
 }
 fs.writeFileSync('docs/garage-return-smoke.json',JSON.stringify(results,null,2));
})().catch(e=>{console.error(e);process.exit(1)});
