import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'healing_screen.dart';
import 'package:untitled/main_screen.dart';
import 'package:untitled/aichat_screen.dart';

class EmotionTrackingTab extends StatefulWidget {
  const EmotionTrackingTab({super.key});

  @override
  EmotionTrackingTabState createState() => EmotionTrackingTabState();
}

class EmotionTrackingTabState extends State<EmotionTrackingTab> {
  int _selectedToggleIndex = 1; // 0: 일간, 1: 주간, 2: 월간

  final FirestoreService _firestoreService = FirestoreService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  int _currentMentalHealthScore = 0;
  int _currentMoodScore = 0;
  String _selectedEmotion = '';
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFFF9FAFB);

    return Container(
      color: backgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24.0, 80.0, 24.0, 96.0),
        child: Column(
          children: [
            _buildTimeToggle(),
            const SizedBox(height: 24.0),
            _buildSelectedTabContent(),
          ],
        ),
      ),
    );
  }

  /// 선택된 탭에 따라 다른 콘텐츠 표시
  Widget _buildSelectedTabContent() {
    switch (_selectedToggleIndex) {
      case 0:
        return _buildDailyContent();
      case 1:
        return _buildWeeklyContent();
      case 2:
        return _buildMonthlyContent();
      default:
        return _buildWeeklyContent();
    }
  }

  /// 일간/주간/월간 토글
  Widget _buildTimeToggle() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          children: [
            _buildToggleItem('일간', 0),
            _buildToggleItem('주간', 1),
            _buildToggleItem('월간', 2),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(String text, int index) {
    final bool isSelected = (_selectedToggleIndex == index);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedToggleIndex = index;
          });
        },
        child: Container(
          height: 36.0,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Center(
            child: Text(
              text,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                fontSize: 14.0,
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 일간 탭 ====================
  Widget _buildDailyContent() {
    return Column(
      children: [
        _buildDailyStatusCard(),
        const SizedBox(height: 24.0),
        _buildDailyEmotionDistributionCard(),
        const SizedBox(height: 24.0),
        _buildDailyTrendsCard(),
        const SizedBox(height: 24.0),
        _buildDailyInsightsCard(),
        const SizedBox(height: 24.0),
        _buildDailyQuickActionsCard(),
      ],
    );
  }

  /// 오늘의 상태 카드 (스트레스, 건강 점수, 수면 시간)
  Widget _buildDailyStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1),)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘의 상태', style: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 18, color: const Color(0xFF1F2937),)),
          const SizedBox(height: 16.0),
          if (_currentUserId != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // [1] 스트레스 (기존 유지)
                _buildStreamedStatusItem(
                  stream: _firestoreService.getMoodScoresStream(_currentUserId!),
                  label: '스트레스',
                  valueColor: const Color(0xFF1F2937),
                  timePeriod: 'daily',
                  scoreExtractor: (data) => (data['score'] as num?)?.toDouble() ?? 0.0,
                  isStress: true,
                ),
                // [2] 건강 점수 (수정됨!) -> 종합 점수(overallScore)를 가져오도록 변경
                _buildStreamedStatusItem(
                  stream: _firestoreService.getDailyMentalStatusListStream(_currentUserId!), // [변경]
                  label: '종합 건강 점수', // [변경] 라벨을 명확하게
                  valueColor: const Color(0xFF2563EB),
                  timePeriod: 'daily',
                  // [변경] 'overallScore' 필드를 읽도록 수정
                  scoreExtractor: (data) => (data['overallScore'] as num?)?.toDouble() ?? 0.0,
                ),
              ],
            )
          else
            const Center(child: Text('로그인이 필요합니다.')),
        ],
      ),
    );
  }

  /// 오늘의 감정 분포 카드
  Widget _buildDailyEmotionDistributionCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 감정 분포',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('기쁨', 0.0, const Color(0xFF22C55E), '0%'),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('슬픔', 0.0, const Color(0xFF3B82F6), '0%'),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('불안', 0.0, const Color(0xFFEAB308), '0%'),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('분노', 0.0, const Color(0xFFEF4444), '0%'),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('평온', 0.0, const Color(0xFF6B7280), '0%'),
        ],
      ),
    );
  }

  /// 주간 변화 추이 카드 (스트레스 지수, 건강 점수, 수면 시간)
  Widget _buildDailyTrendsCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '주간 변화 추이',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 24.0),
          if (_currentUserId != null) ...[
            _buildWeeklyMetricChart('스트레스 지수', const Color(0xFFEF4444), _firestoreService.getMoodScoresStream(_currentUserId!)),
            const SizedBox(height: 24.0),
            _buildWeeklyMetricChart('건강 점수', const Color(0xFF3B82F6), _firestoreService.getMentalHealthScoresStream(_currentUserId!)),
            const SizedBox(height: 24.0),
            _buildWeeklyMetricChart('수면 시간', const Color(0xFFA855F7), _buildSleepDataStream(), dataField: 'duration', isSleepData: true),
            const SizedBox(height: 24.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAverageSummaryItem(
                    '평균 스트레스',
                    _firestoreService.getMoodScoresStream(_currentUserId!),
                    (data) => (data['score'] as num).toDouble(),
                    '',
                  ),
                _buildAverageSummaryItem(
                    '평균 건강점수',
                    _firestoreService.getMentalHealthScoresStream(_currentUserId!),
                    (data) => (data['score'] as num).toDouble(),
                    '',
                  ),
                _buildAverageSummaryItem(
                    '평균 수면',
                    _firestoreService.getSleepScoresStream(_currentUserId!),
                    (data) => (data['duration'] as num).toDouble(),
                    'h',
                  ),
              ],
            ),
          ] else
            const Center(child: Text('로그인이 필요합니다.')),
        ],
      ),
    );
  }

  /// 인사이트 카드
  Widget _buildDailyInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '인사이트',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildInsightItem(
            '수면과 스트레스의 상관관계',
            '수면 시간이 6시간 미만일 때 스트레스 지수가 평균 25% 높아집니다.',
            const Color(0xFF2563EB),
            const Color(0xFFDBEAFE),
          ),
          const SizedBox(height: 16.0),
          _buildInsightItem(
            '긍정 감정 증가',
            '이번 주 기쁨 감정이 지난주 대비 15% 증가했습니다. 좋은 변화네요!',
            const Color(0xFF16A34A),
            const Color(0xFFDCFCE7),
          ),
          const SizedBox(height: 16.0),
          _buildInsightItem(
            '주의 필요',
            '화요일과 수요일에 불안 감정이 높게 나타났습니다. 해당 요일의 패턴을 확인해보세요.',
            const Color(0xFFCA8A04),
            const Color(0xFFFEF9C3),
          ),
        ],
      ),
    );
  }

  /// 빠른 액션 카드
  Widget _buildDailyQuickActionsCard() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionItem(
            'AI와 대화',
            '감정 상태 체크',
            Icons.chat_bubble_outline,
            const Color(0xFF16A34A),
            const Color(0xFFDCFCE7),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AIChatScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 16.0),
        Expanded(
          child: _buildQuickActionItem(
            '힐링 콘텐츠',
            '맞춤 추천',
            Icons.spa_outlined,
            const Color(0xFFEA580C),
            const Color(0xFFFFEDD5),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HealingScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==================== 주간 탭 ====================
  Widget _buildWeeklyContent() {
    return Column(
      children: [
        _buildWeeklyStatusCard(),
        const SizedBox(height: 24.0),
        _buildTrendsCard(),
        const SizedBox(height: 24.0),
        _buildInsightCard(),
        const SizedBox(height: 24.0),
        _buildQuickActionsCard(),
      ],
    );
  }

  Widget _buildWeeklyStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1),)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('이번 주 상태', style: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 18, color: const Color(0xFF1F2937),)),
          const SizedBox(height: 16.0),
          if (_currentUserId != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // [1] 스트레스 (기존 유지)
                _buildStreamedStatusItem(
                  stream: _firestoreService.getMoodScoresStream(_currentUserId!),
                  label: '평균 스트레스',
                  valueColor: const Color(0xFF1F2937),
                  timePeriod: 'weekly',
                  scoreExtractor: (data) => (data['score'] as num?)?.toDouble() ?? 0.0,
                  isStress: true,
                ),
                // [2] 건강 점수 (수정됨!)
                _buildStreamedStatusItem(
                  stream: _firestoreService.getDailyMentalStatusListStream(_currentUserId!), // [변경]
                  label: '평균 건강 점수',
                  valueColor: const Color(0xFF2563EB),
                  timePeriod: 'weekly',
                  // [변경] 'overallScore' 필드를 읽도록 수정
                  scoreExtractor: (data) => (data['overallScore'] as num?)?.toDouble() ?? 0.0,
                ),
              ],
            )
          else
            const Center(child: Text('로그인이 필요합니다.')),
          const SizedBox(height: 24.0),
          Text('평균 감정 분포', style: GoogleFonts.roboto(fontWeight: FontWeight.w500, fontSize: 14, color: const Color(0xFF1F2937),)),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('기쁨', 0.0, const Color(0xFF22C55E), '0%'),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('슬픔', 0.0, const Color(0xFF3B82F6), '0%'),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('불안', 0.0, const Color(0xFFF59E0B), '0%'),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('분노', 0.0, const Color(0xFFEF4444), '0%'),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('평온', 0.0, const Color(0xFF6B7280), '0%'),
        ],
      ),
    );
  }

  // ==================== 공통 위젯 및 헬퍼 ====================

  /// 데이터 스트림을 기반으로 상태 아이템을 빌드하는 헬퍼 위젯
  Widget _buildStreamedStatusItem({
    required Stream<List<Map<String, dynamic>>> stream,
    required String label,
    required Color valueColor,
    required String timePeriod, // 'daily', 'weekly', 'monthly'
    required double Function(Map<String, dynamic>) scoreExtractor,
    String unit = '',
    bool isStress = false,
  }) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildStatusItem(label: label, value: null, valueColor: valueColor); // 로딩 중 플레이스홀더
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildStatusItem(label: label, value: 'N/A', valueColor: valueColor);
        }

        final data = snapshot.data!;
        final now = DateTime.now();
        List<Map<String, dynamic>> filteredData;

        // 기간별 데이터 필터링
        switch (timePeriod) {
          case 'daily':
            final startOfDay = DateTime(now.year, now.month, now.day);
            final endOfDay = startOfDay.add(const Duration(days: 1));
            filteredData = data.where((item) {
              final ts = item['timestamp'];
              if (ts == null || ts is! Timestamp) return false;  // ✅ null 체크
              final timestamp = ts.toDate();
              return timestamp.isAfter(startOfDay) && timestamp.isBefore(endOfDay);
            }).toList();
            break;
          case 'weekly':
            final startOfWeek = DateTime(now.year, now.month, now.day - (now.weekday - 1));
            final endOfWeek = startOfWeek.add(const Duration(days: 7));
            filteredData = data.where((item) {
              final ts = item['timestamp'];
              if (ts == null || ts is! Timestamp) return false;  // ✅ null 체크
              final timestamp = ts.toDate();
              return timestamp.isAfter(startOfWeek) && timestamp.isBefore(endOfWeek);
            }).toList();
            break;
          case 'monthly':
            final startOfMonth = DateTime(now.year, now.month, 1);
            final endOfMonth = DateTime(now.year, now.month + 1, 1);
            filteredData = data.where((item) {
              final ts = item['timestamp'];
              if (ts == null || ts is! Timestamp) return false;  // ✅ null 체크
              final timestamp = ts.toDate();
              return timestamp.isAfter(startOfMonth) && timestamp.isBefore(endOfMonth);
            }).toList();
            break;
          default:
            filteredData = [];
        }

        if (filteredData.isEmpty) {
          return _buildStatusItem(label: label, value: 'N/A', valueColor: valueColor);
        }

        double sum = 0;
        for (var item in filteredData) {
          sum += scoreExtractor(item);
        }
        final average = sum / filteredData.length;

        Map<String, dynamic> tagDetails = {};
        if (isStress) {
          tagDetails = _getStressTagDetails(average);
        }

        return _buildStatusItem(
          label: label,
          value: '${average.toStringAsFixed(unit.isEmpty ? 0 : 1)}$unit',
          valueColor: valueColor,
          tag: isStress ? tagDetails['text'] : null,
          tagColor: isStress ? tagDetails['color'] : null,
          tagBgColor: isStress ? tagDetails['bgColor'] : null,
        );
      },
    );
  }

  /// 스트레스 점수에 따른 태그와 색상을 반환하는 함수
  Map<String, dynamic> _getStressTagDetails(double score) {
    if (score < 40) {
      return {'text': '낮음', 'color': const Color(0xFF16A34A), 'bgColor': const Color(0xFFDCFCE7)};
    } else if (score < 70) {
      return {'text': '보통', 'color': const Color(0xFFCA8A04), 'bgColor': const Color(0xFFFEFCE8)};
    } else {
      return {'text': '높음', 'color': const Color(0xFFDC2626), 'bgColor': const Color(0xFFFEE2E2)};
    }
  }

  Widget _buildStatusItem({
    required String label,
    String? value,
    required Color valueColor,
    String? tag,
    Color? tagColor,
    Color? tagBgColor,
  }) {
    return Expanded(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (tag != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: tagBgColor,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: tagColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
            ],
            value == null
                ? const SizedBox(
                    height: 23, // Approximate height of the text
                    width: 23,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    value,
                    style: GoogleFonts.roboto(
                      fontSize: tag == null ? 23 : 18,
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF6B7280),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
          ],
        ),
    );
}

  Widget _buildEmotionProgress(String label, double value, Color color, String percentage) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9999),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 32,
          child: Text(
            percentage,
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF6B7280),
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendsCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '주간 변화 추이',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 24.0),
          if (_currentUserId != null) ...[
            _buildWeeklyMetricChart('스트레스 지수', const Color(0xFFEF4444), _firestoreService.getMoodScoresStream(_currentUserId!)),
            const SizedBox(height: 24.0),
            _buildWeeklyMetricChart('건강 점수', const Color(0xFF3B82F6), _firestoreService.getMentalHealthScoresStream(_currentUserId!)),
            const SizedBox(height: 24.0),
            _buildWeeklyMetricChart('수면 시간', const Color(0xFFA855F7), _buildSleepDataStream(), dataField: 'duration', isSleepData: true),
            const SizedBox(height: 24.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAverageSummaryItem(
                  '평균 스트레스',
                  _firestoreService.getMoodScoresStream(_currentUserId!),
                      (data) => (data['score'] as num?)?.toDouble() ?? 0.0,  // ✅
                  '',
                ),
                _buildAverageSummaryItem(
                  '평균 건강점수',
                  _firestoreService.getMentalHealthScoresStream(_currentUserId!),
                      (data) => (data['score'] as num?)?.toDouble() ?? 0.0,  // ✅
                  '',
                ),
                _buildAverageSummaryItem(
                  '평균 수면',
                  _firestoreService.getSleepScoresStream(_currentUserId!),
                      (data) => (data['duration'] as num?)?.toDouble() ?? 0.0,  // ✅
                  'h',
                ),
              ],
            ),
          ] else
            const Center(child: Text('로그인이 필요합니다.')),
        ],
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _buildSleepDataStream() {
    // 이제 FirestoreService에서 실제 수면 데이터를 가져옵니다.
    return _firestoreService.getSleepScoresStream(_currentUserId!);
  }

