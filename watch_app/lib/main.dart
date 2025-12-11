import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wear/wear.dart';
import 'package:watch_connectivity/watch_connectivity.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const WatchScreen(),
      theme: ThemeData.dark(), // 배터리 절약을 위해 다크 테마 권장
    );
  }
}

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  final _watch = WatchConnectivity();
  Timer? _timer;
  int _heartRate = 70;
  bool _isSending = false;

  void _toggleSending() {
    setState(() {
      _isSending = !_isSending;
    });

    if (_isSending) {
      // 1초마다 데이터 전송 (가짜 데이터)
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _heartRate = (_heartRate < 120) ? _heartRate + 1 : 70;
        });

        // 휴대폰으로 데이터 전송
        _watch.updateApplicationContext({
          'heartRate': _heartRate,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      });
    } else {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WatchShape(
      builder: (context, shape, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, color: Colors.red, size: 32),
                const SizedBox(height: 8),
                Text(
                  '$_heartRate BPM',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _toggleSending,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSending ? Colors.red : Colors.green,
                  ),
                  child: Text(_isSending ? "중지" : "측정 시작"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}