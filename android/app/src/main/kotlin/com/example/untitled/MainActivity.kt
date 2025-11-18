package com.example.untitled

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.time.Duration
import java.time.Instant

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.untitled/health_connect"
    private var healthClient: HealthConnectClient? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Flutter → Android 통신 채널 등록
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getHealthData" -> getHealthData(result)
                    else -> result.notImplemented()
                }
            }

        // Health Connect 클라이언트 생성
        try {
            healthClient = HealthConnectClient.getOrCreate(this)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /** -------------------------------------------------------------
     *   Health Connect에서 데이터 읽기 (걸음/심박/수면)
     * ------------------------------------------------------------- */
    private fun getHealthData(result: MethodChannel.Result) {
        GlobalScope.launch {
            val client = healthClient ?: return@launch

            val now = Instant.now()
            val start = now.minus(Duration.ofDays(1))   // 최근 24시간

            // 걸음 수 Read
            val stepsData = client.readRecords(
                ReadRecordsRequest(
                    StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, now)
                )
            )
            val steps = stepsData.records.sumOf { it.count }

            // 심박수
            val heartData = client.readRecords(
                ReadRecordsRequest(
                    HeartRateRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, now)
                )
            )
            val heartRates = heartData.records.flatMap { it.samples }.map { it.beatsPerMinute }
            val avgHeartRate = if (heartRates.isNotEmpty()) heartRates.average() else 0.0

            // 수면 데이터
            val sleepData = client.readRecords(
                ReadRecordsRequest(
                    SleepSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, now)
                )
            )
            val totalSleepMinutes = sleepData.records.sumOf {
                Duration.between(it.startTime, it.endTime).toMinutes()
            }

            // Flutter로 데이터 반환
            withContext(Dispatchers.Main) {
                result.success(
                    mapOf(
                        "steps" to steps,
                        "avgHeartRate" to avgHeartRate,
                        "sleepMinutes" to totalSleepMinutes
                    )
                )
            }
        }
    }
}
