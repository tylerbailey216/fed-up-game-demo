// Fleet acceptance uses actual card/button taps. Unlock fixtures are origin-local and ephemeral.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
(async()=>{
 const url=process.argv[2]||'http://127.0.0.1:8766/';const results=[];
 const requested=process.argv.find(a=>a.startsWith('--layout='))?.slice(9);
 for(const [width,height,touch] of [[360,640,true],[844,390,true],[768,1024,true],[1280,720,false]].filter(([w,h])=>!requested||requested===`${w}x${h}`)){
  const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl']});
  try{
   const page=await browser.newPage({viewport:{width,height},hasTouch:touch,deviceScaleFactor:1});const errors=[];
   page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|Invalid call|FLEET TEST FAIL/.test(m.text()))errors.push(m.text());});
   await page.goto(url+'?qa=fleet');await page.waitForFunction(()=>window.fedupFleet?.garage,{timeout:120000});
   await page.locator('#loading').waitFor({state:'hidden',timeout:30000});
   const state=()=>page.evaluate(()=>window.fedupFleet);
   const command=async value=>{await page.evaluate(v=>window.fedupFleetCommand=v,value);await page.waitForTimeout(350);};
   const click=async xy=>{const s=await state();const at=[xy[0]*width/s.viewport[0],xy[1]*height/s.viewport[1]];if(touch)await page.touchscreen.tap(...at);else await page.mouse.click(...at);await page.waitForTimeout(300);};
   let s=await state();if(s.cards.filter(c=>c.locked).length!==3)throw Error('Initial locked roster');
   for(const r of s.actions){if(r[1]+r[3]>s.viewport[1]+1||r[3]*height/s.viewport[1]<43)throw Error('Action clipped or smaller than touch target');}
   for(const c of s.cards){const r=c.rect;if(r[0]<0||r[1]<0||r[0]+r[2]>s.viewport[0]+1||r[1]+r[3]>s.viewport[1]+1)throw Error('Card outside viewport');}
   await page.screenshot({path:`docs/fleet-locked-${width}x${height}.png`});
   await click([s.cards[1].x,s.cards[1].y]);if(!(await state()).disabled)throw Error('Locked vehicle can depart');
   await command('unlock');await command('unlock');s=await state();if(s.deliveries!==5||s.cards.some(c=>c.locked))throw Error('Receipt/unlock mismatch');
   await page.screenshot({path:`docs/fleet-unlocked-${width}x${height}.png`});
   for(const id of ['truck','semi','tank','sleigh','turkey']){
    s=await state();const c=s.cards.find(c=>c.id===id);await click([c.x,c.y]);await click((await state()).confirm);
    await page.waitForFunction(id=>window.fedupFleet?.vehicle===id&&window.fedupFleet.driving&&!window.fedupFleet.garage,id,{timeout:30000});
    await page.waitForTimeout(700);await page.screenshot({path:`docs/fleet-${id}-${width}x${height}.png`});
    s=await state();if(id==='turkey'?(s.legs!==2||s.wheels!==0):s.wheels!==({truck:4,semi:6,tank:12,sleigh:4}[id]))throw Error('Missing live wheels or turkey legs');
    await command('review');await page.screenshot({path:`docs/fleet-illustrated-${id}-${width}x${height}.png`});await command('review_end');
    if(id==='sleigh'){
     const y=s.y;if(touch)await click(s.flight_button);else await page.keyboard.press('v');await page.waitForFunction(y=>window.fedupFleet.y>y+2,y,{timeout:10000});
     await page.screenshot({path:`docs/fleet-flight-${width}x${height}.png`});
     if(touch)await click((await state()).flight_button);else await page.keyboard.press('v');await page.waitForFunction(y=>window.fedupFleet.y<y+.3,y,{timeout:15000});
    }
    await command('garage');await page.waitForFunction(()=>window.fedupFleet.garage);
   }
   if(errors.length)throw Error(errors.join('\n'));results.push({width,height,touch,passed:true});console.log(`PASS FLEET ${width}x${height}`);
  }finally{await browser.close();}
 }
 fs.writeFileSync('docs/fleet-browser-smoke.json',JSON.stringify(results,null,2));
})().catch(e=>{console.error(e);process.exit(1);});
