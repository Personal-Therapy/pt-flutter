import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/profile_tab.dart';
import 'package:untitled/services/firestore_service.dart';

// [!!] 1단계에서 만든 '추적' 탭 파일을 가져옵니다.
import 'emotion_tracking_tab.dart';
import 'healing_screen.dart';
import 'diagnosis_screen.dart';

//ai채팅 탭
import 'aichat_screen.dart';
// --- Color Definitions ---
const Color kColorBgStart = Color(0xFFEFF6FF);
const Color kColorBgEnd = Color(0xFFFAF5FF);
const Color kColorTextTitle = Color(0xFF1F2937);
const Color kColorTextSubtitle = Color(0xFF4B5563);
const Color kColorTextLabel = Color(0xFF374151);
const Color kColorTextHint = Color(0xFF9CA3AF);
const Color kColorTextLink = Color(0xFF2563EB); // Primary Blue
const Color kColorBtnPrimary = Color(0xFF2563EB); // Primary Blue
const Color kColorEditTextBg = Color(0xFFF3F4F6); // Light Gray for text fields
const Color kColorError = Color(0xFFEF4444); // Red for error messages

// --- NEW Colors for Main Screen ---
const Color kColorCardBg = Colors.white; // 카드 배경색
const Color kColorMoodSliderActive = kColorBtnPrimary; // 슬라이더 활성 색상
const Color kColorMoodSliderInactive = Color(0xFFD1D5DB); // 슬라이더 비활성 색상
const Color kColorAccentIconBg = Color(0xFFF3F4FF); // 작은 카드 아이콘 배경
const Color kColorEmergencyCardBg = Color(0xFFFEE2E2); // 긴급 상황 카드 배경 (연한 빨강)
const Color kColorEmergencyBtnText = Color(0xFFEF4444); // 긴급 버튼 텍스트 (진한 빨강)
const Color kColorEmergencyBtnBorder = Color(0xFFEF4444); // 긴급 버튼 테두리 (진한 빨강)
const Color kColorBottomNavInactive = Color(0xFF9CA3AF); // 하단바 비활성 아이콘/텍스트

// CSV 텍스트 데이터 (동일)
final Map<String, String> kTexts = {
  'main_greeting': '안녕하세요!',
  'main_subtitle': '오늘 하루는 어떠셨나요? 마음의 건강을 함께 돌봐드릴게요.',
  'mood_check_title': '빠른 기분 체크',
  'mood_check_description': '현재 기분을 1-10으로 표현해주세요',
  'mood_analyze_button': '기분 분석하기',
  'mental_health_title': '정신건강 진단',
  'mental_health_subtitle': '전문적인 심리 상태\n체크',
  'healing_content_title': '힐링 콘텐츠',
  'healing_content_subtitle': '맞춤형 치유\n콘텐츠',
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

// [!!] '상담'과 '프로필' 탭을 위한 임시 화면입니다.
class PlaceholderTab extends StatelessWidget {
  final String title;
  const PlaceholderTab({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.roboto(color: kColorTextTitle)),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          '$title 페이지',
          style: GoogleFonts.roboto(fontSize: 24, color: kColorTextSubtitle),
        ),
      ),
    );
  }
}


