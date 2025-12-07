import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:untitled/services/firestore_service.dart';

// --- 색상 정의 (에러 색상 kColorError 추가) ---
const Color kColorBgStart = Color(0xFFEFF6FF);
const Color kColorBgEnd = Color(0xFFFAF5FF);
const Color kColorTextTitle = Color(0xFF1F2937);
const Color kColorTextSubtitle = Color(0xFF4B5563);
const Color kColorTextLabel = Color(0xFF374151);
const Color kColorTextHint = Color(0xFF9CA3AF);
const Color kColorTextLink = Color(0xFF2563EB);
const Color kColorTextDivider = Color(0xFF6B7280);
const Color kColorBtnPrimary = Color(0xFF2563EB);
const Color kColorBtnGoogleBorder = Color(0xFFD1D5DB);
const Color kColorEditTextBg = Color(0xFFF3F4F6);
const Color kColorError = Color(0xFFEF4444); // 👈 RTF 기반 에러 색상
// ---

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {
  // 폼 필드 값을 제어하기 위한 컨트롤러
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // UI 상태 변수
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  // 에러 메시지를 저장할 상태 변수
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _termsError;

  // 컨트롤러 리소스 해제
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- 1. 유효성 검사 함수 ---
  Future<void> _validateAndSignUp() async {
    // 0. 모든 에러 메시지를 초기화 및 로딩 시작
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _termsError = null;
      _isLoading = true; // Start loading
    });

    bool isValid = true;
    final name = _nameController.text;
    final email = _emailController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // 1. 이름 검사 (DIV-22)
    if (name.isEmpty) {
      setState(() => _nameError = "이름을 입력해주세요");
      isValid = false;
    }

    // 2. 이메일 검사 (DIV-32)
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = "유효한 이메일을 입력해주세요");
      isValid = false;
    }

    // 3. 비밀번호 검사 (DIV-42) - 8자 이상
    if (password.length < 8) {
      setState(() => _passwordError = "비밀번호는 8자 이상이어야 합니다.");
      isValid = false;
    }
    // [보안 강화] 영문/숫자/특수문자 포함 여부 검사 (정규식 사용)
    else if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[!@#$%^&*()_+])[A-Za-z\d!@#$%^&*()_+]{8,}$').hasMatch(password)) {
      setState(() => _passwordError = "비밀번호는 영문, 숫자, 특수문자를 포함해야 합니다.");
      isValid = false;
    }

    // 4. 비밀번호 확인 검사 (DIV-52)
    if (password != confirmPassword) {
      setState(() => _confirmPasswordError = "비밀번호가 일치하지 않습니다");
      isValid = false;
    }

    // 5. 약관 동의 검사 (DIV-63)
    if (!_agreeToTerms) {
      setState(() => _termsError = "약관에 동의해주세요");
      isValid = false;
    }

    // 모든 검사 통과 시 Firebase 회원가입 시도
    if (isValid) {
      try {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // 회원가입 성공 후 추가적인 사용자 정보 저장 (예: 이름)
        if (userCredential.user != null) {
          await FirestoreService().addUser(
            userCredential.user!.uid,
            name, // User's name from the input field
            email,
          );
        }

        print("Firebase 회원가입 성공: ${userCredential.user?.uid}");

        // 회원가입 성공 시 이전 화면 (로그인 화면)으로 돌아가기
        if (mounted) {
          Navigator.pop(context);
        }

      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          setState(() => _passwordError = '비밀번호가 너무 취약합니다.');
        } else if (e.code == 'email-already-in-use') {
          setState(() => _emailError = '이미 사용 중인 이메일입니다.');
        } else if (e.code == 'invalid-email') {
          setState(() => _emailError = '유효하지 않은 이메일 형식입니다.');
        } else {
          setState(() => _emailError = '회원가입에 실패했습니다: ${e.message}');
        }
      } catch (e) {
        setState(() => _emailError = '알 수 없는 오류가 발생했습니다: $e');
      }
    }

    setState(() {
      _isLoading = false; // Stop loading
    });
  }

  // --- 구글 로그인 함수 ---
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Google Sign In 시작 (웹 클라이언트 ID 명시)
      final GoogleSignInAccount? googleUser = await GoogleSignIn(
        scopes: ['email'],
        serverClientId: '830768959120-0hlmi87bb8bmhd1blut0jr0tqp16k7gq.apps.googleusercontent.com',
      ).signIn();

      if (googleUser == null) {
        // 사용자가 로그인을 취소함
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 2. Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Firebase 인증 자격증명 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Firebase로 로그인
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // 5. Firestore에 사용자 정보 저장 (처음 가입하는 경우)
      if (userCredential.user != null) {
        final user = userCredential.user!;
        await FirestoreService().addUser(
          user.uid,
          user.displayName ?? 'Google 사용자',
          user.email ?? '',
        );
      }

      print("Google 로그인 성공");

      // 로그인 성공 시 이전 화면으로 돌아가기
      if (mounted) {
        Navigator.pop(context);
      }

    } catch (e) {
      print("Google 로그인 오류: $e");
      setState(() {
        _emailError = 'Google 로그인에 실패했습니다. 다시 시도해주세요.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kColorBgStart, kColorBgEnd],
            stops: [0.0, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 96.0),
              Text(
                '계정 만들기',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kColorTextTitle,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                '회원가입을 위해 정보를 입력해주세요',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: kColorTextSubtitle,
                ),
              ),
              const SizedBox(height: 32.0),

              // --- 2. 회원가입 폼 카드 (수정됨) ---
              _buildSignUpFormCard(),

              const SizedBox(height: 24.0),
              _buildDivider(),
              const SizedBox(height: 24.0),
              _buildGoogleLoginButton(),
              const SizedBox(height: 32.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '이미 계정이 있으신가요? ',
                    style: GoogleFonts.roboto(
                      color: kColorTextSubtitle,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context), // 👈 로딩 중 비활성화
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '로그인',
                      style: GoogleFonts.roboto(
                        color: kColorTextLink,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32.0),
            ],
          ),
        ),
      ),
    );
  }

  // --- 위젯 분리 (수정됨) ---

  // 회원가입 폼 카드
  Widget _buildSignUpFormCard() {
    return Card(
      elevation: 2.0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이름
            _buildTextField(
              label: '이름',
              hint: '이름을 입력하세요',
              controller: _nameController,
              errorText: _nameError, // 👈 에러 상태 전달
            ),

            // 이메일
            _buildTextField(
              label: '이메일',
              hint: '이메일을 입력하세요',
              controller: _emailController,
              errorText: _emailError, // 👈 에러 상태 전달
              keyboardType: TextInputType.emailAddress,
            ),

            // 비밀번호
            _buildTextField(
              label: '비밀번호',
              hint: '비밀번호를 입력하세요',
              controller: _passwordController,
              errorText: _passwordError, // 👈 에러 상태 전달
              isPassword: true,
              isVisible: _passwordVisible,
              onToggleVisibility: () {
                setState(() => _passwordVisible = !_passwordVisible);
              },
            ),

            // 비밀번호 확인
            _buildTextField(
              label: '비밀번호 확인',
              hint: '비밀번호를 다시 입력하세요',
              controller: _confirmPasswordController,
              errorText: _confirmPasswordError, // 👈 에러 상태 전달
              isPassword: true,
              isVisible: _confirmPasswordVisible,
              onToggleVisibility: () {
                setState(() => _confirmPasswordVisible = !_confirmPasswordVisible);
              },
            ),

            // 약관 동의
            Column( // 에러 메시지를 표시하기 위해 Column으로 감싸기
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() => _agreeToTerms = !_agreeToTerms);
                  },
                  child: Row(
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (value) {
                          setState(() => _agreeToTerms = value ?? false);
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Text(
                          '이용약관 및 개인정보 정책에 동의합니다.',
                          style: GoogleFonts.roboto(
                            color: kColorTextSubtitle,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 약관 동의 에러 메시지 (DIV-63)
                if (_termsError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 12.0),
                    child: Text(
                      _termsError!,
                      style: GoogleFonts.roboto(
                        color: kColorError,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24.0),

            // 회원가입 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : _validateAndSignUp, // 👈 로딩 중 비활성화 및 함수 연결
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorBtnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                minimumSize: const Size(double.infinity, 45),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 24.0,
                width: 24.0,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              )
                  : Text(
                '회원가입',
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 폼 필드 공통 위젯 (에러 메시지 표시 기능 추가)
  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller, // 👈 컨트롤러 받기
    String? errorText, // 👈 에러 메시지 받기
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      // 각 필드 그룹의 하단 간격을 16.0으로 통일
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: kColorTextLabel,
            ),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: controller, // 👈 컨트롤러 연결
            keyboardType: keyboardType,
            obscureText: isPassword && !isVisible,
            decoration: _inputDecoration(
              hintText: hint,
              suffixIcon: isPassword
                  ? IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  color: kColorTextHint,
                ),
                onPressed: onToggleVisibility,
              )
                  : null,
            ),
          ),
          // --- 3. 에러 메시지를 조건부로 표시 ---
          // errorText가 null이 아니면 (에러가 있으면) 이 위젯을 그림
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0), // RTF: padding-top: 4px
              child: Text(
                errorText,
                style: GoogleFonts.roboto(
                  color: kColorError, // RTF: color: #EF4444
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // '또는' 구분선 위젯 (로그인과 동일)
  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: kColorBtnGoogleBorder, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '또는',
            style: GoogleFonts.roboto(color: kColorTextDivider, fontSize: 14),
          ),
        ),
        const Expanded(child: Divider(color: kColorBtnGoogleBorder, thickness: 1)),
      ],
    );
  }

            // Google 로그인 버튼 위젯 (로그인과 동일)
    Widget _buildGoogleLoginButton() {
      return OutlinedButton.icon(
        onPressed: _isLoading ? null : _signInWithGoogle,
        icon: Image.asset(
        'assets/images/google_logo.png',
        height: 24.0,
      ),
      label: Text(
        'Google로 계속하기',
        style: GoogleFonts.roboto(
          color: kColorTextLabel,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 47),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        side: const BorderSide(color: kColorBtnGoogleBorder),
      ),
    );
  }

  // TextField 공통 디자인 (로그인과 동일)
  InputDecoration _inputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.roboto(color: kColorTextHint, fontSize: 14),
      filled: true,
      fillColor: kColorEditTextBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffixIcon,
    );
  }
}