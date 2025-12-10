import 'dart:math';
import 'youtube_service.dart';

/// 힐링 콘텐츠 추천 서비스 (Phase 1 개선 완료)
///
/// 주요 개선사항:
/// 1. PAD 모델 기반 긁급도 계산
/// 2. Submodular 함수 기반 다양성 최적화
/// 3. 정규표현식 기반 품질 필터링 강화
///
/// 사용법:
/// final service = HealingRecommendationService();
/// final videos = await service.getHealingRecommendations(
///   userScore: 35,
///   mood: 'anxious',
/// );
class HealingRecommendationService {
  final YoutubeService _youtubeService = YoutubeService();
  final HealingKeywordDatabase _database = HealingKeywordDatabase();
  final PADMoodCalculator _padCalculator = PADMoodCalculator();
  final ImprovedQualityFilter _qualityFilter = ImprovedQualityFilter();
  final SubmodularDiversityOptimizer _diversityOptimizer = SubmodularDiversityOptimizer();

  /// 힐링 영상 추천 (메인 함수)
  ///
  /// [userScore]: 0-100 사이의 점수 (외부에서 받아옴, 낮을수록 스트레스 높음)
  /// [mood]: 선택적 기분 상태 ('tired', 'anxious', 'sad', 'angry', 'bored')
  /// [totalResults]: 추천할 영상 개수 (기본 10개)
  Future<List<Map<String, String>>> getHealingRecommendations({
    required int userScore,
    String? mood,
    int totalResults = 10,
  }) async {
    print('=== 힐링 추천 시작 (score: $userScore${mood != null ? ', mood: $mood' : ''}) ===');

    // I. 상태 분석 & 가중치 계산 (✅ PAD 모델 적용)
    final context = _analyzeUserState(userScore, mood);
    print('[긴급도] ${_padCalculator.explainUrgency(userScore, mood)}');

    final weights = _calculateDynamicWeights(context);
    final counts = _convertToCounts(weights, totalResults);

    print('[가중치] Core: ${counts['core']}, Refresh: ${counts['refresh']}, Safety: ${counts['safety']}');

    // II. 키워드 추출
    final keywords = _extractCuratedKeywords(context, mood);

    // III. 상황별 쿼리 생성
    final timeContext = _getCurrentContext();
    final queries = _buildContextualQueries(keywords, timeContext);

    // IV. 영상 수집
    final candidates = await _collectCandidates(queries, counts);
    print('[수집] 후보 영상: ${candidates.length}개');

    // V. 품질 필터링 (✅ 정규표현식 기반 강화)
    final filtered = _filterByQuality(candidates, context);
    print('[필터링] 품질 통과: ${filtered.length}개');

    // VI. 다양성 보장 (✅ Submodular 최적화)
    final finalList = _ensureDiversity(filtered, totalResults);

    print('=== 추천 완료: ${finalList.length}개 ===\n');

    return finalList;
  }

  // ========================================
  // I. 상태 분석 & 가중치 계산 (✅ PAD 모델 적용)
  // ========================================

  /// 사용자 상태 분석
  Map<String, dynamic> _analyzeUserState(int score, String? mood) {
    final stressLevel = _database.getStressLevel(score);
    final urgency = _padCalculator.calculateUrgency(score, mood);

    return {
      'score': score,
      'stressLevel': stressLevel,
      'mood': mood,
      'urgency': urgency,
    };
  }

  /// 동적 가중치 계산
  /// urgency에 따라 Core/Refresh/Safety 비율 결정
  Map<String, double> _calculateDynamicWeights(Map<String, dynamic> context) {
    final urgency = context['urgency'] as double;

    double wSafety, wCore, wRefresh;

    if (urgency > 0.8) {
      // 위급 상황
      wSafety = 0.2;
      wCore = 0.7;
      wRefresh = 0.1;
    } else if (urgency > 0.6) {
      // 높은 스트레스
      wSafety = 0.15;
      wCore = 0.65;
      wRefresh = 0.2;
    } else if (urgency > 0.4) {
      // 중간
      wSafety = 0.1;
      wCore = 0.5;
      wRefresh = 0.4;
    } else if (urgency > 0.2) {
      // 낮음
      wSafety = 0.1;
      wCore = 0.3;
      wRefresh = 0.6;
    } else {
      // 매우 안정
      wSafety = 0.05;
      wCore = 0.15;
      wRefresh = 0.8;
    }

    return {
      'safety': wSafety,
      'core': wCore,
      'refresh': wRefresh,
    };
  }

