// Real browser keyboard/touch acceleration on shipping grass and asphalt.
const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
(async()=>{
 const results=[];let browser;
 try{
  const layouts=process.argv.includes('--profile')?[[1280,720,false]]:[[360,640,true],[844,390,true],[1280,720,false]];
  for(const [width,height,touch] of layouts){
   browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl']});
   const context=await browser.newContext({viewport:{width,height},hasTouch:touch,deviceScaleFactor:1});
   const page=await context.newPage(),errors=[];
   page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   await page.goto((process.argv[2]||'http://127.0.0.1:8766/')+'?qa=controls');
   await page.waitForFunction(()=>window.fedupQA,null,{timeout:90000});
   const state=()=>page.evaluate(()=>window.fedupQA);
   const timing=()=>page.evaluate(()=>new Promise(resolve=>{let last;const frames=[];function tick(t){if(last)frames.push(t-last);last=t;if(frames.length===90){frames.sort((a,b)=>a-b);resolve({fps:90000/frames.reduce((a,b)=>a+b,0),p95_ms:frames[85]});}else requestAnimationFrame(tick);}requestAnimationFrame(tick);}));
   const command=async value=>{await page.evaluate(v=>window.fedupQACommand=v,value);await page.waitForFunction(()=>!window.fedupQACommand,null,{timeout:10000});await page.waitForTimeout(350);};
   const cdp=await context.newCDPSession(page);
   const gas=async down=>{
    if(touch){const q=await state(),r=q.regions.gas;await cdp.send('Input.dispatchTouchEvent',{type:down?'touchStart':'touchEnd',touchPoints:down?[{id:1,x:(r[0]+r[2]/2)*width,y:(r[1]+r[3]/2)*height}]:[]});}
    else if(down)await page.keyboard.down('w');else await page.keyboard.up('w');
   };
   await command('terrain_road');let q=await state(),before=q.terrain_emitted;
   await gas(true);await page.waitForTimeout(1600);await gas(false);q=await state();
   if(q.terrain_emitted!==before||q.terrain_wheels.some(v=>v!=='asphalt'))throw new Error('Road dust/leak '+JSON.stringify(q));
   await command('terrain_grass');before=(await state()).terrain_emitted;
   await gas(true);
   await page.waitForFunction(n=>window.fedupQA.terrain_emitted>n+35,before,{timeout:18000});
   q=await state();
   if(q.terrain_chips<1||q.terrain_dust<1||q.terrain_wheels.some(v=>v!=='grass')||q.terrain_live>q.terrain_limit)throw new Error('Grass spray invalid '+JSON.stringify(q));
   await page.screenshot({path:`docs/terrain-browser-${width}x${height}.png`});
   const active=await timing();await command('terrain_fx_off');const hidden=await timing();await command('terrain_fx_on');
   const active_again=process.argv.includes('--profile')?await timing():null;
   await gas(false);
   results.push({width,height,touch,build:q.build,emitted:q.terrain_emitted-before,live:q.terrain_live,capacity:q.terrain_limit,physics_ms:q.physics_ms,draw_calls:q.draw_calls,active,hidden,active_again,errors});
   await command('terrain_road');q=await state();
   if(q.terrain_live!==0)throw new Error('Reset left terrain particles behind');
   if(errors.length)throw new Error(errors.join('\n'));
   console.log('PASS',JSON.stringify(results.at(-1)));
   await context.close();await browser.close();browser=null;
  }
  fs.writeFileSync(process.argv.includes('--profile')?'docs/terrain-profile-smoke.json':'docs/terrain-smoke.json',JSON.stringify(results,null,2));
 }finally{if(browser)await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
