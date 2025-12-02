# Personal Therapy: 마음을 치유하는 Flutter 앱

Personal Therapy는 사용자의 정서적 웰빙을 증진시키고 정신 건강을 관리하는 데 도움을 주기 위해 설계된 Flutter 기반 모바일 애플리케이션입니다. 감정 추적, 건강 지표 모니터링, 그리고 개인화된 AI 상담 기능을 통해 사용자가 자신을 더 잘 이해하고 건강한 삶을 유지하도록 지원합니다.

## ✨ 주요 기능

-   **정서 상태 추적**:
    -   **감정 기록**: 일간, 주간, 월간 단위로 자신의 감정 변화를 기록하고 시각화하여 패턴을 파악할 수 있습니다.
    -   **감정 분포 분석**: 기록된 감정 데이터를 기반으로 긍정, 부정, 중립 감정의 분포를 확인합니다.
-   **건강 지표 모니터링**:
    -   **스트레스 지수**: 스트레스 수준을 추적하고 시간에 따른 변화 추이를 그래프로 확인합니다.
    -   **건강 점수**: 전반적인 건강 점수를 모니터링하고 추이 그래프를 통해 변화를 시각화합니다.
    -   **수면 시간**: 수면 시간을 기록하고, Firestore에 저장된 데이터를 기반으로 주간 평균 수면 시간을 분석하여 보여줍니다.
    -   **걸음 수**: HealthKit (iOS) 또는 Google Fit (Android) 연동을 통해 실시간 걸음 수를 확인합니다.
-   **AI 상담**:
    -   **Gemini AI 챗봇**: Google Gemini API를 활용하여 개인화된 AI 상담사와 대화하며 심리적 지원과 조언을 얻을 수 있습니다. `.env` 파일을 통해 API 키를 안전하게 관리합니다.
-   **개인화된 인사이트**: 기록된 데이터와 연동된 건강 지표를 바탕으로 사용자에게 유용한 인사이트를 제공하여 자기 이해를 돕습니다.
-   **안심 연락망 관리**: 비상 상황에 대비하여 신뢰할 수 있는 연락처 목록을 추가하고 관리할 수 있습니다.
-   **알림 및 계정 관리**: 감정 기록, 위기 감지, 힐링 콘텐츠 알림 설정 및 개인 정보, 로그아웃, 계정 탈퇴 등의 계정 관리 기능을 제공합니다.

## 🛠️ 기술 스택

-   **프레임워크**: Flutter
-   **언어**: Dart
-   **상태 관리**: `StatefulWidget`, `StreamBuilder`를 활용한 반응형 UI 패턴
-   **백엔드**: [Firebase](https://firebase.google.com/)
    -   **인증 (Authentication)**: 사용자 로그인 및 회원가입 관리.
    -   **Firestore**: 감정 기록, 건강 점수, 수면 기록 등 모든 사용자 데이터 저장 및 실시간 동기화.
-   **AI**: [Google Gemini API](https://ai.google.dev/models/gemini)
-   **환경 변수 관리**: `flutter_dotenv` (API 키 등 민감 정보 안전하게 로드)
-   **건강 데이터 연동**: `health` (HealthKit 및 Google Fit을 통한 걸음 수 데이터 접근)
-   **데이터 시각화**: `fl_chart` (추이 그래프 생성)
-   **폰트**: `google_fonts` (Roboto 폰트 사용)
-   **네트워킹**: `http` (API 통신)
-   **비디오 재생**: `youtube_player_flutter` (힐링 콘텐츠 제공)
-   **로컬 저장소**: `shared_preferences`

## 🚀 프로젝트 시작하기

### 📋 전제 조건

-   [**Flutter SDK**](https://flutter.dev/docs/get-started/install) 설치 및 환경 설정 (버전 3.9.2 이상 권장).
-   [**Firebase 프로젝트 설정**](https://firebase.google.com/docs/flutter/setup):
    -   새로운 Firebase 프로젝트 생성 또는 기존 프로젝트 사용.
    -   Flutter 앱을 Android 및 iOS 플랫폼에 등록합니다.
    -   Android: `google-services.json` 파일을 다운로드하여 `android/app/` 디렉토리에 배치합니다.
    -   iOS: `GoogleService-Info.plist` 파일을 다운로드하여 `ios/Runner/` 디렉토리에 배치합니다.
-   [**Google Cloud 프로젝트에서 Gemini API 활성화 및 API 키 발급**](https://cloud.google.com/gemini/docs/reference/rest):
    -   Gemini API를 사용하도록 설정하고 API 키를 발급받습니다.

### ⚙️ 설치 및 실행 가이드

1.  **리포지토리 클론**:
    ```bash
    git clone https://github.com/Personal-Therapy/pt-flutter.git
    cd personal_therapy
    ```

2.  **환경 변수 설정**:
    -   프로젝트 루트 디렉토리에 `.env` 파일을 생성합니다. (`.gitignore`에 `.env`가 포함되어 있으므로 버전 관리 시스템에 업로드되지 않습니다.)
    -   발급받은 Gemini API 키를 다음과 같이 추가합니다:
        ```env
        GEMINI_API_KEY=당신의_발급받은_Gemini_API_키
        ```

3.  **의존성 설치**:
    ```bash
    flutter pub get
    ```

4.  **애플리케이션 실행**:
    ```bash
    flutter run
    ```
    또는 특정 기기에서 실행:
    ```bash
    flutter run -d <device_id>
    ```

## 🤝 기여하기

이 프로젝트에 대한 기여는 언제든지 환영합니다. 버그 보고, 기능 제안, 코드 개선 등 모든 형태의 참여를 기다립니다.

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 프로젝트의 `LICENSE` 파일을 참조하십시오.