  /// 가중치를 실제 개수로 변환 (정렬 기반 잔여 배분 방식)
  Map<String, int> _convertToCounts(Map<String, double> weights, int total) {
    // 1) raw 계산
    final raw = {
      'safety': weights['safety']! * total,
      'core': weights['core']! * total,
      'refresh': weights['refresh']! * total,
    };

    // 2) floor 적용
    final floored = {
      'safety': raw['safety']!.floor(),
      'core': raw['core']!.floor(),
      'refresh': raw['refresh']!.floor(),
    };

    // 3) 잔여(rest = total - floor_total)
    int used = floored.values.reduce((a, b) => a + b);
    int rest = total - used;

    // 4) 소수점 큰 순으로 나머지 배분
    final fractional = [
      MapEntry('safety', raw['safety']! - floored['safety']!),
      MapEntry('core', raw['core']! - floored['core']!),
      MapEntry('refresh', raw['refresh']! - floored['refresh']!),
    ];

    fractional.sort((a, b) => b.value.compareTo(a.value)); // 내림차순

    for (var entry in fractional) {
      if (rest == 0) break;
      floored[entry.key] = floored[entry.key]! + 1;
      rest--;
    }

    // 5) 최소 개수 보장
    floored.updateAll((key, value) => max(1, value));

    return floored;
  }

  // ========================================
  // II. 키워드 추출
  // ========================================

  /// 전문가 큐레이션 키워드 추출
  Map<String, List<String>> _extractCuratedKeywords(
      Map<String, dynamic> context,
      String? mood,
      ) {
    final stressLevel = context['stressLevel'] as String;

    var coreKeywords = _database.getCoreKeywords(stressLevel);
    final refreshKeywords = _database.getRefreshKeywords(stressLevel);
    final safetyKeywords = _database.getSafetyKeywords();

    // 기분 상태가 있으면 Core 키워드 앞부분을 기분 키워드로 대체
    if (mood != null) {
      final moodKeywords = _database.getMoodKeywords(mood, stressLevel);
      coreKeywords = [...moodKeywords, ...coreKeywords.skip(moodKeywords.length)];
    }

    return {
      'core': coreKeywords,
      'refresh': refreshKeywords,
      'safety': safetyKeywords,
    };
  }

  // ========================================
  // III. 상황별 쿼리 생성
  // ========================================

  /// 현재 시간 컨텍스트 추출
  Map<String, String> _getCurrentContext() {
    final now = DateTime.now();

    return {
      'timeOfDay': _getTimeOfDay(now.hour),
      'dayOfWeek': now.weekday >= 6 ? 'weekend' : 'weekday',
    };
  }

  String _getTimeOfDay(int hour) {
    if (hour >= 6 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 18) return 'afternoon';
    if (hour >= 18 && hour < 22) return 'evening';
    return 'night';
  }

  /// 키워드에 시간 정보 추가
  Map<String, List<String>> _buildContextualQueries(
      Map<String, List<String>> keywords,
      Map<String, String> context,
      ) {
    final result = <String, List<String>>{};

    for (final entry in keywords.entries) {
      final type = entry.key;
      final baseKeywords = entry.value;
      final queries = <String>[];

      for (final keyword in baseKeywords) {
        // 기본 쿼리
        queries.add(keyword);

        // Core와 Safety만 시간대 조합
        if (type == 'core' || type == 'safety') {
          final timeKeyword = _database.getTimeContextKeyword(
            context['timeOfDay']!,
          );
          if (timeKeyword.isNotEmpty) {
            queries.add('$keyword $timeKeyword');
          }
        }
      }

      result[type] = queries;
    }

    return result;
  }

  // ========================================
  // IV. 유튜브 영상 수집
  // ========================================

