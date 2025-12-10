import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:untitled/auth_wrapper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:untitled/firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file before initializing Firebase
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

      home: const AuthWrapper(),
    );
  }
}