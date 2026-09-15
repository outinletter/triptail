const state={photos:[],groups:[],html:''};
const $=id=>document.getElementById(id);const fileInput=$('fileInput');
fileInput.addEventListener('change',e=>addFiles([...e.target.files]));
['dragover','drop'].forEach(ev=>$('dropzone').addEventListener(ev,e=>{e.preventDefault();if(ev==='drop')addFiles([...e.dataTransfer.files])}));
function addFiles(files){state.photos.push(...files.filter(f=>f.type.startsWith('image/')).map((file,i)=>({file,id:crypto.randomUUID(),url:URL.createObjectURL(file),name:file.name,index:state.photos.length+i})));renderPhotos()}
function renderPhotos(){$('photoCount').textContent=`${state.photos.length}장`;$('photoGrid').innerHTML=state.photos.map((p,i)=>`<div class="thumb"><img src="${p.url}" alt="${p.name}"><button onclick="removePhoto('${p.id}')">×</button></div>`).join('')}
window.removePhoto=id=>{state.photos=state.photos.filter(p=>p.id!==id);renderPhotos()};
$('demoBtn').onclick=()=>{ $('place').value='교토 기요미즈데라';$('memo').value='언덕길을 올라 만난 오래된 목조 무대와 도시 풍경이 인상적이었다.'; if(!state.photos.length) $('dropzone').click()};
$('analyzeBtn').onclick=()=>{if(!state.photos.length){alert('사진을 먼저 올려주세요.');return}state.groups=[];for(let i=0;i<state.photos.length;i+=3)state.groups.push(state.photos.slice(i,i+3));renderGroups();updatePrompt();$('results').classList.remove('hidden');$('preview').classList.remove('hidden');$('results').scrollIntoView({behavior:'smooth'})};
function renderGroups(){$('groups').innerHTML=state.groups.map((g,i)=>`<div class="group"><div class="group-photos">${g.map(p=>`<img src="${p.url}" alt="">`).join('')}</div><div class="group-info"><strong>묶음 ${i+1} · ${g.length}장</strong><small>${g.map(photoLabel).join(', ')} · ChatGPT에서 실제 유사도와 대표 사진을 다시 판단</small></div><span class="tag">업로드 대상</span></div>`).join('')}
$('reanalyze').onclick=()=>{renderGroups();updatePrompt();};
$('previewBtn').onclick=()=>{usePastedHtml();$('preview').scrollIntoView({behavior:'smooth'})};
$('openChatGptBtn').onclick=()=>{window.open('https://chatgpt.com','_blank','noopener')};
$('copyPromptBtn').onclick=async()=>{updatePrompt();await navigator.clipboard.writeText($('promptText').value);$('copyPromptBtn').textContent='복사 완료';setTimeout(()=>$('copyPromptBtn').textContent='프롬프트 복사',1500)};
function photoLabel(photo){return `P${String(state.photos.indexOf(photo)+1).padStart(3,'0')}`}
function updatePrompt(){const place=$('place').value||'미확인 여행지';const date=$('date').value||'미기재';const tone=$('tone').value;const memo=$('memo').value||'별도 메모 없음';const photoList=state.photos.map(p=>`${photoLabel(p)}: ${p.name}`).join('\n');$('promptText').value=`당신은 여행 사진을 분석해 네이버 블로그와 티스토리에 게시할 수 있는 글을 작성하는 전문 여행 에디터야. 아래 사진들을 실제로 관찰한 내용에 근거해 분석하고, 읽기 좋은 여행 원고와 붙여넣기 가능한 HTML을 작성해줘.

여행지: ${place}
방문 날짜: ${date}
글 분위기: ${tone}
여행 메모: ${memo}

사진 목록:
${photoList}

요청:
1. 사진 속 장소·건물·유적·조형물·음식·거리·자연·인물·표지판을 구체적으로 분석해줘. 확인된 사실, 사진을 바탕으로 한 추정, 추가 확인이 필요한 내용을 구분해줘.
2. 모든 사진을 강제로 그룹화하지 마. 서로 다른 장면은 개별 사진으로 유지해줘.
3. 거의 같은 구도의 사진만 비슷한 사진 그룹으로 묶고, 초점·선명도·노출·구도·정보 전달력·중복 정도를 기준으로 잘 나온 사진 1~3장만 선별해줘. 그룹명, 후보 사진, 선별 사진, 선택 이유, 본문 또는 슬라이드 처리 방식을 알려줘.
4. 같은 장소라도 각도·거리·세부·분위기가 다르면 최대 2~3장을 슬라이드로 제안해줘. 중복이 심할 때만 대표 사진 1장으로 줄여줘.
5. 각 사진에 실제 장소나 대상 중심의 자연스러운 제목과 캡션을 붙여줘. 확실하지 않으면 추정 표현을 사용해줘.
6. P001, P002 같은 번호는 분석·관리용으로 유지하되 최종 본문과 HTML에서는 숨겨줘. 사용자가 요청할 때만 제목 뒤에 번호를 표시해줘.
7. 여행지 소개, 사진 대상 설명, 역사·건축·문화·종교·예술적 특징, 가이드가 들려줄 이야기, 사회적 의미, 전설·일화·재미있는 이야기를 포함해줘. 사실과 해석과 전설을 구분하고, 가능한 경우 공식 기관 출처를 정리해줘.
8. 특정 유명 블로거의 문체를 복제하지 말고, 짧은 문단·충분한 여백·감성적인 한 줄 인용·부드러운 소제목·구체적인 관찰을 활용해줘. 과장과 반복적인 일반 문장을 피하고 사진마다 다른 세부를 설명해줘.
9. HTML은 단순한 네이버 블로그·티스토리용으로 작성해줘. 'Noto Sans KR', 'Apple SD Gothic Neo', Arial, sans-serif 글꼴, 본문 line-height 1.85, 본문 왼쪽 정렬, 필요할 때 도입·캡션 가운데 정렬, 인용문 왼쪽 테두리 또는 가운데 정렬을 사용해줘. 외부 CSS·복잡한 자바스크립트·가짜 이미지 URL은 사용하지 마.
10. 사진 위치에는 [사진: 사진 제목]을, 슬라이드에는 [슬라이드: 사진 제목 1 / 사진 제목 2 / 사진 제목 3]을 사용해줘.
11. 최종 출력 순서는 사진 분석 요약 → 비슷한 사진 그룹과 선별 결과 → 대표 사진·슬라이드 추천 → 사진별 제목 → 블로그 제목 3개 → 블로그 원고 → HTML → 사실·추정·전설 구분 → 참고 출처 → 추가 확인 정보 순서로 작성해줘. 사진으로 확인할 수 없는 내용은 일반적인 문장으로 채우지 말고 솔직히 밝혀줘.`}
function usePastedHtml(){state.html=$('chatGptResult').value.trim();$('article').innerHTML=state.html||'<p>ChatGPT가 만든 HTML을 붙여넣으면 이곳에서 미리볼 수 있습니다.</p>'}
$('downloadBtn').onclick=()=>{usePastedHtml();const blob=new Blob([state.html],{type:'text/html;charset=utf-8'});const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='triptail-blog.html';a.click()};
$('copyBtn').onclick=async()=>{usePastedHtml();await navigator.clipboard.writeText(state.html||'');$('copyBtn').textContent='복사 완료';setTimeout(()=>$('copyBtn').textContent='HTML 복사',1500)};
