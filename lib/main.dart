import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'healing_screen.dart';
// 1. 우리가 만든 로그인 화면 파일을 import 합니다.
// (파일 경로가 'lib/login_screen.dart'라고 가정)
import 'login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // .env 파일 읽기

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Therapy',

      // (디버그 배너 제거)
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        primarySwatch: Colors.blue,

        // (추가) 앱 전반의 기본 폰트를 Roboto로 설정 (추천)
        textTheme: GoogleFonts.robotoTextTheme(
          Theme.of(context).textTheme,
        ),
      ),

      // ▼▼▼ 이 부분이 핵심입니다 ▼▼▼
      // 앱의 'home' (첫 화면)을
      // 기본 'MyHomePage'가 아닌 'LoginScreen()'으로 지정합니다.
      home: const LoginScreen(),
    );
  }
}