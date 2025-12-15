import 'dart:math';
import 'youtube_service.dart';

import 'dart:math';
import 'youtube_service.dart';

class HealingRecommendationService {
  final YoutubeService _youtubeService = YoutubeService();
  final HealingKeywordDatabase _database = HealingKeywordDatabase();
  final ScoreBasedPADCalculator _padCalculator = ScoreBasedPADCalculator();
  final ImprovedQualityFilter _qualityFilter = ImprovedQualityFilter();
  final SubmodularDiversityOptimizer _diversityOptimizer =
  SubmodularDiversityOptimizer();

  /// 전체 추천 (기존 로직)
  Future<List<Map<String, String>>> getHealingRecommendations({
    required int userScore,
    int totalResults = 10,
  }) async {
    print('==== 힐링 추천 시작 (score: $userScore) ====');

    final context = _analyzeUserState(userScore);

    print('[PAD] ${_padCalculator.explainPAD(userScore)}');
    print('[긴급도] ${(context["urgency"] * 100).toStringAsFixed(1)}%');

    final weights = _calculateDynamicWeights(context);
    final counts = _convertToCounts(weights, totalResults);

    print(
        '[목표 개수] Core: ${counts["core"]}, Refresh: ${counts["refresh"]}, Safety: ${counts["safety"]}');

    final keywords = _extractCuratedKeywords(context);

    final timeContext = _getCurrentContext();
    final queries = _buildContextualQueries(keywords, timeContext);

    final candidates = await _collectCandidates(queries, counts);
    print('[수집] 후보 영상: ${candidates.length}개');

    final filtered = _filterByQuality(candidates, context);
    print('[필터링] 품질 통과: ${filtered.length}개');

    final finalList = _ensureDiversity(filtered, totalResults);
    print('[추천 완료] 최종: ${finalList.length}개');

    return finalList;
  }

  /// 🆕 카테고리별 영상 추천
  Future<List<Map<String, String>>> getVideosByCategory({
    required String category, // '명상', '수면', 'ASMR'
    required int userScore,
    int totalResults = 10,
  }) async {
    print('==== 카테고리 추천 시작 (category: $category, score: $userScore) ====');

    // 카테고리별 전용 키워드 가져오기
    final keywords = _database.getCategorySpecificKeywords(category, userScore);

    if (keywords.isEmpty) {
      print('[경고] 알 수 없는 카테고리: $category');
      return [];
    }

    print('[키워드] $category: ${keywords.join(", ")}');

    // 카테고리별 YouTube 카테고리 ID 매핑
    String? categoryId;
    if (category == '명상' || category == '수면') {
      categoryId = '10'; // Music
    } else if (category == 'ASMR') {
      categoryId = '22'; // People & Blogs
    }

    // 영상 수집
    final candidates = <Map<String, String>>[];
    final seen = <String>{};

    for (final keyword in keywords) {
      if (candidates.length >= totalResults * 2) break;

      try {
        final videos = await _youtubeService.fetchByKeyword(
          keyword,
          categoryId: categoryId,
        );

        for (final v in videos) {
          final id = v["id"]!;
          if (!seen.contains(id)) {
            seen.add(id);
            candidates.add({
              ...v,
              "category": category,
              "keyword": keyword,
            });
          }
        }
      } catch (e) {
        print('[오류] 키워드 "$keyword" 검색 실패: $e');
        continue;
      }
    }

    print('[수집] 후보 영상: ${candidates.length}개');

    // 품질 필터링
    final context = {"score": userScore};
    final filtered = _filterByQuality(candidates, context);
    print('[필터링] 품질 통과: ${filtered.length}개');

    // 다양성 확보
    final finalList = _ensureDiversity(filtered, totalResults);
    print('[추천 완료] 최종: ${finalList.length}개');

    return finalList;
  }
  Map<String, dynamic> _analyzeUserState(int score) {
    final stressLevel = _database.getStressLevel(score);
    final pad = _padCalculator.calculatePAD(score);
    final urgency = _padCalculator.calculateUrgencyFromPAD(pad, score);

    return {
      "score": score,
      "stressLevel": stressLevel,
      "PAD": pad,
      "urgency": urgency,
    };
  }

