import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:untitled/main_screen.dart';
import 'package:untitled/services/health_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color kConnectedGreen = Color(0xFF21C45D);
const Color kStressHigh = Color(0xFFF59E0B);
const Color kStressNormal = Color(0xFF3B81F5);
const Color kStressLow = Color(0xFF4ADE80);
const Color kPrimaryGreen = Color(0xFF16A34A);

class WearableDeviceScreen extends StatefulWidget {
  const WearableDeviceScreen({Key? key}) : super(key: key);

  @override
  _WearableDeviceScreenState createState() => _WearableDeviceScreenState();
}

class _WearableDeviceScreenState extends State<WearableDeviceScreen> {
  final HealthService _healthService = HealthService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Timer? _dataUpdateTimer;
  bool _isLoading = true;
  bool _isConnected = false;

  // 마지막 업데이트 시간
  DateTime? _lastUpdatedTime;

  // 데이터
  int _steps = 0;
  double _activeCalories = 0;
  int _currentHR = 72;
  int _currentHRV = 35;
  int _restingHR = 65;
  int _currentStress = 45;
  String _userState = '보통';
  String _recommendation = '';
  Color _userStateColor = kStressNormal;

  List<Map<String, dynamic>> _connectedDevices = [];
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

  /// 초기화
  Future<void> _initializeHealthData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (Platform.isAndroid) {
        final status = await _healthService.checkHealthConnectStatus();
        if (status.toString().contains('unavailable')) {
          _showErrorSnackBar('Health Connect가 설치되지 않았습니다.');
          return;
        }
      }

