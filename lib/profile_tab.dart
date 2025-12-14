import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:health/health.dart';
import 'package:google_fonts/google_fonts.dart';

// [!!] 필요한 파일들 import
import 'add_contact_sheet.dart';
import 'personal_info_screen.dart';
import 'health_result_page.dart';

// ---------------------------------------------------------------------------
// 색상 정의
// ---------------------------------------------------------------------------
const Color kColorBtnPrimary = Color(0xFF2563EB);
const Color kColorCardBg = Colors.white;
const Color kColorTextTitle = Color(0xFF1F2937);
const Color kColorTextSubtitle = Color(0xFF4B5563);
const Color kColorMoodSliderInactive = Color(0xFFD1D5DB);
const Color kColorError = Color(0xFFEF4444);

// 이 파일에서만 쓰이는 추가 색상들
const Color kPrimaryGreen = Color(0xFF16A34A);
const Color kPrimaryPurple = Color(0xFF9333EA);
const Color kDarkRed = Color(0xFFB91C1C);

// ---------------------------------------------------------------------------

// 연락처 데이터 모델
class EmergencyContact {
  String name;
  String phone;
  String tag;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  EmergencyContact({
    required this.name,
    required this.phone,
    required this.tag,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  ProfileTabState createState() => ProfileTabState();
}

class ProfileTabState extends State<ProfileTab> {
  final FirestoreService _firestoreService = FirestoreService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final Health _health = Health();
  int _stepCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchStepData();
  }

  /// 걸음 수 데이터 가져오기
  Future<void> _fetchStepData() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // 권한 확인 (요청하지 않고 확인만)
      bool? hasPermission = await _health.hasPermissions(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );

      if (hasPermission == true) {
        int? steps = await _health.getTotalStepsInInterval(midnight, now);
        if (steps != null) {
          if (mounted) {
            setState(() {
              _stepCount = steps;
            });
          }
        }
      }
    } catch (e) {
      print('걸음 수 데이터 가져오기 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
      child: Column(
        children: [
          _buildUserStatsCard(),
          const SizedBox(height: 24),
          _buildHealthStatusCard(context),
          const SizedBox(height: 24),
          _buildEmergencyContactsCard(context),
          const SizedBox(height: 24),
          _buildNotificationSettingsCard(),
          const SizedBox(height: 24),
          _buildAccountCard(),
          const SizedBox(height: 24),
          _buildDeleteAccountCard(),
        ],
      ),
    );
  }

