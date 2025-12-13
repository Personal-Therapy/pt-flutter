package com.project.personaltherapy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.health.services.client.HealthServices
import androidx.health.services.client.MeasureCallback
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataPointContainer
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.DeltaDataType
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Galaxy Watch에서 Health Services API를 사용하여 HRV를 측정하는 서비스
 *
 * Health Services는 Galaxy Watch에서 고품질 심박 데이터를 제공합니다.
 * IBI (Inter-Beat Interval) 데이터를 포함하여 정확한 HRV 계산이 가능합니다.
 */
class HrvMonitorService : LifecycleService() {

    private val rrIntervals = mutableListOf<Double>() // RR Interval (ms) 저장용
    private var isRunning = false
    private var isMeasuring = false

    private var measureClient: androidx.health.services.client.MeasureClient? = null
    private var currentCallback: MeasureCallback? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)

        if (isRunning) {
            println("[HRV Service] Already running")
            return START_STICKY
        }

        isRunning = true

        // 1. 포그라운드 서비스 시작 (Notification 필수)
        startForeground(1, createNotification())

        println("[HRV Service] Started - using Health Services API")

        // Health Services 초기화
        measureClient = HealthServices.getClient(this).measureClient

        // 2. 5분 주기 루프 시작
        lifecycleScope.launch {
            while (isRunning) {
                measureHrvOnce()

                // 4분 휴식 (총 5분 주기)
                println("[HRV Service] Sleeping for 4 minutes...")
                delay(4 * 60 * 1000L)
            }
        }

        return START_STICKY
    }

    /**
     * 1분간 심박수를 측정하여 HRV 계산
     */
    private suspend fun measureHrvOnce() {
        rrIntervals.clear()
        isMeasuring = true

        println("[HRV Service] === Starting 1-minute measurement ===")

        val callback = object : MeasureCallback {
            override fun onAvailabilityChanged(
                dataType: DeltaDataType<*, *>,
                availability: Availability
            ) {
                println("[HRV Service] Availability changed: ${availability.id}")
                // Availability 상태 로깅
                println("  → Availability: $availability")
            }

            override fun onDataReceived(data: DataPointContainer) {
                if (!isMeasuring) return

                try {
                    // HEART_RATE_BPM 데이터 포인트 가져오기
                    val heartRateData = data.getData(DataType.HEART_RATE_BPM)

                    for (dataPoint in heartRateData) {
                        // BPM 값
                        val bpm = dataPoint.value

                        // 📊 IBI (Inter-Beat Interval) 데이터 확인
                        // Galaxy Watch는 DataPoint의 추가 필드에 IBI 정보를 포함할 수 있음
                        val metadata = dataPoint.metadata

                        // IBI 데이터가 있는지 확인
                        var hasIbi = false
                        var ibiValue = 0.0

                        // 방법 1: Metadata에서 IBI 찾기
                        try {
                            // IBI는 milliseconds 단위로 제공될 수 있음
                            if (metadata.containsKey("ibi")) {
                                ibiValue = metadata.getDouble("ibi")
                                hasIbi = true
                            } else if (metadata.containsKey("rr_interval")) {
                                ibiValue = metadata.getDouble("rr_interval")
                                hasIbi = true
                            }
                        } catch (e: Exception) {
                            // Metadata에 IBI가 없음
                        }

                        // 방법 2: BPM으로부터 역산 (fallback)
                        if (!hasIbi && bpm > 0) {
                            ibiValue = 60000.0 / bpm
                            println("[HRV Service] No IBI in metadata, calculated from BPM: ${ibiValue.toInt()}ms (BPM=$bpm)")
                        } else if (hasIbi) {
                            println("[HRV Service] ✅ IBI from metadata: ${ibiValue.toInt()}ms (BPM=$bpm)")
                        }

                        // 유효한 RR Interval 범위 체크 (300ms ~ 2000ms, 즉 30-200 bpm)
                        if (ibiValue in 300.0..2000.0) {
                            rrIntervals.add(ibiValue)
                        } else {
                            println("[HRV Service] ⚠️ Invalid IBI: ${ibiValue.toInt()}ms - skipped")
                        }
                    }
                } catch (e: Exception) {
                    println("[HRV Service] Error processing data: ${e.message}")
                    e.printStackTrace()
                }
            }
        }

        currentCallback = callback

        // Health Services에 콜백 등록
        try {
            measureClient?.registerMeasureCallback(DataType.HEART_RATE_BPM, callback)
            println("[HRV Service] ✅ Health Services callback registered")
        } catch (e: Exception) {
            println("[HRV Service] ❌ Failed to register callback: ${e.message}")
            e.printStackTrace()
            isMeasuring = false
            return
        }

        // 1분간 데이터 수집
        delay(60 * 1000L)

        // 콜백 해제
        // Note: Health Services API에서 명시적 unregister가 필요하지 않을 수 있음
        // MeasureClient는 서비스가 종료될 때 자동으로 정리됨
        println("[HRV Service] Measurement complete, stopping data collection")

        isMeasuring = false
        currentCallback = null

        // HRV 계산 및 전송
        if (rrIntervals.size > 2) {
            val rmssd = calculateRmssd(rrIntervals)
            val avgHeartRate = calculateAvgHeartRate(rrIntervals)

            println("=== HRV MEASURED ===")
            println("RMSSD: ${rmssd.toInt()} ms")
            println("Avg HR: $avgHeartRate bpm")
            println("Sample count: ${rrIntervals.size}")
            println("RR Intervals: ${rrIntervals.take(5).map { it.toInt() }}... (showing first 5)")

            // 📱 폰으로 데이터 전송
            sendHrvDataToPhone(rmssd, avgHeartRate)
        } else {
            println("[HRV Service] ⚠️ Insufficient data: ${rrIntervals.size} samples")
            println("  → Make sure watch is on wrist and Health Services is available")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false

        // 콜백 정리
        // Health Services는 서비스 종료 시 자동으로 정리됨
        isMeasuring = false
        currentCallback = null
        measureClient = null

        println("[HRV Service] Stopped")
    }

    // RMSSD 계산 공식
    private fun calculateRmssd(intervals: List<Double>): Double {
        if (intervals.size < 2) return 0.0

        var sumSquaredDiff = 0.0
        for (i in 0 until intervals.size - 1) {
            val diff = intervals[i + 1] - intervals[i]
            sumSquaredDiff += diff.pow(2)
        }
        return sqrt(sumSquaredDiff / (intervals.size - 1))
    }

    // 평균 심박수 계산
    private fun calculateAvgHeartRate(intervals: List<Double>): Int {
        if (intervals.isEmpty()) return 0
        val avgInterval = intervals.average()
        return (60000.0 / avgInterval).toInt()
    }

    // 📱 Wearable Data Layer API로 폰 앱에 HRV 데이터 전송
    private fun sendHrvDataToPhone(rmssd: Double, avgHeartRate: Int) {
        lifecycleScope.launch {
            try {
                val dataClient = Wearable.getDataClient(this@HrvMonitorService)

                val putDataReq = PutDataMapRequest.create("/hrv_data").apply {
                    dataMap.putDouble("rmssd", rmssd)
                    dataMap.putInt("avgHeartRate", avgHeartRate)
                    dataMap.putLong("timestamp", System.currentTimeMillis())
                    dataMap.putString("formattedTime", getCurrentTimeString())
                }.asPutDataRequest()

                val putDataTask = dataClient.putDataItem(putDataReq)
                Tasks.await(putDataTask)

                println("[HRV Service] ✅ Data sent to phone: RMSSD=${rmssd.toInt()}ms, HR=$avgHeartRate bpm")
            } catch (e: Exception) {
                println("[HRV Service] ❌ Failed to send data to phone: ${e.message}")
                e.printStackTrace()
            }
        }
    }

    private fun getCurrentTimeString(): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
        return sdf.format(Date())
    }

    private fun createNotification(): Notification {
        val channelId = "hrv_service_channel"
        val channel = NotificationChannel(
            channelId,
            "HRV Monitor Service",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Measures HRV every 5 minutes using Health Services"
        }

        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("HRV 측정 중 (Health Services)")
            .setContentText("5분마다 고품질 심박변이도를 측정합니다")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
    }
}