/// 탭을 관리하는 메인 스크린 (허브 역할)
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // [!!] '홈' 탭의 슬라이더 값(_currentMoodValue)은
  // 이제 _HomeScreenContent 위젯 내부에서 관리합니다.
  int _selectedIndex = 0; // '홈' 탭을 기본값으로 설정

  // [!!] 각 탭에 보여줄 페이지 위젯 리스트입니다.
  static final List<Widget> _pages = <Widget>[
    // 0: 홈 탭 (디자인 보존을 위해 별도 위젯으로 분리)
    const _HomeScreenContent(),
    // 1: 상담 탭
    const AIChatScreen(),
    // 2: 추적 탭 (파일 1에서 만든 위젯)
    // '추적' 탭은 자체 디자인에 맞는 AppBar가 필요합니다.
    Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // 추적 탭 배경색
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB), // 추적 탭 배경색과 맞춤
        elevation: 0,
        title: Text(
          '감정 추적',
          style: GoogleFonts.roboto( // 폰트 통일
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: const EmotionTrackingTab(), // '추적' 탭의 내용물
    ),
// [!!!] 3: 프로필 탭 수정 [!!!]
    Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // (프로필 배경색)
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        title: Text(
          '프로필', // (프로필 앱바 제목)
          style: GoogleFonts.roboto(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: const ProfileTab(), // 👈 [!!] 2. PlaceholderTab을 ProfileTab으로 교체!
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // [!!] '홈' 탭(index 0)일 때만 배경이 AppBar 뒤로 확장되도록 합니다.
    return Scaffold(
      extendBodyBehindAppBar: _selectedIndex == 0,
      // [!!] '홈' 탭(index 0)일 때만 기존의 블러 AppBar를,
      // 그 외 탭에서는 null (각자 AppBar를 갖도록)
      appBar: _selectedIndex == 0 ? _buildHomeAppBar() : null,

      // [!!] IndexedStack을 사용하여 탭 전환 시 각 탭의 상태를 보존합니다.
      // (예: '홈' 탭의 스크롤 위치, 슬라이더 값)
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      // 하단 네비게이션 바는 기존 코드 그대로 사용합니다.
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // '홈' 탭 전용 AppBar (기존 코드와 동일)
  PreferredSizeWidget _buildHomeAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60.0),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kColorTextSubtitle),
          onPressed: () => Navigator.pop(context),
        ),
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

  // 하단 네비게이션 바 (기존 코드와 동일)
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
// [!!] '홈' 탭의 모든 UI와 상태를 이 위젯이 관리합니다.
// ---------------------------------------------------------------
class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent({Key? key}) : super(key: key);

  @override
  _HomeScreenContentState createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent> {
  // '홈' 탭의 슬라이더 상태를 여기서 관리
  double _currentMoodValue = 5.0;

  @override
  Widget build(BuildContext context) {
    // 기존 MainScreen의 'body'가 이곳으로 왔습니다.
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
        // AppBar 영역을 확보하기 위해 Padding을 줍니다.
        Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight),
          child: SingleChildScrollView(
            // 기존 padding 값 (상단 80px)은 AppBar가 투명하다는 전제였습니다.
            // AppBar 높이(kToolbarHeight) + 추가 여백(80)
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

                // '홈' 탭의 카드들 (이제 이 위젯의 메서드를 호출)
                _buildMoodCheckCard(),
                const SizedBox(height: 24.0),

                Row(
                  children: [
                    // [!!!] 2. '정신건강 진단' 카드를 InkWell로 감쌉니다. [!!!]
                    Expanded(
                      child: InkWell(
                        // [!!] 3. 둥근 모서리 효과를 위해 추가
                        borderRadius: BorderRadius.circular(16.0),
                        // [!!] 4. onTap 이벤트 추가
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
                    const SizedBox(width: 16.0),
// [!!!] 2. '힐링 콘텐츠' 카드를 InkWell로 감쌉니다. [!!!]
                    Expanded(
                      child: InkWell(
                        // [!] 힐링 스크린으로 이동하는 로직
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HealingScreen()),
                          );
                        },
                        // [!] 카드의 둥근 모서리와 물결 효과를 맞춤
                        borderRadius: BorderRadius.circular(16.0),
                        child: _buildSmallFeatureCard(
                          iconWidget: Image.asset(
                            'assets/images/heart.png',
                            width: 48.0,
                            height: 48.0,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.error_outline,
                                color: kColorError, size: 48.0),
                          ),
                          title: kTexts['healing_content_title']!,
                          subtitle: kTexts['healing_content_subtitle']!,
                        ),
                      ),
                    ),
                  ],
                ),
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
                _buildTodayHealingCard(),
                const SizedBox(height: 24.0),

                _buildEmergencyCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- '홈' 탭 전용 헬퍼 메서드들 ---
  // (모두 _HomeScreenContentState 안으로 이동)

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
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                thumbColor: kColorBtnPrimary,
                overlayColor: kColorBtnPrimary.withOpacity(0.2),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
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
                  // [!!] 이 위젯(_HomeScreenContent)의 상태를 업데이트
                  setState(() {
                    _currentMoodValue = value;
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
              onPressed: () async {
                // 슬라이더 값(1-10)을 100점 만점으로 변환
                final int moodScore = (_currentMoodValue * 10).round();
                debugPrint('[MOOD_CHECK] 슬라이더 값: ${_currentMoodValue.round()} / 10');
                debugPrint('[MOOD_CHECK] 기분 점수: $moodScore / 100');

                // Firestore에 저장
                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId != null) {
                  final firestoreService = FirestoreService();
                  await firestoreService.updateDailyMentalStatus(
                    uid: userId,
                    moodCheckScore: moodScore,
                  );
                  debugPrint('[MOOD_CHECK] Firestore 저장 완료!');
                } else {
                  debugPrint('[MOOD_CHECK] 로그인되지 않음 - 저장 실패');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorBtnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                minimumSize: const Size(double.infinity, 45),
              ),
              child: Text(
                kTexts['mood_analyze_button']!,
                style: GoogleFonts.roboto(
                  color: Colors.white,
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
    return Card(
      elevation: 2.0,
      color: kColorCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16.0)),
                child: Image.network(
                  'https://placehold.co/600x300/E0E7FF/1F2937?text=Video+Thumbnail', // Placeholder 이미지
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: Center(
                        child: Icon(Icons.video_call_outlined,
                            color: Colors.grey[400], size: 50)),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: 영상 재생 로직
                },
                child: const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kTexts['today_healing_video_title']!,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kColorTextTitle,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  kTexts['today_healing_video_description']!,
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
} // [!!] _HomeScreenContentState 끝