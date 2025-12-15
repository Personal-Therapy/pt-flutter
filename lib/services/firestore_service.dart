import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _getFormattedDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Add a new user document to Firestore during registration
  Future<void> addUser(String uid, String name, String email) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'conversationCount': 0,
      'averageHealthScore': 0,
      'healingContentCount': 0,
    });
  }

  // Get user data
  Stream<Map<String, dynamic>?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    });
  }

  // Create or update user data from Google Sign-In
  Future<void> upsertGoogleUser(User user) async {
    final userRef = _db.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      // If user is new, create document with all default fields
      await userRef.set({
        'uid': user.uid,
        'name': user.displayName ?? '사용자', // Provide a default name
        'email': user.email,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'conversationCount': 0,
        'averageHealthScore': 0,
        'healingContentCount': 0,
      });
    } else {
      // If user exists, just update name and photoURL
      await userRef.update({
        'name': user.displayName,
        'photoURL': user.photoURL,
      });
    }
  }

  // Update user mood score
  Future<void> updateMoodScore(
      String uid,
      int moodScore, {
        Map<String, dynamic>? detailedAnswers,
        double? detailScore,
        Map<String, String>? categories,
      }) async {
    final data = {
      'score': moodScore,
      'timestamp': FieldValue.serverTimestamp(),
      if (detailedAnswers != null) 'detailedAnswers': detailedAnswers,
      if (detailScore != null) 'detailScore': detailScore,
      if (categories != null) 'categories': categories,
    };
    await _db.collection('users').doc(uid).collection('mood_scores').add(data);

    await updateDailyMentalStatus(
      uid: uid,
      moodCheckScore: moodScore * 10,
    );
  }

  // Get user mood scores
  Stream<List<Map<String, dynamic>>> getMoodScoresStream(String uid) {
    return _db.collection('users').doc(uid).collection('mood_scores')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data())
          .where((data) => data['timestamp'] != null && data['score'] != null)
          .toList();
    });
  }

  // Update user mental health score
  Future<void> updateMentalHealthScore(String uid, String testType, int mentalHealthScore) async {
    // Invert and normalize the score. A raw score of 10 (best) becomes 100, and 50 (worst) becomes 0.
    double normalizedScore = (50 - mentalHealthScore) * 2.5;

    await _db.collection('users').doc(uid).collection('mental_health_scores').add({
      'testType': testType,
      'score': mentalHealthScore, // Keep original score for context
      'normalizedScore': normalizedScore.round(), // Store normalized score
      'timestamp': FieldValue.serverTimestamp(),
    });

    // After updating individual mental health score, trigger overall daily mental status update
    await updateDailyMentalStatus(
      uid: uid,
      selfDiagnosisScore: normalizedScore.round(), // Pass the normalized score for this specific test
      selfDiagnosisTestType: testType,
    );
  }

  // Get user mental health scores
  Stream<List<Map<String, dynamic>>> getMentalHealthScoresStream(String uid) {
    return _db.collection('users').doc(uid).collection('mental_health_scores')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

// [신규] AI Chat 감정 분석 점수 저장 및 집계 업데이트 (수정됨: 감정 데이터 추가)
  Future<void> updateAIChatScore(
      String uid,
      int aiScore, {
        // 💡 Map<String, int> 타입의 감정 데이터를 받도록 추가
        required Map<String, int> emotions,
      }) async {
    // 1. AI 분석 기록 저장
    await _db.collection('users').doc(uid).collection('ai_chat_scores').add({
      'score': aiScore,
      'emotions': emotions, // 💡 감정 데이터 저장
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. 일일 종합 점수 업데이트 트리거
    await updateDailyMentalStatus(
      uid: uid,
      aiConversationScore: aiScore,
    );
  }

  // [수정] 생체 데이터 기반 생체리듬 점수 저장 (HRV 기반)
  // stressScore 대신 biorhythmScore로 변경, nullable 지원
  Future<void> updateBiometricScore(
      String uid, {
        int? biorhythmScore,  // HRV 기반 생체리듬 점수 (0-100, 높을수록 좋음)
        double? hrvValue,     // 원본 HRV RMSSD 값 (ms)
        int? heartRate,       // 원본 심박수
      }) async {
    // 점수가 null이면 저장하지 않음 (데이터 없는 경우)
    if (biorhythmScore == null) {
      print('⚠️ 생체리듬 점수가 null - 저장 건너뜀');
      return;
    }

    await _db.collection('users').doc(uid).collection('biometric_scores').add({
      'score': biorhythmScore,
      'hrvRmssd': hrvValue,       // 원본 HRV 값 저장 (디버깅/분석용)
      'heartRate': heartRate,     // 원본 심박수 저장
      'timestamp': FieldValue.serverTimestamp(),
    });

    await updateDailyMentalStatus(
      uid: uid,
      biometricStressScore: biorhythmScore,
    );
  }

  // [레거시 호환] 기존 updateBiometricStress 함수 유지 (하위 호환성)
  @Deprecated('Use updateBiometricScore instead')
  Future<void> updateBiometricStress(String uid, int stressScore) async {
    // 스트레스 점수를 건강 점수로 변환 (100 - 스트레스)
    // 단, 0이면 데이터 없는 것으로 간주하고 저장하지 않음
    if (stressScore == 0) {
      print('⚠️ 스트레스 점수 0 - 데이터 없음으로 간주, 저장 건너뜀');
      return;
    }

    final healthScore = (100 - stressScore).clamp(0, 100);

    await _db.collection('users').doc(uid).collection('biometric_scores').add({
      'score': healthScore,
      'originalStress': stressScore,  // 원본 스트레스 값 보존
      'timestamp': FieldValue.serverTimestamp(),
    });

    await updateDailyMentalStatus(
      uid: uid,
      biometricStressScore: healthScore,
    );
  }

  // [수정/안전모드] Update daily mental status with fixed weighted scores
  // 이 함수는 클래스의 메서드로 독립적으로 존재해야 합니다.
  // [수정/로그추가] Update daily mental status with logs
  Future<void> updateDailyMentalStatus({
    required String uid,
    int? selfDiagnosisScore, // Normalized (0-100)
    String? selfDiagnosisTestType,
    int? moodCheckScore,      // 0-100
    int? aiConversationScore, // 0-100
    int? biometricStressScore,// 0-100
  }) async {
    final dateKey = _getFormattedDateKey(DateTime.now());
    final docRef = _db.collection('users').doc(uid).collection('daily_mental_status').doc(dateKey);

    // 1. 기존 데이터 가져오기
    final existingDoc = await docRef.get();
    final Map<String, dynamic> existingData = existingDoc.data() ?? {};
    final componentScores = existingData['componentScores'] ?? {};

    // -----------------------------------------------------------------------
    // A. 자가진단 (Self-Diagnosis) 처리
    // -----------------------------------------------------------------------
    Map<String, dynamic> selfDiagMap = {};
    // [안전장치] 기존 데이터가 Map인지 확인
    if (componentScores['selfDiagnosis'] is Map) {
      selfDiagMap = Map<String, dynamic>.from(componentScores['selfDiagnosis']);
    }

    if (selfDiagnosisScore != null && selfDiagnosisTestType != null) {
      selfDiagMap[selfDiagnosisTestType] = selfDiagnosisScore;
    }

    List<int> diagValues = [];
    selfDiagMap.forEach((key, value) {
      if (key != 'average' && value is num) {
        diagValues.add(value.toInt());
      }
    });

    int? avgSelfDiagnosis;
    if (diagValues.isNotEmpty) {
      avgSelfDiagnosis = (diagValues.reduce((a, b) => a + b) / diagValues.length).round();
    }
    selfDiagMap['average'] = avgSelfDiagnosis;

    // -----------------------------------------------------------------------
    // B. 현재 값 확정 (안전 모드)
    // -----------------------------------------------------------------------

    // 1. Mood Check 안전하게 가져오기
    int? currentMood = moodCheckScore;
    if (currentMood == null) {
      var rawMood = componentScores['dailyEmotion']?['moodCheck'];
      if (rawMood is int) {
        currentMood = rawMood;
      } else if (rawMood is num) {
        currentMood = rawMood.round();
      } else if (rawMood is Map && rawMood['score'] is num) {
        // 혹시 {score: 50} 형태로 저장되어 있다면 점수만 추출
        currentMood = (rawMood['score'] as num).round();
      }
    }

    // 2. AI Conversation 안전하게 가져오기
    int? currentAi = aiConversationScore;
    if (currentAi == null) {
      var rawAi = componentScores['dailyEmotion']?['aiConversation'];
      if (rawAi is int) {
        currentAi = rawAi;
      } else if (rawAi is num) {
        currentAi = rawAi.round();
      } else if (rawAi is Map) {
        // {'average': 70} 형태인 경우 처리
        var avg = rawAi['average'];
        if (avg is num) currentAi = avg.round();
      }
    }

    // 3. Biometric Stress 안전하게 가져오기
    int? currentBio = biometricStressScore;
    if (currentBio == null) {
      var rawBio = componentScores['biometricStress'];
      if (rawBio is int) {
        currentBio = rawBio;
      } else if (rawBio is num) {
        currentBio = rawBio.round();
      } else if (rawBio is Map && rawBio['score'] is num) {
        currentBio = (rawBio['score'] as num).round();
      }
    }

    // -----------------------------------------------------------------------
    // C. 가중 평균 계산
    // -----------------------------------------------------------------------
    double sumWeightedScore = 0.0;
    double sumWeights = 0.0;

    if (avgSelfDiagnosis != null) {
      sumWeightedScore += avgSelfDiagnosis * 0.4;
      sumWeights += 0.4;
    }
    if (currentMood != null) {
      sumWeightedScore += currentMood * 0.1;
      sumWeights += 0.1;
    }
    if (currentAi != null) {
      sumWeightedScore += currentAi * 0.3;
      sumWeights += 0.3;
    }
    if (currentBio != null) {
      sumWeightedScore += currentBio * 0.2;
      sumWeights += 0.2;
    }

    int? finalOverallScore;
    if (sumWeights > 0) {
      finalOverallScore = (sumWeightedScore / sumWeights).round();
    }

    // -----------------------------------------------------------------------
    // 🔥 [로그 출력] 여기가 추가된 부분입니다 🔥
    // -----------------------------------------------------------------------
    print('\n\n');
    print('🔥🔥🔥🔥🔥🔥🔥🔥 [점수 집계 로그 시작] 🔥🔥🔥🔥🔥🔥🔥🔥');
    print('📅 날짜: $dateKey');
    print('--------------------------------------------------');
    print('1️⃣ 자가진단 (40%): ${avgSelfDiagnosis ?? "데이터 없음"} (상세: $selfDiagMap)');
    print('2️⃣ 기분체크 (10%): ${currentMood ?? "데이터 없음"}');
    print('3️⃣ AI 대화 (30%): ${currentAi ?? "데이터 없음"}');
    print('4️⃣ 생체신호 (20%): ${currentBio ?? "데이터 없음"}');
    print('--------------------------------------------------');
    print('🏆 최종 반영된 점수: ${finalOverallScore ?? "계산 불가"} / 100');
    print('🔥🔥🔥🔥🔥🔥🔥🔥 [점수 집계 로그 종료] 🔥🔥🔥🔥🔥🔥🔥🔥');
    print('\n\n');

    // -----------------------------------------------------------------------
    // D. Firestore 저장
    // -----------------------------------------------------------------------
    // -----------------------------------------------------------------------
    // D. Firestore 저장
    // -----------------------------------------------------------------------
    await docRef.set({
      'date': dateKey,
      'overallScore': finalOverallScore,
      'componentScores': {
        'selfDiagnosis': selfDiagMap,
        'dailyEmotion': {
          'moodCheck': currentMood,
          'aiConversation': currentAi != null ? {'average': currentAi} : null,
        },
        'biometricStress': currentBio,
      },
      // [추가됨] 차트가 날짜를 인식할 수 있도록 Timestamp 필드 추가!
      'timestamp': Timestamp.fromDate(DateTime.now()),

      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>?> getDailyMentalStatusStream(String uid, DateTime date) {
    final dateKey = _getFormattedDateKey(date);
    return _db.collection('users').doc(uid).collection('daily_mental_status').doc(dateKey).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    });
  }

  // Update user sleep time
  Future<void> addSleepRecord(String uid, double duration) async {
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await _db.collection('users').doc(uid).collection('sleep_records').doc(dateKey).set({
      'duration': duration,
      'timestamp': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
    });
  }

  // Get user sleep scores
  Stream<List<Map<String, dynamic>>> getSleepScoresStream(String uid) {
    return _db.collection('users').doc(uid).collection('sleep_records')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data())
          .where((data) => data['timestamp'] != null && data['duration'] != null)
          .toList();
    });
  }

  // 개발용: 모든 수면 기록 삭제
  Future<void> deleteAllSleepRecords(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).collection('sleep_records').get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // 안심 연락망 관리
  Future<void> addEmergencyContact(String uid, Map<String, dynamic> contact) async {
    final userDoc = _db.collection('users').doc(uid);
    await userDoc.update({
      'emergencyContacts': FieldValue.arrayUnion([contact])
    });
  }

  Future<void> updateEmergencyContact(String uid, int index, Map<String, dynamic> contact) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      List<dynamic> contacts = List.from(userDoc.data()?['emergencyContacts'] ?? []);
      if (index < contacts.length) {
        contacts[index] = contact;
        await _db.collection('users').doc(uid).update({'emergencyContacts': contacts});
      }
    }
  }

  Future<void> deleteEmergencyContact(String uid, int index) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      List<dynamic> contacts = List.from(userDoc.data()?['emergencyContacts'] ?? []);
      if (index < contacts.length) {
        contacts.removeAt(index);
        await _db.collection('users').doc(uid).update({'emergencyContacts': contacts});
      }
    }
  }

  Stream<List<Map<String, dynamic>>> getEmergencyContactsStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data()?['emergencyContacts'] != null) {
        return List<Map<String, dynamic>>.from(
            snapshot.data()!['emergencyContacts'].map((contact) => Map<String, dynamic>.from(contact))
        );
      }
      return [];
    });
  }

  // 일별 종합 점수 리스트 가져오기 (통계 화면용)
  Stream<List<Map<String, dynamic>>> getDailyMentalStatusListStream(String uid) {
    return _db.collection('users').doc(uid).collection('daily_mental_status')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // AI Chat 감정 분석 점수 전체 리스트 가져오기 (감정 분포 계산에 사용)
  Stream<List<Map<String, dynamic>>> getAIChatScoresStream(String uid) {
    // timestamp를 기준으로 내림차순 정렬하여 모든 AI 챗 스코어 기록을 가져옵니다.
    return _db.collection('users').doc(uid).collection('ai_chat_scores')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// health_data 컬렉션에서 건강 데이터 스트림 가져오기
  Stream<List<Map<String, dynamic>>> getHealthDataStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('health_data')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<int?> getTodayOverallScore(String uid) async {
    final dateKey = _getFormattedDateKey(DateTime.now());

    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('daily_mental_status')
        .doc(dateKey)
        .get();

    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    final score = data['overallScore'];
    if (score is int) return score;
    if (score is num) return score.round();

    return null;
  }

  // ==================== 채팅 메시지 저장/불러오기 ====================

  /// 채팅 메시지 저장
  Future<void> saveChatMessage({
    required String uid,
    required String text,
    required bool isUser,
    Map<String, dynamic>? emotionAnalysis,
  }) async {
    await _db.collection('users').doc(uid).collection('chat_messages').add({
      'text': text,
      'isUser': isUser,
      'timestamp': FieldValue.serverTimestamp(),
      if (emotionAnalysis != null) 'emotionAnalysis': emotionAnalysis,
    });
  }

  /// 채팅 메시지 불러오기 (시간순 정렬)
  Future<List<Map<String, dynamic>>> getChatMessages(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('chat_messages')
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// 채팅 메시지 스트림 (실시간 업데이트용)
  Stream<List<Map<String, dynamic>>> getChatMessagesStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('chat_messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// 모든 채팅 메시지 삭제 (새 대화 시작용)
  Future<void> clearChatMessages(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('chat_messages')
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}