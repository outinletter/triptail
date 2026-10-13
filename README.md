# TripTail

여행 사진을 AI로 분석해 네이버 블로그와 티스토리용 글·HTML을 만드는 모바일 설치형 웹 앱입니다.

## 실행

`npm start`를 실행하고 `http://localhost:3000`을 여세요. DeepSeek API 키는 화면에 입력하거나 서버의 `DEEPSEEK_API_KEY` 환경 변수로 설정합니다. 화면에 입력한 키는 브라우저에 저장하지 않습니다. 스마트폰에서는 같은 네트워크의 PC 주소로 접속할 수 있습니다. 앱 설치와 클립보드 기능은 HTTPS 또는 localhost 환경을 권장합니다.

## 다음 단계

Windows PowerShell 예시: `$env:DEEPSEEK_API_KEY="발급받은키"; npm start`

생성된 HTML은 미리보기, 복사, 다운로드할 수 있습니다. API 키는 저장소에 기록하지 마세요.

JPG, PNG, WEBP 사진을 최대 12장(장당 20MB) 업로드할 수 있습니다. 사진은 최대 변 1600px로 줄여 DeepSeek에 전송합니다. 사진별 배경 관찰, 장소 추정, 확신도를 표시하고 이를 바탕으로 블로그 HTML을 만듭니다. 여행지는 선택 입력이며, 추정한 장소와 사실은 게시 전에 확인하세요. HTML의 사진 표시는 게시할 때 실제 사진으로 교체하세요. 원격 접속 시 키 보호를 위해 HTTPS를 사용하세요.

## Cloudflare Worker

사진 선택 → 사진 장소 찾기 → 사진별 장소 확인 → 관련 배경 자료 선택 → 블로그 작성 순서로 사용합니다. Google Vision 후보와 인식 점수는 확정된 장소나 확률이 아닙니다. 사진별 장소를 수정하거나 미확인으로 진행할 수 있습니다. Wikipedia 검색 결과가 같은 장소인지 확인하고 선택한 자료만 글에 사용합니다. 자료가 없으면 역사 정보를 만들지 않습니다.

Worker에 `GOOGLE_VISION_API_KEY`를 Secret으로 등록하고 Google Cloud에서 Cloud Vision API와 결제를 활성화하세요. 사진 장소 찾기 실행 시 사진은 Google Vision에 전송됩니다. 원본 JPEG의 EXIF GPS는 축소 전에 기기에서 읽고 자동 전송하지 않습니다. GPS가 없는 사진과 JPEG 이외의 형식도 랜드마크 인식을 사용할 수 있습니다. HEIC는 JPEG로 변환해야 합니다.

로컬 서버에서도 같은 API 처리를 사용합니다. `DEEPSEEK_API_KEY`, `GOOGLE_VISION_API_KEY`를 환경 변수로 설정하세요. Node.js 20 이상이 필요합니다.

`npm run deploy`로 `triptail` Worker와 화면 파일을 배포합니다. 기존 Cloudflare Git 빌드의 `npx wrangler deploy` 명령도 그대로 사용할 수 있습니다. Wrangler가 화면 파일만 `dist/`에 준비하며 `/api/*`는 `worker.js`에서 처리합니다. 로컬 Node 서버는 그대로 유지합니다.

배포 후 Settings → Runtime variables and secrets에서 이름 `DEEPSEEK_API_KEY`, 유형 Secret으로 키를 등록하세요. 빌드 변수에 등록하지 마세요. 키는 코드나 배포 설정에 기록하지 않습니다. Secret이 없고 화면에서도 키를 입력하지 않으면 API는 안내 메시지와 HTTP 503을 반환합니다. 키 등록 전에는 실제 AI 분석을 완료할 수 없습니다.

## 네이티브 iOS 앱

`ios/TripTail.xcodeproj`를 Xcode에서 열고 `TripTail` 스킴을 선택하세요. iOS 17 이상, iPhone/iPad를 지원합니다. 번들 ID는 `com.addvalue.triptail`이며 개발 팀은 기존 앱과 같은 `A7QB8PT33N`으로 설정되어 있습니다. 다른 팀에서는 Signing 설정을 변경하세요.

- 시스템 사진 선택기: JPEG/PNG/HEIC 등 기기가 읽을 수 있는 사진, 최대 12장·장당 20MB
- 원본을 1600px 이하 JPEG로 재인코딩해 EXIF/GPS 제거, Apple Vision 글자 인식은 기기 내 실행
- 사진 없이 메모만으로도 오프라인 초안 작성, 편집, 기기 내 저장/삭제
- 실제 샘플 글 체험, 미저장 글 닫기 확인, 공유 시트, 안전한 HTML 파일 내보내기
- AI 선택 시 매번 전송 동의, 기존 HTTPS Worker 사용, 앱에 API 키 포함하지 않음
- 사진은 보관함에 저장하지 않으며 글만 보호된 기기 파일에 저장

검증: `node --test tests/*.test.js`, `npm run build`. iOS UI 테스트는 `TripTail` 스킴의 Test를 실행하세요. 빌드 제품과 개발 인증서/프로비저닝 파일은 저장소에 올리지 않습니다.

심사 검토 결과와 제출 전 운영 확인 사항은 `APP_STORE_REVIEW.md`를 참고하세요. 지원 및 개인정보 삭제 요청: `outintube@gmail.com`.

## 아이폰의 장소 확인 및 블로그 화면

Google Vision으로 장소 확인 → 사진별 실제 장소명 확인·수정 → Wikipedia 소개·역사 자료 선택 → AI 블로그 작성 순서로 진행합니다. 좌표가 있는 자료에는 5km 범위의 주변 문서도 조회합니다. Google Vision 인식 점수는 정확성을 보장하지 않으며 확인한 장소명은 AI가 다시 추정하지 않습니다.

AI가 작성한 소제목·문단·인용문 HTML은 안전한 태그만 유지하고 앱에서 밝은 여행 블로그 스타일로 보여줍니다. 선택 사진은 현재 미리보기에서만 표시하며 저장하거나 HTML 파일로 내보내는 자료에는 사진 자리 표시와 글이 포함됩니다. 글을 직접 수정하면 수정한 본문으로 미리보기와 HTML을 다시 구성합니다. 기존 저장 글과 호환됩니다.

## 사진만으로 자동 블로그 작성

아이폰 화면의 별도 Google Vision 버튼과 나의 여행 입력 섹션을 제거했습니다. AI로 사진 분석·글쓰기 버튼을 누르고 외부 전송 동의 후 Google Vision → 관련 장소 자료 조회 → HTML 블로그 작성을 자동으로 진행합니다. 최고 인식 후보가 0.5 미만이면 미확인으로 처리하며 사용자 확인을 받았다고 표현하지 않습니다. 장소명과 일치하는 출처만 자동 선택합니다.

사진을 원본 인코딩으로 읽고 EXIF DateTimeOriginal 또는 DateTimeDigitized에서 촬영일을 추출합니다. 날짜가 없거나 잘못됐으면 미확인으로 유지하며 오늘 날짜를 대신 사용하지 않습니다. 촬영일만 별도로 AI에 전달하고 GPS·원본 메타데이터는 재인코딩 과정에서 제거합니다.