  /// 타입별로 영상 수집
  Future<List<Map<String, String>>> _collectCandidates(
      Map<String, List<String>> queries,
      Map<String, int> counts,
      ) async {
    final candidates = <Map<String, String>>[];

    const String musicId = '10'; // 음악
    const String peopleBlogsId = '22'; // 사람/블로그

    // Core 영상: 가장 집중적이고 안전한 힐링 (음악 위주)
    candidates.addAll(
      await _fetchByType(queries['core']!, counts['core']!, 'core',
          categoryId: musicId),
    );

    // Refresh 영상: 기분 전환, 일상 탈출
    candidates.addAll(
      await _fetchByType(queries['refresh']!, counts['refresh']!, 'refresh',
          categoryId: peopleBlogsId),
    );

    // Safety 영상: 보편적 힐링 (카테고리 제한 없음)
    candidates.addAll(
      await _fetchByType(queries['safety']!, counts['safety']!, 'safety'),
    );

    return candidates;
  }

  /// 특정 타입의 영상 수집 (목표의 2배 수집)
  Future<List<Map<String, String>>> _fetchByType(
      List<String> queries,
      int targetCount,
      String type,
      {String? categoryId}
      ) async {
    final results = <Map<String, String>>[];
    final seen = <String>{};

    for (final query in queries) {
      if (results.length >= targetCount * 2) break;

      try {
        final videos = await _youtubeService.fetchByKeyword(
          query,
          categoryId: categoryId,
        );

        for (final video in videos) {
          final id = video['id']!;
          if (!seen.contains(id)) {
            seen.add(id);
            results.add({
              ...video,
              'type': type,
              'keyword': query,
            });
          }
        }
      } catch (e) {
        print('[수집 오류] $query: $e');
        continue;
      }
    }

    return results;
  }

  // ========================================
  // V. 품질 필터링 (✅ 정규표현식 기반 강화)
  // ========================================

  /// 힐링 콘텐츠 품질 기준으로 필터링
  List<Map<String, String>> _filterByQuality(
      List<Map<String, String>> candidates,
      Map<String, dynamic> context,
      ) {
    final scored = <Map<String, dynamic>>[];

    for (final video in candidates) {
      final title = video['title'] ?? '';
      final desc = video['desc'] ?? '';

      // ✅ 개선된 품질 점수 계산
      final qualityScore = _qualityFilter.calculateQualityScore(title, desc);

      // 점수 0.3 이상만 통과
      if (qualityScore >= 0.3) {
        scored.add({
          ...video,
          'qualityScore': qualityScore,
        });
      }
    }

    // 점수 높은 순 정렬
    scored.sort((a, b) =>
        (b['qualityScore'] as double).compareTo(a['qualityScore'] as double)
    );

    // Map<String, String>으로 변환 (qualityScore는 유지)
    return scored.map((item) {
      final result = <String, String>{};
      item.forEach((key, value) {
        result[key] = value.toString();
      });
      return result;
    }).toList();
  }

  // ========================================
  // VI. 다양성 보장 (✅ Submodular 최적화)
  // ========================================

  /// Submodular 함수 기반 다양성 최적화
  List<Map<String, String>> _ensureDiversity(
      List<Map<String, String>> videos,
      int targetCount,
      ) {
    return _diversityOptimizer.selectDiverseVideos(
      candidates: videos,
      targetCount: targetCount,
    );
  }
}

// ========================================
// ✅ PAD 모델 기반 긴급도 계산기
// ========================================

/// PAD (Pleasure-Arousal-Dominance) 모델 데이터
class MoodPAD {
  final double valence;   // 1-9 (불쾌→쾌)
  final double arousal;   // 1-9 (차분→각성)
  final double dominance; // 1-9 (무력→지배)

  const MoodPAD(this.valence, this.arousal, this.dominance);
}

/// PAD 모델 기반 긴급도 계산기
class PADMoodCalculator {
  // 논문 기반 mood별 PAD 값 (1-9 스케일)
  // 출처: Warriner et al. (2013) - Norms of valence, arousal, and dominance
  static const Map<String, MoodPAD> moodPADValues = {
    'anxious': MoodPAD(2.5, 7.5, 3.0),  // 불쾌, 고각성, 낮은 통제감
    'angry':   MoodPAD(2.0, 8.0, 6.0),  // 불쾌, 고각성, 높은 공격성
    'sad':     MoodPAD(2.0, 3.5, 3.5),  // 불쾌, 저각성, 낮은 통제감
    'tired':   MoodPAD(4.0, 2.0, 4.0),  // 중립, 저각성, 중립 통제감
    'bored':   MoodPAD(4.5, 2.5, 5.0),  // 약간 불쾌, 저각성
  };

