import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/services/firestore_service.dart';

// Gemini API 엔드포인트
const String geminiEndpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        text: '안녕하세요! 저는 마음케어 AI 상담사입니다. 오늘 하루는 어떠셨나요?',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// ✅ MyApplication의 requestGeminiResponse()를 Dart로 옮긴 버전
  Future<String> _callGemini(String userMessage) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception('Gemini API 키가 설정되어 있지 않습니다.');
    }

    final uri = Uri.parse('$geminiEndpoint?key=$apiKey');

    // 🧠 상담사 역할 + 스타일을 명시하는 프롬프트
    final counselorPrompt = '''
너는 마음을 돌보는 온라인 상담 챗봇이야.

[역할]
- 따뜻하고 공감적인 톤으로 대답해.
- 현실적인 조언도 주되, "공감 : 조언" 비율을 6:4 정도로 유지해.
- 사용자의 감정을 먼저 알아주고(공감), 그 다음에 짧게 제안해줘.

[말투]
- 존댓말을 쓰되, 너무 딱딱하지 않고 부드러운 대화체로 말해.
- 한 번에 3~5문장 안쪽으로만 답해. 너무 길게 설명하지 마.
- 해결책은 한두 가지 정도만 제안하고, 선택은 사용자에게 맡겨.

[주의]
- 의사나 심리상담사를 대신하는 존재처럼 진단하지는 말고,
  필요해 보이면 "믿을 수 있는 주변 사람이나 전문가에게 도움을 요청해보는 것도 좋겠다" 정도로만 권유해.

[사용자 메시지]
$userMessage
''';

    // Java에서 만든 requestBody:
    // { "contents": [{ "parts": [{ "text": "..." }] }] }
    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': counselorPrompt}
          ]
        }
      ]
    };

    final response = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini 서버 오류: ${response.statusCode}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    // Java 코드에서 했던 것:
    // candidates[0].content.parts[0].text
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw Exception('유효하지 않은 응답 형식 (candidates 없음)');
    }

    final content = candidates[0]['content'];
    if (content == null) {
      throw Exception('유효하지 않은 응답 형식 (content 없음)');
    }

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw Exception('유효하지 않은 응답 형식 (parts 없음)');
    }

    final text = parts[0]['text'];
    if (text is! String || text.isEmpty) {
      throw Exception('유효하지 않은 응답 형식 (text 없음)');
    }

    return text;
  }

  /// 🧠 유저 메시지에서 감정 분석을 수행하는 함수
  Future<EmotionAnalysisResult> _analyzeEmotions(String userMessage) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return EmotionAnalysisResult.empty();
    }

    final uri = Uri.parse('$geminiEndpoint?key=$apiKey');

    final prompt = '''
너는 한국어 심리상담 전문 분석가야.

사용자 메시지를 분석하여 다음 JSON 형식으로만 응답해:
{
  "emotions": {
    "joy": 0-10,
    "sadness": 0-10,
    "anger": 0-10,
    "anxiety": 0-10,
    "peace": 0-10
  },
  "mentalHealthSignals": {
    "depression": 0-10,
    "anxiety": 0-10,
    "stress": 0-10
  },
  "sentiment": {
    "positive": 0.0-1.0,
    "negative": 0.0-1.0,
    "neutral": 0.0-1.0
  },
  "keywords": ["키워드1", "키워드2", ...]
}

[분석 기준]
- emotions: 각 감정의 강도 (0=없음, 10=매우 강함)
  - joy: 기쁨, 행복, 즐거움
  - sadness: 슬픔, 우울함, 허무함 
  - anger: 분노, 짜증, 억울함
  - anxiety: 불안, 걱정, 두려움
  - peace: 평온, 안정, 편안함
- mentalHealthSignals: 정신건강 관련 신호 강도 (0=없음, 10=매우 심각)
  - depression: 우울증 관련 신호 (무기력, 흥미상실, 자책 등)
  - anxiety: 불안장애 관련 신호 (과도한 걱정, 공황 등)
  - stress: 스트레스 관련 신호 (압박감, 피로, 번아웃 등)
- sentiment: 전체 감정의 긍정/부정/중립 비율 (합계=1.0)
- keywords: 핵심 감정 키워드 추출 (한국어, 최대 5개)

💡 아주 중요한 규칙:
- 반드시 "JSON만" 반환해. 설명, 말투, 다른 문장은 쓰지 마.
- 숫자는 정수(emotions, mentalHealthSignals)와 소수(sentiment)로 정확히 구분해.

분석할 메시지:
"$userMessage"
''';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    };

    final response = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      return EmotionAnalysisResult.empty();
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return EmotionAnalysisResult.empty();
    }

    final content = candidates[0]['content'];
    final parts = content?['parts'];
    if (parts is! List || parts.isEmpty) {
      return EmotionAnalysisResult.empty();
    }

    final text = parts[0]['text'];
    if (text is! String || text.isEmpty) {
      return EmotionAnalysisResult.empty();
    }

    debugPrint('[EMOTION_RAW] $text');

    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) {
        debugPrint('[EMOTION_PARSE] JSON 영역을 찾지 못했습니다. text=$text');
        return EmotionAnalysisResult.empty();
      }

      final jsonString = text.substring(start, end + 1);
      debugPrint('[EMOTION_JSON] $jsonString');

      final Map<String, dynamic> j = jsonDecode(jsonString);
      final result = EmotionAnalysisResult.fromJson(j);

      debugPrint('[EMOTION_ANALYSIS] input="$userMessage"');
      debugPrint('[EMOTION_ANALYSIS] result=${result.toJson()}');

      return result;
    } catch (e) {
      debugPrint('[EMOTION_PARSE_ERROR] $e');
      return EmotionAnalysisResult.empty();
    }
  }


  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();

    setState(() {
      // 일단 분석 전이니까 emotionAnalysis는 null
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
        ),
      );

      _isSending = true;
      _messages.add(
        _ChatMessage(
          text: '생각 중이에요…',
          isUser: false,
          isThinking: true,
        ),
      );
    });

    try {
      // 🧠 감정 분석 + 답변 생성 병렬 실행
      final results = await Future.wait([
        _analyzeEmotions(text),
        _callGemini(text),
      ]);

      final analysis = results[0] as EmotionAnalysisResult;
      final reply = results[1] as String;

      // DB 저장용 JSON 로그
      debugPrint('[EMOTION_RESULT] ${analysis.toJson()}');

      // 점수 계산 로그
      debugPrint('[SCORE] 긍정 점수: ${analysis.positiveScore.toStringAsFixed(2)} (0-10)');
      debugPrint('[SCORE] 부정 점수: ${analysis.negativeScore.toStringAsFixed(2)} (0-10)');
      debugPrint('[SCORE] 최종 점수: ${analysis.finalScoreB3.round()} / 100');

      // Firestore에 B-3 방식 점수 저장
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final firestoreService = FirestoreService();
        await firestoreService.updateDailyMentalStatus(
          uid: userId,
          aiConversationScore: analysis.finalScoreB3.round(),
        );
        debugPrint('[AI_CHAT] Firestore 저장 완료! 점수: ${analysis.finalScoreB3.round()}');
      }

      setState(() {
        // "생각 중" 버블 제거
        _messages.removeWhere((m) => m.isThinking);

        // 제일 마지막 유저 메시지에 분석 결과를 붙여주는 패턴
        final lastUserIndex =
        _messages.lastIndexWhere((m) => m.isUser && !m.isThinking);

        if (lastUserIndex != -1) {
          final old = _messages[lastUserIndex];
          _messages[lastUserIndex] = _ChatMessage(
            text: old.text,
            isUser: old.isUser,
            isThinking: old.isThinking,
            isError: old.isError,
            emotionAnalysis: analysis, // 👈 감정 분석 결과
          );
        }

        // 실제 Gemini 응답 추가
        _messages.add(
          _ChatMessage(
            text: reply,
            isUser: false,
          ),
        );
      });
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m.isThinking);
        _messages.add(
          _ChatMessage(
            text: '⚠️ Gemini 응답 중 오류가 발생했습니다.\n($e)',
            isUser: false,
            isError: true,
          ),
        );
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'AI 상담',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 채팅 메시지 영역
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];

                final align =
                msg.isUser ? Alignment.centerRight : Alignment.centerLeft;

                final bubbleColor = msg.isUser
                    ? const Color(0xFF2563EB)
                    : (msg.isError
                    ? const Color(0xFFFFE4E6)
                    : Colors.white);

                final textColor = msg.isUser
                    ? Colors.white
                    : (msg.isError
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFF111827));

                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft:
                        msg.isUser ? const Radius.circular(16) : Radius.zero,
                        bottomRight:
                        msg.isUser ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontStyle:
                        msg.isThinking ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 입력창 영역
          SafeArea(
            top: false,
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  // 마이크 버튼 (아직 기능 없음)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5E7EB),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.mic_none_rounded, size: 20),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 텍스트 입력 필드
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: '마음에 떠오르는 생각을 적어 보세요…',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 전송 버튼
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isSending
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, size: 18),
                      color: Colors.white,
                      onPressed: _isSending ? null : _handleSend,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isThinking;
  final bool isError;
  final EmotionAnalysisResult? emotionAnalysis; // 👈 감정 분석 결과 (유저 메시지에만 사용)

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isThinking = false,
    this.isError = false,
    this.emotionAnalysis,
  });
}