  Map<String, double> _calculateDynamicWeights(Map<String, dynamic> ctx) {
    final urgency = ctx["urgency"] as double;

    double wSafety, wCore, wRefresh;

    if (urgency > 0.8) {
      wSafety = 0.25;
      wCore = 0.60;
      wRefresh = 0.15;
    } else if (urgency > 0.6) {
      wSafety = 0.20;
      wCore = 0.55;
      wRefresh = 0.25;
    } else if (urgency > 0.4) {
      wSafety = 0.15;
      wCore = 0.50;
      wRefresh = 0.35;
    } else if (urgency > 0.2) {
      wSafety = 0.10;
      wCore = 0.35;
      wRefresh = 0.55;
    } else {
      wSafety = 0.05;
      wCore = 0.20;
      wRefresh = 0.75;
    }

    return {
      "safety": wSafety,
      "core": wCore,
      "refresh": wRefresh,
    };
  }

  Map<String, int> _convertToCounts(Map<String, double> weights, int total) {
    final raw = {
      "safety": weights["safety"]! * total,
      "core": weights["core"]! * total,
      "refresh": weights["refresh"]! * total,
    };

    final floored = {
      "safety": raw["safety"]!.floor(),
      "core": raw["core"]!.floor(),
      "refresh": raw["refresh"]!.floor(),
    };

    int used = floored.values.reduce((a, b) => a + b);
    int rest = total - used;

    final fractional = [
      MapEntry("safety", raw["safety"]! - floored["safety"]!),
      MapEntry("core", raw["core"]! - floored["core"]!),
      MapEntry("refresh", raw["refresh"]! - floored["refresh"]!),
    ]..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in fractional) {
      if (rest == 0) break;
      floored[entry.key] = floored[entry.key]! + 1;
      rest--;
    }

    floored.updateAll((key, value) => max(1, value));

    return floored;
  }

  Map<String, List<String>> _extractCuratedKeywords(Map<String, dynamic> ctx) {
    final stressLevel = ctx["stressLevel"] as String;

    final core = _database.getCoreKeywords(stressLevel);
    final refresh = _database.getRefreshKeywords(stressLevel);
    final safety = _database.getSafetyKeywords();

    return {
      "core": core,
      "refresh": refresh,
      "safety": safety,
    };
  }

  Map<String, String> _getCurrentContext() {
    final now = DateTime.now();
    return {
      "timeOfDay": _getTimeOfDay(now.hour),
      "dayOfWeek": now.weekday >= 6 ? "weekend" : "weekday",
    };
  }

  String _getTimeOfDay(int hour) {
    if (hour >= 6 && hour < 12) return "morning";
    if (hour >= 12 && hour < 18) return "afternoon";
    if (hour >= 18 && hour < 22) return "evening";
    return "night";
  }

  Map<String, List<String>> _buildContextualQueries(
      Map<String, List<String>> keywords,
      Map<String, String> ctx,
      ) {
    final result = <String, List<String>>{};

    for (final entry in keywords.entries) {
      final base = entry.value;
      final isDeep = (entry.key == "core" || entry.key == "safety");
      final queries = <String>[];

      for (final kw in base) {
        queries.add(kw);
        if (isDeep) {
          final timeKw = _database.getTimeContextKeyword(ctx["timeOfDay"]!);
          if (timeKw.isNotEmpty) queries.add("$kw $timeKw");
        }
      }

      result[entry.key] = queries;
    }

    return result;
  }

  Future<List<Map<String, String>>> _collectCandidates(
      Map<String, List<String>> queries,
      Map<String, int> counts,
      ) async {
    const music = "10";
    const blog = "22";

    final candidates = <Map<String, String>>[];

    candidates.addAll(await _fetchByType(
        queries["core"]!, counts["core"]!, "core",
        categoryId: music));
    candidates.addAll(await _fetchByType(
        queries["refresh"]!, counts["refresh"]!, "refresh",
        categoryId: blog));
    candidates.addAll(
        await _fetchByType(queries["safety"]!, counts["safety"]!, "safety"));

    return candidates;
  }

  Future<List<Map<String, String>>> _fetchByType(
      List<String> queries,
      int targetCount,
      String type, {
        String? categoryId,
      }) async {
    final results = <Map<String, String>>[];
    final seen = <String>{};

    for (final q in queries) {
      if (results.length >= targetCount * 2) break;

      try {
        final videos =
        await _youtubeService.fetchByKeyword(q, categoryId: categoryId);

        for (final v in videos) {
          final id = v["id"]!;
          if (!seen.contains(id)) {
            seen.add(id);
            results.add({...v, "type": type, "keyword": q});
          }
        }
      } catch (_) {
        continue;
      }
    }

    return results;
  }

  List<Map<String, String>> _filterByQuality(
      List<Map<String, String>> candidates,
      Map<String, dynamic> ctx,
      ) {
    final scored = <Map<String, dynamic>>[];

    for (final v in candidates) {
      final score =
      _qualityFilter.calculateQualityScore(v["title"]!, v["desc"]!);

      if (score >= 0.3) {
        scored.add({...v, "qualityScore": score});
      }
    }

    scored.sort((a, b) =>
        (b["qualityScore"] as double).compareTo(a["qualityScore"] as double));

    return scored.map((e) {
      final clean = <String, String>{};
      e.forEach((k, v) => clean[k] = v.toString());
      return clean;
    }).toList();
  }

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