  /// 개선된 긴급도 계산 (0.0 ~ 1.0)
  double calculateUrgency(int userScore, String? mood) {
    // 1) 기본 긴급도: 점수 기반 (역비례)
    double baseUrgency = (100 - userScore) / 100.0;

    // 2) Mood가 없으면 기본값 반환
    if (mood == null || !moodPADValues.containsKey(mood)) {
      return baseUrgency;
    }

    final pad = moodPADValues[mood]!;

    // 3) PAD → Urgency 변환 공식
    // Valence 낮을수록 (불쾌) → 긴급도 증가
    double valenceComponent = (9.0 - pad.valence) / 9.0 * 0.15;

    // Arousal 높을수록 (각성) → 긴급도 증가
    double arousalComponent = (pad.arousal - 1.0) / 8.0 * 0.15;

    // Dominance 낮을수록 (무력감) → 긴급도 증가
    double dominanceComponent = (9.0 - pad.dominance) / 9.0 * 0.10;

    // 4) 최종 긴급도 (최대값 제한)
    double finalUrgency = baseUrgency + valenceComponent + arousalComponent + dominanceComponent;

    return finalUrgency.clamp(0.0, 1.0);
  }

  /// 긴급도 설명 (디버깅용)
  String explainUrgency(int score, String? mood) {
    final urgency = calculateUrgency(score, mood);
    final level = urgency > 0.8 ? '매우 높음'
        : urgency > 0.6 ? '높음'
        : urgency > 0.4 ? '중간'
        : urgency > 0.2 ? '낮음' : '매우 낮음';

    String explanation = '${(urgency * 100).toStringAsFixed(1)}% ($level)';

    if (mood != null && moodPADValues.containsKey(mood)) {
      final pad = moodPADValues[mood]!;
      explanation += ' [PAD: V=${pad.valence}, A=${pad.arousal}, D=${pad.dominance}]';
    }

    return explanation;
  }
}

// ========================================
// ✅ 정규표현식 기반 품질 필터
// ========================================

/// 개선된 품질 필터링 시스템
class ImprovedQualityFilter {
  // 긍정 키워드 패턴 (Valence > 6.0 기준)
  final Map<RegExp, double> positivePatterns = {
    RegExp(r'\b(힐링|healing)\b', caseSensitive: false): 0.20,
    RegExp(r'\b(명상|meditation|mindfulness)\b', caseSensitive: false): 0.20,
    RegExp(r'\b(평온|peaceful|calm|tranquil)\b', caseSensitive: false): 0.15,
    RegExp(r'\b(자연|nature|natural)\b', caseSensitive: false): 0.15,
    RegExp(r'\b(asmr|백색소음|white noise)\b', caseSensitive: false): 0.15,
    RegExp(r'\b(수면|sleep|sleeping)\b', caseSensitive: false): 0.10,
    RegExp(r'\b(편안|relaxing|comfortable)\b', caseSensitive: false): 0.10,
    RegExp(r'\b(치유|therapy|healing)\b', caseSensitive: false): 0.10,
  };

  // 부정 키워드 패턴 (Valence < 3.0 기준)
  final Map<RegExp, double> negativePatterns = {
    RegExp(r'\b(충격|shock|shocking)\b', caseSensitive: false): -0.50,
    RegExp(r'\b(극혐|혐오|disgusting)\b', caseSensitive: false): -0.50,
    RegExp(r'\b(공포|horror|scary|무서운)\b', caseSensitive: false): -0.30,
    RegExp(r'\b(긴장|tension|스릴|thriller)\b', caseSensitive: false): -0.30,
    RegExp(r'\b(논란|controversy|문제)\b', caseSensitive: false): -0.25,
    RegExp(r'\b(자극|stimulation|센세이션)\b', caseSensitive: false): -0.20,
    RegExp(r'\b(위험|danger|주의|warning)\b', caseSensitive: false): -0.20,
    RegExp(r'\b(폭력|violence|공격)\b', caseSensitive: false): -0.40,
  };

