import 'package:flutter/material.dart';
import 'package:untitled/main_screen.dart'; // Import main_screen.dart for shared color constants
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// profile_tab.dart 또는 main.dart에 정의된 색상 상수들을 가져옵니다.
// (일관성을 위해 profile_tab.dart의 상수들을 그대로 사용합니다)
// const Color kPageBackground = Color(0xFFF9FAFB);
// const Color kCardBackground = Color(0xFFFFFFFF);
// const Color kColorBtnPrimary = Color(0xFF2563EB);
// const Color kColorTextTitle = Color(0xFF111827);
// const Color kColorTextSubtitle = Color(0xFF6B7280);
const Color kTextHint = Color(0xFF9CA3AF); // This seems unique to this file
// const Color kColorEditTextBg = Color(0xFFF3F4F6);
// const Color kColorBtnPrimary = Color(0xFF2563EB);

/// 개인정보 수정 페이지 (개인정보 설정.rtf 기반)
class PersonalInfoScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String email;


  const PersonalInfoScreen({
    super.key,
    required this.userData,
    required this.email,
  });

  @override
  PersonalInfoScreenState createState() => PersonalInfoScreenState();
}

class PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  // (예시) 입력 필드를 위한 컨트롤러
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  // [!!] 1. 비밀번호 변경 로직을 위한 상태 변수 추가
  bool _isChangingPassword = false;

  // [!!] 2. 새 비밀번호 필드를 위한 컨트롤러 추가
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _birthController;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.userData['name'] ?? '',
    );

    _phoneController = TextEditingController(
      text: widget.userData['phone'] ?? '',
    );
    _birthController = TextEditingController(
      text: widget.userData['birth'] ?? '',
    );

    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _birthController.dispose();

    // [!!] 4. 비밀번호 컨트롤러 dispose
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBgStart,
      // RTF 'DIV-3' (padding: 80px 24px 96px)를 위해 앱바를 투명하게 띄움
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // 'DIV-147' (AppBar)
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: kColorTextTitle,
            size: 20, // 'Icon-144'
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '개인정보 수정', // 'SPAN-151'
          style: TextStyle(
            color: kColorTextTitle,
            fontSize: 18,
            fontWeight: FontWeight.w600, // font-weight: 600
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        // 'height: 1735px'를 반영, 'padding: 80px 24px 96px' 적용
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 96),
        child: Column(
          children: [
            // 'DIV-4' (프로필 이미지 카드)
            _buildProfileImageEditor(),
            SizedBox(height: 24),

            // 'DIV-20' (이름)
            _buildInfoRowWithButton(
              label: '이름', // 'H3-22'
              controller: _nameController, // 'INPUT-25'
              buttonText: '변경', // 'BUTTON-31'
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({
                  'name': _nameController.text.trim(),
                });

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('이름이 변경되었습니다')),
                );
              },

            ),
            SizedBox(height: 16),

            // 'DIV-35' (이메일 - readonly)
            _buildInfoRowReadOnly(
              label: '이메일', // 'H3-37'
              value: widget.email, // 'INPUT-40'
            ),
            SizedBox(height: 16),

            // 'DIV-51' (전화번호)
            _buildInfoRowWithButton(
              label: '전화번호', // 'H3-53'
              controller: _phoneController, // 'INPUT-56'
              buttonText: '변경', // 'BUTTON-62'
              keyboardType: TextInputType.phone,
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({
                  'phone': _phoneController.text.trim(),
                });

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('전화번호가 변경되었습니다')),
                );
              },

            ),
            SizedBox(height: 16),

            // 'DIV-66' (생년월일 - readonly)
          _buildSettingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '생년월일',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _birthController,
                        readOnly: true,
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate:
                            DateTime.tryParse(_birthController.text) ??
                                DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            locale: const Locale('ko'),
                          );

                          if (pickedDate == null) return;

                          final formatted =
                              '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';

                          setState(() {
                            _birthController.text = formatted;
                          });
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: kColorEditTextBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .update({
                          'birth': _birthController.text.trim(),
                        });

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('생년월일이 변경되었습니다')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kColorBtnPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('변경'),
                    ),
                  ],
                ),
              ],
            ),
          ),


          SizedBox(height: 16),

            // [!!] 5. 'DIV-97' (비밀번호) -> _buildPasswordSection으로 변경
            _buildPasswordSection(),

            SizedBox(height: 24),

            // 'DIV-115' (소셜 계정)
            _buildSocialConnectCard(),
          ],
        ),
      ),
    );
  }

  // 'DIV-4' (프로필 이미지 위젯)
  Widget _buildProfileImageEditor() {
    return Column(
      children: [
        // 'DIV-6' (128px 원)
        CircleAvatar(
          radius: 64, // 128px / 2
          backgroundColor: Color(0xFFDBEAFE),
          child: Icon(Icons.person, size: 80, color: kColorBtnPrimary),
          // TODO: 실제 이미지 적용
        ),
        SizedBox(height: 16),
        Text(
          '이미지 변경', // 'P-16'
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: kColorBtnPrimary,
          ),
        ),
      ],
    );
  }

  // 'DIV-20', 'DIV-51' (변경 버튼이 있는 입력 필드)
  Widget _buildInfoRowWithButton({
    required String label,
    required TextEditingController controller,
    required String buttonText,
    required VoidCallback onPressed,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: kColorEditTextBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kColorBtnPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(buttonText),
              ),
            ],
          ),
        ],
      ),
    );
  }


  // 'DIV-35', 'DIV-66' (읽기 전용 필드)
  Widget _buildInfoRowReadOnly({required String label, required String value}) {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), // 'H3'
          SizedBox(height: 12),
          Container( // 'INPUT' (Disabled)
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kColorEditTextBg, // background: #F3F4F6
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: kColorTextSubtitle), // 읽기 전용 텍스트
            ),
          ),
        ],
      ),
    );
  }

  // [!!] 6. 비밀번호 섹션 위젯 (수정됨)
  Widget _buildPasswordSection() {
    return _buildSettingCard(
      // [!!] 7. 상태에 따라 다른 위젯을 보여줌
      child: _isChangingPassword
          ? _buildPasswordEditView() // 비밀번호 변경 뷰
          : _buildPasswordReadOnlyView(), // 기본 뷰
    );
  }

  // [!!] 8. 기본 비밀번호 뷰 (기존 _buildPasswordRow)
  Widget _buildPasswordReadOnlyView() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('비밀번호', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), // 'H3-99'
            SizedBox(height: 4),
            Text('••••••••', style: TextStyle(fontSize: 16, color: kColorTextSubtitle)), // 'P-105'
          ],
        ),
        OutlinedButton( // 'BUTTON-108'
          onPressed: () {
            // [!!] 9. '변경' 버튼 클릭 시 상태 변경
            setState(() {
              _isChangingPassword = true;
            });
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: kColorBtnPrimary,
            side: BorderSide(color: kColorEditTextBg),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('변경'),
        ),
      ],
    );
  }

  // [!!] 10. 비밀번호 변경 뷰 (새로 추가)
  Widget _buildPasswordEditView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('비밀번호 변경', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        SizedBox(height: 16),
        _buildPasswordTextField(
          controller: _currentPasswordController,
          hintText: '현재 비밀번호',
        ),
        SizedBox(height: 12),
        _buildPasswordTextField(
          controller: _newPasswordController,
          hintText: '새 비밀번호',
        ),
        SizedBox(height: 12),
        _buildPasswordTextField(
          controller: _confirmPasswordController,
          hintText: '새 비밀번호 확인',
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  // [!!] 11. '취소' 버튼 클릭 시 상태 변경
                  setState(() {
                    _isChangingPassword = false;
                  });
                  // 컨트롤러 초기화 (선택 사항)
                  _currentPasswordController.clear();
                  _newPasswordController.clear();
                  _confirmPasswordController.clear();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: kColorTextSubtitle,
                  side: BorderSide(color: kColorEditTextBg),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('취소'),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  if (_newPasswordController.text != _confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('비밀번호가 일치하지 않습니다')),
                    );
                    return;
                  }

                  try {
                    final user = FirebaseAuth.instance.currentUser!;
                    final providers = user.providerData.map((e) => e.providerId).toList();

                    if (!providers.contains('password')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('소셜 로그인 계정은 비밀번호를 변경할 수 없습니다')),
                      );
                      return;
                    }
                    final email = user.email!;

                    // ✅ 1. 재인증
                    final credential = EmailAuthProvider.credential(
                      email: email,
                      password: _currentPasswordController.text,
                    );

                    await user.reauthenticateWithCredential(credential);

                    // ✅ 2. 비밀번호 변경
                    await user.updatePassword(_newPasswordController.text);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('비밀번호가 변경되었습니다')),
                    );

                    setState(() {
                      _isChangingPassword = false;
                    });

                    _currentPasswordController.clear();
                    _newPasswordController.clear();
                    _confirmPasswordController.clear();
                  } on FirebaseAuthException catch (e) {
                    String message;

                    if (e.code == 'wrong-password' ||
                        e.code == 'invalid-credential' ||
                        e.code == 'user-mismatch') {
                      message = '현재 비밀번호가 일치하지 않습니다';
                    } else if (e.code == 'weak-password') {
                      message = '새 비밀번호가 너무 약합니다';
                    } else if (e.code == 'requires-recent-login') {
                      message = '보안을 위해 다시 로그인해 주세요';
                    } else {
                      message = '비밀번호 변경에 실패했습니다';
                    }

                    debugPrint('FirebaseAuthException code: ${e.code}');

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  }


                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: kColorBtnPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('저장'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // [!!] 13. 비밀번호 입력 필드 헬퍼 (새로 추가)
  Widget _buildPasswordTextField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
      obscureText: true, // 비밀번호 숨기기
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 16, color: kTextHint),
        filled: true,
        fillColor: kColorEditTextBg,
        border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(8)
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // 'DIV-115' (소셜 계정 카드)
  Widget _buildSocialConnectCard() {
    return _buildSettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('연결된 소셜 계정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), // 'H3-117'
          SizedBox(height: 16),
          // 'DIV-120' (Google)
          _buildSocialRow(
            icon: Icons.ac_unit, // TODO: Google 아이콘으로 교체
            iconColor: Colors.red,
            text: 'Google 계정',
            isConnected: true,
          ),
          Divider(height: 24),
          // 'DIV-128' (Kakao)
          _buildSocialRow(
            icon: Icons.chat_bubble, // TODO: Kakao 아이콘으로 교체
            iconColor: Colors.yellow,
            text: '카카오 계정',
            isConnected: false,
          ),
        ],
      ),
    );
  }

  // 소셜 계정 연결 Row 헬퍼
  Widget _buildSocialRow({
    required IconData icon,
    required Color iconColor,
    required String text,
    required bool isConnected,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        SizedBox(width: 12),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 16, color: kColorTextTitle)),
        ),
        Text(
          isConnected ? '연결됨' : '연결하기', // 'P-126', 'P-134'
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isConnected ? kColorTextSubtitle : kColorBtnPrimary,
          ),
        ),
      ],
    );
  }

  // 공통 카드 컨테이너
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
}