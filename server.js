import http from 'node:http';import fs from 'node:fs';import path from 'node:path';
import {Readable} from 'node:stream';import worker from './worker.js';
const root=process.cwd(),port=3000,key=process.env.DEEPSEEK_API_KEY;
const assets=new Set(['index.html','privacy.html','app.js','location-ui.js','photo-gps.js','styles.css','sw.js','icon.png','manifest.json']);
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.png':'image/png','.json':'application/json'};
const server=http.createServer(async(req,res)=>{
const url=new URL(req.url,'http://localhost');
if(url.pathname.startsWith('/api/')){
try{const request=new Request(`http://${req.headers.host}${req.url}`,{method:req.method,headers:req.headers,...(['GET','HEAD'].includes(req.method)?{}:{body:Readable.toWeb(req),duplex:'half'})});const response=await worker.fetch(request,{DEEPSEEK_API_KEY:key,GOOGLE_VISION_API_KEY:process.env.GOOGLE_VISION_API_KEY});res.writeHead(response.status,Object.fromEntries(response.headers));return res.end(await response.text())}catch{res.writeHead(500,{'Content-Type':'application/json'});return res.end(JSON.stringify({error:'서버 요청 처리에 실패했습니다.'}))}}
if(!['GET','HEAD'].includes(req.method)){res.writeHead(405,{Allow:'GET, HEAD'});return res.end()}
const name=url.pathname==='/'?'index.html':url.pathname.slice(1);
if(!assets.has(name)){res.writeHead(404);return res.end('Not found')}
res.writeHead(200,{'Content-Type':mime[path.extname(name)]||'application/octet-stream','X-Content-Type-Options':'nosniff'});
if(req.method==='HEAD')return res.end();fs.createReadStream(path.join(root,name)).pipe(res);
});server.listen(port,()=>console.log(`TripTail: http://localhost:${port}`));
