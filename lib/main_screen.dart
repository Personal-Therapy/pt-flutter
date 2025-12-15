import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io'; // Platform detection
import 'package:google_fonts/google_fonts.dart';
import 'package:untitled/profile_tab.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// [!!] 파일 임포트 복구
import 'package:untitled/wearable_device_screen.dart'; // 웨어러블 화면
import 'package:untitled/services/health_service.dart'; // 헬스 서비스
import 'emotion_tracking_tab.dart';
import 'healing_screen.dart';
import 'diagnosis_screen.dart';
import 'mood_detail_questions_screen.dart'; // 기분 상세 질문 화면
import 'aichat_screen.dart';
import 'package:untitled/services/healing_recommendation_service.dart';
import 'package:untitled/services/firestore_service.dart';


// --- Color Definitions ---
const Color kColorBgStart = Color(0xFFEFF6FF);
const Color kColorBgEnd = Color(0xFFFAF5FF);
const Color kColorTextTitle = Color(0xFF1F2937);
const Color kColorTextSubtitle = Color(0xFF4B5563);
const Color kColorTextLabel = Color(0xFF374151);
const Color kColorTextHint = Color(0xFF9CA3AF);
const Color kColorTextLink = Color(0xFF2563EB);
const Color kColorBtnPrimary = Color(0xFF2563EB);
const Color kColorEditTextBg = Color(0xFFF3F4F6);
const Color kColorError = Color(0xFFEF4444);

// --- NEW Colors for Main Screen ---
const Color kColorCardBg = Colors.white;
const Color kColorMoodSliderActive = kColorBtnPrimary;
const Color kColorMoodSliderInactive = Color(0xFFD1D5DB);
const Color kColorAccentIconBg = Color(0xFFF3F4FF);
const Color kColorEmergencyCardBg = Color(0xFFFEE2E2);
const Color kColorEmergencyBtnText = Color(0xFFEF4444);
const Color kColorEmergencyBtnBorder = Color(0xFFEF4444);
const Color kColorBottomNavInactive = Color(0xFF9CA3AF);

bool _isMoodSelected = false;

// CSV 텍스트 데이터
final Map<String, String> kTexts = {
  'main_greeting': '안녕하세요!',
  'main_subtitle': '오늘 하루는 어떠셨나요? 마음의 건강을 함께 돌봐드릴게요.',
  'mood_check_title': '빠른 기분 체크',
  'mood_check_description': '현재 기분을 1-10으로 표현해주세요',
  'mood_analyze_button': '기분 분석하기',
  'mental_health_title': '정신건강 진단',
  'mental_health_subtitle': '전문적인 심리 상태\n체크',
  // 'healing_content_title': '힐링 콘텐츠', // (제거됨)
  // 'healing_content_subtitle': '맞춤형 치유\n콘텐츠', // (제거됨)
  'wearable_device_title': '웨어러블 기기 연동', // [!!] 2.1 추가
  'wearable_device_subtitle': '활동, 수면, 심박수\n데이터 연동', // [!!] 2.2 추가
  'today_healing_title': '오늘의 힐링',
  'today_healing_video_title': '5분 명상으로 마음 정리하기',
  'today_healing_video_description': '스트레스를 줄이고 마음의 평화를 찾는 간단한 명상법을 배워보세요.',
  'emergency_title': '긴급 상황 시',
  'emergency_warning': '위기 상황이거나 즉시 도움이 필요하시다면 주저하지 마시고 연락하세요.',
  'emergency_call_button': '생명의전화 1393',
  'emergency_chat_button': '전문가와 즉시 상담',
  'nav_home': '홈',
  'nav_chat': '상담',
  'nav_stats': '추적',
  'nav_profile': '프로필',
};

