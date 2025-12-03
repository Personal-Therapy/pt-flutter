import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/firestore_service.dart';

class MoodDetailQuestionsScreen extends StatefulWidget {
  final int moodScore;
  final String userId;

  const MoodDetailQuestionsScreen({
    Key? key,
    required this.moodScore,
    required this.userId,
  }) : super(key: key);

  @override
  State<MoodDetailQuestionsScreen> createState() =>
      _MoodDetailQuestionsScreenState();
}

class _MoodDetailQuestionsScreenState extends State<MoodDetailQuestionsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, Map<String, dynamic>> _answers = {}; // 답변과 점수를 함께 저장
  bool _isSubmitting = false;

  // 색상 상수 (main_screen.dart와 동일하게 사용)
  static const Color kColorBtnPrimary = Color(0xFF6B4EFF);
  static const Color kColorCardBg = Colors.white;
  static const Color kColorTextTitle = Color(0xFF2D3142);
  static const Color kColorTextSubtitle = Color(0xFF7D8CA3);

  List<Map<String, dynamic>> _getQuestions() {
    // 기분 점수에 따라 다른 질문 반환
    if (widget.moodScore >= 1 && widget.moodScore <= 3) {
      // 부정적인 기분 (1-3점)
      return [
        {
          'id': 'negative_reason',
          'question': '오늘 기분이 좋지 않은 가장 큰 이유는 무엇인가요?',
          'options': [
            {'text': '업무/학업 스트레스', 'score': 1},
            {'text': '대인관계 문제', 'score': 2},
            {'text': '건강/신체 문제', 'score': 3},
            {'text': '경제적 어려움', 'score': 2},
            {'text': '미래에 대한 불안', 'score': 1},
          ]
        },
        {
          'id': 'negative_intensity',
          'question': '이런 감정이 얼마나 오래 지속되었나요?',
          'options': [
            {'text': '오늘 처음 느꼈어요', 'score': 4},
            {'text': '2-3일 정도', 'score': 3},
            {'text': '일주일 정도', 'score': 2},
            {'text': '2주 이상', 'score': 1},
          ]
        },
        {
          'id': 'negative_physical',
          'question': '신체적으로 느끼는 증상이 있나요?',
          'options': [
            {'text': '수면 문제 (불면증/과수면)', 'score': 1},
            {'text': '식욕 변화', 'score': 2},
            {'text': '두통이나 몸의 통증', 'score': 2},
            {'text': '특별한 증상 없음', 'score': 4},
          ]
        },
        {
          'id': 'negative_help',
          'question': '지금 가장 필요한 것은 무엇인가요?',
          'options': [
            {'text': '혼자만의 시간과 휴식', 'score': 3},
            {'text': '누군가와 대화', 'score': 3},
            {'text': '전문가 상담', 'score': 1},
            {'text': '잘 모르겠어요', 'score': 2},
          ]
        },
      ];
    } else if (widget.moodScore >= 4 && widget.moodScore <= 6) {
      // 보통 기분 (4-6점)
      return [
        {
          'id': 'neutral_feeling',
          'question': '오늘 하루의 전반적인 느낌은 어땠나요?',
          'options': [
            {'text': '평범하고 무난했어요', 'score': 3},
            {'text': '약간 지루했어요', 'score': 2},
            {'text': '그럭저럭 괜찮았어요', 'score': 4},
            {'text': '기복이 있었어요', 'score': 2},
          ]
        },
        {
          'id': 'neutral_energy',
          'question': '현재 에너지 레벨은 어떤가요?',
          'options': [
            {'text': '무기력함', 'score': 1},
            {'text': '피곤함', 'score': 2},
            {'text': '보통', 'score': 3},
            {'text': '활기참', 'score': 4},
          ]
        },
        {
          'id': 'neutral_social',
          'question': '오늘 다른 사람들과의 교류는 어땠나요?',
          'options': [
            {'text': '사람을 만나고 싶지 않았어요', 'score': 1},
            {'text': '필요한 만큼만 했어요', 'score': 3},
            {'text': '즐겁게 대화했어요', 'score': 4},
            {'text': '특별한 교류가 없었어요', 'score': 2},
          ]
        },
      ];
    } else {
      // 긍정적인 기분 (7-10점)
      return [
        {
          'id': 'positive_reason',
          'question': '오늘 기분이 좋은 이유는 무엇인가요?',
          'options': [
            {'text': '좋은 소식이 있었어요', 'score': 4},
            {'text': '즐거운 활동을 했어요', 'score': 4},
            {'text': '편안한 휴식을 취했어요', 'score': 3},
            {'text': '특별한 이유 없이 좋아요', 'score': 4},
          ]
        },
        {
          'id': 'positive_energy',
          'question': '현재 에너지 레벨은 어떤가요?',
          'options': [
            {'text': '매우 활기차요', 'score': 4},
            {'text': '적당히 활동적이에요', 'score': 3},
            {'text': '편안하고 만족스러워요', 'score': 4},
            {'text': '행복하지만 조금 피곤해요', 'score': 3},
          ]
        },
        {
          'id': 'positive_share',
          'question': '이 좋은 기분을 유지하기 위해 무엇을 하고 싶나요?',
          'options': [
            {'text': '취미 활동 하기', 'score': 4},
            {'text': '좋아하는 사람과 시간 보내기', 'score': 4},
            {'text': '새로운 것에 도전하기', 'score': 4},
            {'text': '그냥 이대로 즐기기', 'score': 3},
          ]
        },
      ];
    }
  }

  String _getMoodCategory() {
    if (widget.moodScore >= 1 && widget.moodScore <= 3) {
      return '힘든 하루';
    } else if (widget.moodScore >= 4 && widget.moodScore <= 6) {
      return '평범한 하루';
    } else {
      return '좋은 하루';
    }
  }

  IconData _getMoodIcon() {
    if (widget.moodScore >= 1 && widget.moodScore <= 3) {
      return Icons.sentiment_very_dissatisfied;
    } else if (widget.moodScore >= 4 && widget.moodScore <= 6) {
      return Icons.sentiment_neutral;
    } else {
      return Icons.sentiment_very_satisfied;
    }
  }

  Color _getMoodColor() {
    if (widget.moodScore >= 1 && widget.moodScore <= 3) {
      return Colors.red[400]!;
    } else if (widget.moodScore >= 4 && widget.moodScore <= 6) {
      return Colors.orange[400]!;
    } else {
      return Colors.green[400]!;
    }
  }

  Future<void> _submitAnswers() async {
    // 모든 질문에 답변했는지 확인
    final questions = _getQuestions();
    for (var question in questions) {
      if (_answers[question['id']] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 질문에 답변해주세요.')),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 총 점수 계산
      int totalScore = 0;
      _answers.forEach((key, value) {
        totalScore += (value['score'] as int);
      });

      // 평균 점수 계산 (선택지 점수는 1-4 사이)
      double averageScore = totalScore / questions.length;

      // Firestore에 저장할 데이터 준비
      Map<String, String> answersForFirestore = {};
      _answers.forEach((key, value) {
        answersForFirestore[key] = value['text'];
      });

      // Firestore에 기분 점수 및 상세 답변 저장
      await _firestoreService.updateMoodScore(
        widget.userId,
        widget.moodScore,
        detailedAnswers: answersForFirestore,
        detailScore: averageScore, // 상세 질문 평균 점수
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기분 분석이 저장되었습니다!')),
        );
        Navigator.pop(context); // 이전 화면으로 돌아가기
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
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
    final questions = _getQuestions();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          '기분 분석',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            color: kColorTextTitle,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kColorTextTitle),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 기분 점수 카드
              Card(
                elevation: 2.0,
                color: kColorCardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        _getMoodIcon(),
                        size: 64,
                        color: _getMoodColor(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getMoodCategory(),
                        style: GoogleFonts.roboto(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kColorTextTitle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '기분 점수: ${widget.moodScore}/10',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: kColorTextSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 안내 텍스트
              Text(
                '몇 가지 질문에 답변해주시면\n더 정확한 분석이 가능합니다.',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: kColorTextSubtitle,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // 질문 목록
              ...questions.asMap().entries.map((entry) {
                final index = entry.key;
                final question = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: _buildQuestionCard(
                    questionNumber: index + 1,
                    questionId: question['id']!,
                    questionText: question['question']!,
                    options: question['options']! as List<Map<String, dynamic>>,
                  ),
                );
              }).toList(),

              const SizedBox(height: 24),

              // 제출 버튼
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAnswers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kColorBtnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Text(
                  '분석 완료',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard({
    required int questionNumber,
    required String questionId,
    required String questionText,
    required List<Map<String, dynamic>> options,
  }) {
    return Card(
      elevation: 1.0,
      color: kColorCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: kColorBtnPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$questionNumber',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    questionText,
                    style: GoogleFonts.roboto(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kColorTextTitle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 객관식 선택지들
            ...options.map((option) {
              final isSelected = _answers[questionId]?['text'] == option['text'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _answers[questionId] = {
                        'text': option['text'],
                        'score': option['score'],
                      };
                    });
                  },
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? kColorBtnPrimary.withOpacity(0.1)
                          : const Color(0xFFF5F7FA),
                      border: Border.all(
                        color: isSelected
                            ? kColorBtnPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? kColorBtnPrimary
                                  : kColorTextSubtitle.withOpacity(0.3),
                              width: 2,
                            ),
                            color: isSelected
                                ? kColorBtnPrimary
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option['text'],
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: isSelected
                                  ? kColorBtnPrimary
                                  : kColorTextTitle,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
