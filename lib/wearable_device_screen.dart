import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io'; // Platform detection
import 'package:untitled/main_screen.dart'; // Import main_screen.dart to use its color constants
import 'package:untitled/services/health_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/services/firestore_service.dart'; // 이 줄을 추가하세요

// [!!] 1. 새 RTF 파일에서 추가된 색상
const Color kConnectedGreen = Color(0xFF21C45D); // "연결됨"
const Color kStressHigh = Color(0xFFF59E0B); // 스트레스 '높음' (주황)
const Color kStressNormal = Color(0xFF3B81F5); // 스트레스 '보통' (파랑)
const Color kStressLow = Color(0xFF4ADE80); // 스트레스 '낮음' (밝은 녹색)
const Color kPrimaryGreen = Color(0xFF16A34A);


/// 웨어러블 기기 연동 페이지 (웨어러블 기기_수정.rtf 기반)
class WearableDeviceScreen extends StatefulWidget {
  const WearableDeviceScreen({Key? key}) : super(key: key);

  @override
  _WearableDeviceScreenState createState() => _WearableDeviceScreenState();
}

class _WearableDeviceScreenState extends State<WearableDeviceScreen> {
  final HealthService _healthService = HealthService();
  final FirestoreService _firestoreService = FirestoreService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Timer? _dataUpdateTimer;
  bool _isLoading = true;
  bool _isConnected = false;

  // 실시간 모니터링 데이터
  int _steps = 0;
  double _activeCalories = 0;
  int? _currentHR; // null = 데이터 없음
  int? _currentHRV; // null = 데이터 없음
  int? _restingHR; // null = 데이터 없음
  int _currentStress = 0;
  String _userState = '데이터 수집 중';
  String _recommendation = '';
  Color _userStateColor = kColorTextHint;

  // 연결된 기기 목록
  List<Map<String, dynamic>> _connectedDevices = [];

  // 스트레스 로그 데이터 (실제 데이터로 채워짐)
  List<Map<String, dynamic>> _stressLog = [];

