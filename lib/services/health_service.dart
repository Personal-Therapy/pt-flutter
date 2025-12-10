import 'package:health/health.dart' as health;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Apple Health / Health Connect 데이터를 관리하는 서비스
class HealthService {
  final health.Health _healthFactory = health.Health();

  // 가져올 데이터 타입 정의
  // 주의: HEART_RATE_VARIABILITY_SDNN은 Health Connect에서 지원되지 않음
  static final List<health.HealthDataType> _dataTypes = [
    health.HealthDataType.STEPS,
    health.HealthDataType.ACTIVE_ENERGY_BURNED,
    health.HealthDataType.HEART_RATE,
    health.HealthDataType.RESTING_HEART_RATE,
    // health.HealthDataType.HEART_RATE_VARIABILITY_SDNN, // Health Connect에서 미지원
  ];

  /// Health Connect가 사용 가능한지 확인 (Android만 해당)
  Future<health.HealthConnectSdkStatus> checkHealthConnectStatus() async {
    try {
      final status = await health.Health().getHealthConnectSdkStatus();
      print('Health Connect 상태: $status');
      return status ?? health.HealthConnectSdkStatus.sdkUnavailable;
    } catch (e) {
      print('Health Connect 상태 확인 실패: $e');
      return health.HealthConnectSdkStatus.sdkUnavailable;
    }
  }

  /// Health 권한 요청
  Future<bool> requestAuthorization() async {
    try {
      // 읽기 권한 목록 생성 (모든 데이터 타입에 대해)
      final permissions = _dataTypes
          .map((type) => health.HealthDataAccess.READ)
          .toList();

      print('요청할 데이터 타입 개수: ${_dataTypes.length}');
      print('요청할 권한: $_dataTypes');

      // 권한 요청 (데이터 타입과 권한을 명시적으로 전달)
      bool requested = await _healthFactory.requestAuthorization(
        _dataTypes,
        permissions: permissions,
      );

      print('권한 요청 응답: $requested');

      if (!requested) {
        print('Health 권한 요청 거부됨');
        return false;
      }

      // 각 데이터 타입별로 권한 확인 (일부만 허용되어도 OK)
      int grantedCount = 0;
      for (var dataType in _dataTypes) {
        bool? hasPermission = await _healthFactory.hasPermissions(
          [dataType],
          permissions: [health.HealthDataAccess.READ],
        );

        if (hasPermission == true) {
          grantedCount++;
          print('$dataType: 권한 허용됨');
        } else {
          print('$dataType: 권한 거부됨 또는 미지원');
        }
      }

      print('전체 ${_dataTypes.length}개 중 $grantedCount개 권한 허용됨');

      // 최소 1개 이상의 권한이 허용되면 성공으로 간주
      if (grantedCount > 0) {
        print('Health 권한이 성공적으로 부여됨 ($grantedCount/${_dataTypes.length})');
        return true;
      } else {
        print('Health 권한이 부여되지 않음. Health Connect 앱에서 권한을 확인하세요.');
        return false;
      }
    } catch (e) {
      print('Health 권한 요청 실패: $e');
      return false;
    }
  }

