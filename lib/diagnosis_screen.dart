import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// main.dart에 있는 색상 상수들을 가져옵니다.
// (만약 별도 파일로 관리한다면 해당 파일을 import 하세요)
const Color kColorBgStart = Color(0xFFEFF6FF);
const Color kColorBgEnd = Color(0xFFFAF5FF);
const Color kColorTextTitle = Color(0xFF1F2937);
const Color kColorTextSubtitle = Color(0xFF4B5563);
const Color kColorTextLabel = Color(0xFF374151);
const Color kColorBtnPrimary = Color(0xFF2563EB); // Primary Blue
const Color kColorCardBg = Colors.white;

// RTF 파일에서 새로 정의된 색상들
const Color kPageBackground = Color(0xFFF9FAFB);
const Color kWarningCardBg = Color(0xFFF3F4F6);

/// 정신건강 진단 페이지 (RTF 파일 기준)
class DiagnosisScreen extends StatelessWidget {
  const DiagnosisScreen({Key? key}) : super(key: key);

  // [!!] 1. 검사 항목 리스트 (기존과 동일)
  static final List<DiagnosisTestItem> tests = [
    DiagnosisTestItem(
      title: '우울증 자가진단',
      description: '최근 2주간의 기분 상태를 바탕으로 우울 증상을 느껴왔는지 확인합니다.',
      iconAssetPath: 'assets/images/sad.png', // 사용할 아이콘 경로
      iconBgColor: Color(0xFFDBEAFE), // light blue
      destinationScreen: const DepressionTestScreen(),
    ),
    DiagnosisTestItem(
      title: '불안장애 자가진단',
      description: '일상생활에서 불안감과 걱정을 얼마나 자주 느끼는지 확인합니다.',
      iconAssetPath: 'assets/images/anxiety.png', // 사용할 아이콘 경로
      iconBgColor: Color(0xFFFEF3C7), // light yellow
      destinationScreen: const AnxietyTestScreen(),
    ),
    DiagnosisTestItem(
      title: '스트레스 자가진단',
      description: '최근 한 달간 스트레스 요인을 얼마나 많이 경험했는지 확인합니다.',
      iconAssetPath: 'assets/images/stress.png', // 사용할 아이콘 경로
      iconBgColor: Color(0xFFFEE2E2), // light red
      destinationScreen: const StressTestScreen(),
    ),
    DiagnosisTestItem(
      title: '자살위험성 평가',
      description: '현재 자신의 삶에 대해 어떻게 느끼는지, 위험성은 없는지 확인합니다.',
      iconAssetPath: 'assets/images/heart_pulse_icon.png', // 사용할 아이콘 경로
      iconBgColor: Color(0xFFE0E7FF), // light purple/indigo
      destinationScreen: const SuicideRiskTestScreen(),
    ),
  ];