  // 부정문 패턴 (즉시 탈락)
  final List<RegExp> negationPatterns = [
    RegExp(r'(안|못)\s+(힐링|명상|평온|편안)', caseSensitive: false),
    RegExp(r'(no|not|never)\s+(healing|meditation|calm)', caseSensitive: false),
    RegExp(r'\b(실패|failed|망함)\b', caseSensitive: false),
  ];

  /// 품질 점수 계산
  double calculateQualityScore(String title, String description) {
    final text = '$title $description'.toLowerCase();

    // 1) 부정문 체크 (즉시 탈락)
    for (final pattern in negationPatterns) {
      if (pattern.hasMatch(text)) {
        return 0.0;
      }
    }

    // 2) 기본 점수
    double score = 0.5;

    // 3) 긍정 요소 가산
    positivePatterns.forEach((pattern, weight) {
      if (pattern.hasMatch(text)) {
        score += weight;
      }
    });

    // 4) 부정 요소 감점
    negativePatterns.forEach((pattern, penalty) {
      if (pattern.hasMatch(text)) {
        score += penalty;
      }
    });

    // 5) 설명 길이 보너스 (신뢰성 지표)
    if (description.length > 100) {
      score += 0.10;
    }
    if (description.length > 300) {
      score += 0.05;
    }

    return score.clamp(0.0, 1.0);
  }
}

// ========================================
// ✅ Submodular 함수 기반 다양성 최적화
// ========================================

/// Submodular Function 기반 다양성 최적화기
class SubmodularDiversityOptimizer {
  /// 다양성 점수 계산 (Diminishing Returns 원리)
  ///
  /// 이론적 배경:
  /// - f(S ∪ {x}) - f(S) ≥ f(T ∪ {x}) - f(T) for S ⊆ T
  /// - 같은 요소 추가 시 작은 집합에서 더 큰 이득
  double calculateDiversityScore({
    required int channelCount,
    required int keywordCount,
    required int totalSelected,
  }) {
    // 1) 채널 다양성 점수 (로그 감쇠)
    // 첫 중복: -0.2, 둘째: -0.15, 셋째: -0.12, ...
    double channelPenalty = 0.0;
    if (channelCount > 0) {
      // log(1 + x) 기반 감쇠 (Netflix Re-ranking 방식)
      channelPenalty = 0.3 * log(1 + channelCount) / log(2);
    }

    // 2) 키워드 다양성 점수 (선형 감쇠)
    double keywordPenalty = keywordCount * 0.15;

    // 3) Position Bias 보정
    // 초반 선택일수록 다양성 중요도 높음
    double positionWeight = 1.0 - (totalSelected / 20.0).clamp(0.0, 0.5);

    // 4) 최종 다양성 점수
    double diversityScore = 1.0 - (channelPenalty + keywordPenalty) * positionWeight;

    return diversityScore.clamp(0.0, 1.0);
  }

  /// 최종 점수 계산 (Quality + Diversity)
  double calculateFinalScore({
    required double qualityScore,
    required int channelCount,
    required int keywordCount,
    required int totalSelected,
    double alpha = 0.7, // 품질 가중치 (70%)
  }) {
    final diversityScore = calculateDiversityScore(
      channelCount: channelCount,
      keywordCount: keywordCount,
      totalSelected: totalSelected,
    );

    // Quality-Diversity 트레이드오프
    return alpha * qualityScore + (1 - alpha) * diversityScore;
  }

