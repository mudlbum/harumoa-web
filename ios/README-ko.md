# 하루모아 iOS 테스트 프로젝트

현재 웹·Android 0.9.25의 화면, 모델, 입력 초안, 로컬 전송 대기 목록을 재사용합니다. Swift와 WKWebView를 사용하는 iOS17 이상 iPhone/iPad 프로젝트입니다. 승인된 기존 아이콘을 사용합니다. 광고·구매 SDK는 포함하지 않습니다.

## 설치에 필요한 것

`harumoa-v0.9.25-ios-UNSIGNED.ipa`는 Apple 서명이 없는 컴파일 확인용 파일입니다. 아이폰에 파일을 눌러 바로 설치할 수 없습니다. 파일의 `.ipa` 확장자는 설치 허가를 의미하지 않습니다.

- 본인 iPhone에서 개발 테스트: Mac의 Xcode에서 `Harumoa.xcodeproj`를 열고 Signing & Capabilities에 본인 Apple 계정을 선택한 뒤, iPhone을 연결하여 실행합니다. 무료 Personal Team에는 기간·기능 제한이 있습니다.
- 가족에게 배포: Apple Developer Program, App Store Connect 앱 등록, Apple 서명과 빌드 업로드, 필요한 TestFlight 베타 심사 후 초대 링크를 사용합니다.
- 등록한 기기에 IPA 배포: 해당 기기와 맞는 Apple 인증서·프로비저닝 프로파일로 서명하고 설치해야 합니다.

Apple 비밀번호, 인증서 개인키와 프로파일을 채팅이나 공개 저장소에 올리지 마세요. 서명되지 않은 IPA를 TestFlight에 업로드하지 마세요. Mac이 없는 경우 공개 GitHub의 macOS Actions에서 서명 전 컴파일은 확인할 수 있지만, 설치에는 Apple 서명 설정이 필요합니다.

## 포함된 기능과 확인 범위

번들 파일만 WKWebView의 `harumoa://localhost`에서 실행합니다. 원격 페이지·iframe에 네이티브 브리지를 제공하지 않습니다. 외부 링크는 Safari 또는 해당 시스템 앱으로 엽니다. 기본 WKWebsiteDataStore와 실제 IndexedDB/localStorage를 사용합니다. 입력창 위 도구와 키보드 공간은 iOS의 keyboardLayoutGuide를 사용합니다.

네이티브 녹음은 사용자가 마이크를 허용한 후 전경에서 AAC/M4A로 시작합니다. 최대3분이며 배경 전환 시 취소합니다. 완료 파일은 현재 입력창과 계정의 기존 첨부 검증/저장 코드로 전달하고 임시 파일을 지웁니다. 시스템 파일 선택, 한 개 연락처 선택과 초대 공유 시트를 사용합니다. 버튼음은 ambient 오디오로 무음 스위치와 다른 오디오를 존중합니다. 알림/기상 알람은 현재 전경 웹 방식이며 iOS 배경 알람·푸시를 구현한 것으로 표시하지 않습니다.

GoogleSignIn 공식 SDK9.0.0을 Swift Package Manager로 연결합니다. 기본 계정 선택 뒤 drive.file 및 선택한 Calendar 권한을 별도로 요청하며 기존 actor/파일/충돌 규칙을 유지합니다. 토큰을 JS 영구 저장소에 쓰지 않습니다. SDK는 Apple Keychain을 사용합니다. 로그아웃 중 완료한 이전 로그인 응답은 버립니다. iOS용 OAuth ID가 비어 있으면 연결 준비 메시지를 표시하고 로컬 체험이 가능합니다. iOS 가족 파일 Picker는 아직 미구현이며 전체 Drive/Sheets 권한으로 우회하지 않습니다.

만8~13세 Google·공유·민감 기능 제한과 만8세 미만 저장 제한을 유지합니다. 실제 보호자 동의, App Store 정책·개인정보 신고, 실기기 품질 확인은 별도 출시 작업입니다. 시뮬레이터 녹음은 실제 iPhone 마이크 품질 검사와 다릅니다.

## Google 설정

기존 Google Cloud 프로젝트에서 **iOS 유형** OAuth 클라이언트를 실제 서명할 bundle ID와 맞춰 만들고 `Harumoa/Config.xcconfig`의 `GOOGLE_IOS_CLIENT_ID`와 역순 URL 스킴 `GOOGLE_REVERSED_CLIENT_ID`를 채웁니다. Android/web 클라이언트 ID를 iOS ID로 대신 쓰지 않습니다. 외부 사용자 공개 심사·테스트 사용자·가족 Picker는 이전 대기 상태입니다.

## 재생성과 빌드

원본 프로젝트에서 `python scripts/build.py` 다음 `python scripts/prepare_ios.py`를 실행합니다. 공개 저장소에 내보낼 때는 두 번째 명령에 `--output C:/Users/mudlb/GitHub/harumoa-web`을 추가합니다. iOS 화면 파일을 직접 수정하지 않습니다.

Mac에서 `bash ios/build-preview.sh`는 시뮬레이터 실제 WKWebView 초안 복원/저장/IndexedDB, 네이티브 IPC와 미등록 Google 오류, 녹음/로컬 파일 읽기를 검사한 뒤 서명되지 않은 device archive/IPA를 만듭니다. Google와 실제 iPhone 사용 확인은 이 테스트에 포함되지 않습니다. 스토어 승인을 증명하지 않습니다.

공식 안내: [Apple 기기 배포](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices), [TestFlight](https://developer.apple.com/testflight/), [Apple Developer Program](https://developer.apple.com/programs/), [Google iOS 설정](https://developers.google.com/identity/sign-in/ios/start-integrating).
