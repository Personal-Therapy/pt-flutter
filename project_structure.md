# 프로젝트 구조: Personal Therapy (Flutter 애플리케이션)

이 문서는 Personal Therapy Flutter 애플리케이션의 고수준 아키텍처와 주요 구성 요소를 설명합니다.

```
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
