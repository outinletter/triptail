import http from 'node:http';import fs from 'node:fs';import path from 'node:path';
import {Readable} from 'node:stream';import worker from './worker.js';
const root=process.cwd(),port=3000,key=process.env.DEEPSEEK_API_KEY;const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.png':'image/png','.json':'application/json'};
const server=http.createServer(async(req,res)=>{
if(req.url.startsWith('/api/')){
try{const request=new Request(`http://${req.headers.host}${req.url}`,{method:req.method,headers:req.headers,...(['GET','HEAD'].includes(req.method)?{}:{body:Readable.toWeb(req),duplex:'half'})});const response=await worker.fetch(request,{DEEPSEEK_API_KEY:key,GOOGLE_VISION_API_KEY:process.env.GOOGLE_VISION_API_KEY});res.writeHead(response.status,Object.fromEntries(response.headers));return res.end(await response.text())}catch{res.writeHead(500,{'Content-Type':'application/json'});return res.end(JSON.stringify({error:'서버 요청 처리에 실패했습니다.'}))}}
const file=path.join(root,req.url==='/'?'index.html':req.url);if(!file.startsWith(root)||!fs.existsSync(file)){res.writeHead(404);return res.end('Not found')}res.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream'});fs.createReadStream(file).pipe(res)});server.listen(port,()=>console.log(`TripTail: http://localhost:${port}`));
