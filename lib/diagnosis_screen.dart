import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert'; // [!!] SurveyScreen에서 JSON 사용을 위해 추가 (이전 코드 기반)

// main.dart에 있는 색상 상수들을 가져오기
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

  //  1-1. 각 검사별 질문 리스트 (10개 항목) - 하드코딩한 부분 추후 DB 연동 예정
  // 우울증 자가진단
  static final List<String> depressionQuestions = [
    '나는 항상 게으르고 아무것도 하고 싶지 않다.',
    '지난 2주 동안 잠들기 어렵거나, 불안한 수면, 과도한 수면을 경험했다.',
    '나는 항상 아무도 나를 중요하게 생각하지 않는다고 느낀다.',
    '아침에 일어나면 미래를 기대한다.',
    '나는 매일 혼란 속에 있는 것 같다.',
    '내 미래는 희망이 없어 보인다.',
    '나는 결코 내 기준에 도달할 수 없을 것이다.',
    '나는 한때 나의 관심을 끌었던 일과 활동에 대한 관심을 잃었다.',
    '나는 나에게 가치가 없다고 느낀다.',
    '나는 내 인생을 끝내는 것에 대해 생각했다.'
  ];

  // 불안장애 자가진단
  static final List<String> anxietyQuestions = [
    '익숙하지 않은 사회적 상황에서도 편안함을 느낀다.',
    '사람들과 어울리는 모임에서 대개 차분하고 편안한다.',
    '잘 알지 못하는 사람에게 말을 거는 것이 부담스럽지 않다.',
    '모르는 사람들 속에 있어도 보통 마음이 불편하지 않다.',
    '사람을 처음 만날 때 대체로 편안함을 느낀다.',
    '사람들에게 소개될 때 대체로 더 잘보이려고 신경을 쓴다.',
    '방에 낯선 사람이 꽉 차 있어도 거리낌 없이 들어갈 수 있다.',
    '여러 사람들 앞에서 이야기 하는 것이 불편하지 않다.',
    '여럿이 있는 곳에서 내게 시선이 집중되는 것이 불편하지 않다.',
    '식당 등에서 큰소리로 종업원을 부르는 것이 어렵지 않다.'
  ];

  // 스트레스 자가진단
  static final List<String> stressQuestions = [
    '쉽게 짜증이 나고 기분의 변동이 심하다.',
    '피부가 거칠고 각종 피부 질환이 심해졌다.',
    '온 몸의 근육이 긴장되고 여기저기 쑤신다.',
    '잠을 잘 못 들거나 깊은 잠을 못 자고 자주 잠에서 깬다.',
    '매사에 자신감이 없고 자기비하를 많이 한다.',
    '별다른 이유없이 불안 초조하다.',
    '쉽게 피로감을 느낀다.',
    '매사에 집중이 잘 안되고 일(학습)의 능률이 떨어진다.',
    '식욕이 없어 잘 안 먹거나 갑자기 폭식을 한다.',
    '기억력이 나빠져 잘 잊어버린다.'
  ];

  // 자살 위험성 평가
  static final List<String> suicideRiskQuestions = [
    '최근에 삶이 더 이상 의미 없다고 느낀 적이 있다.',
    '잠들기 어렵거나 자주 깨는 등 수면에 문제가 있다.',
    '식욕이 크게 줄었거나 과하게 먹는 일이 많다.',
    '극심한 죄책감이나 무가치함을 자주 느낀다.',
    '스스로를 해치고 싶은 생각이 든 적이 있다.',
    '죽음이나 자살에 대해 구체적으로 생각해 본 적이 있다.',
    '최근 며칠 동안 집중하기 어렵거나 아무 일에도 흥미가 없다.',
    '나를 도와줄 사람이 없다고 느낀다.',
    '감정이 무뎌지거나 공허함을 자주 느낀다.',
    '최근 극심한 스트레스나 충격적인 사건을 경험했다.'
  ];

  // 1-2. 검사 항목 리스트
  static final List<DiagnosisTestItem> tests = [
    DiagnosisTestItem(
      title: '우울증 자가진단',
      description: '최근 2주간의 기분 상태를 바탕으로 우울 증상을 느껴왔는지 확인합니다.',
      iconAssetPath: 'assets/images/sad.png',
      iconBgColor: Color(0xFFDBEAFE),
      questions: depressionQuestions,
    ),
    DiagnosisTestItem(
      title: '불안장애 자가진단',
      description: '일상생활에서 불안감과 걱정을 얼마나 자주 느끼는지 확인합니다.',
      iconAssetPath: 'assets/images/anxiety.png',
      iconBgColor: Color(0xFFFEF3C7),
      questions: anxietyQuestions,
    ),
    DiagnosisTestItem(
      title: '스트레스 자가진단',
      description: '최근 한 달간 스트레스 요인을 얼마나 많이 경험했는지 확인합니다.',
      iconAssetPath: 'assets/images/stress.png',
      iconBgColor: Color(0xFFFEE2E2),
      questions: stressQuestions,
    ),
    DiagnosisTestItem(
      title: '자살위험성 평가',
      description: '현재 자신의 삶에 대해 어떻게 느끼는지, 위험성은 없는지 확인합니다.',
      iconAssetPath: 'assets/images/heart_pulse_icon.png',
      iconBgColor: Color(0xFFE0E7FF),
      questions: suicideRiskQuestions,
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
        padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
        child: Column(
          children: [
            // 'DIV-4' (헤더 카드)
            _buildHeaderCard(),

            // ListView.separated로 변경
            ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: tests.length,
              itemBuilder: (context, index) {
                final test = tests[index];
                // _buildTestCard 호출 (onStart 로직 변경)
                return _buildTestCard(
                  test: test,
                  // 'SurveyScreen'으로 'title'과 'questions'를 전달하며 이동
                  onStart: () => _navigateTo(
                    context,
                    SurveyScreen(
                      title: test.title,
                      questions: test.questions,
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 16.0),
            ),
            const SizedBox(height: 16), // 하단 여백 설정

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
      // 헤더 카드와 목록 사이 간격 조절
      margin: const EdgeInsets.only(bottom: 30.0),
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

// -------------------------------------------------------------------
// 5. 공통 검사 카드
// -------------------------------------------------------------------

  Widget _buildTestCard({
    required DiagnosisTestItem test,
    required VoidCallback onStart,
  }) {
    return InkWell(
      onTap: onStart,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: kColorCardBg,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // 아이콘
            CircleAvatar(
              radius: 20,
              backgroundColor: test.iconBgColor,
              child: Image.asset(
                test.iconAssetPath,
                width: 45,
                height: 45,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.psychology,
                    size: 24,
                    color: kColorTextSubtitle.withOpacity(0.6),
                  );
                },
              ),
            ),
            const SizedBox(width: 12.0),
            // 텍스트 영역
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
                  // 설명
                  Text(
                    test.description,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: kColorTextSubtitle,
                      height: 1.5,
                    ),
                    maxLines: 3,
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
// 6. 검사 항목 데이터를 담을 클래스
// -------------------------------------------------------------------
class DiagnosisTestItem {
  final String title;
  final String description;
  final String iconAssetPath;
  final Color iconBgColor;
  final List<String> questions;

  DiagnosisTestItem({
    required this.title,
    required this.description,
    required this.iconAssetPath,
    required this.iconBgColor,
    required this.questions,
  });
}


// -------------------------------------------------------------------
// 7. 새로운 공통 설문조사 페이지 (StatefulWidget)
// -------------------------------------------------------------------
class SurveyScreen extends StatefulWidget {
  final String title;
  final List<String> questions;

  const SurveyScreen({
    Key? key,
    required this.title,
    required this.questions,
  }) : super(key: key);

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  late List<int?> _answers;
  static const List<String> _options = [
    '전혀 그렇지 않다', // 1점
    '그렇지 않다',      // 2점
    '보통',             // 3점
    '그렇다',           // 4점
    '매우 그렇다',      // 5점
  ];

  @override
  void initState() {
    super.initState();
    _answers = List.filled(widget.questions.length, null);
  }

  void _handleSubmit() {
    if (_answers.any((answer) => answer == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모든 항목에 답변해주세요.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    int totalScore = _answers.fold(0, (sum, score) => sum + (score ?? 0));

    // --- (JSON 저장 로직 - 추후 작성 예정) ---
    // Map<String, dynamic> resultMap = {
    //   'testType': widget.title, // 또는 categoryKey
    //   'totalScore': totalScore,
    //   'timestamp': DateTime.now().toIso8601String(),
    //   'responses': []
    // };
    // for (int i = 0; i < widget.questions.length; i++) {
    //   resultMap['responses'].add({
    //     'questionText': widget.questions[i],
    //     'answer': _answers[i],
    //   });
    // }
    // String jsonResult = jsonEncode(resultMap);
    // print('--- 검사 결과 (JSON) ---');
    // print(jsonResult);
    // ----------------------------------------

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('검사 완료'),
        content: Text(
            '총점: $totalScore 점입니다.\n\n(주의: 본 검사는 의학적 진단이 아니며, 참고용으로만 사용해 주세요.)'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: kColorCardBg,
        foregroundColor: kColorTextTitle,
        elevation: 1,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: kColorTextTitle,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: kPageBackground,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: widget.questions.length,
              itemBuilder: (context, index) {
                return SurveyQuestionItem(
                  questionNumber: index + 1,
                  questionText: widget.questions[index],
                  options: _options,
                  selectedValue: _answers[index],
                  onChanged: (value) {
                    setState(() {
                      _answers[index] = value;
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorBtnPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _handleSubmit,
              child: Text(
                '결과 보기',
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// -------------------------------------------------------------------
// 8. 개별 질문 항목 위젯 (StatelessWidget)
// -------------------------------------------------------------------
class SurveyQuestionItem extends StatelessWidget {
  final int questionNumber;
  final String questionText;
  final List<String> options;
  final int? selectedValue;
  final ValueChanged<int?> onChanged;

  const SurveyQuestionItem({
    Key? key,
    required this.questionNumber,
    required this.questionText,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 1,
      color: kColorCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$questionNumber. $questionText',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: kColorTextTitle,
              ),
            ),
            const SizedBox(height: 12.0),
            Column(
              children: List.generate(options.length, (index) {
                final value = index + 1;
                final optionText = options[index];

                return RadioListTile<int>(
                  title: Text(
                    optionText,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: kColorTextLabel,
                    ),
                  ),
                  value: value,
                  groupValue: selectedValue,
                  onChanged: onChanged,
                  activeColor: kColorBtnPrimary,
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}