// ===== PAD & 각종 헬퍼 클래스들 =====

class PAD {
  final double valence;
  final double arousal;
  final double dominance;
  PAD(this.valence, this.arousal, this.dominance);
}

class ScoreBasedPADCalculator {
  PAD calculatePAD(int score) {
    double valence = score / 100 * 4 + 3; // 3~7
    double arousal = (100 - score) / 100 * 6 + 2; // 2~8
    double dominance = score / 100 * 3 + 3; // 3~6

    return PAD(
      valence.clamp(1.0, 9.0),
      arousal.clamp(1.0, 9.0),
      dominance.clamp(1.0, 9.0),
    );
  }

  double calculateUrgencyFromPAD(PAD pad, int score) {
    double v = (9 - pad.valence) / 9 * 0.15;
    double a = (pad.arousal - 1) / 8 * 0.15;
    double d = (9 - pad.dominance) / 9 * 0.10;

    double base = (100 - score) / 100;

    return (base + v + a + d).clamp(0.0, 1.0);
  }

  String explainPAD(int score) {
    final p = calculatePAD(score);
    return "V=${p.valence.toStringAsFixed(2)}, "
        "A=${p.arousal.toStringAsFixed(2)}, "
        "D=${p.dominance.toStringAsFixed(2)}";
  }
}

class ImprovedQualityFilter {
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

  final List<RegExp> negationPatterns = [
    RegExp(r'(안|못)\s+(힐링|명상|평온|편안)', caseSensitive: false),
    RegExp(r'(no|not|never)\s+(healing|meditation|calm)', caseSensitive: false),
    RegExp(r'\b(실패|failed|망함)\b', caseSensitive: false),
  ];

  double calculateQualityScore(String title, String description) {
    final text = '$title $description'.toLowerCase();

    for (final pattern in negationPatterns) {
      if (pattern.hasMatch(text)) {
        return 0.0;
      }
    }

    double score = 0.5;

    positivePatterns.forEach((pattern, weight) {
      if (pattern.hasMatch(text)) {
        score += weight;
      }
    });

    negativePatterns.forEach((pattern, penalty) {
      if (pattern.hasMatch(text)) {
        score += penalty;
      }
    });

    if (description.length > 100) {
      score += 0.10;
    }
    if (description.length > 300) {
      score += 0.05;
    }

    return score.clamp(0.0, 1.0);
  }
}