  // 페이지 이동 헬퍼 함수
  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: kColorTextTitle,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '정신건강 진단',
          style: GoogleFonts.roboto(
            color: kColorTextTitle,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        // RTF 'DIV-3'의 padding: 80px 24px 24px
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        child: Column(
          children: [
            // 'DIV-4' (헤더 카드)
            _buildHeaderCard(),
            const SizedBox(height: 0),

            // [!!] 2. GridView -> ListView.separated로 변경
            // GridView.count(crossAxisCount: 1)은
            // childAspectRatio가 1.0(정사각형)으로 기본 설정되어 카드가 너무 커집니다.
            // 1열 목록은 ListView가 더 적합합니다.
            ListView.separated(
              shrinkWrap: true, // SingleChildScrollView 내부이므로
              physics: NeverScrollableScrollPhysics(), // 중첩 스크롤 방지
              itemCount: tests.length, // tests 리스트의 갯수만큼
              itemBuilder: (context, index) {
                final test = tests[index];
                // [!!] 3. _buildTestCard 호출 (기존과 동일)
                return _buildTestCard(
                  test: test,
                  onStart: () => _navigateTo(context, test.destinationScreen),
                );
              },
              // [!!] 4. 항목 사이에 16px 간격 추가
              separatorBuilder: (context, index) => const SizedBox(height: 16.0),
            ),
            const SizedBox(height: 1),

            // 'DIV-73' (주의사항 카드)
            _buildNoticeCard(),
          ],
        ),
      ),
    );
  }

  // 'DIV-4' (헤더 카드)
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: kColorCardBg,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '정신건강 진단',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kColorTextTitle,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            '현재 나의 마음 상태가 어떤 상태인지 확인해 보세요. 간단한 검사를 통해 도움을 받을 수 있습니다.',
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: kColorTextSubtitle,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // [!!] 4. 그리드 레이아웃에 맞게 수정된 공통 검사 카드
  Widget _buildTestCard({
    required DiagnosisTestItem test,
    required VoidCallback onStart,
  }) {
    return InkWell(
      onTap: onStart,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        width: double.infinity,
        // [!!] 5. 그리드 카드에 맞게 내부 패딩 조절
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: kColorCardBg,
          borderRadius: BorderRadius.circular(16.0),
        ),
        // [!!] 6. Column -> Row로 변경
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // 아이콘
            CircleAvatar(
              radius: 20, // [!!] 7. 아이콘 크기 조절 (24 -> 20)
              backgroundColor: test.iconBgColor,
              child: Image.asset(
                test.iconAssetPath,
                width: 45, // [!!] 8. 이미지 크기 조절 (30 -> 24)
                height: 45,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.psychology,
                    size: 24, // [!!] 9. 대체 아이콘 크기 조절
                    color: kColorTextSubtitle.withOpacity(0.6),
                  );
                },
              ),
            ),
            // [!!] 10. 가로 간격 추가
            const SizedBox(width: 12.0),
            // [!!] 11. 텍스트 영역을 Expanded로 감싸기
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    test.title,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: kColorTextTitle,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  // 설명 (기존과 동일)
                  Text(
                    test.description,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: kColorTextSubtitle,
                      height: 1.5,
                    ),
                    maxLines: 3, // 3줄까지만 보이도록 (옵션)
                    overflow: TextOverflow.ellipsis, // 3줄 넘어가면 ...
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 'DIV-73' (주의사항 카드)
  Widget _buildNoticeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kWarningCardBg,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: kColorTextSubtitle,
            size: 20,
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              '본 검사는 의학적 진단이 아니며, 참고용으로만 사용해 주세요. 정확한 진단은 전문의와 상담하세요.',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: kColorTextSubtitle,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// [!!] 9. 검사 항목 데이터를 담을 클래스 (기존과 동일)
// -------------------------------------------------------------------
class DiagnosisTestItem {
  final String title;
  final String description;
  final String iconAssetPath;
  final Color iconBgColor;
  final Widget destinationScreen;

  DiagnosisTestItem({
    required this.title,
    required this.description,
    required this.iconAssetPath,
    required this.iconBgColor,
    required this.destinationScreen,
  });
}


// -------------------------------------------------------------------
// [!!] 10. 임시 검사 페이지들 (기존과 동일)
// -------------------------------------------------------------------

class DepressionTestScreen extends StatelessWidget {
  const DepressionTestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('우울증 자가진단')),
      body: Center(child: Text('우울증 검사 페이지입니다.')),
    );
  }
}

class AnxietyTestScreen extends StatelessWidget {
  const AnxietyTestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('불안장애 자가진단')),
      body: Center(child: Text('불안장D/자D/진단')),
    );
  }
}

class StressTestScreen extends StatelessWidget {
  const StressTestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('스트레스 자가진단')),
      body: Center(child: Text('스트레스 검사 페이지입니다.')),
    );
  }
}

class SuicideRiskTestScreen extends StatelessWidget {
  const SuicideRiskTestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('자살위험성 평가')),
      body: Center(child: Text('자살위험성 평가 페이지입니다.')),
    );
  }
}