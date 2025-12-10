import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
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

    // Java에서 만든 requestBody:
    // { "contents": [{ "parts": [{ "text": "..." }] }] }
    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': userMessage}
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

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();

    setState(() {
      // 1) 내 메시지 추가
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
        ),
      );

      // 2) Gemini 생각 중… 표시
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
      final reply = await _callGemini(text);

      setState(() {
        // "생각 중" 버블 제거
        _messages.removeWhere((m) => m.isThinking);
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

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isThinking = false,
    this.isError = false,
  });
}