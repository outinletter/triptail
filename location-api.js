const reply=(status,data)=>Response.json(data,{status,headers:{'Cache-Control':'no-store'}});

export async function identifyPlaces(input,env){
  if(!env.GOOGLE_VISION_API_KEY)return reply(503,{error:'Worker에 GOOGLE_VISION_API_KEY Secret을 등록하세요.'});
  const response=await fetch('https://vision.googleapis.com/v1/images:annotate',{
    method:'POST',headers:{'Content-Type':'application/json','x-goog-api-key':env.GOOGLE_VISION_API_KEY},signal:AbortSignal.timeout(60000),
    body:JSON.stringify({requests:input.images.map(image=>({image:{content:image.split(',')[1]},features:[{type:'LANDMARK_DETECTION',maxResults:3},{type:'TEXT_DETECTION'}]}))})
  });
  const data=await response.json();
  if(!response.ok)return reply(response.status,{error:`Google Vision 오류 (${response.status}). API 활성화·결제·키 제한을 확인하세요.`});
  if(!Array.isArray(data.responses)||data.responses.length!==input.images.length)return reply(502,{error:'Google Vision 결과가 불완전합니다.'});
  return reply(200,{photos:data.responses.map((photo,index)=>({
    id:`P${String(index+1).padStart(3,'0')}`,
    candidates:(photo.landmarkAnnotations||[]).map(item=>({name:item.description||'',score:item.score||0,coordinates:item.locations?.[0]?.latLng||null})),
    text:(photo.textAnnotations?.[0]?.description||'').slice(0,2000),
    error:photo.error?'이 사진의 장소 인식에 실패했습니다. 직접 입력하거나 미확인으로 진행하세요.':''
  }))});
}

export async function researchPlaces(input){
  if(!Array.isArray(input.places)||!input.places.length||input.places.length>12||!input.places.every(name=>typeof name==='string'&&name.length<=200))return reply(400,{error:'확인한 장소명을 보내주세요.'});
  const names=[...new Set(input.places.filter(name=>name.trim()))];
  const results=[];
  await Promise.all(names.map(async name=>{
    try{
      const language=/[가-힣]/.test(name)?'ko':'en';
      const url=new URL(`https://${language}.wikipedia.org/w/api.php`);
      const headers={'User-Agent':'TripTail/1.0 (https://triptail.outinletter.workers.dev)'};
      const fields={action:'query',prop:'extracts|info|coordinates',explaintext:'1',colimit:'1',inprop:'url',redirects:'1',format:'json'};
      url.search=new URLSearchParams({...fields,titles:name});
      let response=await fetch(url,{headers,signal:AbortSignal.timeout(15000)});
      if(!response.ok)throw Error('research');
      let data=await response.json();if(data.error)throw Error('research');
      if(!Object.values(data.query?.pages||{}).some(page=>page.extract)){
        url.search=new URLSearchParams({...fields,generator:'search',gsrsearch:name,gsrlimit:'3',exintro:'1',exlimit:'3',exchars:'1200'});
        response=await fetch(url,{headers,signal:AbortSignal.timeout(15000)});
        if(!response.ok)throw Error('research');
        data=await response.json();if(data.error)throw Error('research');
      }
      const sources=Object.values(data.query?.pages||{}).sort((a,b)=>(a.index||0)-(b.index||0)).filter(page=>page.extract&&typeof page.fullurl==='string'&&/^https:\/\/(en|ko)\.wikipedia\.org\/wiki\//.test(page.fullurl)).map(page=>({title:page.title,url:page.fullurl,summary:page.extract.slice(0,6000),coordinates:page.coordinates?.[0]||null}));
      for(const source of sources){
        source.nearby=[];
        const point=source.coordinates;delete source.coordinates;
        if(!point||!Number.isFinite(point.lat)||!Number.isFinite(point.lon))continue;
        try{
          const near=new URL(`https://${language}.wikipedia.org/w/api.php`);
          near.search=new URLSearchParams({action:'query',generator:'geosearch',ggscoord:`${point.lat}|${point.lon}`,ggsradius:'5000',ggslimit:'4',prop:'extracts|info',exintro:'1',explaintext:'1',exchars:'1200',exlimit:'4',inprop:'url',format:'json'});
          const response=await fetch(near,{headers:{'User-Agent':'TripTail/1.0 (https://triptail.outinletter.workers.dev)'},signal:AbortSignal.timeout(10000)});
          if(response.ok){const data=await response.json();source.nearby=Object.values(data.query?.pages||{}).filter(p=>p.title!==source.title&&p.extract&&typeof p.fullurl==='string'&&/^https:\/\/(en|ko)\.wikipedia\.org\/wiki\//.test(p.fullurl)).slice(0,3).map(p=>({title:p.title,url:p.fullurl,summary:p.extract.slice(0,1200)}))}
        }catch{/* Nearby data is optional; never invent unavailable facts. */}
      }
      results.push({place:name,sources,error:sources.length?'':'관련 자료가 없습니다. 배경 사실을 추가하지 않고 진행할 수 있습니다.'});
    }catch{results.push({place:name,sources:[],error:'배경 자료 조회에 실패했습니다. 재시도하거나 자료 없이 진행하세요.'})}
  }));
  return reply(200,{results});
}
