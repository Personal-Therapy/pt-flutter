import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'package:untitled/services/firestore_service.dart'; // Add this import
import 'package:untitled/main_screen.dart'; // Import main_screen.dart for shared color constants
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import 'package:health/health.dart'; // Add this import
import 'package:google_fonts/google_fonts.dart';

import 'add_contact_sheet.dart'; // [!!] 팝업창 위젯 import
import 'personal_info_screen.dart'; // [!!] 1. 새로 만든 페이지 import
import 'health_result_page.dart';

// [주의] MainScreen에서 이미 모든 Health 권한을 요청했으므로,
// 이 파일에서는 권한 요청 없이 데이터만 가져옵니다.

// RTF 파일에서 정의된 색상 상수 (주석 처리 또는 main_screen.dart에서 가져옴)
// const Color kPageBackground = Color(0xFFF9FAFB); // Use kColorBgStart
// const Color kCardBackground = Color(0xFFFFFFFF); // Use kColorCardBg
// const Color kColorBtnPrimary = Color(0xFF2563EB); // Use kColorBtnPrimary
const Color kPrimaryGreen = Color(0xFF16A34A); // This color seems unique to this file for now
const Color kPrimaryPurple = Color(0xFF9333EA);
const Color kColorError = Color(0xFFDC2626); // Use kColorError (or define a specific red if different)
const Color kDarkRed = Color(0xFFB91C1C);
// const Color kDisabledGrey = Color(0xFFE5E7EB); // Use kColorMoodSliderInactive
// const Color kColorTextTitle = Color(0xFF111827); // Use kColorTextTitle
// const Color kColorTextSubtitle = Color(0xFF6B7280); // Use kColorTextSubtitle

// [!!] 연락처 데이터를 관리할 클래스(모델)를 정의합니다.
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

