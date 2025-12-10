import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ⚠️ 실제 앱에서는 이렇게 하드코딩하지 말고
// --dart-define=GEMINI_API_KEY=... 로 넘기거나, 안전한 저장소에 넣는 게 좋아.
// 여기서는 구조 설명을 위해 상수로
const String geminiApiKey = 'AIzaSyD2s8egs5QbN15S9NR8Dh2iTpFIvN0LCiA';

// 네가 Java에서 쓰던 것과 같은 엔드포인트 구조
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
    if (geminiApiKey.isEmpty) {
      throw Exception('Gemini API 키가 설정되어 있지 않습니다.');
    }

    final uri = Uri.parse('$geminiEndpoint?key=$geminiApiKey');

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

  /// 🧠 유저 메시지에서 부정적인/위험 신호 단어를 LLM으로 뽑아내는 함수
  Future<NegativeAnalysisResult> _analyzeNegativeWords(String userMessage) async {
    if (geminiApiKey.isEmpty) {
      return NegativeAnalysisResult.empty();
    }

    final uri = Uri.parse('$geminiEndpoint?key=$geminiApiKey');

    // ⚠️ 프롬프트는 "반드시 JSON만 반환" 하도록 강하게 명령하는 게 포인트
    final prompt = '''
너는 한국어 심리상담 도우미야.

사용자의 문장에서 다음을 분석해줘:
1) 자해/자살, 극단적 선택, 무기력, 우울, 불안, 공포, 심한 욕설 등 "부정적/위험 신호"가 되는 표현이 있는지
2) 얼마나 심각한지: "none", "low", "medium", "high" 중 하나
3) 그런 표현들(단어/짧은 구)을 리스트로 뽑기

특히 아래와 같은 표현이 있으면 반드시 has_negative=true 이고 severity="high" 로 설정해:
- "죽고싶어", "죽고 싶다", "자살", "살기 싫다", "끝내고 싶다"

💡 아주 중요한 규칙:
- 반드시 "JSON만" 반환해. 설명, 말투, 다른 문장은 쓰지 마.
- JSON 구조는 정확히 아래 형태만 사용해.

{
  "has_negative": true or false,
  "severity": "none" or "low" or "medium" or "high",
  "negative_terms": ["...", "..."]
}

분석할 문장:
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
      // 분석 실패 시 그냥 "없음"으로 처리
      return NegativeAnalysisResult.empty();
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return NegativeAnalysisResult.empty();
    }

    final content = candidates[0]['content'];
    final parts = content?['parts'];
    if (parts is! List || parts.isEmpty) {
      return NegativeAnalysisResult.empty();
    }

    final text = parts[0]['text'];
    if (text is! String || text.isEmpty) {
      return NegativeAnalysisResult.empty();
    }

    // 🔍 확인용 로그
    debugPrint('[NEG_RAW] $text');

    // text 안에는 JSON 문자열이 들어 있다고 가정하고 파싱
    try {
      // 1) 원본 로그
      debugPrint('[NEG_RAW] $text');

      // 2) ```json 같은 코드블럭을 포함하고 있을 수 있으니 중괄호 부분만 추출
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) {
        debugPrint('[NEG_PARSE] JSON 영역을 찾지 못했습니다. text=$text');
        return NegativeAnalysisResult.empty();
      }

      final jsonString = text.substring(start, end + 1);
      debugPrint('[NEG_JSON] $jsonString');

      final Map<String, dynamic> j = jsonDecode(jsonString);

      final hasNegative = j['has_negative'] == true;
      final severity = (j['severity'] as String?) ?? 'none';
      final termsRaw = j['negative_terms'];

      final List<String> terms = (termsRaw is List)
          ? termsRaw.map((e) => e.toString()).toList()
          : <String>[];

      // 👇 여기서 테스트용 로그 한 번 찍기
      debugPrint(
        '[NEG_ANALYSIS] input="$userMessage", '
            'hasNegative=$hasNegative, '
            'severity=$severity, '
            'terms=$terms',
      );

      return NegativeAnalysisResult(
        hasNegative: hasNegative,
        severity: severity,
        terms: terms,
      );
    } catch (_) {
      // JSON 파싱 실패 시도 그냥 "없음"으로 처리
      return NegativeAnalysisResult.empty();
    }
  }


  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();

    setState(() {
      // 일단 분석 전이니까 negative는 null
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
      // 🧠 1) 부정 단어 분석
      final analysis = await _analyzeNegativeWords(text);

      // 필요하면 여기서 로그/서버 전송 등
      if (analysis.hasNegative) {
        debugPrint('⚠️ 부정적인 표현 감지: ${analysis.terms} (severity=${analysis.severity})');
        // TODO: DB에 저장하거나, 경고 UI, 긴급 대응 로직 등...
      }

      // 테스트용 콘솔 로그
      if (analysis.hasNegative) {
        debugPrint(
          '[NEG_RESULT] ⚠️ 부정적인 표현 감지 '
              '(severity=${analysis.severity}, terms=${analysis.terms}) '
              'original="$text"',
        );
      } else {
        debugPrint('[NEG_RESULT] 부정적 표현 없음, original="$text"');
      }

      // 🧠 2) 실제 답변 생성
      final reply = await _callGemini(text);

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
            negative: analysis, // 👈 여기!
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
  final NegativeAnalysisResult? negative; // 👈 추가 (유저 메시지에만 사용)

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isThinking = false,
    this.isError = false,
    this.negative
  });
}

class NegativeAnalysisResult {
  final bool hasNegative;
  final String severity; // "none" | "low" | "medium" | "high"
  final List<String> terms;

  NegativeAnalysisResult({
    required this.hasNegative,
    required this.severity,
    required this.terms,
  });

  factory NegativeAnalysisResult.empty() {
    return NegativeAnalysisResult(
      hasNegative: false,
      severity: 'none',
      terms: const [],
    );
  }
}

