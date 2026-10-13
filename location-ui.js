import {state,$,dataUrl,escapeHtml,consentTo} from './app.js';
import {readGps} from './photo-gps.js';

async function post(path,body){const response=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json'},signal:AbortSignal.timeout(90000),body:JSON.stringify(body)});const result=await response.json();if(!response.ok)throw Error(result.error||'요청에 실패했습니다.');return result}
function busy(value){state.busy=value;for(const id of ['identifyBtn','confirmPlacesBtn','deepSeekBtn','fileInput','demoBtn'])$(id).disabled=value;for(const el of $('locationReview').querySelectorAll('input'))el.disabled=value}
function gpsDistance(gps,coordinates){if(!gps||!coordinates)return null;const rad=n=>n*Math.PI/180,a=rad(coordinates.latitude-gps.latitude),b=rad(coordinates.longitude-gps.longitude);return 6371*2*Math.asin(Math.min(1,Math.sqrt(Math.sin(a/2)**2+Math.cos(rad(gps.latitude))*Math.cos(rad(coordinates.latitude))*Math.sin(b/2)**2)))}
$('identifyBtn').onclick=async()=>{
  if(state.busy)return;if(!state.photos.length){alert('사진을 먼저 올려주세요.');return}
  if(!consentTo('Google Vision · Cloudflare','축소 사진을 장소 및 글자 인식에 사용합니다. 원본 GPS는 전송하지 않습니다.'))return;
  busy(true);state.ready=false;state.locations=null;state.sources=[];$('researchSources').innerHTML='';$('results').classList.add('hidden');$('preview').classList.add('hidden');$('locationStatus').textContent='장소 후보를 찾고 있습니다…';
  try{
    const images=[];for(const photo of state.photos){photo.gps=await readGps(photo.file);images.push(await dataUrl(photo.file))}
    let result;
    try{result=await post('/api/landmarks',{images})}catch(error){$('locationStatus').textContent=error.message+' 직접 장소를 입력해 진행할 수 있습니다.';result={photos:state.photos.map((_,i)=>({id:`P${String(i+1).padStart(3,'0')}`,candidates:[],text:'',error:''}))}}
    state.locations=result.photos;
    $('placeCandidates').innerHTML=result.photos.map((photo,i)=>{
      const gps=state.photos[i].gps,candidates=photo.candidates||[];
      return `<section><h3>${escapeHtml(photo.id)} · ${escapeHtml(state.photos[i].name)}</h3><p>${gps?`원본 촬영 GPS: ${gps.latitude.toFixed(5)}, ${gps.longitude.toFixed(5)} (촬영 위치이며 대상의 위치와 다를 수 있음)`:'원본 JPEG에서 GPS를 찾지 못했습니다.'}</p>${candidates.map(candidate=>{const distance=gpsDistance(gps,candidate.coordinates);return `<p>후보: ${escapeHtml(candidate.name)} · 인식 점수 ${Number(candidate.score).toFixed(2)}${distance!==null?` · 촬영 위치와 약 ${distance.toFixed(1)}km`:''}</p>`}).join('')||'<p>랜드마크 후보 없음 — 직접 입력하거나 미확인으로 진행하세요.</p>'}${photo.error?`<p>${escapeHtml(photo.error)}</p>`:''}${photo.text?`<details><summary>사진에서 읽힌 글자</summary><p>${escapeHtml(photo.text)}</p></details>`:''}<label>확인할 장소<input id="confirmedPlace${i}" maxlength="200" list="candidates${i}" value="${escapeHtml(candidates[0]?.name||$('place').value)}"><datalist id="candidates${i}">${candidates.map(c=>`<option value="${escapeHtml(c.name)}"></option>`).join('')}</datalist></label><label><input id="unknownPlace${i}" type="checkbox"> 장소 미확인으로 진행</label></section>`;
    }).join('');
    $('locationReview').classList.remove('hidden');$('locationReview').scrollIntoView({behavior:'smooth'});
    if(!$('locationStatus').textContent.includes('직접 장소'))$('locationStatus').textContent='후보는 추정입니다. 장소를 확인하거나 수정한 뒤 자료를 조회하세요.';
  }catch(error){alert(error.message)}finally{busy(false)}
};
$('placeCandidates').addEventListener('input',()=>{state.ready=false;state.sources=[];$('researchSources').innerHTML='';$('locationStatus').textContent='장소가 변경되었습니다. 다시 확인해주세요.'});
$('confirmPlacesBtn').onclick=async()=>{
  if(state.busy||!state.locations)return;
  const locations=state.locations.map((photo,i)=>({...photo,place:$(`unknownPlace${i}`).checked?'미확인':$(`confirmedPlace${i}`).value.trim(),confirmed:!$(`unknownPlace${i}`).checked}));
  if(locations.some(photo=>!photo.place)){alert('각 사진의 장소를 입력하거나 미확인을 선택하세요.');return}
  if(locations.some(p=>p.confirmed)&&!consentTo('Wikipedia · Cloudflare','확인한 장소명을 배경 자료 검색에 사용합니다. 사진은 전송하지 않습니다.'))return;
  busy(true);state.ready=false;$('locationStatus').textContent='확인한 장소의 배경 자료를 조회하고 있습니다…';
  try{
    const names=locations.filter(photo=>photo.confirmed).map(photo=>photo.place);
    let research={results:[]};if(names.length)research=await post('/api/research',{places:names});
    state.locations=locations;state.research=research.results;
    $('researchSources').innerHTML=research.results.map((item,i)=>`<section><h3>${escapeHtml(item.place)} — 참고 자료 선택</h3><p>검색 결과가 같은 장소인지 제목과 내용을 확인하세요. 선택한 자료만 글에 사용됩니다.</p><label><input type="radio" name="source${i}" value="-1" checked> 배경 자료 없이 작성</label>${item.sources.map((source,n)=>`<label><input type="radio" name="source${i}" value="${n}">${escapeHtml(source.title)}</label><p>${escapeHtml(source.summary)}</p><p><a href="${escapeHtml(source.url)}" target="_blank" rel="noopener noreferrer">출처 확인</a></p>`).join('')}${item.error?`<p>${escapeHtml(item.error)}</p>`:''}</section>`).join('');
    state.ready=true;$('locationStatus').textContent='장소 확인 완료. 관련 자료를 선택한 뒤 블로그 글을 작성하세요.';
  }catch(error){$('locationStatus').textContent=error.message}finally{busy(false)}
};
document.addEventListener('triptail-before-generate',()=>{state.sources=(state.research||[]).flatMap((item,i)=>{const selected=$('researchSources').querySelector(`input[name="source${i}"]:checked`),source=item.sources[Number(selected?.value??-1)];return source?[{place:item.place,...source,summary:source.summary.slice(0,3000),nearby:(source.nearby||[]).slice(0,2).map(p=>({...p,summary:p.summary.slice(0,500)}))}]:[]})});
