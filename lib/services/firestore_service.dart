import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
  Future<void> updateMentalHealthScore(String uid, int mentalHealthScore) async {
    await _db.collection('users').doc(uid).collection('mental_health_scores').add({
      'score': mentalHealthScore,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Get user mental health scores
  Stream<List<Map<String, dynamic>>> getMentalHealthScoresStream(String uid) {
    return _db.collection('users').doc(uid).collection('mental_health_scores')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
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