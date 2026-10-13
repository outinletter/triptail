import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';

test('local server serves only public assets and handles queries/HEAD',async()=>{
  const server=spawn(process.execPath,['server.js'],{cwd:new URL('../',import.meta.url),stdio:['ignore','pipe','pipe']});
  try {
    await new Promise((resolve,reject)=>{server.stdout.once('data',resolve);server.once('error',reject);server.once('exit',code=>reject(Error(`Server exited ${code}`)))});
    for(const file of ['/.git/config','/server.js','/worker.js','/package.json','/.env','/ios/TripTail/Info.plist'])assert.equal((await fetch(`http://localhost:3000${file}`)).status,404);
    const asset=await fetch('http://localhost:3000/app.js?v=4');assert.equal(asset.status,200);assert.match(asset.headers.get('Content-Type'),/javascript/);
    const head=await fetch('http://localhost:3000/',{method:'HEAD'});assert.equal(head.status,200);assert.equal(await head.text(),'');
    assert.equal((await fetch('http://localhost:3000/',{method:'POST'})).status,405);
  } finally { server.kill(); }
});
