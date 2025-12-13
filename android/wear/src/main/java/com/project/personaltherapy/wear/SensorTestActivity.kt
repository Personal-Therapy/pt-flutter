package com.project.personaltherapy

import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Bundle
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

/**
 * 워치에서 사용 가능한 센서 목록을 확인하는 테스트 액티비티
 */
class SensorTestActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        val sensors = sensorManager.getSensorList(Sensor.TYPE_ALL)

        val textView = TextView(this).apply {
            text = buildSensorList(sensors)
            textSize = 12f
            setPadding(16, 16, 16, 16)
        }

        val scrollView = ScrollView(this).apply {
            addView(textView)
        }

        setContentView(scrollView)
    }

    private fun buildSensorList(sensors: List<Sensor>): String {
        val sb = StringBuilder("=== Available Sensors ===\n\n")

        // 중요한 센서들 먼저 체크
        val importantTypes = listOf(
            Sensor.TYPE_HEART_RATE,
            Sensor.TYPE_HEART_BEAT,
            65572 // Samsung PPG 센서 (TYPE_PPG)
        )

        sb.append("★ Important for HRV:\n")
        importantTypes.forEach { type ->
            val sensor = sensors.find { it.type == type }
            if (sensor != null) {
                sb.append("✅ ${sensor.name}\n")
                sb.append("   Type: ${sensor.type}\n")
                sb.append("   Vendor: ${sensor.vendor}\n\n")
            } else {
                sb.append("❌ Type $type not found\n\n")
            }
        }

        sb.append("\n=== All Sensors ===\n\n")
        sensors.forEach { sensor ->
            sb.append("${sensor.name}\n")
            sb.append("  Type: ${sensor.type}\n")
            sb.append("  Vendor: ${sensor.vendor}\n")
            sb.append("  Max Range: ${sensor.maximumRange}\n")
            sb.append("  Resolution: ${sensor.resolution}\n\n")
        }

        return sb.toString()
    }
}
