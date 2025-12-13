package com.project.personaltherapy

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.records.metadata.DataOrigin
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneOffset

class WearDataListenerService : WearableListenerService() {

    companion object {
        private const val TAG = "WearDataListener"
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        // 헬스 커넥트 클라이언트 생성 (Context 필요)
        val healthConnectClient = HealthConnectClient.getOrCreate(applicationContext)

        for (event in dataEvents) {
            if (event.type == DataEvent.TYPE_CHANGED) {
                val item = event.dataItem
                if (item.uri.path == "/hrv_data") {
                    val dataMap = DataMapItem.fromDataItem(item).dataMap

                    val rmssd = dataMap.getDouble("rmssd")
                    val timestamp = dataMap.getLong("timestamp")

                    Log.d(TAG, "⌚ 워치 데이터 수신: RMSSD=$rmssd, Time=$timestamp")

                    // ✅ 헬스 커넥트에 저장 (비동기 실행)
                    saveToHealthConnect(healthConnectClient, rmssd, timestamp)
                }
            }
        }
    }

    private fun saveToHealthConnect(client: HealthConnectClient, rmssd: Double, timestamp: Long) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // 1. 기록 객체 생성
                val record = HeartRateVariabilityRmssdRecord(
                    time = Instant.ofEpochMilli(timestamp),
                    zoneOffset = ZoneOffset.systemDefault().rules.getOffset(Instant.now()),
                    heartRateVariabilityMillis = rmssd,
                    // ✅ 정답: 생성자 대신 manualEntry() 사용
                    metadata = androidx.health.connect.client.records.metadata.Metadata.manualEntry()
                )

                // 2. 헬스 커넥트에 쓰기 (Insert)
                client.insertRecords(listOf(record))
                
                Log.d(TAG, "✅ 헬스 커넥트 저장 완료! (RMSSD: $rmssd)")

            } catch (e: Exception) {
                // 권한이 없거나, 다른 이유로 실패했을 때
                Log.e(TAG, "❌ 헬스 커넥트 저장 실패: ${e.message}")
                // 실패 원인이 '권한 없음'이라면 사용자에게 앱을 켜달라고 알림을 띄우는 것도 방법
            }
        }
    }
}