Widget _buildWeeklyMetricChart(String title, Color color, Stream<List<Map<String, dynamic>>> stream, {String dataField = 'score', bool isSleepData = false}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: const Color(0xFF374151),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12.0),
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 140,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          List<Map<String, dynamic>> data = snapshot.data ?? [];
          Map<int, List<double>> dailyAggregatedScores = {1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: []};

          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6));

          final filteredData = data.where((scoreData) {
            final timestamp = scoreData['timestamp'] as Timestamp?;
            if (timestamp == null) return false;
            final date = timestamp.toDate();
            // 정확한 주간 범위 필터링
            final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
            final endOfDay = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);
            return !date.isBefore(startOfDay) && !date.isAfter(endOfDay);
          }).toList();

          for (var scoreData in filteredData) {
            final timestamp = (scoreData['timestamp'] as Timestamp).toDate();
            final score = (scoreData[dataField] as num?)?.toDouble();
            if (score != null) {
              dailyAggregatedScores.putIfAbsent(timestamp.weekday, () => []).add(score);
            }
          }

          List<BarChartGroupData> barGroups = [];
          double maxY = 0;

          for (int i = 1; i <= 7; i++) {
            final scores = dailyAggregatedScores[i] ?? [];
            final avgScore = scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0.0;
            if (avgScore > maxY) {
              maxY = avgScore;
            }
            barGroups.add(
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: avgScore,
                    color: color,
                    width: 16,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
            );
          }
          
          maxY = isSleepData ? (maxY == 0 ? 10 : (maxY * 1.2).ceilToDouble()) : 100;


          return SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final dayDate = startOfWeek.add(Duration(days: group.x - 1));
                      final dateString = DateFormat('M/d').format(dayDate);
                      String valueText;
                      if (isSleepData) {
                        valueText = '${rod.toY.toStringAsFixed(1)}h';
                      } else {
                        valueText = rod.toY.toStringAsFixed(0);
                      }
                      
                      return BarTooltipItem(
                        '$valueText\n',
                        GoogleFonts.roboto(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: dateString,
                            style: GoogleFonts.roboto(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                    getTooltipColor: (_) => const Color(0xFF374151),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        const style = TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        );
                        Widget text;
                        switch (value.toInt()) {
                          case 1: text = const Text('월', style: style); break;
                          case 2: text = const Text('화', style: style); break;
                          case 3: text = const Text('수', style: style); break;
                          case 4: text = const Text('목', style: style); break;
                          case 5: text = const Text('금', style: style); break;
                          case 6: text = const Text('토', style: style); break;
                          case 7: text = const Text('일', style: style); break;
                          default: text = const Text('', style: style); break;
                        }
                        return SideTitleWidget(axisSide: meta.axisSide, space: 8.0, child: text);
                      },
                      reservedSize: 30,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
                gridData: const FlGridData(show: false),
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
              ),
            ),
          );
        },
      ),
    ],
  );
}


  Widget _buildBarWithLabel(String day, String date, double heightFactor, Color color) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: 100 * (heightFactor.isNaN ? 0.0 : heightFactor),
            width: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            day,
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            date,
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF9CA3AF),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 12,  // ✅ 14 → 12로 줄임
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6B7280),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.roboto(
            fontSize: 16,  // ✅ 18 → 16으로 줄임
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildAverageSummaryItem(String label, Stream<List<Map<String, dynamic>>> stream, double Function(Map<String, dynamic>) scoreExtractor, String unit) {
    return Flexible(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: [
                Text(
                  label,
                  style: GoogleFonts.roboto(
                    fontSize: 12,  // ✅ 14 → 12로 줄임
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const SizedBox(
                  height: 16,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            );
          }
          if (snapshot.hasError) {
            return _buildSummaryItem(label, '오류');
          }

          List<Map<String, dynamic>> data = snapshot.data ?? [];
          double totalScore = 0.0;
          int count = 0;

          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 6));

          // 필터링 및 평균 계산
          final filteredData = data.where((scoreData) {
            final timestamp = scoreData['timestamp'] as Timestamp?;
            return timestamp != null &&
                timestamp.toDate().isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                timestamp.toDate().isBefore(endOfWeek.add(const Duration(days: 1)));
          }).toList();

          for (var item in filteredData) {
            try {
              totalScore += scoreExtractor(item);
              count++;
            } catch (e) {
              // Handle potential parsing errors if scoreExtractor fails
            }
          }

          // ✅ averageValue 정의 (이 부분이 중요!)
          String averageValue = count > 0 ? (totalScore / count).toStringAsFixed(1) : 'N/A';

          // ✅ 폰트 크기 줄인 버전으로 직접 반환
          return Column(
            children: [
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 12,  // ✅ 14 → 12로 줄임
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6B7280),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '$averageValue$unit',
                style: GoogleFonts.roboto(
                  fontSize: 16,  // ✅ 18 → 16으로 줄임
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInsightCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '인사이트',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildInsightItem(
            '수면과 스트레스의 상관관계',
            '수면 시간이 6시간 미만일 때 스트레스 지수가 평균 25% 높아집니다.',
            const Color(0xFF2563EB),
            const Color(0xFFDBEAFE),
          ),
          const SizedBox(height: 16.0),
          _buildInsightItem(
            '긍정 감정 증가',
            '이번 주 기쁨 감정이 지난주 대비 15% 증가했습니다. 좋은 변화네요!',
            const Color(0xFF16A34A),
            const Color(0xFFDCFCE7),
          ),
          const SizedBox(height: 16.0),
          _buildInsightItem(
            '주의 필요',
            '화요일과 수요일에 불안 감정이 높게 나타났습니다. 해당 요일의 패턴을 확인해보세요.',
            const Color(0xFFCA8A04),
            const Color(0xFFFEF9C3),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String title, String description, Color iconColor, Color bgColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.lightbulb_outline, color: iconColor, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: const Color(0xFF1F2937),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: const Color(0xFF4B5563),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionItem(
            'AI와 대화',
            '감정 상태 체크',
            Icons.chat_bubble_outline,
            const Color(0xFF16A34A),
            const Color(0xFFDCFCE7),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AIChatScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 16.0),
        Expanded(
          child: _buildQuickActionItem(
            '힐링 콘텐츠',
            '맞춤 추천',
            Icons.spa_outlined,
            const Color(0xFFEA580C),
            const Color(0xFFFFEDD5),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HealingScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    Color bgColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 12.0),
            Text(
              title,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: const Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 4.0),
            Text(
              subtitle,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: const Color(0xFF4B5563),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 월간 탭 ====================
  Widget _buildMonthlyContent() {
    return Column(
      children: [
        _buildMonthlyStatusCard(),
        const SizedBox(height: 24.0),
        _buildMonthlyEmotionDistributionCard(),
        const SizedBox(height: 24.0),
        _buildMonthlyTrendsCard(),
        const SizedBox(height: 24.0),
        _buildMonthlyInsightsCard(),
        const SizedBox(height: 24.0),
        _buildMonthlyQuickActionsCard(),
      ],
    );
  }

  Widget _buildMonthlyStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1),)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('이번 달 상태', style: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 18, color: const Color(0xFF1F2937),)),
          const SizedBox(height: 16.0),
          if (_currentUserId != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // [1] 스트레스 (기존 유지)
                _buildStreamedStatusItem(
                  stream: _firestoreService.getMoodScoresStream(_currentUserId!),
                  label: '스트레스',
                  valueColor: const Color(0xFF1F2937),
                  timePeriod: 'monthly',
                  scoreExtractor: (data) => (data['score'] as num?)?.toDouble() ?? 0.0,
                  isStress: true,
                ),
                // [2] 건강 점수 (수정됨!)
                _buildStreamedStatusItem(
                  stream: _firestoreService.getDailyMentalStatusListStream(_currentUserId!), // [변경]
                  label: '건강 점수',
                  valueColor: const Color(0xFF2563EB),
                  timePeriod: 'monthly',
                  // [변경] 'overallScore' 필드를 읽도록 수정
                  scoreExtractor: (data) => (data['overallScore'] as num?)?.toDouble() ?? 0.0,
                ),
                // [3] 수면 시간 (기존 유지)
                _buildStreamedStatusItem(
                  stream: _firestoreService.getSleepScoresStream(_currentUserId!),
                  label: '수면 시간',
                  valueColor: const Color(0xFF9333EA),
                  timePeriod: 'monthly',
                  scoreExtractor: (data) => (data['duration'] as num?)?.toDouble() ?? 0.0,
                  unit: 'h',
                ),
              ],
            )
          else
            const Center(child: Text('로그인이 필요합니다.')),
        ],
      ),
    );
  }

  Widget _buildMonthlyEmotionDistributionCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '평균 감정 분포',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildEmotionProgress('기쁨', 0.0, const Color(0xFF22C55E), '0%'),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('슬픔', 0.0, const Color(0xFF3B82F6), '0%'),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('불안', 0.0, const Color(0xFFF59E0B), '0%'),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('분노', 0.0, const Color(0xFFEF4444), '0%'),
          const SizedBox(height: 12.0),
          _buildEmotionProgress('평온', 0.0, const Color(0xFF6B7280), '0%'),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendsCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '월간 변화 추이',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 24.0),
          _buildMonthlyMetricChartWithStream(
            '스트레스',
            const Color(0xFFCA8A04),
            _firestoreService.getMoodScoresStream(_currentUserId!),
          ),
          const SizedBox(height: 24.0),
          _buildMonthlyMetricChartWithStream(
            '건강 점수',
            const Color(0xFF2563EB),
            _firestoreService.getMentalHealthScoresStream(_currentUserId!),
          ),
          const SizedBox(height: 24.0),
          _buildMonthlyMetricChartWithStream(
            '수면 시간',
            const Color(0xFF9333EA),
            _firestoreService.getSleepScoresStream(_currentUserId!),
            dataField: 'duration',
          ),
        ],
      ),
    );
  }

  /// 실제 데이터를 사용하는 월간 차트
  Widget _buildMonthlyMetricChartWithStream(String title, Color color, Stream<List<Map<String, dynamic>>> stream, {String dataField = 'score'}) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        List<Map<String, dynamic>> data = snapshot.data ?? [];

        // 이번 달의 시작과 끝
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);

        // 이번 달 데이터만 필터링
        final monthData = data.where((item) {
          final timestamp = item['timestamp'] as Timestamp?;
          if (timestamp == null) return false;
          final date = timestamp.toDate();
          return date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
                 date.isBefore(endOfMonth.add(const Duration(days: 1)));
        }).toList();

        // 실제 주 수로 나누기 (최대 5주)
        List<double> weeklyAverages = [];
        final daysInMonth = endOfMonth.day;
        final weeksInMonth = (daysInMonth / 7).ceil().clamp(1, 5);

        for (int week = 0; week < weeksInMonth; week++) {
          final weekStart = startOfMonth.add(Duration(days: week * 7));
          final weekEnd = startOfMonth.add(Duration(days: (week + 1) * 7));

          final weekData = monthData.where((item) {
            final timestamp = item['timestamp'] as Timestamp?;
            if (timestamp == null) return false;
            final date = timestamp.toDate();
            return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
                   date.isBefore(weekEnd);
          }).toList();

          if (weekData.isEmpty) {
            weeklyAverages.add(0);
          } else {
            double sum = 0;
            for (var item in weekData) {
              sum += (item[dataField] as num?)?.toDouble() ?? 0;
            }
            weeklyAverages.add(sum / weekData.length);
          }
        }

        final maxValue = weeklyAverages.isEmpty ? 0.0 : weeklyAverages.reduce((a, b) => a > b ? a : b);

        return StatefulBuilder(
          builder: (context, setState) {
            int? selectedWeekIndex;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 12.0),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(weeklyAverages.length, (index) {
                    final value = weeklyAverages[index];
                    final heightRatio = maxValue > 0 ? value / maxValue : 0.0;
                    final height = 80.0 * heightRatio;
                    final isSelected = selectedWeekIndex == index;

                    // 수면 시간은 "h" 단위로, 나머지는 정수로 표시
                    final valueText = dataField == 'duration'
                        ? '${value.toStringAsFixed(1)}h'
                        : value.toStringAsFixed(0);

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedWeekIndex = isSelected ? null : index;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.only(right: index < weeklyAverages.length - 1 ? 8.0 : 0),
                          child: Column(
                            children: [
                              // 수치 표시 (터치했을 때만)
                              SizedBox(
                                height: 20,
                                child: isSelected && value > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          valueText,
                                          style: GoogleFonts.roboto(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              // 막대 그래프
                              Container(
                                height: 80,
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: height > 0 ? height : 4,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 주차 레이블
                              Text(
                                '${index + 1}주차',
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  color: isSelected ? color : const Color(0xFF6B7280),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMonthlyInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '인사이트',
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16.0),
          _buildInsightItem(
            '수면과 스트레스의 상관관계',
            '수면 시간이 6시간 미만일 때 스트레스 지수가 평균 25% 높아집니다.',
            const Color(0xFF2563EB),
            const Color(0xFFDBEAFE),
          ),
          const SizedBox(height: 16.0),
          _buildInsightItem(
            '긍정 감정 증가',
            '이번 달 기쁨 감정이 지난달 대비 15% 증가했습니다. 좋은 변화네요!',
            const Color(0xFF16A34A),
            const Color(0xFFDCFCE7),
          ),
          const SizedBox(height: 16.0),
          _buildInsightItem(
            '주의 필요',
            '매월 셋째 주에 불안 감정이 높게 나타났습니다. 해당 주의 패턴을 확인해보세요.',
            const Color(0xFFCA8A04),
            const Color(0xFFFEF9C3),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyQuickActionsCard() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionItem(
            'AI와 대화',
            '감정 상태 체크',
            Icons.chat_bubble_outline,
            const Color(0xFF16A34A),
            const Color(0xFFDCFCE7),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AIChatScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 16.0),
        Expanded(
          child: _buildQuickActionItem(
            '힐링 콘텐츠',
            '맞춤 추천',
            Icons.spa_outlined,
            const Color(0xFFEA580C),
            const Color(0xFFFFEDD5),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HealingScreen()),
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(message),
      ),
    );
  }
}