// 프로필 탭
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
  final TextEditingController _sleepTimeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStepData();
  }

  /// 걸음 수 데이터 가져오기
  /// [주의] MainScreen에서 이미 권한을 요청했으므로 여기서는 데이터만 가져옵니다.
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
      } else {
        print('⚠️ 걸음 수 권한이 없습니다. MainScreen에서 권한을 요청하세요.');
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

  // 사용자 스탯 카드
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
          final conversationCount = (userData['conversationCount'] ?? 0).toString();
          final averageHealthScore = (userData['averageHealthScore'] ?? 0).toString();
          final healingContentCount = (userData['healingContentCount'] ?? 0).toString();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ 프로필 정보 (기존 그대로 유지)
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFFDBEAFE),
                    child: Icon(Icons.person, size: 30, color: kColorBtnPrimary),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Personal Therapy와 함께한 지 ${daysWithApp}일',
                        style: const TextStyle(fontSize: 14, color: kColorTextSubtitle),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Divider(color: Colors.grey[200]),
              const SizedBox(height: 16),

              // ✅ 통계는 이 Row 하나만!
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: _buildStatItem('대화 횟수', conversationCount, kColorBtnPrimary),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _buildStatItem('평균 건강 점수', averageHealthScore, kPrimaryGreen),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _buildStatItem('힐링 콘텐츠', healingContentCount, kPrimaryPurple),
                    ),
                  ),
                ],
              ),
            ],
          );

        },
      ),
    );
  }

  // 스탯 아이템 (기존과 동일)
  Widget _buildStatItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: kColorTextSubtitle)),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ✅ 나의 상태 카드
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
                      // 현재 사용자 데이터 가져오기
                      _firestoreService.getUserStream(_currentUserId!).first.then((userData) {
                        if (userData != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HealthResultPage(userData: userData),
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
          StreamBuilder<Map<String, dynamic>?>(
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
              final healthScore = (userData['averageHealthScore'] ?? 'N/A').toString();
              // final sleepTime = userData['sleepTime'] as String? ?? 'N/A'; // 기존 코드 주석 처리 또는 제거

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(child: StatusItem(icon: Icons.favorite, title: '건강 점수', value: healthScore)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showSleepTimeInputDialog(context),
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _currentUserId != null ? _firestoreService.getSleepScoresStream(_currentUserId!) : null,
                        builder: (context, sleepSnapshot) {
                          print('StreamBuilder - ConnectionState: ${sleepSnapshot.connectionState}');
                          print('StreamBuilder - HasError: ${sleepSnapshot.hasError}');
                          if (sleepSnapshot.hasData) {
                            print('StreamBuilder - Sleep Data: ${sleepSnapshot.data}');
                          }
                          
                          if (sleepSnapshot.connectionState == ConnectionState.waiting) {
                            return const StatusItem(icon: Icons.hotel, title: '수면 시간', value: '...');
                          }
                          if (sleepSnapshot.hasError) {
                            return const StatusItem(icon: Icons.hotel, title: '수면 시간', value: '오류');
                          }
                          
                          List<Map<String, dynamic>> sleepData = sleepSnapshot.data ?? [];
                          double totalDuration = 0.0;
                          int count = 0;

                          // 최근 7일간의 평균 수면 시간 계산 로직 (emotion_tracking_tab.dart 재활용)
                          final now = DateTime.now();
                          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                          final endOfWeek = startOfWeek.add(const Duration(days: 6));

                          final filteredData = sleepData.where((record) {
                            final timestamp = record['timestamp'] as Timestamp?;
                            return timestamp != null &&
                                timestamp.toDate().isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                                timestamp.toDate().isBefore(endOfWeek.add(const Duration(days: 1)));
                          }).toList();

                          for (var record in filteredData) {
                            try {
                              totalDuration += (record['duration'] as num).toDouble();
                              count++;
                            } catch (e) {
                              // 오류 처리
                            }
                          }

                          String averageSleep = count > 0 ? (totalDuration / count).toStringAsFixed(1) : 'N/A';

                          return StatusItem(icon: Icons.hotel, title: '수면 시간', value: '$averageSleep 시간');
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: StatusItem(
                      icon: Icons.directions_walk,
                      title: '걸음 수',
                      value: _stepCount.toString(),
                    ),
                  ),
                ],
              );
            },
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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('저장'),
              onPressed: () async {
                if (_currentUserId != null) {
                  print('현재 사용자 UID: $_currentUserId'); // 디버그 로그 추가
                  print('수면 시간 저장 시도: $_currentSliderValue 시간'); // 저장 시도 로그
                  try {
                    await _firestoreService.addSleepRecord(
                        _currentUserId!, _currentSliderValue);
                    print('수면 시간 저장 성공: $_currentSliderValue 시간'); // 저장 성공 로그
                    Navigator.of(context).pop(); // 성공 시에만 팝업 닫기
                  } catch (e) {
                    print('수면 시간 저장 실패: $e'); // 저장 실패 로그
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('수면 시간 저장에 실패했습니다: ${e.toString()}')),
                    );
                  }
                } else {
                  print('오류: _currentUserId가 null입니다.'); // 디버그 로그 추가
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그인 정보가 없어 수면 시간을 저장할 수 없습니다. 다시 로그인해주세요.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }


  // --- 2. 안심 연락망 카드 ---
  Widget _buildEmergencyContactsCard(BuildContext context) {
    if (_currentUserId == null) {
      return _buildCardContainer(
        child: const Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return _buildCardContainer(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getEmergencyContactsStream(_currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }

          final contacts = snapshot.data ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
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
                          ? Color(0xFFE5E7EB)
                          : Color(0xFFDBEAFE),
                      child: Icon(
                        Icons.add,
                        color: contacts.length >= 3
                            ? Color(0xFF9CA3AF)
                            : kColorBtnPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '위기 상황 감지 시 알림을 받을 연락처를 설정하세요. (${contacts.length}/3)',
                style: TextStyle(fontSize: 14, color: kColorTextSubtitle),
              ),
              SizedBox(height: 20),

              // 연락처 목록
              if (contacts.isEmpty)
                Center(
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
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('연락처가 삭제되었습니다')),
                          );
                        }
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

  // 팝업 띄우기 함수
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
                  bgColor: Color(0xFFE0E7FF),
                  iconColor: Color(0xFF4338CA),
                )
              : null,
          onSave: (String name, String phone, String tag) async {
            if (_currentUserId == null) return;

            final contactData = {
              'name': name,
              'phone': phone,
              'tag': tag,
            };

            try {
              if (editIndex != null) {
                // 수정 모드
                await _firestoreService.updateEmergencyContact(
                  _currentUserId!,
                  editIndex,
                  contactData,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('연락처가 수정되었습니다')),
                  );
                }
              } else {
                // 추가 모드
                if (contacts.length >= 3) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('최대 3개까지만 등록할 수 있습니다')),
                    );
                  }
                  return;
                }
                await _firestoreService.addEmergencyContact(
                  _currentUserId!,
                  contactData,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('연락처가 추가되었습니다')),
                  );
                }
              }
              Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('오류가 발생했습니다: $e')),
                );
              }
            }
          },
        );
      },
    );
  }

  // --- 3. 알림 설정 카드 (기존과 동일) ---
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
              Text(
                '알림 설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 16),
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

  // 3. 계정 설정 카드
  Widget _buildAccountCard() {
    VoidCallback navigateToSettings = () {
      if (_currentUserId == null) return;

      final email = FirebaseAuth.instance.currentUser?.email ?? '';

      _firestoreService
          .getUserStream(_currentUserId!)
          .first
          .then((userData) {
        if (userData != null && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PersonalInfoScreen(
                userData: userData,
                email: email,
              ),
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
            onTap: navigateToSettings, // 여기서 실행
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


  // --- 5. 회원 탈퇴 카드 (기존과 동일, 버튼 스타일 수정) ---
  Widget _buildDeleteAccountCard() {
    return _buildCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: kColorError, size: 24),
              SizedBox(width: 8),
              Text(
                '회원 탈퇴',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '계정을 삭제하면... 모든 데이터가 영구적으로 삭제...',
            style: TextStyle(fontSize: 14, color: kDarkRed),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kColorError, // primary -> backgroundColor
              foregroundColor: Colors.white, // onPrimary -> foregroundColor
              minimumSize: Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {},
            child: Text('생명의전화 1393'),
          ),
          SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFF3F4F6), // primary -> backgroundColor
              foregroundColor: kColorTextSubtitle, // onPrimary -> foregroundColor
              minimumSize: Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {},
            child: Text('회원 탈퇴'),
          ),
        ],
      ),
    );
  }

  // --- 헬퍼 위젯들 ---

  // 공통 카드 컨테이너 (기존과 동일)
  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kColorCardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  // 연락처 아이템 헬퍼
  Widget _buildContactItem({
    required String name,
    required String phone,
    required String tag,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    // 태그에 따라 아이콘과 색상 결정
    IconData icon;
    Color bgColor;
    Color iconColor;

    switch (tag) {
      case '가족':
        icon = Icons.family_restroom;
        bgColor = Color(0xFFFEE2E2);
        iconColor = Color(0xFFDC2626);
        break;
      case '친구':
        icon = Icons.people;
        bgColor = Color(0xFFD1FAE5);
        iconColor = Color(0xFF16A34A);
        break;
      case '상담사':
        icon = Icons.support_agent;
        bgColor = Color(0xFFFEF3C7);
        iconColor = Color(0xFFD97706);
        break;
      default:
        icon = Icons.person;
        bgColor = Color(0xFFE0E7FF);
        iconColor = Color(0xFF4338CA);
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
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '$phone · $tag',
                  style: TextStyle(color: kColorTextSubtitle),
                ),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.edit, color: kColorTextSubtitle, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.delete, color: kColorError, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  // 스위치 아이템 (기존과 동일)
  Widget _buildSwitchItem(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16)),
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

  // [!!] 7. 계정 메뉴 아이템 헬퍼 (수정됨)
  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String text,
    required VoidCallback onTap, // [!!] 8. onTap 파라미터 추가
  }) {
    // [!!] 9. InkWell로 감싸서 탭 가능하게 만듦
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0), // 물결 효과 범위
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(fontSize: 16))),
            Icon(Icons.arrow_forward_ios, size: 16, color: kColorTextSubtitle),
          ],
        ),
      ),
    );
  }
} // [!!] _ProfileTabState 끝

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
