import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../worker.js';
import {readGps} from '../photo-gps.js';

const image='data:image/jpeg;base64,YQ==';
const request=(path,body)=>new Request(`https://triptail.example/api/${path}`,{method:'POST',body:JSON.stringify(body)});
test('Vision key, validation, candidates, no matches, and per-photo errors',async t=>{
  assert.equal((await worker.fetch(request('landmarks',{images:[image]}),{})).status,503);
  assert.equal((await worker.fetch(request('landmarks',{images:[]}),{GOOGLE_VISION_API_KEY:'mock'})).status,400);
  t.mock.method(globalThis,'fetch',async(url,options)=>{
    assert.equal(url,'https://vision.googleapis.com/v1/images:annotate');
    assert.equal(options.headers['x-goog-api-key'],'mock');
    const payload=JSON.parse(options.body);assert.equal(payload.requests[0].image.content,'YQ==');
    assert.deepEqual(payload.requests[0].features.map(f=>f.type),['LANDMARK_DETECTION','TEXT_DETECTION']);
    return Response.json({responses:[{landmarkAnnotations:[{description:'Aqueduct of Segovia',score:.92,locations:[{latLng:{latitude:40.95,longitude:-4.12}}]}],textAnnotations:[{description:'Segovia'}]},{},{error:{message:'private'}}]});
  });
  const response=await worker.fetch(request('landmarks',{images:[image,image,image]}),{GOOGLE_VISION_API_KEY:'mock'});
  assert.equal(response.status,200);const data=await response.json();
  assert.equal(data.photos[0].candidates[0].name,'Aqueduct of Segovia');
  assert.equal(data.photos[0].text,'Segovia');assert.equal(data.photos[1].candidates.length,0);
  assert.ok(data.photos[2].error);assert.ok(!JSON.stringify(data).includes('private'));
});
test('Research accepts only bounded place names, filters sources, and preserves missing results',async t=>{
  assert.equal((await worker.fetch(request('research',{places:[null]}),{})).status,400);
  t.mock.method(globalThis,'fetch',async url=>{
    if(url.searchParams.get('gsrsearch')==='Unknown')return Response.json({});
    return Response.json({query:{pages:{1:{title:'Aqueduct of Segovia',extract:'Roman aqueduct in Segovia.',fullurl:'https://en.wikipedia.org/wiki/Aqueduct_of_Segovia',index:1},2:{title:'Unsafe',extract:'Bad',fullurl:'javascript:alert(1)',index:2}}}});
  });
  const response=await worker.fetch(request('research',{places:['Aqueduct of Segovia','Unknown','Aqueduct of Segovia']}),{});
  const data=await response.json();assert.equal(response.status,200);assert.equal(data.results.length,2);
  assert.equal(data.results[0].sources.length,1);assert.equal(data.results[1].sources.length,0);assert.ok(data.results[1].error);
});
test('External failures do not expose Google credentials',async t=>{
  t.mock.method(globalThis,'fetch',async()=>Response.json({error:{message:'mock-secret'}},{status:403}));
  const response=await worker.fetch(request('landmarks',{images:[image]}),{GOOGLE_VISION_API_KEY:'mock-secret'});
  assert.equal(response.status,403);assert.ok(!(await response.text()).includes('mock-secret'));
});
function jpegGps(little){
  const buffer=new ArrayBuffer(142),view=new DataView(buffer),start=12;
  view.setUint16(0,0xffd8);view.setUint16(2,0xffe1);view.setUint16(4,136);view.setUint32(6,0x45786966);
  view.setUint16(start,little?0x4949:0x4d4d);view.setUint16(start+2,42,little);view.setUint32(start+4,8,little);
  view.setUint16(start+8,1,little);
  const entry=(offset,tag,type,count,value)=>{const p=start+offset;view.setUint16(p,tag,little);view.setUint16(p+2,type,little);view.setUint32(p+4,count,little);view.setUint32(p+8,value,little)};
  entry(10,0x8825,4,1,26);view.setUint16(start+26,4,little);
  entry(28,1,2,2,0);view.setUint8(start+36,78);entry(40,2,5,3,80);
  entry(52,3,2,2,0);view.setUint8(start+60,87);entry(64,4,5,3,104);
  for(const [offset,values] of [[80,[40,57,0]],[104,[4,7,12]]])values.forEach((value,i)=>{view.setUint32(start+offset+i*8,value,little);view.setUint32(start+offset+i*8+4,1,little)});
  view.setUint16(140,0xffd9);return buffer;
}
test('Original JPEG GPS handles both TIFF byte orders and rejects malformed files',async()=>{
  for(const little of [true,false]){
    const buffer=jpegGps(little),gps=await readGps({arrayBuffer:async()=>buffer});
    assert.ok(Math.abs(gps.latitude-40.95)<.000001);assert.ok(Math.abs(gps.longitude+4.12)<.000001);
    new DataView(buffer).setUint32(12+80+4,0,little);
    assert.equal(await readGps({arrayBuffer:async()=>buffer}),null);
  }
  assert.equal(await readGps({arrayBuffer:async()=>new ArrayBuffer(3)}),null);
});