/// 탭을 관리하는 메인 스크린 (허브 역할)
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // [복구] 헬스 서비스 인스턴스 및 권한 요청 변수
  final HealthService _healthService = HealthService();
  bool _healthPermissionRequested = false;

  // 뒤로가기 버튼 두 번 클릭으로 앱 종료
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    // [복구] 로그인 성공 시 앱 시작 단계에서 권한 요청
    _requestHealthPermissions();
  }

  /// [복구] 앱 시작 시 모든 Health 권한을 한번에 요청하는 로직
  Future<void> _requestHealthPermissions() async {
    if (_healthPermissionRequested) return;
    _healthPermissionRequested = true;

    try {
      if (Platform.isAndroid) {
        final status = await _healthService.checkHealthConnectStatus();
        if (status.toString().contains('unavailable')) {
          print('Health Connect가 설치되지 않았습니다.');
          return;
        }
      }

      print('🔐 앱 시작: 모든 Health 권한 요청 시작...');
      bool authorized = await _healthService.requestAuthorization();

      if (authorized) {
        print('✅ 모든 Health 권한이 허용되었습니다.');
      } else {
        print('⚠️ Health 권한이 거부되었습니다.');
      }
    } catch (e) {
      print('❌ Health 권한 요청 실패: $e');
    }
  }

  static final List<Widget> _pages = <Widget>[
    const _HomeScreenContent(),
    const AIChatScreen(),
    Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        title: Text(
          '감정 추적',
          style: GoogleFonts.roboto(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: const EmotionTrackingTab(),
    ),
    Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        title: Text(
          '프로필',
          style: GoogleFonts.roboto(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: const ProfileTab(),
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 홈 탭이 아니면 홈 탭으로 이동
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return;
        }

        // 홈 탭에서 뒤로가기: 2초 이내 두 번 클릭 시 앱 종료
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '한 번 더 누르면 종료됩니다',
                style: GoogleFonts.roboto(),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // 2초 이내 두 번째 클릭: 앱 종료
        SystemNavigator.pop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: _selectedIndex == 0,
        appBar: _selectedIndex == 0 ? _buildHomeAppBar() : null,
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: _buildBottomNavigationBar(),
      ),
    );
  }

  PreferredSizeWidget _buildHomeAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60.0),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // 뒤로가기 버튼 제거
        title: Text(
          'Personal Therapy',
          style: GoogleFonts.pacifico(
            color: kColorTextTitle,
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
        centerTitle: false,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, 0.9),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 2.0,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1.0,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.transparent,
        selectedItemColor: kColorBtnPrimary,
        unselectedItemColor: kColorBottomNavInactive,
        selectedLabelStyle:
        GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.roboto(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: kTexts['nav_home']!,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            label: kTexts['nav_chat']!,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart),
            label: kTexts['nav_stats']!,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: kTexts['nav_profile']!,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// 홈 탭 콘텐츠
// ---------------------------------------------------------------
class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent({super.key});

  @override
  _HomeScreenContentState createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent> {
  double _currentMoodValue = 5.0;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final HealingRecommendationService _healingService =
  HealingRecommendationService();
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, String>? _todayHealingVideo;
  bool _loadingHealing = true;

  @override
  void initState() {
    super.initState();
    _loadTodayHealing();
  }

  Future<void> _loadTodayHealing() async {
    if (_currentUserId == null) {
      setState(() => _loadingHealing = false);
      return;
    }

    try {
      int? score = await _firestoreService.getTodayOverallScore(_currentUserId!);

      // 오늘 점수 없으면 기본값
      score ??= 65;

      print(' [홈] 오늘의 힐링 점수 사용값 = $score');

      final videos = await _healingService.getHealingRecommendations(userScore: score);

      setState(() {
        _todayHealingVideo = videos.isNotEmpty ? videos.first : null;
        _loadingHealing = false;
      });
    } catch (e) {
      debugPrint('오늘의 힐링 로드 실패: $e');
      setState(() => _loadingHealing = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kColorBgStart, kColorBgEnd],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 80.0, 24.0, 96.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kTexts['main_greeting']!,
                  style: GoogleFonts.roboto(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kColorTextTitle,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  kTexts['main_subtitle']!,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: kColorTextSubtitle,
                  ),
                ),
                const SizedBox(height: 32.0),

                _buildMoodCheckCard(),
                const SizedBox(height: 24.0),

                IntrinsicHeight( // <-- 1. IntrinsicHeight 추가
                  child: Row(
                    // [수정] stretch를 사용하여 자식 위젯들이 IntrinsicHeight에 맞춰 늘어나도록 합니다.
                    crossAxisAlignment: CrossAxisAlignment.stretch, // <-- 2. stretch 설정
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16.0),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DiagnosisScreen(),
                              ),
                            );
                          },
                          child: _buildSmallFeatureCard(
                            iconWidget: Image.asset(
                              'assets/images/heart_pulse_icon.png',
                              width: 48.0,
                              height: 48.0,
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error_outline,
                                  color: kColorError, size: 48.0),
                            ),
                            title: kTexts['mental_health_title']!,
                            subtitle: kTexts['mental_health_subtitle']!,
                          ),
                        ),
                      ),
                      // [수정] 카드 사이 간격을 5.0에서 16.0으로 넓혀 더 균형 있게 만듭니다.
                      const SizedBox(width: 16.0), // <-- 3. 간격 조정 (선택 사항)
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const WearableDeviceScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(16.0),
                          child: _buildSmallFeatureCard(
                            iconWidget: Image.asset(
                              'assets/images/icon_watch.png',
                              width: 30.0, // 아이콘 크기 통일을 위해 수정 (기존 30.0 -> 48.0 권장)
                              height: 30.0, // 아이콘 크기 통일을 위해 수정 (기존 30.0 -> 48.0 권장)
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.watch,
                                  color: kColorError, size: 48.0),
                            ),
                            title: kTexts['wearable_device_title']!,
                            subtitle: kTexts['wearable_device_subtitle']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ), // <-- 4. IntrinsicHeight 닫기
                const SizedBox(height: 24.0),

                Text(
                  kTexts['today_healing_title']!,
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kColorTextTitle,
                  ),
                ),
                const SizedBox(height: 16.0),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HealingScreen()),
                    );
                  },
                  child: _buildTodayHealingCard(),
                ),
                const SizedBox(height: 24.0),

                _buildEmergencyCard(),
              ],
            ),
          ),
        ),
      ],
    );


  }

  Widget _buildMoodCheckCard() {
    return Card(
      elevation: 2.0,
      color: kColorCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              kTexts['mood_check_title']!,
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kColorTextTitle,
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              kTexts['mood_check_description']!,
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: kColorTextSubtitle,
              ),
            ),
            const SizedBox(height: 16.0),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6.0,
                activeTrackColor: kColorMoodSliderActive,
                inactiveTrackColor: kColorMoodSliderInactive,
                thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                thumbColor: kColorBtnPrimary,
                overlayColor: kColorBtnPrimary.withOpacity(0.2),
                overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 16.0),
                valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                valueIndicatorColor: kColorBtnPrimary,
                valueIndicatorTextStyle: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Slider(
                min: 1,
                max: 10,
                divisions: 9,
                value: _currentMoodValue,
                label: _currentMoodValue.round().toString(),
                onChanged: (value) {
                  setState(() {
                    _currentMoodValue = value;
                    _isMoodSelected = true;
                  });
                },
              ),
            ),
            Text(
              _currentMoodValue.round().toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kColorTextTitle,
              ),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: (_currentUserId == null || !_isMoodSelected)
                  ? null
                  : () {
                // [복구] 기분 분석 상세 질문 화면으로 이동하는 로직으로 복구
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MoodDetailQuestionsScreen(
                      moodScore: _currentMoodValue.round(),
                      userId: _currentUserId,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorBtnPrimary,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                minimumSize: const Size(double.infinity, 45),
              ),
              child: Text(
                kTexts['mood_analyze_button']!,
                style: GoogleFonts.roboto(
                  color: (_currentUserId == null || !_isMoodSelected)
                      ? Colors.grey[600]
                      : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallFeatureCard({
    required Widget iconWidget,
    required String title,
    required String subtitle,
  }) {
    return Card(
      elevation: 2.0,
      color: kColorCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            iconWidget,
            const SizedBox(height: 16.0),
            Text(
              title,
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kColorTextTitle,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              subtitle,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: kColorTextSubtitle,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayHealingCard() {
    if (_loadingHealing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_todayHealingVideo == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.video_library_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  '오늘의 힐링 콘텐츠가 없습니다.',
                  style: GoogleFonts.roboto(color: kColorTextSubtitle),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final video = _todayHealingVideo!;

    return GestureDetector(
      onTap: () {
        // 바로 유튜브 영상 재생 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => YoutubePlayerPage(
              videoId: video['id'] ?? '',
              title: video['title'] ?? '',
            ),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    video['thumb'] ?? '',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image, size: 50)),
                    ),
                  ),
                ),
                // 재생 버튼 표시
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video['title'] ?? '',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kColorTextTitle,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    video['desc'] ?? '',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: kColorTextSubtitle,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: kColorEmergencyCardBg,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.call, color: kColorEmergencyBtnText, size: 20),
              const SizedBox(width: 8.0),
              Text(
                kTexts['emergency_title']!,
                style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kColorTextTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          Text(
            kTexts['emergency_warning']!,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: kColorTextSubtitle,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24.0),
          ElevatedButton(
            onPressed: () {
              // TODO: 생명의전화 연결 로직
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kColorEmergencyBtnText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              minimumSize: const Size(double.infinity, 45),
            ),
            child: Text(
              kTexts['emergency_call_button']!,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          OutlinedButton(
            onPressed: () {
              // TODO: 전문가와 즉시 상담 로직
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: kColorEmergencyBtnText,
              side: const BorderSide(color: kColorEmergencyBtnBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              minimumSize: const Size(double.infinity, 45),
            ),
            child: Text(
              kTexts['emergency_chat_button']!,
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}