  @override
  void initState() {
    super.initState();
    _initializeHealthData();
    // 5분마다 데이터 업데이트
    _dataUpdateTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) => _refreshHealthData(),
    );
  }

  @override
  void dispose() {
    _dataUpdateTimer?.cancel();
    super.dispose();
  }

  /// Health 데이터 초기화
  /// [주의] MainScreen에서 이미 권한을 요청했으므로 여기서는 확인만 합니다.
  Future<void> _initializeHealthData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Android: Health Connect 상태 확인
      if (Platform.isAndroid) {
        final status = await _healthService.checkHealthConnectStatus();
        print('Health Connect SDK 상태: $status');

        if (status.toString().contains('unavailable')) {
          _showErrorSnackBar('Health Connect가 설치되지 않았습니다.\nGoogle Play에서 Health Connect를 설치하세요.');
          return;
        }
      }

      // 권한이 이미 있는지 확인 (MainScreen에서 이미 요청했음)
      print('🔍 Health 권한 확인 중...');
      bool authorized = await _healthService.requestAuthorization();
      print('📋 Health 권한 상태: $authorized');
      // 필요하면 권한 재요청 (사용자가 명시적으로 거부한 경우)
      // authorized = await _healthService.requestAuthorization();

      if (authorized) {
        await _refreshHealthData();
        await _loadTodayStressLog();

        // 연결된 웨어러블 기기 정보 가져오기
        final devices = await _healthService.getConnectedDevices();
        print('가져온 기기 정보: $devices');

        setState(() {
          _isConnected = true;

          // 개발/테스트용: 데이터가 없으면 샘플 데이터 사용
          final bool useTestData = devices.isEmpty && Platform.isAndroid;

          if (useTestData) {
            // 테스트용 샘플 기기 및 데이터 표시
            print('⚠️ 실제 데이터 없음 - 샘플 데이터 사용');
            _connectedDevices = [
              {'name': '샘플 기기 (Health Connect 데이터 없음)', 'battery': null, 'status': '데이터 소스를 연결하세요'},
            ];

            // 샘플 심박수 데이터 생성
            _stressLog = [
              {'time': '06:00', 'hr': 72, 'hrv': 35, 'stress': 30},
              {'time': '08:00', 'hr': 78, 'hrv': 32, 'stress': 40},
              {'time': '10:00', 'hr': 85, 'hrv': 28, 'stress': 55},
              {'time': '12:00', 'hr': 80, 'hrv': 30, 'stress': 45},
              {'time': '14:00', 'hr': 75, 'hrv': 33, 'stress': 35},
            ];
          } else if (devices.isNotEmpty) {
            // 실제 웨어러블 기기가 있으면 표시
            _connectedDevices = devices.map((device) {
              // 마지막 동기화 시간 계산
              final lastSync = device['lastSync'] as DateTime;
              final difference = DateTime.now().difference(lastSync);
              String syncStatus;

              if (difference.inMinutes < 5) {
                syncStatus = '방금 전';
              } else if (difference.inMinutes < 60) {
                syncStatus = '${difference.inMinutes}분 전';
              } else if (difference.inHours < 24) {
                syncStatus = '${difference.inHours}시간 전';
              } else {
                syncStatus = '${difference.inDays}일 전';
              }

              return {
                'name': device['name'] as String,
                'battery': null, // Health API에서 배터리 정보는 제공하지 않음
                'status': syncStatus,
              };
            }).toList();
          } else {
            // 기기가 없으면 플랫폼 기본값 표시
            if (Platform.isIOS) {
              _connectedDevices = [
                {'name': 'Apple Health', 'battery': null, 'status': '데이터 동기화 활성화됨'},
              ];
            } else if (Platform.isAndroid) {
              _connectedDevices = [
                {'name': 'Health Connect', 'battery': null, 'status': '데이터 동기화 활성화됨'},
              ];
            } else {
              _connectedDevices = [
                {'name': 'Health Connect', 'battery': null, 'status': '데이터 동기화 활성화됨'},
              ];
            }
          }
        });
      } else {
        final errorMsg = Platform.isAndroid
            ? 'Health Connect 권한이 필요합니다.\nHealth Connect 앱에서 이 앱의 권한을 확인하세요.'
            : 'Apple Health 데이터 접근 권한이 필요합니다.';
        _showErrorSnackBar(errorMsg);
      }
    } catch (e) {
      _showErrorSnackBar('데이터를 가져오는 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Health 데이터 새로고침
  // [수정] 데이터 새로고침 및 Firestore 저장 연결
  Future<void> _refreshHealthData() async {
    try {
      final now = DateTime.now();

      // 1. HealthService에서 데이터 가져오기 (기존 코드)
      final healthData = await _healthService.fetchRecentHealthData();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      final avgHeartData = await _healthService.fetchAverageHeartData(
        startTime: oneHourAgo,
        endTime: now,
      );

      setState(() {
        _steps = healthData['steps'] ?? 0;
        _activeCalories = healthData['activeCalories'] ?? 0.0;
        _currentHR = avgHeartData['avgHR'];
        _currentHRV = avgHeartData['avgHRV'];
        _restingHR = healthData['restingHR'];
      });

      // 2. 사용자 상태 및 스트레스 분석 (기존 코드)
      _analyzeUserState(); // 이 함수가 _currentStress 값을 업데이트함

      // 3. [중요] Firestore에 생체 점수 저장
      final userId = _currentUserId;
      if (userId != null) {
        // A. 기존 방식의 로그 저장 (선택 사항)
        await _healthService.saveHealthDataToFirestore(userId, {
          'steps': _steps,
          'activeCalories': _activeCalories,
          'heartRate': _currentHR,
          'hrv': _currentHRV,
          'restingHR': _restingHR,
          'stressLevel': _currentStress, // 원본 스트레스 지수 (높을수록 나쁨)
          'userState': _userState,
          'timestamp': now,
        });

        // B. [신규] 종합 점수 산출을 위한 점수 저장
        // 스트레스(0~100, 높을수록 나쁨) -> 건강점수(0~100, 높을수록 좋음)로 변환
        // 예: 스트레스 80 -> 건강점수 20
        int bioHealthScore = (100 - _currentStress).clamp(0, 100);

        await _firestoreService.updateBiometricStress(userId, bioHealthScore);

        print('✅ [Wearable] 생체 점수 업데이트 완료: 스트레스 $_currentStress -> 건강점수 $bioHealthScore');
      }
    } catch (e) {
      print('데이터 새로고침 실패: $e');
    }
  }

  /// 오늘의 스트레스 로그 로드
  Future<void> _loadTodayStressLog() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final stressLog = await _healthService.fetchHourlyHeartData(startOfDay);

      setState(() {
        _stressLog = stressLog;
      });
    } catch (e) {
      print('스트레스 로그 로드 실패: $e');
    }
  }

  /// 사용자 상태 분석
  void _analyzeUserState() {
    final analysis = _healthService.analyzeUserState(
      _currentHR,
      _currentHRV,
      _restingHR,
    );

    setState(() {
      _userState = analysis['state'];
      _currentStress = analysis['stressLevel'];
      _recommendation = analysis['recommendation'];

      // 상태별 색상 설정
      if (_userState.contains('높은 스트레스')) {
        _userStateColor = kStressHigh;
      } else if (_userState.contains('편안')) {
        _userStateColor = kStressLow;
      } else {
        _userStateColor = kStressNormal;
      }
    });
  }

  /// 에러 메시지 표시
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: kColorError),
      );
    }
  }

  /// Health Connect 앱 설명 다이얼로그 표시 (Android만)
  Future<void> _showHealthConnectGuide() async {
    if (Platform.isAndroid) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Health Connect 설정 가이드'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  '📱 Health Connect 데이터 소스 연결',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 12),
                Text(
                  '1. Health Connect 앱을 엽니다\n'
                  '2. "앱" 탭으로 이동합니다\n'
                  '3. Samsung Health, Google Fit 등을 선택합니다\n'
                  '4. "데이터 허용"을 활성화합니다\n'
                  '5. 걸음 수, 심박수 권한을 허용합니다',
                ),
                SizedBox(height: 16),
                Text(
                  '⚠️ 데이터가 없는 경우',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 12),
                Text(
                  '• Samsung Health나 Google Fit에서 실제로 걸어서 데이터를 생성하세요\n'
                  '• Health Connect에 데이터 소스가 연결되어 있는지 확인하세요\n'
                  '• 웨어러블 기기가 Health Connect와 동기화되어 있는지 확인하세요',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBgStart,
      appBar: AppBar(
        backgroundColor: kColorBgStart,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: kColorTextTitle,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '웨어러블 연동',
          style: TextStyle(
            color: kColorTextTitle,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kColorBtnPrimary),
            onPressed: _isLoading ? null : _refreshHealthData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('건강 데이터를 불러오는 중...',
                      style: TextStyle(color: kColorTextSubtitle)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _refreshHealthData();
                await _loadTodayStressLog();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    _buildRealtimeMonitoringCard(),
                    const SizedBox(height: 24),
                    _buildActivityCard(),
                    const SizedBox(height: 24),
                    _buildConnectedDevicesCard(),
                    const SizedBox(height: 24),
                    _buildRecommendationCard(),
                    const SizedBox(height: 24),
                    _buildHealthConnectInfoCard(),
                  ],
                ),
              ),
            ),
    );
  }

  // --- [!!] 9. 새 RTF 기반 헬퍼 위젯들 ---

  /// '실시간 모니터링' 카드
  Widget _buildRealtimeMonitoringCard() {
    return _buildSettingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '실시간 모니터링',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: kColorTextTitle
                        )
                    ),
                    SizedBox(height: 4),
                    Text(
                        '지난 1시간 평균',
                        style: TextStyle(
                            fontSize: 12,
                            color: kColorTextSubtitle
                        )
                    ),
                  ],
                ),
                Spacer(),
                Icon(Icons.circle, color: _isConnected ? kConnectedGreen : kColorTextHint, size: 12),
                SizedBox(width: 6),
                Text(
                  _isConnected ? '연결됨' : '연결 끊김',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _isConnected ? kConnectedGreen : kColorTextHint
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.favorite, _currentHR, 'BPM', '심박수', kColorError),
                _buildStatItem(Icons.waves, _currentHRV, 'ms', '심박변이도', kColorBtnPrimary),
                _buildStateItem(Icons.sentiment_very_satisfied, _userState, '신체 상태', _userStateColor),
              ],
            ),
          ],
        )
    );
  }

  /// 실시간 모니터링용 스탯 아이템 (심박수, HRV 등)
  Widget _buildStatItem(IconData icon, int? value, String unit, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: value == null ? kColorTextHint : color, size: 28),
        SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value == null ? '-' : '$value',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: value == null ? kColorTextHint : kColorTextTitle
              ),
            ),
            if (value != null) ...[
              SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kColorTextSubtitle
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: kColorTextSubtitle),
        ),
      ],
    );
  }

  /// 신체 상태 아이템
  Widget _buildStateItem(IconData icon, String state, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        SizedBox(height: 8),
        Text(
          state,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: kColorTextSubtitle),
        ),
      ],
    );
  }

  /// '연결된 기기' 카드
  Widget _buildConnectedDevicesCard() {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              '연결된 기기',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kColorTextTitle
              )
          ),
          const SizedBox(height: 16),
          // 연결된 기기 목록
          _connectedDevices.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                children: [
                  const Icon(Icons.watch_off_outlined, size: 48, color: kColorTextHint),
                  const SizedBox(height: 12),
                  Text(
                    Platform.isIOS
                        ? 'Apple Health 권한이 필요합니다.'
                        : 'Health Connect 권한이 필요합니다.',
                    style: const TextStyle(
                      color: kColorTextTitle,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    )
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Platform.isIOS
                        ? '설정 > 개인정보 보호 > 건강에서 권한을 허용하세요.'
                        : '앱 설정에서 Health Connect 권한을 허용하세요.',
                    style: const TextStyle(color: kColorTextSubtitle),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (Platform.isAndroid)
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _initializeHealthData,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('권한 재요청'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kColorBtnPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showHealthConnectGuide,
                          icon: const Icon(Icons.help_outline, size: 18),
                          label: const Text('권한 설정 방법 보기'),
                          style: TextButton.styleFrom(
                            foregroundColor: kColorBtnPrimary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 연결된 기기 목록
              ...(_connectedDevices.map((device) =>
                  _buildConnectedDeviceRow(
                    name: device['name'],
                    battery: device['battery'],
                    status: device['status'],
                  )
              ).toList()),

              // 시간별 심박수 및 HRV 데이터 표
              if (_stressLog.isNotEmpty) ...[
                const Divider(height: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '오늘의 심박수 및 HRV',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kColorTextTitle
                      )
                    ),
                    SizedBox(height: 4),
                    Text(
                      '2시간 간격 평균값',
                      style: TextStyle(
                        fontSize: 12,
                        color: kColorTextSubtitle
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildHeartRateTable(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 연결된 기기 Row 헬퍼
  Widget _buildConnectedDeviceRow({required String name, required int? battery, required String status}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          const Icon(Icons.watch, size: 32, color: kColorBtnPrimary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kColorTextTitle)
                ),
                const SizedBox(height: 4),
                Text(
                    battery != null ? '$battery%・$status' : status,
                    style: const TextStyle(fontSize: 14, color: kColorTextSubtitle)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 시간별 심박수 및 HRV 표
  Widget _buildHeartRateTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kColorTextHint.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: kColorBgStart,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    '시간',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kColorTextTitle,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '심박수',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kColorTextTitle,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'HRV',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kColorTextTitle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 데이터 행들
          ..._stressLog.asMap().entries.map((entry) {
            final index = entry.key;
            final log = entry.value;
            final isLastRow = index == _stressLog.length - 1;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: index % 2 == 0 ? Colors.white : kColorBgStart.withOpacity(0.3),
                borderRadius: isLastRow
                    ? const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      )
                    : null,
                border: !isLastRow
                    ? const Border(
                        bottom: BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      log['time'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: kColorTextTitle,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${log['hr']} BPM',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kColorTextTitle,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${log['hrv']} ms',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kColorTextTitle,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// '건강 조언' 카드
  Widget _buildRecommendationCard() {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: kColorBtnPrimary, size: 24),
              const SizedBox(width: 8),
              const Text(
                  '건강 조언',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kColorTextTitle
                  )
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _userStateColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 상태: $_userState',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _userStateColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _recommendation.isEmpty ? '데이터를 수집하는 중입니다.' : _recommendation,
                  style: const TextStyle(
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

  /// '오늘의 스트레스 변화' 카드
  Widget _buildStressLogCard() {
    // 실제 데이터로부터 통계 계산
    final stats = _calculateStressStatistics();

    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '오늘의 스트레스 변화',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kColorTextTitle
              )
          ),
          SizedBox(height: 16),
          // 스트레스 로그 목록
          Column(
            children: _stressLog.map((log) =>
                _buildStressLogRow(
                  time: log['time'],
                  hr: log['hr'],
                  hrv: log['hrv'],
                  stress: log['stress'],
                )
            ).toList(),
          ),
          Divider(height: 32),
          // 스트레스 요약 (실제 계산된 값 사용)
          _buildStressSummaryRow(
            avgStress: stats['avgStress']!,
            maxStress: stats['maxStress']!,
            avgHr: stats['avgHr']!,
          ),
        ],
      ),
    );
  }

  /// 스트레스 로그로부터 통계 계산
  Map<String, int> _calculateStressStatistics() {
    if (_stressLog.isEmpty) {
      return {
        'avgStress': 0,
        'maxStress': 0,
        'avgHr': 0,
      };
    }

    int totalStress = 0;
    int maxStress = 0;
    int totalHr = 0;

    for (var log in _stressLog) {
      final stress = log['stress'] as int;
      final hr = log['hr'] as int;

      totalStress += stress;
      totalHr += hr;

      if (stress > maxStress) {
        maxStress = stress;
      }
    }

    final avgStress = (totalStress / _stressLog.length).round();
    final avgHr = (totalHr / _stressLog.length).round();

    return {
      'avgStress': avgStress,
      'maxStress': maxStress,
      'avgHr': avgHr,
    };
  }

  /// 스트레스 로그 Row 헬퍼
  Widget _buildStressLogRow({required String time, required int hr, required int hrv, required int stress}) {
    Color stressColor;
    if (stress >= 65) stressColor = kColorError;
    else if (stress >= 40) stressColor = kStressHigh;
    else if (stress >= 25) stressColor = kStressNormal;
    else stressColor = kStressLow;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
              time,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kColorTextTitle)
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
                '심박수 $hr・HRV $hrv',
                style: TextStyle(fontSize: 14, color: kColorTextSubtitle)
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: stressColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
                '$stress',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: stressColor)
            ),
          ),
        ],
      ),
    );
  }

  /// 스트레스 요약 Row 헬퍼
  Widget _buildStressSummaryRow({required int avgStress, required int maxStress, required int avgHr}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            Text('평균 스트레스', style: TextStyle(fontSize: 12, color: kColorTextSubtitle)),
            SizedBox(height: 4),
            Text(
              '$avgStress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kColorTextTitle),
            ),
          ],
        ),
        Column(
          children: [
            Text('최고 스트레스', style: TextStyle(fontSize: 12, color: kColorTextSubtitle)),
            SizedBox(height: 4),
            Text(
              '$maxStress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kColorTextTitle),
            ),
          ],
        ),
        Column(
          children: [
            Text('평균 심박수', style: TextStyle(fontSize: 12, color: kColorTextSubtitle)),
            SizedBox(height: 4),
            Text(
              '$avgHr',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kColorTextTitle),
            ),
          ],
        ),
      ],
    );
  }

  /// 'Health Connect 연동 정보' 카드
  Widget _buildHealthConnectInfoCard() {
    final cardTitle = Platform.isIOS ? 'Apple Health 연동 정보' : 'Health Connect 연동 정보';
    final syncInfo = Platform.isIOS
        ? 'Apple Watch에서 자동으로 동기화됩니다.'
        : 'Samsung Health 등 연결된 앱에서 데이터를 가져옵니다.';

    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              cardTitle,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kColorTextTitle
              )
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.monitor_heart,
            title: '실시간 생체 데이터',
            subtitle: '심박수, 심박변이도를 통해 스트레스 지수를 자동 계산합니다.',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.sync,
            title: '자동 동기화',
            subtitle: syncInfo,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.shield_outlined,
            title: '개인정보 보호',
            subtitle: '모든 건강 데이터는 기기에서 안전하게 처리됩니다.',
          ),
          // Android인 경우 Health Connect 권한 재요청 버튼 추가
          if (Platform.isAndroid) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _healthService.reopenHealthConnectPermissions();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Health Connect 권한 화면에서 추가 권한을 부여하세요.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.health_and_safety, size: 20),
                label: const Text(
                  'Health Connect 권한 다시 요청',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kColorBtnPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '💡 Samsung Health를 Health Connect에 연결하고 추가 권한을 부여하면 더 많은 건강 데이터를 받아올 수 있습니다.\n\n📱 Health Connect 앱을 열고 "앱 권한" → "Personal Therapy"에서 권한을 확인하세요.',
              style: TextStyle(
                fontSize: 13,
                color: kColorTextSubtitle,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 연동 정보 Row 헬퍼
  Widget _buildInfoRow({required IconData icon, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kColorBtnPrimary, size: 24),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kColorTextTitle)
              ),
              SizedBox(height: 4),
              Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: kColorTextSubtitle)
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 공통 카드 컨테이너
  Widget _buildSettingCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kColorCardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  /// '오늘의 활동' 카드
  Widget _buildActivityCard() {
    return _buildSettingCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                '오늘의 활동',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kColorTextTitle
                )
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.directions_walk, _steps, '걸음', '걸음 수', kPrimaryGreen),
                _buildStatItem(Icons.local_fire_department, _activeCalories.round(), 'kcal', '소모 칼로리', kColorError),
              ],
            ),
          ],
        )
    );
  }
}