class EmotionAnalysisResult {
  final Map<String, int> emotions;           // joy, sadness, anger, anxiety, peace (0-10)
  final Map<String, int> mentalHealthSignals; // depression, anxiety, stress (0-10)
  final Map<String, double> sentiment;       // positive, negative, neutral (비율)
  final List<String> keywords;               // 감정 키워드 목록

  EmotionAnalysisResult({
    required this.emotions,
    required this.mentalHealthSignals,
    required this.sentiment,
    required this.keywords,
  });

  factory EmotionAnalysisResult.empty() {
    return EmotionAnalysisResult(
      emotions: {'joy': 0, 'sadness': 0, 'anger': 0, 'anxiety': 0, 'peace': 0},
      mentalHealthSignals: {'depression': 0, 'anxiety': 0, 'stress': 0},
      sentiment: {'positive': 0.0, 'negative': 0.0, 'neutral': 1.0},
      keywords: const [],
    );
  }

  factory EmotionAnalysisResult.fromJson(Map<String, dynamic> json) {
    return EmotionAnalysisResult(
      emotions: Map<String, int>.from(json['emotions'] ?? {}),
      mentalHealthSignals: Map<String, int>.from(json['mentalHealthSignals'] ?? {}),
      sentiment: Map<String, double>.from(
        (json['sentiment'] as Map?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
      ),
      keywords: List<String>.from(json['keywords'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emotions': emotions,
      'mentalHealthSignals': mentalHealthSignals,
      'sentiment': sentiment,
      'keywords': keywords,
    };
  }

  /// 긍정 점수 계산: (joy + peace) / 2 (0-10 범위)
  double get positiveScore {
    final joy = emotions['joy'] ?? 0;
    final peace = emotions['peace'] ?? 0;
    return (joy + peace) / 2.0;
  }

  /// 부정 점수 계산: (sadness + anger + anxiety) / 3 (0-10 범위)
  double get negativeScore {
    final sadness = emotions['sadness'] ?? 0;
    final anger = emotions['anger'] ?? 0;
    final anxiety = emotions['anxiety'] ?? 0;
    return (sadness + anger + anxiety) / 3.0;
  }

  /// 최종 점수 계산 (A-1 방식): (긍정 점수 / (긍정 점수 + 부정 점수 + 0.01)) × 100
  double get finalScoreA1 {
    final pos = positiveScore;
    final neg = negativeScore;
    return (pos / (pos + neg + 0.01)) * 100;
  }

  /// 최종 점수 계산 (B-3 방식): ((positive - negative + 1) / 2) × 100
  double get finalScoreB3 {
    final positive = sentiment['positive'] ?? 0.0;
    final negative = sentiment['negative'] ?? 0.0;
    final score = ((positive - negative + 1) / 2) * 100;

    // 0-100 범위 제한
    return score.clamp(0.0, 100.0);
  }

  /// 기본 finalScore는 A-1 방식 사용 (하위 호환성)
  double get finalScore => finalScoreA1;
}