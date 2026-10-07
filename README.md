# 하루모아 PC 웹

Android v0.9.25와 같은 데이터 모델을 사용하는 PC·모바일 브라우저용 하루모아입니다. `site/`에는 배포할 정적 파일만 들어 있습니다. GitHub Pages는 웹 화면을 제공하고, 개인 기록은 사용자의 Google Sheets·Drive에 저장합니다.

**웹 접속:** [하루모아 열기](https://mudlbum.github.io/harumoa-web/) · [공개 GitHub 저장소](https://github.com/mudlbum/harumoa-web)

**앱 안내:** [소개](https://mudlbum.github.io/harumoa-web/welcome.html) · [개인정보](https://mudlbum.github.io/harumoa-web/privacy.html) · [문의](https://mudlbum.github.io/harumoa-web/support.html) · [데이터 삭제](https://mudlbum.github.io/harumoa-web/delete.html) · [이용 안내](https://mudlbum.github.io/harumoa-web/terms.html)

공개 문의 담당자는 Jaiven Lee이며 이메일은 mudlbum@gmail.com입니다. 이 페이지는 현재 시험 버전의 처리와 제한을 설명합니다. Google OAuth 공개 심사와 스토어 배포는 아직 완료되지 않았습니다. 첫 출시 대상은 한국·미국·캐나다의 만8세 이상입니다. 기본 기능은 무료이고 Android Pro 광고 제거는 판매 전입니다. 현재 웹과 APK에는 광고가 없습니다. 만8–13세의 Google·공유·민감 기능은 실제 보호자 동의 확인 절차가 준비될 때까지 제한하며, 만8세 미만의 저장·연결은 막습니다. 이 제한을 검증된 보호자 동의 완료로 표시하지 않습니다.

**Android 가족 테스트:** [v0.9.25 APK 내려받기](https://github.com/mudlbum/harumoa-web/releases/download/v0.9.25/harumoa-v0.9.25-durable-drafts-test.apk) · [릴리스와 SHA-256](https://github.com/mudlbum/harumoa-web/releases/tag/v0.9.25) · [가족 테스트 안내](https://github.com/mudlbum/harumoa-web/releases/download/v0.9.25/harumoa-family-test-ko.md)

웹 주소와 APK 링크를 가족에게 공유할 수 있습니다. Google 설정 없이 화면을 볼 때는 **로그인 없이 기능 체험**을 선택합니다. 실제 Google 저장에는 등록된 테스트 계정을 사용하며, 새 참여자의 Google 이메일은 개발자에게 알려 주세요. 테스터가 Cloud 프로젝트나 OAuth 클라이언트를 만들 필요는 없습니다. 웹 체험과 직접 받은 APK 설치는 Google Play 비공개 테스트의 참여 기록에 포함되지 않습니다.

이 저장소는 GitHub Actions로 Pages에 배포합니다. GitHub Desktop에서 `main`의 변경을 커밋하고 **Push origin**을 누르면 같은 주소로 자동 업데이트됩니다. Actions의 **Deploy Harumoa web**가 성공하면 배포가 완료됩니다. 현재 배포 주소의 Google JavaScript origin은 기존 앱과 같은 웹 OAuth 클라이언트에 등록했습니다.

## 사용

배포 주소를 열고 **Google로 계속하기**를 누른 뒤, 휴대폰 앱에서 사용하던 Google 계정으로 저장 권한을 연결합니다. 기존 하루모아 파일을 먼저 찾아 열므로 다른 기기에서 가족이나 개인 공간을 다시 만들 필요가 없습니다. 로그인 없이 체험하기는 별도의 로컬 예시 데이터입니다.

저장한 변경은 Google Sheets에 전송하고, 다른 기기는 열린 화면에서 약 30초 간격으로 확인합니다. 탭으로 돌아오거나 Google 연결 화면의 **지금 동기화**를 누르면 다시 확인합니다. 동시에 같은 항목을 수정하면 충돌을 표시하며 기록을 지우거나 자동 덮어쓰지 않습니다. 인터넷이 끊기면 작성 내용을 기기에 보관하며, 재연결·Google 권한 연결 후 다시 전송합니다.

브라우저를 다시 열 때 마지막 계정의 캐시를 보여 줄 수 있지만, Google 접근 토큰은 브라우저 저장소에 보관하지 않습니다. 연결이 만료되면 **Google 다시 연결**을 눌러 주세요. 공유 PC에서는 사용 후 로그아웃하고 브라우저의 사이트 데이터를 지워 주세요.

## 최초 배포 설정

1. 저장소 Settings → Pages → Build and deployment에서 **GitHub Actions**를 선택합니다.
2. Actions → **Deploy Harumoa web**를 실행합니다. 이후 `main`에 변경을 올리면 자동 배포합니다.
3. 앱과 같은 Google Cloud 프로젝트의 기존 **웹 OAuth 클라이언트**에서 Authorized JavaScript origins에 사이트의 origin을 추가합니다. 예를 들어 `https://mudlbum.github.io`를 넣으며 `/harumoa-web/` 경로는 넣지 않습니다. 다른 클라이언트·프로젝트로 바꾸면 기존 파일 접근과 검색이 달라질 수 있습니다.
4. 해당 프로젝트의 Drive API·Sheets API 사용 설정을 확인합니다. 브라우저 가족 초대는 공식 Google Picker로 초대된 파일 한 개를 승인합니다. Picker API 및 별도 브라우저 키 설정은 현재 개발자가 승인 대기 중이며, 활성화 전에는 새 브라우저 가족 연결이 불가합니다. 전체 Sheets 권한 대체 경로는 제거했습니다. Calendar 기능을 연결할 때에는 Calendar API와 별도 동의가 필요합니다. OAuth가 테스트 상태라면 사용할 계정을 테스트 사용자로 등록해야 합니다.

`site/config.js`의 웹 클라이언트 ID는 공개 설정입니다. 클라이언트 비밀키, 서비스 계정 JSON, 접근 토큰을 넣지 않습니다. Android 제한 API 키는 웹에 복사하지 않습니다. 정적 Pages 배포에는 서버가 필요하지 않습니다.

## 로컬 실행과 수정

Python이 설치된 PC에서 저장소 폴더에서 `python -m http.server 8000 --directory site`를 실행한 뒤 `http://localhost:8000`을 엽니다. Google 연결 테스트에는 이 localhost origin도 웹 OAuth 클라이언트에 등록해야 합니다. 파일을 더블 클릭한 `file:` 주소에서는 Google 연결이 동작하지 않습니다.

`site/app.js`와 `site/app.css`는 원본 하루모아 프로젝트에서 생성한 결과입니다. 기능 수정은 원본의 `web/`, `src/`에서 하고 `python scripts/build.py`, `python scripts/prepare_web.py --output <이 저장소 경로>`로 재생성합니다. 이 저장소는 웹 배포용이며 Android 프로젝트·서명키·사용자 파일·작업 로그를 포함하지 않습니다.

## 검증 범위

PC Chromium에서 실제 정적 파일·CSP·브라우저 fetch를 사용하여 웹 OAuth fixture와 Android bridge fixture가 같은 Google REST 저장소 fixture를 읽고 쓰는지 검증합니다. 실제 Google 계정 동의·운영 서버 응답·휴대폰과의 실제 동기화는 별도 사용 확인이 필요합니다. 가족 초대는 named-reader 권한을 유지하며, 두 번째 계정의 웹 파일 선택·접근은 운영 계정으로 추가 확인해야 합니다.

웹의 카메라·마이크 기능에는 브라우저 권한과 HTTPS가 필요합니다. 브라우저가 닫힌 상태의 백그라운드 알림은 정적 Pages만으로 보장하지 않습니다.

공식 문서: [GitHub Pages workflow](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages), [Google 웹 OAuth 설정](https://developers.google.com/identity/oauth2/web/guides/get-google-api-clientid), [Google 토큰 방식](https://developers.google.com/identity/oauth2/web/guides/use-token-model).
