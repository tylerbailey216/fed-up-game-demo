// Isolate camera update cost from the same stationary populated render.
const {chromium}=require('./webqa/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl']});
 try{
  const page=await browser.newPage({viewport:{width:844,height:390},hasTouch:true});
  await page.goto((process.argv[2]||'http://127.0.0.1:8766/')+'?qa=arcade');
  await page.waitForFunction(()=>window.fedupQA,null,{timeout:90000});await page.waitForTimeout(2500);
  const renderer=await page.evaluate(()=>{const gl=document.querySelector('canvas').getContext('webgl2');const info=gl.getExtension('WEBGL_debug_renderer_info');return info?gl.getParameter(info.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER);});
  for(const command of ['fixed_resume','fixed_pause','fixed_resume','quiet']){
   await page.evaluate(v=>window.fedupQACommand=v,command);await page.waitForTimeout(600);
   const timing=await page.evaluate(()=>new Promise(resolve=>{let last;const times=[];function sample(t){if(last)times.push(t-last);last=t;if(times.length===60){times.sort((a,b)=>a-b);resolve({fps:60000/times.reduce((a,b)=>a+b,0),p95_ms:times[56],telemetry:window.fedupQA});}else requestAnimationFrame(sample);}requestAnimationFrame(sample);}));
   console.log(JSON.stringify({command,renderer,...timing}));
  }
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
