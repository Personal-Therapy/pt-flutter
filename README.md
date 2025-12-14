# Personal Therapy: 마음을 치유하는 Flutter 앱

Personal Therapy는 사용자의 정서적 웰빙을 증진시키고 정신 건강을 관리하는 데 도움을 주기 위해 설계된 Flutter 기반 모바일 애플리케이션입니다. 감정 추적, 건강 지표 모니터링, 그리고 개인화된 AI 상담 기능을 통해 사용자가 자신을 더 잘 이해하고 건강한 삶을 유지하도록 지원합니다.

## ✨ 주요 기능

-   **정서 상태 추적**:
    -   **감정 기록**: 일간, 주간, 월간 단위로 자신의 감정 변화를 기록하고 시각화하여 패턴을 파악할 수 있습니다.
    -   **감정 분포 분석**: AI 대화를 통한 감정 분석으로 긍정, 부정, 중립 감정의 분포를 확인합니다.
-   **정신건강 자가진단**:
    -   **우울증 자가진단**: 최근 2주간의 기분 상태를 바탕으로 우울 증상을 확인합니다.
    -   **불안장애 자가진단**: 일상생활에서 불안감과 걱정을 얼마나 자주 느끼는지 확인합니다.
    -   **스트레스 자가진단**: 최근 한 달간 스트레스 요인을 얼마나 많이 경험했는지 확인합니다.
    -   **자살위험성 평가**: 현재 자신의 삶에 대한 느낌과 위험성을 확인합니다.
    -   각 테스트는 10개 문항, 5점 리커트 척도로 구성되어 있습니다.
-   **건강 지표 모니터링**:
    -   **일일 종합 정신건강 점수**: 자가진단(40%), AI 대화 분석(30%), 생체신호(20%), 기분체크(10%)의 가중 평균으로 계산됩니다.
    -   **건강 점수**: 전반적인 건강 점수를 모니터링하고 추이 그래프를 통해 변화를 시각화합니다.
    -   **수면 시간**: 수면 시간을 기록하고, Firestore에 저장된 데이터를 기반으로 주간 평균 수면 시간을 분석하여 보여줍니다.
    -   **걸음 수**: 웨어러블 기기와, Health connect (Android) 연동을 통해 실시간 걸음 수를 확인합니다.
-   **AI 상담**:
    -   **Gemini AI 챗봇**: Google Gemini API를 활용하여 개인화된 AI 상담사와 대화하며 심리적 지원과 조언을 얻을 수 있습니다.
    -   **감정 분석**: 대화 내용을 분석하여 사용자의 감정 상태(기쁨, 슬픔, 분노, 불안, 평온)를 파악하고 기록합니다.
    -   **병렬 처리**: `Future.wait`를 활용하여 감정 분석과 AI 답변 생성을 동시에 실행하여 응답 속도를 최적화합니다.
    -   **대화 기록 저장**: 채팅 메시지가 Firestore에 저장되어 이전 대화를 불러올 수 있습니다.
-   **힐링 컨텐츠**:
    -   **YouTube 기반 힐링 영상**: 명상, 수면, ASMR 등 카테고리별 힐링 영상을 제공합니다.
    -   **개인화 추천**: PAD(Pleasure-Arousal-Dominance) 모델 기반으로 사용자의 정신건강 점수에 따라 맞춤형 콘텐츠를 추천합니다.
    -   **품질 필터링**: 긍정/부정 키워드 패턴 매칭을 통해 적절한 콘텐츠만 제공합니다.
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

### 📋 프로젝트 설정

-   [**Flutter SDK**] 설치 및 환경 설정 (버전 3.9.2 이상 권장).
-   [**Firebase 프로젝트 설정**]:
    -   새로운 Firebase 프로젝트 생성 또는 기존 프로젝트 사용.
    -   Flutter 앱을 Android 플랫폼에 등록합니다.
    -   Android: `google-services.json` 파일을 다운로드하여 `android/app/` 디렉토리에 배치합니다.
-   [**Google Cloud 프로젝트에서 Gemini API 활성화 및 API 키 발급**]:
    -   Gemini API를 사용하도록 설정하고 API 키를 발급받습니다.

### ⚙️ 설치 및 실행 가이드

1.  **리포지토리 클론**:
    ```bash
    git clone https://github.com/Personal-Therapy/pt-flutter.git
    cd personal_therapy
    ```

2.  **환경 변수 설정**:
    -   프로젝트 루트 디렉토리에 `.env` 파일을 생성합니다. (`.gitignore`에 `.env`가 포함되어 있으므로 버전 관리 시스템에 업로드되지 않습니다.)
    -   발급받은 API 키들을 다음과 같이 추가합니다:
        ```env
        GEMINI_API_KEY=당신의_발급받은_Gemini_API_키
        YOUTUBE_API_KEY=당신의_발급받은_YouTube_API_키
        ```
    -   **Gemini API**: AI 상담 기능에 사용됩니다.
    -   **YouTube API**: 힐링 컨텐츠 영상 검색 및 제공에 사용됩니다.

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
    

### 디렉터리 구조

