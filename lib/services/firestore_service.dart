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

  // Update daily mental status with weighted scores
  Future<void> updateDailyMentalStatus({
    required String uid,
    int? selfDiagnosisScore, // This will be the *latest* normalized score from a completed test
    String? selfDiagnosisTestType, // The type of the latest completed test
    int? moodCheckScore,
    int? aiConversationScore,
    int? biometricStressScore,
  }) async {
    final dateKey = _getFormattedDateKey(DateTime.now());
    final docRef = _db.collection('users').doc(uid).collection('daily_mental_status').doc(dateKey);

    // Fetch existing daily data
    final existingDoc = await docRef.get();
    final Map<String, dynamic> existingData = existingDoc.data() ?? {};

    // 1. Determine Self-Diagnosis Scores for the Day
    double? dailySelfDiagnosisAverage;
    Map<String, dynamic> latestSelfDiagnosisScores = Map<String, dynamic>.from(existingData['componentScores']?['selfDiagnosis'] ?? {});

    // Fetch all mental health scores for the current day
    final startOfDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final selfDiagnosisSnapshots = await _db
        .collection('users')
        .doc(uid)
        .collection('mental_health_scores')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    List<double> normalizedSdScores = [];
    for (var doc in selfDiagnosisSnapshots.docs) {
      final data = doc.data();
      if (data['normalizedScore'] != null && data['testType'] != null) {
        normalizedSdScores.add(data['normalizedScore'].toDouble());
        // Always store the latest score for each test type from the fetched daily records
        latestSelfDiagnosisScores[data['testType']] = data['normalizedScore'];
      }
    }

    if (normalizedSdScores.isNotEmpty) {
      dailySelfDiagnosisAverage = normalizedSdScores.reduce((a, b) => a + b) / normalizedSdScores.length;
    }

    // Use the latest provided individual score if it's newer or this is the first update for the type
    if (selfDiagnosisScore != null && selfDiagnosisTestType != null) {
      // Ensure that if a new score is being passed, it overrides or updates the latest for its type
      latestSelfDiagnosisScores[selfDiagnosisTestType] = selfDiagnosisScore;
      // Also, if this new score causes a change in the average, this needs to be reflected.
      // For simplicity and robustness, the average is always recalculated from all fetched scores,
      // so if the `updateMentalHealthScore` has just added a new score, it will be included in `selfDiagnosisSnapshots`.
    }

    // Consolidate current component scores
    int? currentSelfDiagnosisAvg = dailySelfDiagnosisAverage?.round();
    int? currentMoodCheckScore = moodCheckScore ?? existingData['componentScores']?['dailyEmotion']?['moodCheck'];
    int? currentAiConversationScore = aiConversationScore ?? existingData['componentScores']?['dailyEmotion']?['aiConversation']?['average'];
    int? currentBiometricStressScore = biometricStressScore ?? existingData['componentScores']?['biometricStress'];


    // Initial weights
    double sdWeight = 0.4; // Self-diagnosis
    double deWeight = 0.4; // Daily emotion (mood check + AI conversation)
    double bsWeight = 0.2; // Biometric stress

    double mcWeight = 0.1; // Mood Check (part of daily emotion)
    double aiWeight = 0.3; // AI Conversation (part of daily emotion)

    // Recalculate weights based on available data
    double totalAvailableWeight = 0;
    double sdEffectiveWeight = 0;
    double deEffectiveWeight = 0;
    double bsEffectiveWeight = 0;

    double mcEffectiveWeight = 0;
    double aiEffectiveWeight = 0;
    double dailyEmotionComponentsWeight = 0;


    // Determine effective weights for daily emotion components
    if (currentMoodCheckScore != null) {
      mcEffectiveWeight = mcWeight;
      dailyEmotionComponentsWeight += mcWeight;
    }
    if (currentAiConversationScore != null) {
      aiEffectiveWeight = aiWeight;
      dailyEmotionComponentsWeight += aiWeight;
    }

    if (currentSelfDiagnosisAvg != null) {
      sdEffectiveWeight = sdWeight;
      totalAvailableWeight += sdWeight;
    }
    // Only add daily emotion weight if at least one sub-component is available
    if (currentMoodCheckScore != null || currentAiConversationScore != null) {
       deEffectiveWeight = deWeight;
       totalAvailableWeight += deWeight;
    }
    if (currentBiometricStressScore != null) {
      bsEffectiveWeight = bsWeight;
      totalAvailableWeight += bsWeight;
    }
    
    // Normalize weights if some components are missing
    if (totalAvailableWeight == 0) {
      // If no components are available, overall score is null
      await docRef.set({
        'date': dateKey,
        'overallScore': null,
        'componentScores': {
          'selfDiagnosis': {'average': currentSelfDiagnosisAvg, ...latestSelfDiagnosisScores},
          'dailyEmotion': {
            'moodCheck': currentMoodCheckScore,
            'aiConversation': {'average': currentAiConversationScore},
          },
          'biometricStress': currentBiometricStressScore,
        },
        'weights': {
          'selfDiagnosis': 0.0,
          'dailyEmotion': 0.0,
          'biometricStress': 0.0,
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    double normalizedSelfDiagnosisWeight = sdEffectiveWeight / totalAvailableWeight;
    double normalizedDailyEmotionWeight = deEffectiveWeight / totalAvailableWeight;
    double normalizedBiometricStressWeight = bsEffectiveWeight / totalAvailableWeight;
    
    // Calculate Daily Emotion Average Score
    double dailyEmotionAverageScore = 0;
    double dailyEmotionScoreSum = 0;
    int dailyEmotionComponentCount = 0;

    if (currentMoodCheckScore != null) {
      dailyEmotionScoreSum += currentMoodCheckScore * (mcEffectiveWeight / dailyEmotionComponentsWeight);
      dailyEmotionComponentCount++;
    }
    if (currentAiConversationScore != null) {
      dailyEmotionScoreSum += currentAiConversationScore * (aiEffectiveWeight / dailyEmotionComponentsWeight);
      dailyEmotionComponentCount++;
    }

    if (dailyEmotionComponentCount > 0) {
      dailyEmotionAverageScore = dailyEmotionScoreSum; // Already weighted average
    }


    // Calculate overall score
    double overallScore = 0;
    if (currentSelfDiagnosisAvg != null) {
      overallScore += (currentSelfDiagnosisAvg / 100) * normalizedSelfDiagnosisWeight;
    }
    if (dailyEmotionComponentCount > 0) {
      overallScore += (dailyEmotionAverageScore / 100) * normalizedDailyEmotionWeight;
    }
    if (currentBiometricStressScore != null) {
      overallScore += (currentBiometricStressScore / 100) * normalizedBiometricStressWeight;
    }

    // Convert overallScore to 0-100 scale and round
    overallScore = (overallScore * 100).roundToDouble();

    await docRef.set({
      'date': dateKey,
      'overallScore': overallScore,
      'componentScores': {
        'selfDiagnosis': {'average': currentSelfDiagnosisAvg, ...latestSelfDiagnosisScores},
        'dailyEmotion': {
          'moodCheck': currentMoodCheckScore,
          'aiConversation': {'average': currentAiConversationScore},
          'average': dailyEmotionAverageScore == 0 && dailyEmotionComponentCount == 0 ? null : dailyEmotionAverageScore.roundToDouble(),
        },
        'biometricStress': currentBiometricStressScore,
      },
      'weights': {
        'selfDiagnosis': normalizedSelfDiagnosisWeight,
        'dailyEmotion': normalizedDailyEmotionWeight,
        'biometricStress': normalizedBiometricStressWeight,
      },
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

  // Update user sleep time (하루에 한 번만 저장, 같은 날이면 업데이트)
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
}