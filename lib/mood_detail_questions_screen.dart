import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:untitled/services/firestore_service.dart';

// 색상 정의
const Color kColorBgStart = Color(0xFFEFF6FF);
const Color kColorBgEnd = Color(0xFFFAF5FF);
const Color kColorTextTitle = Color(0xFF1F2937);
const Color kColorTextSubtitle = Color(0xFF4B5563);
const Color kColorBtnPrimary = Color(0xFF2563EB);
const Color kColorCardBg = Colors.white;
const Color kColorSelectedBorder = Color(0xFF8B5CF6); // 보라색
const Color kColorSelectedBg = Color(0xFFF3F4FF);

class MoodDetailQuestionsScreen extends StatefulWidget {
  final int moodScore;
  final String userId;

  const MoodDetailQuestionsScreen({
    super.key,
    required this.moodScore,
    required this.userId,
  });

  @override
  State<MoodDetailQuestionsScreen> createState() =>
      _MoodDetailQuestionsScreenState();
}

class _MoodDetailQuestionsScreenState extends State<MoodDetailQuestionsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isSubmitting = false;

  // 사용자 선택 저장 (질문 ID -> 선택된 답변 인덱스)
  final Map<String, int> _selectedAnswers = {};

  // 질문 데이터 구조
  late List<Map<String, dynamic>> _questions;

  @override
  void initState() {
    super.initState();
    _questions = _getQuestionsForScore(widget.moodScore);
  }

  // 기분 점수에 따른 질문 반환
  List<Map<String, dynamic>> _getQuestionsForScore(int score) {
    if (score >= 1 && score <= 3) {
      // 부정적 (1-3점): 4개 질문
      return [
        {
          'id': 'negative_reason',
          'type': 'category',
          'question': '기분이 좋지 않은 이유는 무엇인가요?',
          'options': [
            {'text': '업무/학업 스트레스', 'value': 'work'},
            {'text': '대인관계 문제', 'value': 'relationship'},
            {'text': '신체 건강 문제', 'value': 'health'},
            {'text': '경제적 어려움', 'value': 'financial'},
            {'text': '기타', 'value': 'other'},
          ],
        },
        {
          'id': 'negative_severity',
          'type': 'score',
          'question': '이러한 기분이 얼마나 심각한가요?',
          'options': [
            {'text': '매우 심각함', 'score': 1},
            {'text': '꽤 심각함', 'score': 2},
            {'text': '약간 힘듦', 'score': 3},
            {'text': '조금 불편함', 'score': 4},
          ],
        },
        {
          'id': 'negative_duration',
          'type': 'score',
          'question': '이런 기분이 얼마나 지속되었나요?',
          'options': [
            {'text': '2주 이상', 'score': 1},
            {'text': '1주일 정도', 'score': 2},
            {'text': '며칠', 'score': 3},
            {'text': '오늘만', 'score': 4},
          ],
        },
        {
          'id': 'negative_impact',
          'type': 'score',
          'question': '일상생활에 지장이 있나요?',
          'options': [
            {'text': '매우 큰 지장', 'score': 1},
            {'text': '상당한 지장', 'score': 2},
            {'text': '약간의 지장', 'score': 3},
            {'text': '거의 없음', 'score': 4},
          ],
        },
      ];
    } else if (score >= 4 && score <= 6) {
      // 보통 (4-6점): 3개 질문
      return [
        {
          'id': 'neutral_factor',
          'type': 'category',
          'question': '현재 기분에 가장 영향을 준 것은 무엇인가요?',
          'options': [
            {'text': '업무/학업', 'value': 'work'},
            {'text': '대인관계', 'value': 'relationship'},
            {'text': '건강 상태', 'value': 'health'},
            {'text': '일상 생활', 'value': 'daily_life'},
            {'text': '기타', 'value': 'other'},
          ],
        },
        {
          'id': 'neutral_day',
          'type': 'score',
          'question': '오늘 하루는 어떠셨나요?',
          'options': [
            {'text': '매우 힘들었음', 'score': 1},
            {'text': '조금 힘들었음', 'score': 2},
            {'text': '괜찮았음', 'score': 3},
            {'text': '좋았음', 'score': 4},
          ],
        },
        {
          'id': 'neutral_stress',
          'type': 'score',
          'question': '스트레스 관리는 잘 되고 있나요?',
          'options': [
            {'text': '전혀 안 됨', 'score': 1},
            {'text': '잘 안 됨', 'score': 2},
            {'text': '어느 정도 됨', 'score': 3},
            {'text': '잘 됨', 'score': 4},
          ],
        },
      ];
    } else {
      // 긍정적 (7-10점): 3개 질문
      return [
        {
          'id': 'positive_reason',
          'type': 'category',
          'question': '기분이 좋은 이유는 무엇인가요?',
          'options': [
            {'text': '성취/성공', 'value': 'achievement'},
            {'text': '좋은 관계', 'value': 'relationship'},
            {'text': '건강 개선', 'value': 'health'},
            {'text': '취미/여가', 'value': 'hobby'},
            {'text': '기타', 'value': 'other'},
          ],
        },
        {
          'id': 'positive_duration',
          'type': 'score',
          'question': '이런 긍정적인 기분이 얼마나 지속되었나요?',
          'options': [
            {'text': '여러 날', 'score': 4},
            {'text': '며칠', 'score': 3},
            {'text': '오늘만', 'score': 2},
            {'text': '잠시만', 'score': 1},
          ],
        },
        {
          'id': 'positive_maintain',
          'type': 'score',
          'question': '이런 좋은 기분을 유지할 수 있을 것 같나요?',
          'options': [
            {'text': '확신함', 'score': 4},
            {'text': '그럴 것 같음', 'score': 3},
            {'text': '잘 모르겠음', 'score': 2},
            {'text': '어려울 것 같음', 'score': 1},
          ],
        },
      ];
    }
  }

  // 모든 질문에 답변했는지 확인
  bool _allQuestionsAnswered() {
    return _selectedAnswers.length == _questions.length;
  }

  // 제출 처리
  Future<void> _submitAnswers() async {
    if (!_allQuestionsAnswered()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모든 질문에 답변해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // detailedAnswers 구성 (선택한 답변 텍스트)
      final Map<String, dynamic> detailedAnswers = {};

      // categories 구성 (카테고리형 질문의 value)
      final Map<String, String> categories = {};

      // 점수형 질문들의 점수 합산
      final List<int> scores = [];

      for (int i = 0; i < _questions.length; i++) {
        final question = _questions[i];
        final selectedIndex = _selectedAnswers[question['id']]!;
        final selectedOption = question['options'][selectedIndex];

        // 답변 텍스트 저장
        detailedAnswers[question['id']] = selectedOption['text'];

        if (question['type'] == 'category') {
          // 카테고리 저장
          categories[question['id']] = selectedOption['value'];
        } else if (question['type'] == 'score') {
          // 점수 수집
          scores.add(selectedOption['score'] as int);
        }
      }

      // 평균 점수 계산
      final double detailScore = scores.isNotEmpty
          ? scores.reduce((a, b) => a + b) / scores.length
          : 0.0;

      // Firestore에 저장
      await _firestoreService.updateMoodScore(
        widget.userId,
        widget.moodScore,
        detailedAnswers: detailedAnswers,
        detailScore: detailScore,
        categories: categories,
      );

      if (mounted) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('기분 분석이 저장되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );

        // 화면 닫기
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kColorBgStart, kColorBgEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 커스텀 AppBar
              _buildAppBar(),

              // 질문 리스트
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더
                      Text(
                        '기분 분석',
                        style: GoogleFonts.roboto(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: kColorTextTitle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '몇 가지 질문에 답변하여 더 정확한 분석을 받아보세요.',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: kColorTextSubtitle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: kColorBtnPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '현재 기분: ${widget.moodScore}/10',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: kColorBtnPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 질문들
                      ..._questions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final question = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: _buildQuestionCard(
                            questionNumber: index + 1,
                            question: question,
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // 제출 버튼
                      _buildSubmitButton(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: kColorTextSubtitle),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'Personal Therapy',
            style: GoogleFonts.pacifico(
              fontSize: 20,
              color: kColorTextTitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required int questionNumber,
    required Map<String, dynamic> question,
  }) {
    return Card(
      elevation: 2,
      color: kColorCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 질문 번호와 텍스트
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: kColorBtnPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '$questionNumber',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question['question'],
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kColorTextTitle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 선택지들
            ...List.generate(
              question['options'].length,
              (index) => _buildOptionTile(
                questionId: question['id'],
                optionIndex: index,
                optionText: question['options'][index]['text'],
                isSelected: _selectedAnswers[question['id']] == index,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String questionId,
    required int optionIndex,
    required String optionText,
    required bool isSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedAnswers[questionId] = optionIndex;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? kColorSelectedBg : Colors.grey[50],
            border: Border.all(
              color: isSelected ? kColorSelectedBorder : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // 라디오 버튼 스타일 아이콘
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? kColorSelectedBorder : Colors.white,
                  border: Border.all(
                    color: isSelected ? kColorSelectedBorder : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  optionText,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: isSelected ? kColorTextTitle : kColorTextSubtitle,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final allAnswered = _allQuestionsAnswered();

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (_isSubmitting || !allAnswered) ? null : _submitAnswers,
        style: ElevatedButton.styleFrom(
          backgroundColor: kColorBtnPrimary,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                '분석 완료',
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: allAnswered ? Colors.white : Colors.grey[600],
                ),
              ),
      ),
    );
  }
}