```markdown
/personal_therapy
├── lib/                                    # Flutter 애플리케이션 소스 코드
│   ├── main.dart                           # 애플리케이션 진입점. Flutter 위젯 바인딩, Firebase 초기화, DotEnv 로딩을 처리합니다. 루트 위젯 (MyApp)을 설정합니다.
│   ├── auth_wrapper.dart                   # 애플리케이션의 인증 상태를 관리합니다. 사용자의 인증 상태에 따라 로그인 화면 또는 메인 애플리케이션으로 라우팅합니다.
│   ├── login_screen.dart                   # 사용자 로그인 인터페이스.
│   ├── signup_screen.dart                  # 사용자 회원가입 인터페이스.
│   ├── forgot_password_screen.dart         # 비밀번호 재설정 기능 인터페이스.
│   ├── main_screen.dart                    # 하단 내비게이션 바를 구현하며, 주요 애플리케이션 탭의 컨테이너 역할을 합니다.
│   │   ├── emotion_tracking_tab.dart       # 정서적 웰빙을 추적하고 시각화하는 대시보드.
│   │   │   ├── _buildDaily/Weekly/MonthlyContent # 선택된 시간 토글(일간, 주간, 월간)에 따라 특정 콘텐츠를 표시합니다.
│   │   │   ├── _buildDaily/WeeklyMetricChart # 기분 점수, 정신 건강 점수, 수면 시간 차트를 렌더링합니다.
│   │   │   ├── _buildAverageSummaryItem    # Firestore 스트림에서 평균값(예: 스트레스, 건강, 수면)을 동적으로 계산하고 표시하는 헬퍼 위젯입니다.
│   │   │   └── _buildQuickActionItem       # AI 채팅 또는 힐링 콘텐츠로 이동하는 것과 같은 빠른 액션 버튼을 위한 재사용 가능한 위젯입니다.
│   │   ├── diagnosis_screen.dart           # 정신 건강 평가 또는 진단 기능 전용 탭.
│   │   ├── healing_screen.dart             # 힐링 또는 치료 콘텐츠에 접근할 수 있는 탭.
│   │   ├── profile_tab.dart                # 사용자 프로필 관리 및 애플리케이션 설정.
│   │   │   ├── _buildHealthStatusCard      # 건강 점수, 평균 수면 시간, 걸음 수와 같은 현재 건강 통계를 표시합니다.
│   │   │   │   └── _showSleepTimeInputDialog # 사용자에게 수면 시간을 입력하고 저장할 수 있는 대화 상자.
│   │   │   └── StatusItem                  # 상태 아이콘, 제목, 값을 표시하기 위한 재사용 가능한 스테이트리스 위젯.
│   │   └── wearable_device_screen.dart     # 웨어러블 장치 연결 및 관리를 위한 탭.
│   ├── aichat_screen.dart                  # Google Gemini API로 구동되는 대화형 AI 채팅 인터페이스.
│   ├── personal_info_screen.dart           # 사용자가 개인 정보를 확인하고 수정하는 화면.
│   ├── health_result_page.dart             # 건강 검진 또는 평가의 상세 결과를 표시합니다.
│   ├── add_contact_sheet.dart              # 새로운 비상 연락처를 추가하기 위한 하단 시트 위젯.
│   ├── firebase_options.dart               # 플랫폼별 자동 생성된 Firebase 구성 파일.
│   └── services/                           # 외부 API 및 백엔드 시스템과의 상호 작용을 위한 서비스 클래스를 포함합니다.
│       ├── firestore_service.dart          # Firebase Firestore와의 모든 상호 작용을 관리하며, 사용자 데이터, 기분 점수, 정신 건강 점수 및 수면 기록에 대한 CRUD 작업을 포함합니다.
│       │   ├── getUserStream               # Firestore에서 사용자 프로필 데이터를 스트리밍합니다.
│       │   ├── updateMoodScore             # Firestore에 새로운 기분 점수 기록을 추가합니다.
│       │   ├── getMoodScoresStream         # 과거 기분 점수 기록을 스트리밍합니다.
│       │   ├── updateMentalHealthScore     # 새로운 정신 건강 점수 기록을 추가합니다.
│       │   ├── getMentalHealthScoresStream # 과거 정신 건강 점수 기록을 스트리밍합니다.
│       │   ├── addSleepRecord              # Firestore에 새로운 수면 시간 기록을 추가합니다.
│       │   └── getSleepScoresStream        # 과거 수면 시간 기록을 스트리밍합니다.
│       └── youtube_service.dart            # YouTube 콘텐츠 가져오기 또는 상호 작용을 위한 로직을 처리합니다 (주로 힐링 비디오용).
├── assets/                                 # 정적 애플리케이션 에셋 디렉토리.
│   └── images/                             # 애플리케이션 전체에서 사용되는 이미지 에셋을 저장합니다.
│       └── *.png                           # 예시 이미지 파일 (예: anxiety.png, google_logo.png).
├── .env                                    # 환경 변수 파일. `flutter_dotenv`가 런타임에 민감한 키(예: GEMINI_API_KEY)를 로드하는 데 사용합니다.
├── pubspec.yaml                            # 프로젝트 구성 파일. 프로젝트 메타데이터, 종속성 및 에셋 선언을 정의합니다.
├── pubspec.lock                            # 사용된 모든 종속성의 정확한 버전을 기록하는 자동 생성 파일.
├── README.md                               # 프로젝트 문서 및 설정 가이드.
├── android/                                # Android 특정 프로젝트 파일 및 구성.
│   ├── app/
│   │   └── google-services.json            # Android용 Firebase 구성 파일.
│   └── ...                                 # 기타 Android 빌드 파일 (build.gradle.kts, AndroidManifest.xml 등).
├── ios/                                    # iOS 특정 프로젝트 파일 및 구성.
│   ├── Runner/
│   │   └── GoogleService-Info.plist        # iOS용 Firebase 구성 파일.
│   └── ...                                 # 기타 iOS 빌드 파일 (Podfile, project.pbxproj, Info.plist 등).
├── macos/                                  # macOS 특정 프로젝트 파일.
├── linux/                                  # Linux 특정 프로젝트 파일.
├── web/                                    # 웹 특정 프로젝트 파일.
├── windows/                                # Windows 특정 프로젝트 파일.
└── ...                                     # 기타 프로젝트 구성 파일 (.gitignore, analysis_options.yaml, devtools_options.yaml 등).
```