  // 사용자 스탯 카드 (통계 부분 제거됨)
  Widget _buildUserStatsCard() {
    return _buildCardContainer(
      child: StreamBuilder<Map<String, dynamic>?>(
        stream: _currentUserId != null ? _firestoreService.getUserStream(_currentUserId!) : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('사용자 데이터를 불러올 수 없습니다.'));
          }

          final userData = snapshot.data!;
          final userName = userData['name'] ?? '사용자님';
          final userCreationDate = (userData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final daysWithApp = DateTime.now().difference(userCreationDate).inDays;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFFDBEAFE),
                    child: Icon(Icons.person, size: 30, color: kColorBtnPrimary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Personal Therapy와 함께한 지 ${daysWithApp}일',
                          style: const TextStyle(fontSize: 14, color: kColorTextSubtitle),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // 하단 통계 부분 제거됨
            ],
          );
        },
      ),
    );
  }

  // 나의 상태 카드
  Widget _buildHealthStatusCard(BuildContext context) {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '나의 상태',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  // 개발용: 수면 기록 삭제 버튼
                  TextButton(
                    onPressed: () async {
                      if (_currentUserId != null) {
                        await _firestoreService.deleteAllSleepRecords(_currentUserId!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('수면 기록이 모두 삭제되었습니다')),
                          );
                        }
                      }
                    },
                    child: const Text('수면 삭제', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _firestoreService.getUserStream(_currentUserId!).first.then((userData) {
                        if (userData != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HealthResultPage(),
                            ),
                          );
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kColorBtnPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('확인하기'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ✅ 수정: 건강 점수, 수면 시간, 걸음 수를 Firestore에서 가져오기
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. 건강 점수 (정신건강 종합 점수 - overallScore)
              Expanded(
                child: StreamBuilder<Map<String, dynamic>?>(
                  // [변경] 리스트 스트림(List) 대신, 날짜 기반 단일 문서 스트림(Map)을 사용합니다.
                  // _firestoreService에 getDailyMentalStatusStream 함수가 정의되어 있어야 합니다.
                  stream: _currentUserId != null
                      ? _firestoreService.getDailyMentalStatusStream(_currentUserId!, DateTime.now())
                      : null,
                  builder: (context, snapshot) {
                    // 1. 로딩 중일 때
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const StatusItem(icon: Icons.favorite, title: '건강 점수', value: '...');
                    }

                    // 2. 데이터가 아예 없거나(null), 아직 오늘의 기록이 없는 경우
                    if (!snapshot.hasData || snapshot.data == null) {
                      // 오늘의 기록이 없을 때 '0' 또는 'N/A' 등으로 표시
                      return const StatusItem(icon: Icons.favorite, title: '건강 점수', value: 'N/A');
                    }

                    final data = snapshot.data!;

                    // 3. [핵심] updateDailyMentalStatus 함수가 저장한 'overallScore' 필드 가져오기
                    final score = (data['overallScore'] as num?)?.toInt() ?? 0;

                    return StatusItem(icon: Icons.favorite, title: '건강 점수', value: '$score');
                  },
                ),
              ),

              // 2. 수면 시간 (기존 유지)
              Expanded(
                child: GestureDetector(
                  onTap: () => _showSleepTimeInputDialog(context),
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _currentUserId != null ? _firestoreService.getSleepScoresStream(_currentUserId!) : null,
                    builder: (context, sleepSnapshot) {
                      if (sleepSnapshot.connectionState == ConnectionState.waiting) {
                        return const StatusItem(icon: Icons.hotel, title: '수면 시간', value: '...');
                      }

                      List<Map<String, dynamic>> sleepData = sleepSnapshot.data ?? [];
                      double totalDuration = 0.0;
                      int count = 0;

                      // 최근 7일간의 평균 수면 시간 계산
                      final now = DateTime.now();
                      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                      final endOfWeek = startOfWeek.add(const Duration(days: 6));

                      final filteredData = sleepData.where((record) {
                        final ts = record['timestamp'];
                        if (ts == null || ts is! Timestamp) return false;
                        return ts.toDate().isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                            ts.toDate().isBefore(endOfWeek.add(const Duration(days: 1)));
                      }).toList();

                      for (var record in filteredData) {
                        try {
                          totalDuration += (record['duration'] as num?)?.toDouble() ?? 0.0;
                          count++;
                        } catch (e) { }
                      }

                      String averageSleep = count > 0 ? (totalDuration / count).toStringAsFixed(1) : 'N/A';

                      return StatusItem(icon: Icons.hotel, title: '수면 시간', value: '$averageSleep 시간');
                    },
                  ),
                ),
              ),

              // 3. 걸음 수 (Firestore health_data에서 가져오기)
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _currentUserId != null
                      ? _firestoreService.getHealthDataStream(_currentUserId!)
                      : null,
                  builder: (context, snapshot) {
                    // Firestore 데이터가 없으면 Health API 데이터 사용 (폴백)
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return StatusItem(
                        icon: Icons.directions_walk,
                        title: '걸음 수',
                        value: _stepCount > 0 ? _stepCount.toString() : 'N/A',
                      );
                    }

                    // 오늘의 걸음 수 데이터 가져오기
                    final now = DateTime.now();
                    final startOfDay = DateTime(now.year, now.month, now.day);

                    final todayData = snapshot.data!.where((item) {
                      final ts = item['timestamp'];
                      if (ts == null || ts is! Timestamp) return false;
                      final timestamp = ts.toDate();
                      return timestamp.isAfter(startOfDay);
                    }).toList();

                    if (todayData.isEmpty) {
                      return StatusItem(
                        icon: Icons.directions_walk,
                        title: '걸음 수',
                        value: _stepCount > 0 ? _stepCount.toString() : 'N/A',
                      );
                    }

                    // 오늘의 최신 걸음 수
                    final latestData = todayData.last;
                    final steps = (latestData['steps'] as num?)?.toInt() ?? _stepCount;

                    return StatusItem(
                      icon: Icons.directions_walk,
                      title: '걸음 수',
                      value: steps.toString(),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showSleepTimeInputDialog(BuildContext context) async {
    double _currentSliderValue = 8.0;
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('수면 시간 입력'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${_currentSliderValue.toStringAsFixed(1)} 시간'),
                  Slider(
                    value: _currentSliderValue,
                    min: 1,
                    max: 12,
                    divisions: 22,
                    label: _currentSliderValue.toStringAsFixed(1),
                    onChanged: (double value) {
                      setState(() {
                        _currentSliderValue = value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('저장'),
              onPressed: () async {
                if (_currentUserId != null) {
                  try {
                    await _firestoreService.addSleepRecord(
                        _currentUserId!, _currentSliderValue);
                    Navigator.of(context).pop();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('저장 실패: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 안심 연락망 카드
  Widget _buildEmergencyContactsCard(BuildContext context) {
    if (_currentUserId == null) {
      return _buildCardContainer(child: const Center(child: Text('로그인이 필요합니다.')));
    }

    return _buildCardContainer(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getEmergencyContactsStream(_currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final contacts = snapshot.data ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '안심 연락망',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  InkWell(
                    onTap: contacts.length >= 3
                        ? null
                        : () {
                      _showAddContactModal(context, contacts: contacts);
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: contacts.length >= 3
                          ? const Color(0xFFE5E7EB)
                          : const Color(0xFFDBEAFE),
                      child: Icon(
                        Icons.add,
                        color: contacts.length >= 3
                            ? const Color(0xFF9CA3AF)
                            : kColorBtnPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '위기 상황 감지 시 알림을 받을 연락처를 설정하세요. (${contacts.length}/3)',
                style: const TextStyle(fontSize: 14, color: kColorTextSubtitle),
              ),
              const SizedBox(height: 20),
              if (contacts.isEmpty)
                const Center(
                  child: Text(
                    '등록된 연락처가 없습니다.',
                    style: TextStyle(color: kColorTextSubtitle),
                  ),
                )
              else
                Column(
                  children: contacts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final contact = entry.value;
                    return _buildContactItem(
                      name: contact['name'] ?? '',
                      phone: contact['phone'] ?? '',
                      tag: contact['tag'] ?? '',
                      onEdit: () {
                        _showAddContactModal(
                          context,
                          contacts: contacts,
                          editIndex: index,
                          existingContact: contact,
                        );
                      },
                      onDelete: () async {
                        await _firestoreService.deleteEmergencyContact(_currentUserId!, index);
                      },
                    );
                  }).toList(),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showAddContactModal(
      BuildContext context, {
        required List<Map<String, dynamic>> contacts,
        int? editIndex,
        Map<String, dynamic>? existingContact,
      }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext bContext) {
        return AddContactBottomSheet(
          contact: existingContact != null
              ? EmergencyContact(
            name: existingContact['name'] ?? '',
            phone: existingContact['phone'] ?? '',
            tag: existingContact['tag'] ?? '',
            icon: Icons.person,
            bgColor: const Color(0xFFE0E7FF),
            iconColor: const Color(0xFF4338CA),
          )
              : null,
          onSave: (String name, String phone, String tag) async {
            if (_currentUserId == null) return;
            final contactData = {'name': name, 'phone': phone, 'tag': tag};
            try {
              if (editIndex != null) {
                await _firestoreService.updateEmergencyContact(_currentUserId!, editIndex, contactData);
              } else {
                if (contacts.length >= 3) return;
                await _firestoreService.addEmergencyContact(_currentUserId!, contactData);
              }
              Navigator.pop(context);
            } catch (e) {
              // 에러 처리
            }
          },
        );
      },
    );
  }

  // 알림 설정 카드
  Widget _buildNotificationSettingsCard() {
    return StatefulBuilder(
      builder: (context, setState) {
        Map<String, bool> toggles = {
          '감정 기록 알림': true,
          '위기 감지 알림': true,
          '힐링 콘텐츠 알림': false,
        };

        return _buildCardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '알림 설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _buildSwitchItem(
                '감정 기록 알림',
                toggles['감정 기록 알림']!,
                    (value) => setState(() => toggles['감정 기록 알림'] = value),
              ),
              _buildSwitchItem(
                '위기 감지 알림',
                toggles['위기 감지 알림']!,
                    (value) => setState(() => toggles['위기 감지 알림'] = value),
              ),
              _buildSwitchItem(
                '힐링 콘텐츠 알림',
                toggles['힐링 콘텐츠 알림']!,
                    (value) => setState(() => toggles['힐링 콘텐츠 알림'] = value),
              ),
            ],
          ),
        );
      },
    );
  }

  // 계정 설정 카드
  Widget _buildAccountCard() {
    VoidCallback navigateToSettings = () {
      if (_currentUserId == null) return;
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      _firestoreService.getUserStream(_currentUserId!).first.then((userData) {
        if (userData != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PersonalInfoScreen(userData: userData, email: email),
            ),
          );
        }
      });
    };

    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _buildMenuItem(
            icon: Icons.lock_person,
            iconColor: kColorBtnPrimary,
            text: '개인정보 설정',
            onTap: navigateToSettings,
          ),
          const SizedBox(height: 8),
          _buildMenuItem(
            icon: Icons.logout,
            iconColor: kColorError,
            text: '로그아웃',
            onTap: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  // 회원 탈퇴 카드
  Widget _buildDeleteAccountCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: kColorError, size: 24),
              const SizedBox(width: 8),
              const Text(
                '회원 탈퇴',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '계정을 삭제하면 모든 데이터가 영구적으로 삭제됩니다.',
            style: TextStyle(fontSize: 14, color: kDarkRed),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kColorError,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {}, // 탈퇴 로직 필요
            child: const Text('생명의전화 1393'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF3F4F6),
              foregroundColor: kColorTextSubtitle,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () {}, // 탈퇴 로직 필요
            child: const Text('회원 탈퇴'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 헬퍼 위젯들
  // -------------------------------------------------------------------------

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kColorCardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _buildContactItem({
    required String name,
    required String phone,
    required String tag,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    IconData icon;
    Color bgColor;
    Color iconColor;

    switch (tag) {
      case '가족':
        icon = Icons.family_restroom;
        bgColor = const Color(0xFFFEE2E2);
        iconColor = const Color(0xFFDC2626);
        break;
      case '친구':
        icon = Icons.people;
        bgColor = const Color(0xFFD1FAE5);
        iconColor = const Color(0xFF16A34A);
        break;
      case '상담사':
        icon = Icons.support_agent;
        bgColor = const Color(0xFFFEF3C7);
        iconColor = const Color(0xFFD97706);
        break;
      default:
        icon = Icons.person;
        bgColor = const Color(0xFFE0E7FF);
        iconColor = const Color(0xFF4338CA);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: bgColor,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('$phone · $tag', style: const TextStyle(color: kColorTextSubtitle)),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.edit, color: kColorTextSubtitle, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.delete, color: kColorError, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchItem(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: kColorBtnPrimary,
            inactiveTrackColor: kColorMoodSliderInactive,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
            const Icon(Icons.arrow_forward_ios, size: 16, color: kColorTextSubtitle),
          ],
        ),
      ),
    );
  }
}

// 상태 아이템 위젯
class StatusItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const StatusItem({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: kColorBtnPrimary),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: kColorTextSubtitle),
        ),
      ],
    );
  }
}