      bool authorized = await _healthService.requestAuthorization();
      if (authorized) {
        await _refreshHealthData();
        await _loadTodayStressLog();

        setState(() {
          _isConnected = true;
          // (기기 목록은 _refreshHealthData에서 실제 데이터 기반으로 업데이트됨)
        });
      } else {
        _showErrorSnackBar('권한이 필요합니다.');
      }
    } catch (e) {
      _showErrorSnackBar('초기화 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 데이터 새로고침
  Future<void> _refreshHealthData() async {
    try {
      final healthData = await _healthService.fetchRecentHealthData();
      final List<String> devices = List<String>.from(healthData['devices'] ?? []);

      setState(() {
        _steps = healthData['steps'] ?? 0;
        _activeCalories = healthData['activeCalories'] ?? 0.0;
        _currentHR = healthData['currentHR'] ?? 72;
        _currentHRV = healthData['currentHRV'] ?? 35;
        _restingHR = healthData['restingHR'] ?? 65;

        // [수정] 10분 제한 없이 가장 최신 데이터의 시간 사용
        if (healthData['lastMeasureTime'] != null) {
          _lastUpdatedTime = healthData['lastMeasureTime'] as DateTime;
        }

        // 기기 목록 업데이트
        if (devices.isNotEmpty) {
          _connectedDevices = devices.map((deviceName) {
            String name = deviceName;
            if (name.contains('com.sec.android') || name.contains('samsung')) {
              name = 'Health Connect';
            }
            return {
              'name': name,
              'battery': null,
              'status': 'Galaxy watch5 연동'
            };
          }).toList();
        } else {
          if (_isConnected && _connectedDevices.isEmpty) {
            _connectedDevices = [
              {
                'name': Platform.isIOS ? 'Apple Health 기기' : 'Health Connect 기기',
                'battery': null,
                'status': '연결됨 (데이터 대기중)'
              }
            ];
          }
        }
      });

      _analyzeUserState();

      // Firestore 저장
      final userId = _currentUserId;
      if (userId != null) {
        await _healthService.saveHealthDataToFirestore(userId, {
          'steps': _steps,
          'activeCalories': _activeCalories,
          'heartRate': _currentHR,
          'hrv': _currentHRV,
          'restingHR': _restingHR,
          'stressLevel': _currentStress,
          'userState': _userState,
          'timestamp': DateTime.now(),
        });
      }
    } catch (e) {
      print('데이터 새로고침 실패: $e');
    }
  }

  /// 스트레스 로그 (1시간 단위)
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

      if (_userState.contains('높은 스트레스')) {
        _userStateColor = kStressHigh;
      } else if (_userState.contains('편안')) {
        _userStateColor = kStressLow;
      } else {
        _userStateColor = kStressNormal;
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: kColorError),
      );
    }
  }

  // Health Connect 가이드 (Android)
  Future<void> _showHealthConnectGuide() async {
    if (Platform.isAndroid) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Health Connect 권한 설정'),
          content: const Text(
              '설정 > 앱 > Health Connect > 권한 메뉴에서\n이 앱의 모든 권한을 허용해주세요.'
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

  // [수정] 시간 포맷 함수 (null 처리 강화)
  String _formatLastUpdatedTime() {
    if (_lastUpdatedTime == null) return '업데이트 정보 없음';

    final hour = _lastUpdatedTime!.hour;
    final minute = _lastUpdatedTime!.minute;
    final ampm = hour < 12 ? '오전' : '오후';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');

    return '최근 업데이트: $ampm $displayHour:$displayMinute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBgStart,
      appBar: AppBar(
        backgroundColor: kColorBgStart,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kColorTextTitle, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '웨어러블 연동',
          style: TextStyle(color: kColorTextTitle, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kColorBtnPrimary),
            onPressed: _isLoading ? null : () async {
              await _refreshHealthData();
              await _loadTodayStressLog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
              // 로그가 없으면 빈 공간 대신 안내 메시지 혹은 숨김
              if (_stressLog.isNotEmpty) ...[
                _buildStressLogCard(),
                const SizedBox(height: 24),
              ],
              _buildRecommendationCard(),
              const SizedBox(height: 24),
              _buildHealthConnectInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  // --- 위젯 빌더들 ---

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
                    Text('건강 상태 모니터링', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kColorTextTitle)),
                    SizedBox(height: 4),
                    // [핵심] 최근 업데이트 시간 표시
                    Text(_formatLastUpdatedTime(), style: TextStyle(fontSize: 12, color: kColorTextSubtitle)),
                  ],
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isConnected ? kConnectedGreen.withOpacity(0.1) : kColorError.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: _isConnected ? kConnectedGreen : kColorError, size: 10),
                      SizedBox(width: 6),
                      Text(_isConnected ? '연결됨' : '연결 끊김', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _isConnected ? kConnectedGreen : kColorError)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.favorite, _currentHR, 'BPM', '심박수', kColorError),
                _buildStatItem(Icons.waves, _currentHRV, 'ms', '심박변이도', kColorBtnPrimary),
                _buildStatItem(Icons.sentiment_very_satisfied, 0, _userState, '신체 상태', _userStateColor),
              ],
            ),
          ],
        )
    );
  }

  Widget _buildStatItem(IconData icon, int value, String unit, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        SizedBox(height: 8),
        label != '신체 상태'
            ? Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kColorTextTitle)),
            SizedBox(width: 4),
            Text(unit, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kColorTextSubtitle)),
          ],
        )
            : Text(unit, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: kColorTextSubtitle)),
      ],
    );
  }

  Widget _buildConnectedDevicesCard() {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('연결된 기기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kColorTextTitle)),
          const SizedBox(height: 16),
          _connectedDevices.isEmpty
              ? Center(child: Text('연결된 기기가 없습니다.'))
              : Column(
            children: _connectedDevices.map((d) => _buildConnectedDeviceRow(name: d['name'], battery: d['battery'], status: d['status'])).toList(),
          ),
        ],
      ),
    );
  }

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
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kColorTextTitle)),
                const SizedBox(height: 4),
                Text(battery != null ? '$battery%・$status' : status, style: const TextStyle(fontSize: 14, color: kColorTextSubtitle)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard() {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.lightbulb_outline, color: kColorBtnPrimary, size: 24), SizedBox(width: 8), Text('건강 조언', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kColorTextTitle))]),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: _userStateColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('현재 상태: $_userState', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _userStateColor)),
                SizedBox(height: 8),
                Text(_recommendation.isEmpty ? '데이터 수집 중...' : _recommendation, style: TextStyle(fontSize: 14, color: kColorTextSubtitle, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStressLogCard() {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘의 스트레스 변화', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kColorTextTitle)),
          SizedBox(height: 16),
          Column(children: _stressLog.map((log) => _buildStressLogRow(time: log['time'], hr: log['hr'], hrv: log['hrv'], stress: log['stress'])).toList()),
        ],
      ),
    );
  }

  Widget _buildStressLogRow({required String time, required int hr, required int hrv, required int stress}) {
    Color color = stress >= 65 ? kColorError : (stress >= 40 ? kStressHigh : (stress >= 25 ? kStressNormal : kStressLow));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(time, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kColorTextTitle)),
          SizedBox(width: 16),
          Expanded(child: Text('심박수 $hr・HRV $hrv', style: TextStyle(fontSize: 14, color: kColorTextSubtitle))),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text('$stress', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthConnectInfoCard() {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Platform.isIOS ? 'Apple Health 정보' : 'Health Connect 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kColorTextTitle)),
          SizedBox(height: 16),
          _buildInfoRow(icon: Icons.monitor_heart, title: '분석', subtitle: '최근 측정된 데이터를 분석합니다.'),
          SizedBox(height: 16),
          _buildInfoRow(icon: Icons.sync, title: '동기화', subtitle: Platform.isIOS ? '자동 동기화' : '연결된 헬스 앱에서 가져옵니다.'),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kColorBtnPrimary, size: 24),
        SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kColorTextTitle)), SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 14, color: kColorTextSubtitle))])),
      ],
    );
  }

  Widget _buildActivityCard() {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘의 활동', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kColorTextTitle)),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.directions_walk, _steps, '걸음', '걸음 수', kPrimaryGreen),
              _buildStatItem(Icons.local_fire_department, _activeCalories.round(), 'kcal', '소모 칼로리', kColorError),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(color: kColorCardBg, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }
}