class SubmodularDiversityOptimizer {
  double calculateDiversityScore({
    required int channelCount,
    required int keywordCount,
    required int totalSelected,
  }) {
    double channelPenalty = 0.0;
    if (channelCount > 0) {
      channelPenalty = 0.3 * log(1 + channelCount) / log(2);
    }

    double keywordPenalty = keywordCount * 0.15;

    double positionWeight = 1.0 - (totalSelected / 20.0).clamp(0.0, 0.5);

    double diversityScore =
        1.0 - (channelPenalty + keywordPenalty) * positionWeight;

    return diversityScore.clamp(0.0, 1.0);
  }

  double calculateFinalScore({
    required double qualityScore,
    required int channelCount,
    required int keywordCount,
    required int totalSelected,
    double alpha = 0.7,
  }) {
    final diversityScore = calculateDiversityScore(
      channelCount: channelCount,
      keywordCount: keywordCount,
      totalSelected: totalSelected,
    );

    return alpha * qualityScore + (1 - alpha) * diversityScore;
  }

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

      for (int i = 0; i < remaining.length; i++) {
        final video = remaining[i];
        final channelId = video['channelId'] ?? '';
        final keyword = video['keyword'] ?? '';
        final qualityScore =
            double.tryParse(video['qualityScore'] ?? '0.5') ?? 0.5;

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

        channelCount[channelId] = (channelCount[channelId] ?? 0) + 1;
        keywordCount[keyword] = (keywordCount[keyword] ?? 0) + 1;

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

class HealingKeywordDatabase {
  String getStressLevel(int score) {
    if (score < 20) return 'critical';
    if (score < 40) return 'high';
    if (score < 60) return 'moderate';
    if (score < 80) return 'low';
    return 'minimal';
  }

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

  List<String> getSafetyKeywords() {
    return [
      '힐링 음악',
      '편안한 자연',
      '위로가 되는',
    ];
  }

  String getTimeContextKeyword(String timeOfDay) {
    final keywords = {
      'morning': '아침',
      'afternoon': '오후',
      'evening': '저녁',
      'night': '밤',
    };

    return keywords[timeOfDay] ?? '';
  }

  /// 🆕 카테고리별 전용 키워드 (점수 고려)
  List<String> getCategorySpecificKeywords(String category, int userScore) {
    final stressLevel = getStressLevel(userScore);

    final categoryKeywords = {
      '명상': {
        'critical': ['깊은 명상 음악', '마음챙김 명상', '수면 유도 명상', '치유 명상'],
        'high': ['스트레스 해소 명상', '힐링 명상 음악', '명상 가이드', '자연 명상'],
        'moderate': ['편안한 명상', '10분 명상', '명상 음악', '힐링 명상'],
        'low': ['명상 플레이리스트', '명상 브이로그', '짧은 명상'],
        'minimal': ['기분 전환 명상', '명상 루틴', '일상 명상'],
      },
      '수면': {
        'critical': ['불면증 치료 음악', '깊은 수면 음악', '델타파 수면', '수면 유도'],
        'high': ['숙면 음악', '수면 명상', '잠 잘 오는 음악', '수면 백색소음'],
        'moderate': ['편안한 수면 음악', '잠자리 음악', '저녁 수면 음악'],
        'low': ['수면 플레이리스트', '수면 루틴', '릴렉스 음악'],
        'minimal': ['잔잔한 음악', '수면 준비 음악', '휴식 음악'],
      },
      'ASMR': {
        'critical': ['깊은 수면 ASMR', 'ASMR 백색소음', '치유 ASMR', '불면증 ASMR'],
        'high': ['힐링 ASMR', 'ASMR 수면', '릴렉스 ASMR', 'ASMR 명상'],
        'moderate': ['편안한 ASMR', 'ASMR 소리', 'ASMR 브이로그'],
        'low': ['ASMR 플레이리스트', '일상 ASMR', 'ASMR 루틴'],
        'minimal': ['기분 좋은 ASMR', '즐거운 ASMR', 'ASMR 토크'],
      },
    };

    final keywords = categoryKeywords[category]?[stressLevel];
    return keywords ?? [];
  }
}