  /// 최근 건강 데이터 가져오기
  Future<Map<String, dynamic>> fetchRecentHealthData() async {
    try {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(hours: 24));

      print('데이터 가져오기 시작: $startTime ~ $now');

      List<health.HealthDataPoint> healthData = await _healthFactory
          .getHealthDataFromTypes(
        types: _dataTypes,
        startTime: startTime,
        endTime: now,
      );

      print('가져온 데이터 포인트 수: ${healthData.length}');

      // 데이터 타입별 개수 출력
      final typeCounts = <health.HealthDataType, int>{};
      for (var point in healthData) {
        typeCounts[point.type] = (typeCounts[point.type] ?? 0) + 1;
      }
      print('타입별 데이터 개수: $typeCounts');

      // 중복 제거 (Set을 사용하여 UUID 기반으로 중복 제거)
      final uniqueData = <String, health.HealthDataPoint>{};
      for (var point in healthData) {
        uniqueData[point.uuid] = point;
      }
      healthData = uniqueData.values.toList();
      print('중복 제거 후 데이터 포인트 수: ${healthData.length}');

      return _processHealthData(healthData, now);
    } catch (e) {
      print('Health 데이터 가져오기 실패: $e');
      return _getDefaultHealthData();
    }
  }

  /// 특정 시간 범위의 심박수 및 HRV 데이터 가져오기
  Future<List<Map<String, dynamic>>> fetchHourlyHeartData(
      DateTime startDate) async {
    try {
      final endDate = startDate.add(const Duration(days: 1));
      List<health.HealthDataPoint> heartData = await _healthFactory
          .getHealthDataFromTypes(
        types: [
          health.HealthDataType.HEART_RATE,
          health.HealthDataType.HEART_RATE_VARIABILITY_SDNN
        ],
        startTime: startDate,
        endTime: endDate,
      );

      // 중복 제거 (Set을 사용하여 UUID 기반으로 중복 제거)
      final uniqueHeartData = <String, health.HealthDataPoint>{};
      for (var point in heartData) {
        uniqueHeartData[point.uuid] = point;
      }
      heartData = uniqueHeartData.values.toList();

      // 2시간 간격으로 데이터 그룹화
      return _groupDataByHour(heartData, startDate);
    } catch (e) {
      print('시간별 심박 데이터 가져오기 실패: $e');
      return [];
    }
  }

  /// Health 데이터 처리
  Map<String, dynamic> _processHealthData(
      List<health.HealthDataPoint> healthData, DateTime now) {
    int steps = 0;
    double activeCalories = 0;
    int currentHR = 72;
    int currentHRV = 35;
    int restingHR = 65;

    for (var point in healthData) {
      final value = point.value;
      if (value is health.NumericHealthValue) {
        switch (point.type) {
          case health.HealthDataType.STEPS:
            steps += value.numericValue.round();
            break;
          case health.HealthDataType.ACTIVE_ENERGY_BURNED:
            activeCalories += value.numericValue;
            break;
          case health.HealthDataType.HEART_RATE:
            // 가장 최근 심박수 사용
            if (point.dateTo.isAfter(
                now.subtract(const Duration(minutes: 10)))) {
              currentHR = value.numericValue.round();
            }
            break;
          case health.HealthDataType.HEART_RATE_VARIABILITY_SDNN:
            // 가장 최근 HRV 사용
            if (point.dateTo.isAfter(
                now.subtract(const Duration(minutes: 10)))) {
              currentHRV = value.numericValue.round();
            }
            break;
          case health.HealthDataType.RESTING_HEART_RATE:
            restingHR = value.numericValue.round();
            break;
          default:
            break;
        }
      }
    }

    return {
      'steps': steps,
      'activeCalories': activeCalories,
      'currentHR': currentHR,
      'currentHRV': currentHRV,
      'restingHR': restingHR,
      'timestamp': now,
    };
  }

  /// 시간별로 데이터 그룹화
  List<Map<String, dynamic>> _groupDataByHour(
      List<health.HealthDataPoint> data, DateTime startDate) {
    List<Map<String, dynamic>> hourlyData = [];

    // 2시간 간격으로 데이터 그룹화
    for (int hour = 6; hour < 22; hour += 2) {
      final timeSlotStart = DateTime(
          startDate.year, startDate.month, startDate.day, hour);
      final timeSlotEnd = timeSlotStart.add(const Duration(hours: 2));

      // 해당 시간대의 데이터 필터링
      final timeSlotData = data.where((point) =>
          point.dateFrom.isAfter(timeSlotStart) &&
          point.dateFrom.isBefore(timeSlotEnd));

      if (timeSlotData.isEmpty) continue;

      // 평균 계산
      int hrSum = 0;
      int hrCount = 0;
      int hrvSum = 0;
      int hrvCount = 0;

      for (var point in timeSlotData) {
        final value = point.value;
        if (value is health.NumericHealthValue) {
          if (point.type == health.HealthDataType.HEART_RATE) {
            hrSum += value.numericValue.round();
            hrCount++;
          } else if (point.type ==
              health.HealthDataType.HEART_RATE_VARIABILITY_SDNN) {
            hrvSum += value.numericValue.round();
            hrvCount++;
          }
        }
      }

      if (hrCount > 0 && hrvCount > 0) {
        final avgHR = hrSum ~/ hrCount;
        final avgHRV = hrvSum ~/ hrvCount;
        final stress = calculateStressLevel(avgHR, avgHRV);

        hourlyData.add({
          'time': '${hour.toString().padLeft(2, '0')}:00',
          'hr': avgHR,
          'hrv': avgHRV,
          'stress': stress,
        });
      }
    }

    return hourlyData;
  }

  /// 스트레스 레벨 계산
  /// HR과 HRV를 기반으로 0-100 사이의 스트레스 점수 계산
  int calculateStressLevel(int heartRate, int hrv) {
    // 정규화된 심박수 (안정시 심박수 60, 최대 100 가정)
    double normalizedHR = ((heartRate - 60) / 40).clamp(0.0, 1.0);

    // 정규화된 HRV (높을수록 좋음, 20-80 범위 가정)
    double normalizedHRV = (1 - ((hrv - 20) / 60).clamp(0.0, 1.0));

    // 가중 평균으로 스트레스 점수 계산
    // HR 60%, HRV 40% 가중치
    double stressScore = (normalizedHR * 0.6 + normalizedHRV * 0.4) * 100;

    return stressScore.round().clamp(0, 100);
  }

  /// 사용자 상태 분석
  Map<String, dynamic> analyzeUserState(int heartRate, int hrv, int restingHR) {
    final stressLevel = calculateStressLevel(heartRate, hrv);

    String state;
    String recommendation;

    // HR이 안정시보다 20% 이상 높고, HRV가 낮은 경우
    if (heartRate > restingHR * 1.2 && hrv < 30) {
      state = '높은 스트레스';
      recommendation = '심호흡이나 명상으로 긴장을 풀어보세요. 잠시 휴식이 필요합니다.';
    }
    // HR이 안정시보다 10-20% 높거나 HRV가 중간인 경우
    else if (heartRate > restingHR * 1.1 || hrv < 40) {
      state = '약간 긴장';
      recommendation = '가볍게 스트레칭을 하거나 잠깐 산책해보세요.';
    }
    // HRV가 높고 HR이 안정적인 경우
    else if (hrv > 50 && heartRate < restingHR * 1.1) {
      state = '편안함';
      recommendation = '좋은 컨디션입니다! 현재 상태를 유지하세요.';
    }
    // 그 외
    else {
      state = '보통';
      recommendation = '평온한 상태입니다. 꾸준한 활동을 유지하세요.';
    }

    return {
      'state': state,
      'stressLevel': stressLevel,
      'recommendation': recommendation,
    };
  }

  /// 기본 데이터 반환 (권한 없거나 데이터 없을 때)
  Map<String, dynamic> _getDefaultHealthData() {
    return {
      'steps': 0,
      'activeCalories': 0.0,
      'currentHR': 72,
      'currentHRV': 35,
      'restingHR': 65,
      'timestamp': DateTime.now(),
    };
  }

  /// Firestore에 건강 데이터 저장
  Future<void> saveHealthDataToFirestore(
      String userId, Map<String, dynamic> healthData) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('health_data')
          .add({
        ...healthData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Firestore 저장 실패: $e');
    }
  }

  /// Firestore에서 오늘의 건강 데이터 가져오기
  Future<List<Map<String, dynamic>>> getTodayHealthDataFromFirestore(
      String userId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('health_data')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .orderBy('timestamp', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Firestore에서 데이터 가져오기 실패: $e');
      return [];
    }
  }
}
