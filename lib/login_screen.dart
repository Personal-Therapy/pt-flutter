import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:untitled/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:untitled/services/firestore_service.dart';
import 'forgot_password_screen.dart';

// --- Color Definitions ---
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
const Color kColorError = Color(0xFFEF4444); // 👈 [추가] 에러 메시지 색상
// ---

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _stayLoggedIn = false;
  bool _passwordVisible = false;

  // --- ▼ [추가] 컨트롤러 및 상태 변수 ▼ ---
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false; // 로그인 시도 중 로딩 상태
  String? _errorMessage; // 로그인 실패 시 에러 메시지

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  // --- ▲ [추가] 컨트롤러 및 상태 변수 ▲ ---

  // --- ▼ [추가] 로그인 로직 함수 ▼ ---
  Future<void> _login() async {
    // 1. 로딩 시작 및 이전 에러 메시지 초기화
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // --- (B) 미래의 Firebase 인증 로직 (참고용 주석) ---
    // (이 로직을 사용하려면 pubspec.yaml에 'firebase_auth' 추가 및
    // import 'package:firebase_auth/firebase_auth.dart'; 가 필요합니다.)

    try {
      // 1. 컨트롤러에서 이메일/비밀번호 값 가져오기 (양쪽 공백 제거)
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // 2. (선택) 간단한 유효성 검사
      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = "이메일과 비밀번호를 모두 입력해주세요.";
          _isLoading = false;
        });
        return; // 로그인 함수 종료
      }

      // 3. Firebase Auth로 로그인 시도
      // (FirebaseAuth.instance는 미리 초기화되어 있어야 함)
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 4. 로그인 성공 (성공 시 이 try 블록이 끝까지 실행됨)
      print("Firebase 로그인 성공: ${userCredential.user?.uid}");


    } on FirebaseAuthException catch (e) {
      // 5. Firebase 인증 에러 처리
      print("Firebase 로그인 오류: ${e.code}");
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        _errorMessage = '이메일 또는 비밀번호가 일치하지 않습니다.';
      } else if (e.code == 'invalid-email') {
        _errorMessage = '유효하지 않은 이메일 형식입니다.';
      } else {
        _errorMessage = '로그인에 실패했습니다. (코드: ${e.code})';
      }

      setState(() {
        _isLoading = false;
      });
      return; // 에러 발생 시 함수 종료

    } catch (e) {
      // 6. 기타 예외 처리
      print("알 수 없는 오류: $e");
      _errorMessage = '알 수 없는 오류가 발생했습니다.';
      setState(() {
        _isLoading = false;
      });
      return; // 에러 발생 시 함수 종료
    }

    // 3. (A) 또는 (B)가 성공적으로 완료된 후 실행
    setState(() {
      _isLoading = false;
    });

    // (중요) 비동기 작업 후에는 'mounted' 확인을 해주는 것이 안전합니다.
    // AuthWrapper가 화면 전환을 담당하므로 여기서 직접적인 화면 이동은 제거합니다.
    // if (mounted) {
    //   Navigator.pushReplacement(
    //     context,
    //     MaterialPageRoute(builder: (context) => const MainScreen()),
    //   );
    // }
  }
  // --- ▲ [추가] 로그인 로직 함수 ▲ ---

  // --- ▼ [추가] 구글 로그인 함수 ▼ ---
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // 5. Firestore에 사용자 정보 저장/업데이트
      if (userCredential.user != null) {
        await _firestoreService.upsertGoogleUser(userCredential.user!);
      }

      print("Google 로그인 성공 및 Firestore 업데이트 완료");

    } catch (e) {
      print("Google 로그인 오류: $e");
      setState(() {
        _errorMessage = 'Google 로그인에 실패했습니다. 다시 시도해주세요.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }
  // --- ▲ [추가] 구글 로그인 함수 ▲ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kColorBgStart, kColorBgEnd],
                stops: [0.0, 1.0],
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32.0),
                Text(
                  'Personal Therapy',
                  style: GoogleFonts.pacifico(
                    fontSize: 20,
                    color: kColorTextTitle,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 32.0),
                Text(
                  '다시 만나서 반가워요!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: kColorTextTitle,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  '마음의 건강을 함께 돌봐드릴게요',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: kColorTextSubtitle,
                  ),
                ),
                const SizedBox(height: 32.0),
                _buildLoginFormCard(),
                const SizedBox(height: 24.0),
                _buildDivider(),
                const SizedBox(height: 24.0),
                _buildGoogleLoginButton(),
                const SizedBox(height: 24.0),
                TextButton(
                  onPressed: _isLoading ? null : () { // 👈 로딩 중 비활성화
                    // 게스트 로그인 로직은 FirebaseAuth가 아닌 경우에만 의미가 있으므로,
                    // Firebase 연동 후에는 이 버튼의 기능은 변경되거나 제거될 수 있습니다.
                    // 현재는 아무 동작도 하지 않거나, 다른 게스트용 진입점을 고려해야 합니다.
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(builder: (context) => const MainScreen()),
                    // );
                  },
                  child: Text(
                    '게스트로 둘러보기',
                    style: GoogleFonts.roboto(
                      color: kColorTextSubtitle,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '아직 계정이 없으신가요? ',
                      style: GoogleFonts.roboto(
                        color: kColorTextSubtitle,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignUpScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '회원가입',
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
        ],
      ),
    );
  }

  Widget _buildLoginFormCard() {
    return Card(
      elevation: 2.0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // 👈 에러 메시지 중앙 정렬용
          children: [
            Text(
              '이메일',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kColorTextLabel,
              ),
            ),
            const SizedBox(height: 8.0),
            TextField(
              controller: _emailController, // 👈 [수정] 컨트롤러 연결
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(hintText: '이메일을 입력하세요'),
            ),
            const SizedBox(height: 16.0),
            Text(
              '비밀번호',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kColorTextLabel,
              ),
            ),
            const SizedBox(height: 8.0),
            TextField(
              controller: _passwordController, // 👈 [수정] 컨트롤러 연결
              obscureText: !_passwordVisible,
              decoration: _inputDecoration(
                hintText: '비밀번호를 입력하세요',
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: kColorTextHint,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: _isLoading ? null : () { // 👈 로딩 중 비활성화
                    setState(() {
                      _stayLoggedIn = !_stayLoggedIn;
                    });
                  },
                  child: Row(
                    children: [
                      Checkbox(
                        value: _stayLoggedIn,
                        onChanged: _isLoading ? null : (value) { // 👈 로딩 중 비활성화
                          setState(() {
                            _stayLoggedIn = value ?? false;
                          });
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        '로그인 상태 유지',
                        style: GoogleFonts.roboto(
                          color: kColorTextSubtitle,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                    );
                  },
                  child: Text(
                    '비밀번호 찾기',
                    style: GoogleFonts.roboto(
                      color: kColorTextLink,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _isLoading ? null : _login, // 👈 [수정] 로딩 중 비활성화 및 _login 함수 연결
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorBtnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                minimumSize: const Size(double.infinity, 45),
              ),
              child: _isLoading // 👈 [수정] 로딩 중일 때 로딩 아이콘 표시
                  ? const SizedBox(
                height: 24.0,
                width: 24.0,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              )
                  : Text(
                '로그인',
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // --- ▼ [추가] 에러 메시지 표시 ▼ ---
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.roboto(
                    color: kColorError,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            // --- ▲ [추가] 에러 메시지 표시 ▲ ---
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: kColorBtnGoogleBorder, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            '또는',
            style: GoogleFonts.roboto(
              color: kColorTextDivider,
              fontSize: 14,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: kColorBtnGoogleBorder, thickness: 1),
        ),
      ],
    );
  }

  Widget _buildGoogleLoginButton() {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _signInWithGoogle, // 👈 구글 로그인 함수 연결
      icon: Image.asset(
        'assets/images/google_logo.png', // This asset needs to be added to pubspec.yaml
        height: 24.0,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline, color: kColorTextSubtitle),
      ),
      label: Text(
        'Google로 로그인',
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
        side: const BorderSide(
          color: kColorBtnGoogleBorder,
        ),
      ),
    );
  }

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