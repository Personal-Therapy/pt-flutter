import 'dart:io';
import 'package:health/health.dart' as health;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

/// Apple Health / Health Connect / Samsung Health 데이터를 관리하는 서비스
class HealthService {
  final health.Health _healthFactory = health.Health();
  static const MethodChannel _samsungHealthChannel =
      MethodChannel('com.project.personaltherapy/samsung_health');
  bool _samsungHealthAvailable = false;
  bool _samsungHealthInitialized = false;

  // 가져올 데이터 타입 정의 (Galaxy Watch 5 + Samsung Health 지원)
  static final List<health.HealthDataType> _dataTypes = [
    // 기본 활동 데이터
    health.HealthDataType.STEPS,
    health.HealthDataType.ACTIVE_ENERGY_BURNED,
    health.HealthDataType.DISTANCE_DELTA,

    // 심장 건강 데이터
    health.HealthDataType.HEART_RATE,
    health.HealthDataType.RESTING_HEART_RATE,
    health.HealthDataType.HEART_RATE_VARIABILITY_RMSSD,

    // 수면 및 회복
    health.HealthDataType.SLEEP_ASLEEP,
    health.HealthDataType.SLEEP_AWAKE,
    health.HealthDataType.SLEEP_SESSION,

    // 혈중 산소 포화도
    health.HealthDataType.BLOOD_OXYGEN,

    // 운동 데이터
    health.HealthDataType.WORKOUT,

    // 수분 섭취
    health.HealthDataType.WATER,
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

  /// Health Connect 권한 재요청 (네이티브 SDK 직접 사용)
  /// Flutter health 패키지를 우회하여 모든 권한을 요청합니다.
  Future<void> reopenHealthConnectPermissions() async {
    try {
      if (Platform.isAndroid) {
        // 네이티브 메서드로 Health Connect 권한 직접 요청
        await _samsungHealthChannel.invokeMethod('requestHealthConnectPermissions');
        print('✅ Health Connect 네이티브 권한 요청 완료');
      }
    } catch (e) {
      print('❌ Health Connect 네이티브 권한 요청 실패: $e');
      // 실패 시 기존 방식으로 폴백
      try {
        await requestAuthorization();
        print('Health Connect 권한 재요청 완료 (폴백)');
      } catch (e2) {
        print('Health Connect 권한 재요청 실패: $e2');
      }
    }
  }

  /// Health Connect에서 안정시 심박수 데이터 가져오기 (네이티브)
  Future<List<Map<String, dynamic>>> getRestingHeartRateNative(
      DateTime startTime, DateTime endTime) async {
    if (!Platform.isAndroid) {
      return [];
    }

    try {
      final result = await _samsungHealthChannel.invokeMethod('getRestingHeartRate', {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
      });

      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ 안정시 심박수 데이터 가져오기 실패: $e');
      return [];
    }
  }

  /// Health Connect에서 HRV 데이터 가져오기 (네이티브)
  Future<List<Map<String, dynamic>>> getHeartRateVariabilityNative(
      DateTime startTime, DateTime endTime) async {
    if (!Platform.isAndroid) {
      return [];
    }

    try {
      final result = await _samsungHealthChannel.invokeMethod('getHeartRateVariability', {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
      });

      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ HRV 데이터 가져오기 실패: $e');
      return [];
    }
  }

  /// Samsung Health SDK가 사용 가능한지 확인
  Future<bool> checkSamsungHealthAvailable() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final bool? available = await _samsungHealthChannel.invokeMethod('checkSamsungHealthAvailable');
      _samsungHealthAvailable = available ?? false;
      print('Samsung Health 사용 가능 여부: $_samsungHealthAvailable');
      return _samsungHealthAvailable;
    } catch (e) {
      print('Samsung Health 확인 실패: $e');
      _samsungHealthAvailable = false;
      return false;
    }
  }

  /// Samsung Health SDK 초기화
  Future<bool> initializeSamsungHealth() async {
    if (!Platform.isAndroid || !_samsungHealthAvailable) {
      return false;
    }

    try {
      final bool? initialized = await _samsungHealthChannel.invokeMethod('initializeSamsungHealth');
      _samsungHealthInitialized = initialized ?? false;
      print('Samsung Health 초기화: $_samsungHealthInitialized');
      return _samsungHealthInitialized;
    } catch (e) {
      print('Samsung Health 초기화 실패: $e');
      _samsungHealthInitialized = false;
      return false;
    }
  }

  /// Samsung Health에서 심박수 데이터 가져오기
  Future<List<Map<String, dynamic>>> getSamsungHealthHeartRate({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (!_samsungHealthInitialized) {
      print('Samsung Health가 초기화되지 않음');
      return [];
    }

    try {
      final result = await _samsungHealthChannel.invokeMethod('getHeartRateData', {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
      });

      if (result is List) {
        return result.cast<Map<dynamic, dynamic>>().map((item) {
          return {
            'heartRate': item['heartRate'] as num,
            'timestamp': item['timestamp'] as num,
          };
        }).toList();
      }

      return [];
    } catch (e) {
      print('Samsung Health 심박수 데이터 가져오기 실패: $e');
      return [];
    }
  }

  /// Health 권한 요청
  /// Health Connect (Android) 또는 Apple Health (iOS)
  Future<bool> requestAuthorization() async {
    try {
      // 읽기 권한 목록 생성 (모든 데이터 타입에 대해)
      final permissions = _dataTypes
          .map((type) => health.HealthDataAccess.READ)
          .toList();

      print('📱 Galaxy Watch 5 + Samsung Health 데이터 연동 시작');
      print('요청할 데이터 타입 개수: ${_dataTypes.length}');
      print('요청할 권한: $_dataTypes');

      // 권한 요청 (데이터 타입과 권한을 명시적으로 전달)
      bool requested = await _healthFactory.requestAuthorization(
        _dataTypes,
        permissions: permissions,
      );

      print('권한 요청 응답: $requested');

      if (!requested) {
        print('❌ Health 권한 요청이 거부되었습니다.');
        print('💡 Health Connect 앱에서 Samsung Health를 데이터 소스로 연결하세요.');
        return false;
      }

      // 각 데이터 타입별로 권한 확인
      int grantedCount = 0;
      List<String> granted = [];
      List<String> denied = [];

      for (var dataType in _dataTypes) {
        bool? hasPermission = await _healthFactory.hasPermissions(
          [dataType],
          permissions: [health.HealthDataAccess.READ],
        );

        if (hasPermission == true) {
          grantedCount++;
          granted.add(dataType.name);
          print('✅ $dataType: 권한 허용됨');
        } else {
          denied.add(dataType.name);
          print('⚠️ $dataType: 권한 거부됨 또는 미지원');
        }
      }

      print('\n📊 권한 요청 결과:');
      print('전체 ${_dataTypes.length}개 중 $grantedCount개 권한 허용됨');
      print('✅ 허용된 권한 ($grantedCount개): ${granted.join(", ")}');
      if (denied.isNotEmpty) {
        print('⚠️ 거부/미지원 권한 (${denied.length}개): ${denied.join(", ")}');
        print('💡 Health Connect 앱에서 Samsung Health를 확인하고 추가 권한을 부여하세요.');
      }

      // 최소 1개 이상의 권한이 허용되면 성공으로 간주
      if (grantedCount > 0) {
        print('✅ Health 권한이 성공적으로 부여됨 ($grantedCount/${_dataTypes.length})');
        return true;
      } else {
        print('❌ Health 권한이 부여되지 않음. Health Connect 앱에서 권한을 확인하세요.');
        return false;
      }
    } catch (e) {
      print('❌ Health 권한 요청 실패: $e');
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

      // 심박수 및 HRV 데이터 요청
      List<health.HealthDataPoint> heartData = await _healthFactory
          .getHealthDataFromTypes(
        types: [
          health.HealthDataType.HEART_RATE,
          health.HealthDataType.HEART_RATE_VARIABILITY_RMSSD, // 🆕 RMSSD 포함
        ],
        startTime: startDate,
        endTime: endDate,
      );

      print('가져온 심박수 데이터 포인트 수: ${heartData.length}');

      // 중복 제거 (Set을 사용하여 UUID 기반으로 중복 제거)
      final uniqueHeartData = <String, health.HealthDataPoint>{};
      for (var point in heartData) {
        uniqueHeartData[point.uuid] = point;
      }
      heartData = uniqueHeartData.values.toList();
      print('중복 제거 후 심박수 데이터: ${heartData.length}개');

      // 2시간 간격으로 데이터 그룹화 및 평균 계산
      return _groupDataByHour(heartData, startDate);
    } catch (e) {
      print('시간별 심박 데이터 가져오기 실패: $e');
      return [];
    }
  }

  /// 특정 시간 범위의 평균 심박수 가져오기 (3단계 폴백)
  /// 1단계: Health Connect
  /// 2단계: Samsung Health SDK
  /// 3단계: 심박수 기반 HRV 추정
  Future<Map<String, dynamic>> fetchAverageHeartData({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      // 🔵 1단계: Health Connect에서 데이터 가져오기
      List<health.HealthDataPoint> heartData = await _healthFactory
          .getHealthDataFromTypes(
        types: [health.HealthDataType.HEART_RATE],
        startTime: startTime,
        endTime: endTime,
      );

      // Health Connect에 데이터가 없으면 Samsung Health 시도
      if (heartData.isEmpty && Platform.isAndroid) {
        print('🟡 Health Connect에 데이터 없음, Samsung Health 시도...');

        // 🟠 2단계: Samsung Health SDK에서 데이터 가져오기
        if (!_samsungHealthAvailable) {
          await checkSamsungHealthAvailable();
        }

        if (_samsungHealthAvailable && !_samsungHealthInitialized) {
          await initializeSamsungHealth();
        }

        if (_samsungHealthInitialized) {
          final samsungHeartData = await getSamsungHealthHeartRate(
            startTime: startTime,
            endTime: endTime,
          );

          if (samsungHeartData.isNotEmpty) {
            // Samsung Health 데이터로 평균 계산
            int totalHR = 0;
            for (var data in samsungHeartData) {
              totalHR += (data['heartRate'] as num).round();
            }

            final avgHR = (totalHR / samsungHeartData.length).round();
            final avgHRV = estimateHRVFromHeartRate(avgHR, null);

            print('✅ Samsung Health에서 데이터 획득: 평균 심박수 $avgHR, HRV $avgHRV (추정) (${samsungHeartData.length}개 데이터)');

            return {
              'avgHR': avgHR,
              'avgHRV': avgHRV,
              'count': samsungHeartData.length,
              'source': 'samsung_health',
            };
          }
        }

        // Samsung Health도 실패한 경우
        print('⚠️ Samsung Health에서도 데이터 없음');
        return {'avgHR': null, 'avgHRV': null, 'count': 0};
      }

      if (heartData.isEmpty) {
        print('시간대 ${startTime.hour}:00-${endTime.hour}:00 데이터 없음');
        return {'avgHR': null, 'avgHRV': null, 'count': 0};
      }

      // 중복 제거
      final uniqueData = <String, health.HealthDataPoint>{};
      for (var point in heartData) {
        uniqueData[point.uuid] = point;
      }
      heartData = uniqueData.values.toList();

      // 평균 심박수 계산
      int totalHR = 0;
      int count = 0;

      for (var point in heartData) {
        final value = point.value;
        if (value is health.NumericHealthValue) {
          totalHR += value.numericValue.round();
          count++;
        }
      }

      final avgHR = count > 0 ? (totalHR / count).round() : null;

      // 🟢 3단계: 심박수 기반 HRV 추정 (항상 실행)
      final avgHRV = avgHR != null ? estimateHRVFromHeartRate(avgHR, null) : 35;

      print('✅ Health Connect에서 데이터 획득: 평균 심박수 $avgHR, HRV $avgHRV (추정) (${count}개 데이터)');

      return {
        'avgHR': avgHR,
        'avgHRV': avgHRV,
        'count': count,
        'source': 'health_connect',
      };
    } catch (e) {
      print('❌ 평균 심박 데이터 가져오기 실패: $e');

      // 🟠 2단계: Samsung Health SDK 시도
      if (Platform.isAndroid) {
        try {
          if (!_samsungHealthAvailable) {
            await checkSamsungHealthAvailable();
          }

          if (_samsungHealthAvailable && !_samsungHealthInitialized) {
            await initializeSamsungHealth();
          }

          if (_samsungHealthInitialized) {
            final samsungHeartData = await getSamsungHealthHeartRate(
              startTime: startTime,
              endTime: endTime,
            );

            if (samsungHeartData.isNotEmpty) {
              int totalHR = 0;
              for (var data in samsungHeartData) {
                totalHR += (data['heartRate'] as num).round();
              }

              final avgHR = (totalHR / samsungHeartData.length).round();
              final avgHRV = estimateHRVFromHeartRate(avgHR, null);

              print('✅ Samsung Health 폴백 성공: 평균 심박수 $avgHR, HRV $avgHRV (${samsungHeartData.length}개 데이터)');

              return {
                'avgHR': avgHR,
                'avgHRV': avgHRV,
                'count': samsungHeartData.length,
                'source': 'samsung_health_fallback',
              };
            }
          }
        } catch (samsungError) {
          print('❌ Samsung Health 폴백 실패: $samsungError');
        }
      }

      return {'avgHR': null, 'avgHRV': null, 'count': 0};
    }
  }

  /// Health 데이터 처리
  Map<String, dynamic> _processHealthData(
      List<health.HealthDataPoint> healthData, DateTime now) {
    int steps = 0;
    double activeCalories = 0;
    int? currentHR; // null = 데이터 없음
    int? currentHRV; // null = 데이터 없음
    int? restingHR; // null = 데이터 없음

    bool hasSteps = false;
    bool hasCalories = false;
    bool hasHeartRate = false;

    for (var point in healthData) {
      final value = point.value;
      if (value is health.NumericHealthValue) {
        switch (point.type) {
          case health.HealthDataType.STEPS:
            steps += value.numericValue.round();
            hasSteps = true;
            break;
          case health.HealthDataType.ACTIVE_ENERGY_BURNED:
            activeCalories += value.numericValue;
            hasCalories = true;
            break;
          case health.HealthDataType.HEART_RATE:
            // 가장 최근 심박수 사용
            if (point.dateTo.isAfter(
                now.subtract(const Duration(minutes: 10)))) {
              currentHR = value.numericValue.round();
              hasHeartRate = true;
            }
            break;
          case health.HealthDataType.HEART_RATE_VARIABILITY_SDNN:
          case health.HealthDataType.HEART_RATE_VARIABILITY_RMSSD: // 🆕 RMSSD 추가
            // 가장 최근 HRV 사용 (SDNN 또는 RMSSD)
            if (point.dateTo.isAfter(
                now.subtract(const Duration(minutes: 10)))) {
              currentHRV = value.numericValue.round();
              print('HRV 발견: $currentHRV ms (${point.type})');
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

    // HRV가 없으면 심박수 기반으로 추정
    if (currentHR != null && currentHRV == null) {
      currentHRV = estimateHRVFromHeartRate(currentHR, restingHR);
      print('HRV를 심박수 기반으로 추정: $currentHRV ms');
    }

    print('처리된 데이터: 걸음수=$steps (데이터 있음: $hasSteps), '
        '칼로리=$activeCalories (데이터 있음: $hasCalories), '
        '심박수=$currentHR (데이터 있음: $hasHeartRate), '
        'HRV=$currentHRV ${currentHRV != null ? '(추정)' : ''}');

    return {
      'steps': steps,
      'activeCalories': activeCalories,
      'currentHR': currentHR,
      'currentHRV': currentHRV,
      'restingHR': restingHR,
      'timestamp': now,
    };
  }

  /// 시간별로 데이터 그룹화 및 평균 계산
  List<Map<String, dynamic>> _groupDataByHour(
      List<health.HealthDataPoint> data, DateTime startDate) {
    List<Map<String, dynamic>> hourlyData = [];

    // 2시간 간격으로 데이터 그룹화 (06:00-08:00, 08:00-10:00, ...)
    for (int hour = 6; hour < 22; hour += 2) {
      final timeSlotStart = DateTime(
          startDate.year, startDate.month, startDate.day, hour);
      final timeSlotEnd = timeSlotStart.add(const Duration(hours: 2));

      // 해당 시간대의 데이터 필터링
      final timeSlotData = data.where((point) =>
          point.dateFrom.isAfter(timeSlotStart) &&
          point.dateFrom.isBefore(timeSlotEnd));

      if (timeSlotData.isEmpty) {
        print('⚠️ ${hour}:00-${hour + 2}:00 시간대: 데이터 없음');
        continue;
      }

      // 해당 시간대의 평균 심박수 계산
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
          } else if (point.type == health.HealthDataType.HEART_RATE_VARIABILITY_SDNN ||
                     point.type == health.HealthDataType.HEART_RATE_VARIABILITY_RMSSD) { // 🆕 RMSSD 추가
            hrvSum += value.numericValue.round();
            hrvCount++;
            print('HRV 데이터 발견: ${value.numericValue.round()} ms (${point.type})');
          }
        }
      }

      // 심박수 데이터만 있어도 스트레스 로그 추가 (HRV는 옵션)
      if (hrCount > 0) {
        final avgHR = hrSum ~/ hrCount;

        // HRV가 없으면 심박수 기반으로 추정
        final avgHRV = hrvCount > 0
            ? hrvSum ~/ hrvCount  // 실제 HRV 데이터 사용
            : estimateHRVFromHeartRate(avgHR, null); // 심박수 기반 추정 🆕

        final stress = calculateStressLevel(avgHR, avgHRV);

        print('✅ ${hour}:00-${hour + 2}:00 시간대: 평균 심박수 $avgHR BPM, HRV $avgHRV ms ${hrvCount > 0 ? '(실제)' : '(추정)'} (${hrCount}개 데이터)');

        hourlyData.add({
          'time': '${hour.toString().padLeft(2, '0')}:00',
          'hr': avgHR,
          'hrv': avgHRV,
          'stress': stress,
          'dataCount': hrCount, // 데이터 개수 추가
        });
      }
    }

    print('📊 그룹화된 시간별 데이터: ${hourlyData.length}개 시간대 (총 ${data.length}개 데이터 포인트)');
    return hourlyData;
  }

  /// 심박수 기반 HRV 추정
  /// Samsung Health가 없을 때 심박수를 기반으로 HRV를 추정
  /// 완벽하지 않지만 고정값보다는 나음
  int estimateHRVFromHeartRate(int heartRate, int? restingHR) {
    final restingHeartRate = restingHR ?? 60;

    // 안정 시 심박수 대비 현재 심박수 비율
    final hrRatio = heartRate / restingHeartRate;

    // 심박수가 높을수록 HRV는 낮아지는 경향
    // 과학적 근거: 교감신경 활성화 시 HR↑, HRV↓
    if (hrRatio <= 1.0) {
      // 안정 상태 또는 그 이하 → 높은 HRV
      return 50 + ((1.0 - hrRatio) * 30).round(); // 50-80ms
    } else if (hrRatio <= 1.15) {
      // 약간 증가 → 중간 HRV
      return 35 + ((1.15 - hrRatio) * 100).round(); // 35-50ms
    } else if (hrRatio <= 1.3) {
      // 중간 정도 증가 → 낮은 HRV
      return 25 + ((1.3 - hrRatio) * 67).round(); // 25-35ms
    } else if (hrRatio <= 1.5) {
      // 많이 증가 → 매우 낮은 HRV
      return 15 + ((1.5 - hrRatio) * 50).round(); // 15-25ms
    } else {
      // 극도로 높음 → 최소 HRV
      return 15; // 15ms
    }
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
  Map<String, dynamic> analyzeUserState(int? heartRate, int? hrv, int? restingHR) {
    // 데이터가 없으면 기본 상태 반환
    if (heartRate == null || hrv == null || restingHR == null) {
      return {
        'state': '데이터 수집 중',
        'stressLevel': 0,
        'recommendation': 'Health Connect에 데이터 소스를 연결하고 웨어러블 기기를 동기화하세요.',
      };
    }

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
      'currentHR': null, // 데이터 없음
      'currentHRV': null, // 데이터 없음
      'restingHR': null, // 데이터 없음
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

  /// 연결된 데이터 소스 및 기기 정보 가져오기
  Future<List<Map<String, dynamic>>> getConnectedDevices() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      // 최근 데이터를 가져와서 소스 확인
      List<health.HealthDataPoint> healthData = await _healthFactory
          .getHealthDataFromTypes(
        types: [health.HealthDataType.STEPS, health.HealthDataType.HEART_RATE],
        startTime: yesterday,
        endTime: now,
      );

      // 기기 정보 추출 (중복 제거)
      Map<String, Map<String, dynamic>> deviceMap = {};

      for (var point in healthData) {
        // 기기 ID를 키로 사용
        final deviceKey = '${point.sourceId}_${point.sourceName}';

        if (!deviceMap.containsKey(deviceKey)) {
          // 기기 정보 구성
          String deviceName = point.sourceName;
          String manufacturer = '';
          String model = '';

          // sourceName에서 기기 정보 추출
          if (point.sourceName.toLowerCase().contains('samsung')) {
            manufacturer = 'Samsung';
            if (point.sourceName.toLowerCase().contains('watch')) {
              deviceName = 'Samsung Galaxy Watch';
            }
          } else if (point.sourceName.toLowerCase().contains('fitbit')) {
            manufacturer = 'Fitbit';
            deviceName = 'Fitbit Device';
          } else if (point.sourceName.toLowerCase().contains('garmin')) {
            manufacturer = 'Garmin';
            deviceName = 'Garmin Device';
          } else if (point.sourceName.toLowerCase().contains('apple')) {
            manufacturer = 'Apple';
            deviceName = 'Apple Watch';
          } else if (point.sourceName.toLowerCase().contains('google fit')) {
            manufacturer = 'Google';
            deviceName = 'Google Fit (연결된 기기)';
          }

          deviceMap[deviceKey] = {
            'name': deviceName.isNotEmpty ? deviceName : point.sourceName,
            'manufacturer': manufacturer,
            'sourceName': point.sourceName,
            'sourceId': point.sourceId,
            'lastSync': point.dateTo,
          };

          print('발견된 기기: $deviceName (${point.sourceName})');
        }
      }

      print('총 ${deviceMap.length}개 기기 발견');
      return deviceMap.values.toList();
    } catch (e) {
      print('기기 정보 가져오기 실패: $e');
      return [];
    }
  }

  // ===== Wear OS HRV Data Integration =====

  /// 워치 앱으로부터 최신 HRV 데이터 가져오기
  ///
  /// Returns: {
  ///   "rmssd": double,
  ///   "avgHeartRate": int,
  ///   "timestamp": int (milliseconds),
  ///   "formattedTime": String
  /// } or null if no data available
  Future<Map<String, dynamic>?> getLatestHrvDataFromWatch() async {
    if (!Platform.isAndroid) {
      print('⚠️ Wear OS HRV는 Android에서만 사용 가능합니다');
      return null;
    }

    try {
      final result = await _samsungHealthChannel.invokeMethod('getLatestHrvData');

      if (result != null && result is Map) {
        final data = Map<String, dynamic>.from(result);
        print('✅ 워치로부터 HRV 데이터 수신:');
        print('   RMSSD: ${data['rmssd']} ms');
        print('   Avg HR: ${data['avgHeartRate']} bpm');
        print('   Time: ${data['formattedTime']}');
        return data;
      } else {
        print('ℹ️ 워치로부터 수신된 HRV 데이터가 없습니다');
        return null;
      }
    } catch (e) {
      print('❌ 워치 HRV 데이터 가져오기 실패: $e');
      return null;
    }
  }

  /// 워치 HRV 데이터를 Firestore에 저장
  ///
  /// [userId] - 사용자 ID
  /// [hrvData] - getLatestHrvDataFromWatch()에서 반환된 데이터
  Future<void> saveWatchHrvToFirestore(String userId, Map<String, dynamic> hrvData) async {
    try {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(hrvData['timestamp'] as int);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('hrv_records')
          .add({
        'rmssd': hrvData['rmssd'],
        'avgHeartRate': hrvData['avgHeartRate'],
        'timestamp': Timestamp.fromDate(timestamp),
        'source': 'wear_os_watch',
        'formattedTime': hrvData['formattedTime'],
      });

      print('✅ 워치 HRV 데이터 Firestore 저장 완료');
    } catch (e) {
      print('❌ 워치 HRV 데이터 저장 실패: $e');
      rethrow;
    }
  }

  /// 워치 HRV 데이터 스트림 (실시간 업데이트)
  ///
  /// 주기적으로 워치로부터 새 데이터를 폴링하고 스트림으로 전달
  Stream<Map<String, dynamic>?> watchHrvDataStream({
    Duration pollInterval = const Duration(seconds: 30),
  }) async* {
    while (true) {
      final data = await getLatestHrvDataFromWatch();
      yield data;
      await Future.delayed(pollInterval);
    }
  }
}