  /// Greedy Selection with Submodular Optimization
  List<Map<String, String>> selectDiverseVideos({
    required List<Map<String, String>> candidates,
    required int targetCount,
  }) {
    if (candidates.isEmpty) return [];

    final result = <Map<String, String>>[];
    final channelCount = <String, int>{};
    final keywordCount = <String, int>{};
    final remaining = List<Map<String, String>>.from(candidates);

    while (result.length < targetCount && remaining.isNotEmpty) {
      double maxScore = -1.0;
      int bestIndex = -1;

      // 현재 상태에서 최적의 영상 찾기
      for (int i = 0; i < remaining.length; i++) {
        final video = remaining[i];
        final channelId = video['channelId'] ?? '';
        final keyword = video['keyword'] ?? '';
        final qualityScore = double.tryParse(video['qualityScore'] ?? '0.5') ?? 0.5;

        // Submodular 기반 최종 점수 계산
        final finalScore = calculateFinalScore(
          qualityScore: qualityScore,
          channelCount: channelCount[channelId] ?? 0,
          keywordCount: keywordCount[keyword] ?? 0,
          totalSelected: result.length,
        );

        if (finalScore > maxScore) {
          maxScore = finalScore;
          bestIndex = i;
        }
      }

      if (bestIndex != -1) {
        final selected = remaining.removeAt(bestIndex);
        final channelId = selected['channelId'] ?? '';
        final keyword = selected['keyword'] ?? '';

        // 카운트 업데이트 (다음 반복에 영향)
        channelCount[channelId] = (channelCount[channelId] ?? 0) + 1;
        keywordCount[keyword] = (keywordCount[keyword] ?? 0) + 1;

        // qualityScore 제거 후 결과에 추가
        final cleaned = Map<String, String>.from(selected);
        cleaned.remove('qualityScore');

        result.add(cleaned);
      } else {
        break;
      }
    }

    return result;
  }
}

// ========================================
// 키워드 데이터베이스 (기존 유지)
// ========================================

/// 힐링 키워드 관리 클래스
class HealingKeywordDatabase {
  /// 점수 → 스트레스 레벨 매핑
  String getStressLevel(int score) {
    if (score < 20) return 'critical';
    if (score < 40) return 'high';
    if (score < 60) return 'moderate';
    if (score < 80) return 'low';
    return 'minimal';
  }

  /// Core Healing 키워드 (스트레스 레벨별)
  List<String> getCoreKeywords(String level) {
    final keywords = {
      'critical': [
        '깊은 명상 음악',
        '수면 유도 명상',
        '자연의 소리 ASMR',
        '심신 안정 음악',
      ],
      'high': [
        '스트레스 해소 명상',
        '마음 치유 음악',
        '힐링 자연 풍경',
        '빗소리 백색소음',
      ],
      'moderate': [
        '편안한 피아노 음악',
        '힐링 브이로그',
        '카페 분위기 음악',
        '감성 풍경 영상',
      ],
      'low': [
        '감성 플레이리스트',
        '여행 풍경',
        '일상 브이로그',
      ],
      'minimal': [
        '기분 전환 음악',
        '즐거운 일상',
        '취미 생활',
      ],
    };

    return keywords[level] ?? ['힐링'];
  }

  /// Refresh 키워드
  List<String> getRefreshKeywords(String level) {
    final keywords = {
      'critical': [
        '차분한 자연',
        '고요한 풍경',
      ],
      'high': [
        '산책 영상',
        '여유로운 풍경',
      ],
      'moderate': [
        '일상 루틴',
        '감성 카페',
      ],
      'low': [
        '취미 브이로그',
        '여행지',
      ],
      'minimal': [
        '즐거운 활동',
        '기분 좋은 음악',
      ],
    };

    return keywords[level] ?? ['기분 전환'];
  }

  /// Safety Net 키워드 (보편적 힐링)
  List<String> getSafetyKeywords() {
    return [
      '힐링 음악',
      '편안한 자연',
      '위로가 되는',
    ];
  }

  /// 기분 상태별 특화 키워드
  List<String> getMoodKeywords(String mood, String level) {
    final isDeep = level == 'critical' || level == 'high';

    final keywords = {
      'tired': isDeep
          ? ['수면 명상', '피로 회복 음악']
          : ['낮잠 음악', '휴식'],

      'anxious': isDeep
          ? ['불안 해소 명상', '마음 안정']
          : ['차분한 음악', '고요한 자연'],

      'sad': isDeep
          ? ['감정 치유', '위로 음악']
          : ['감성 음악', '따뜻한 이야기'],

      'angry': isDeep
          ? ['분노 조절 명상', '심호흡']
          : ['평온한 풍경', '차분한 음악'],

      'bored': isDeep
          ? ['집중력 향상', '활력 회복']
          : ['기분 전환', '즐거운 활동'],
    };

    return keywords[mood] ?? ['힐링'];
  }

  /// 시간대별 보조 키워드
  String getTimeContextKeyword(String timeOfDay) {
    final keywords = {
      'morning': '아침',
      'afternoon': '오후',
      'evening': '저녁',
      'night': '밤',
    };

    return keywords[timeOfDay] ?? '';
  }
}