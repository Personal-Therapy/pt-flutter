import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/services/firestore_service.dart';
import 'package:intl/intl.dart';

// --- 색상 상수 (다른 파일들과 통일) ---
const Color kColorBgStart = Color(0xFFEFF6FF);
const Color kColorCardBg = Colors.white;
const Color kColorTextTitle = Color(0xFF1F2937);
const Color kColorTextSubtitle = Color(0xFF4B5563);
const Color kColorBtnPrimary = Color(0xFF2563EB);
const Color kColorGood = Color(0xFF22C55E); // 초록 (좋음)
const Color kColorWarning = Color(0xFFF59E0B); // 주황 (주의)
const Color kColorDanger = Color(0xFFEF4444); // 빨강 (위험)

class HealthResultPage extends StatefulWidget {
  const HealthResultPage({super.key});

  @override
  State<HealthResultPage> createState() => _HealthResultPageState();
}

class _HealthResultPageState extends State<HealthResultPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // 점수에 따른 상태 색상 및 텍스트 반환
  Map<String, dynamic> _getStatus(int score) {
    if (score >= 80) return {'text': '매우 좋음', 'color': kColorGood};
    if (score >= 60) return {'text': '양호', 'color': Colors.blue};
    if (score >= 40) return {'text': '보통', 'color': kColorWarning};
    return {'text': '관리 필요', 'color': kColorDanger};
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: Text("로그인이 필요합니다.")));
    }

    // 오늘 날짜 데이터 스트림 호출
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _firestoreService.getDailyMentalStatusStream(_uid!, DateTime.now()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data;

        // 데이터가 없는 경우 처리
        if (data == null || data['overallScore'] == null) {
          return _buildNoDataScreen();
        }

        // --- 데이터 파싱 ---
        final int overallScore = (data['overallScore'] as num).round();
        final componentScores = data['componentScores'] ?? {};

        // 1. 자가진단 (40%)
        final selfDiagMap = componentScores['selfDiagnosis'] ?? {};
        final int selfDiagScore = (selfDiagMap['average'] as num?)?.round() ?? 0;

        // 2. 기분 체크 (10%)
        final dailyEmotion = componentScores['dailyEmotion'] ?? {};
        final int moodScore = (dailyEmotion['moodCheck'] as num?)?.round() ?? 0; // 저장될 때 이미 10~100 처리됨

        // 3. AI 대화 (30%)
        final aiScoreMap = dailyEmotion['aiConversation'] ?? {};
        // aiConversation이 맵일 수도 있고, 정수일 수도 있는 구조에 대응 (FirestoreService 수정본 기준 맵 안에 average나 값 존재 가능)
        // 위 Service 코드 기준: aiConversation: {'average': ...} 형태임
        int aiScore = 0;
        if (aiScoreMap is Map) {
          aiScore = (aiScoreMap['average'] as num?)?.round() ?? 0;
        } else if (aiScoreMap is num) {
          aiScore = aiScoreMap.round();
        }

        // 4. 생체 스트레스 (20%) - 이미 건강점수로 변환되어 저장됨
        final int bioScore = (componentScores['biometricStress'] as num?)?.round() ?? 0;

        // 상태 정보 가져오기
        final statusInfo = _getStatus(overallScore);

        return Scaffold(
          backgroundColor: kColorBgStart,
          appBar: AppBar(
            backgroundColor: kColorBgStart,
            elevation: 0,
            title: Text(
              '오늘의 분석 결과',
              style: GoogleFonts.roboto(
                color: kColorTextTitle,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kColorTextTitle),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 종합 점수 카드 (메인)
                _buildOverallScoreCard(overallScore, statusInfo),

                const SizedBox(height: 24),

                Text(
                  '상세 분석 (기여도)',
                  style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kColorTextTitle,
                  ),
                ),
                const SizedBox(height: 12),

                // 2. 상세 점수 그리드
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailCard(
                        title: '자가진단',
                        score: selfDiagScore,
                        weight: '40%',
                        icon: Icons.assignment_outlined,
                        color: Colors.purple.shade100,
                        iconColor: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailCard(
                        title: 'AI 대화',
                        score: aiScore,
                        weight: '30%',
                        icon: Icons.chat_bubble_outline,
                        color: Colors.blue.shade100,
                        iconColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailCard(
                        title: '생체 리듬',
                        score: bioScore,
                        weight: '20%',
                        icon: Icons.watch_outlined,
                        color: Colors.green.shade100,
                        iconColor: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailCard(
                        title: '기분 체크',
                        score: moodScore,
                        weight: '10%',
                        icon: Icons.sentiment_satisfied_alt,
                        color: Colors.orange.shade100,
                        iconColor: Colors.orange,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // 3. 조언 카드
                _buildAdviceCard(statusInfo),
              ],
            ),
          ),
        );
      },
    );
  }

  // 데이터 없을 때 화면
  Widget _buildNoDataScreen() {
    return Scaffold(
      backgroundColor: kColorBgStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kColorTextTitle),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              "아직 오늘의 데이터가 충분하지 않아요.",
              style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: kColorTextTitle),
            ),
            const SizedBox(height: 8),
            Text(
              "자가진단, 기분 체크, 혹은 워치 연동을\n진행하면 분석 결과가 표시됩니다.",
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(fontSize: 14, color: kColorTextSubtitle),
            ),
          ],
        ),
      ),
    );
  }

  // 종합 점수 카드
  Widget _buildOverallScoreCard(int score, Map<String, dynamic> statusInfo) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: kColorCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '오늘의 정신건강 점수',
            style: GoogleFonts.roboto(
              fontSize: 16,
              color: kColorTextSubtitle,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(statusInfo['color']),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text(
                    '$score',
                    style: GoogleFonts.roboto(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: kColorTextTitle,
                    ),
                  ),
                  Text(
                    statusInfo['text'],
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: statusInfo['color'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            DateFormat('yyyy년 MM월 dd일').format(DateTime.now()),
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // 상세 항목 카드
  Widget _buildDetailCard({
    required String title,
    required int score,
    required String weight,
    required IconData icon,
    required Color color,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kColorCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  weight,
                  style: GoogleFonts.roboto(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: kColorTextSubtitle,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: GoogleFonts.roboto(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kColorTextTitle,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ 100',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 조언 카드
  Widget _buildAdviceCard(Map<String, dynamic> statusInfo) {
    String adviceTitle;
    String adviceBody;

    if (statusInfo['text'] == '매우 좋음') {
      adviceTitle = "최고의 컨디션이네요!";
      adviceBody = "지금의 긍정적인 루틴을 유지하세요. 주변 사람들에게 긍정적인 에너지를 나눠주는 것도 좋습니다.";
    } else if (statusInfo['text'] == '양호') {
      adviceTitle = "안정적인 상태입니다.";
      adviceBody = "약간의 스트레스가 있을 수 있지만 잘 관리하고 계시네요. 가벼운 산책으로 기분을 더 올려보세요.";
    } else if (statusInfo['text'] == '보통') {
      adviceTitle = "잠시 휴식이 필요해요.";
      adviceBody = "스트레스 수치가 조금 높거나 기분이 처져 있습니다. 5분 명상이나 따뜻한 차 한 잔으로 여유를 가져보세요.";
    } else {
      adviceTitle = "마음 돌봄이 필요합니다.";
      adviceBody = "전반적인 지표가 낮습니다. 오늘은 무리하지 말고 충분한 수면을 취하거나, 전문가와의 상담을 고려해보세요.";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kColorCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusInfo['color'].withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb, color: statusInfo['color'], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adviceTitle,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kColorTextTitle,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  adviceBody,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: kColorTextSubtitle,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}