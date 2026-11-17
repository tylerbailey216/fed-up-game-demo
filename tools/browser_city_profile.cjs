const {chromium}=require('./webqa/node_modules/playwright');
const fs=require('fs');
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl']});
 try{
 const page=await browser.newPage({viewport:{width:844,height:390},hasTouch:true,deviceScaleFactor:2});
 const errors=[],samples=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'){errors.push(m.text());console.error(m.text());}});
 const base=process.argv[2]||'http://127.0.0.1:8765/';
 await page.goto(base+(base.includes('?')?'&':'?')+'qa=controls');
 await page.waitForFunction(()=>window.fedupQA,null,{timeout:90000});
 const renderer=await page.evaluate(()=>{const gl=document.querySelector('canvas').getContext('webgl2'),info=gl.getExtension('WEBGL_debug_renderer_info');return info?gl.getParameter(info.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER);});
 console.log('renderer',renderer);
 await page.keyboard.press('x');await page.waitForTimeout(300);
 await page.evaluate(()=>window.fedupQACommand='city');await page.waitForTimeout(8000);
 if(errors.length)throw new Error(errors.join('\n'));
 const commands=process.argv.includes('--audio')?['baseline','quiet_audio','settled_silent','restore_audio','settled_audio']:process.argv.includes('--steady')?['baseline','settled_1','settled_2','settled_3','settled_4']:process.argv.includes('--gpu')?['baseline','no_msaa','half_resolution','full_resolution','restore_msaa']:['baseline','quiet_camera','hide_hud','hide_world','quiet_citizens','quiet_traffic','quiet_audio'];
 for(const command of commands){
  if(command.startsWith('settled'))await page.waitForTimeout(5000);
  else if(command!=='baseline'){await page.evaluate(v=>window.fedupQACommand=v,command);await page.waitForTimeout(2000);}
  const timing=await page.evaluate(()=>new Promise(resolve=>{let last;const times=[];function sample(t){if(last)times.push(t-last);last=t;if(times.length===90){times.sort((a,b)=>a-b);resolve({fps:90000/times.reduce((a,b)=>a+b,0),p95_ms:times[85],canvas:[document.querySelector('canvas').width,document.querySelector('canvas').height],engine:window.fedupQA});}else requestAnimationFrame(sample);}requestAnimationFrame(sample);}));
  samples.push({command,...timing});
  console.log(command,JSON.stringify(timing));
  if(command==='baseline')await page.screenshot({path:'docs/city-profile-normal.png'});
  if(process.argv.includes('--probe'))break;
 }
 await page.screenshot({path:'docs/city-profile.png'});
 fs.writeFileSync('docs/city-profile-smoke.json',JSON.stringify({at:new Date().toISOString(),url:page.url(),renderer,cumulative:true,samples,errors},null,2));
 if(errors.length)throw new Error(errors.join('\n'));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
