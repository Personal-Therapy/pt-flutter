import 'package:flutter/material.dart';

class HealthResultPage extends StatelessWidget {
  const HealthResultPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 이 데이터는 추후 HealthConnectSection에서 전달받도록 변경 가능
    final data = {
      '평균 심박수': '75 bpm',
      '총 걸음 수': '6,200 걸음',
      '총 수면 시간': '7시간 10분',
      '건강 점수': '82점',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('측정 결과'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '나의 건강 상태 요약',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // 표 형태
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
              },
              children: data.entries.map((e) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(e.value),
                    ),
                  ],
                );
              }).toList(),
            ),

            const SizedBox(height: 30),
            const Text(
              '📊 건강 점수 변화 추이 (예시)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // 차트 대신 미리보기용 Container (나중에 Recharts/Charts로 대체 가능)
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('여기에 차트 표시 (추후 그래프 연결 예정)'),
            ),
          ],
        ),
      ),
    );
  }
}
