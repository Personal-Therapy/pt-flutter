package com.project.personaltherapy

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {

    private lateinit var statusText: TextView
    private lateinit var startButton: Button
    private lateinit var stopButton: Button
    private lateinit var sensorTestButton: Button
    private lateinit var connectionTestButton: Button // [추가됨] 연결 테스트 버튼

    // 권한 요청 결과 처리
    private val permissionsLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val allGranted = permissions.values.all { it }
        if (allGranted) {
            statusText.text = "✅ 권한 허용됨\n서비스를 시작할 수 있습니다"
            startButton.isEnabled = true
        } else {
            statusText.text = "❌ 권한이 필요합니다\n설정에서 권한을 허용해주세요"
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // UI 생성
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(16, 16, 16, 16)
        }

        statusText = TextView(this).apply {
            text = "HRV Monitor\n\n권한을 확인 중..."
            textSize = 12f // 글씨 약간 줄임
            setPadding(0, 0, 0, 20)
        }

        startButton = Button(this).apply {
            text = "측정 시작 (Service)"
            isEnabled = false
            setOnClickListener { startHrvService() }
        }

        stopButton = Button(this).apply {
            text = "측정 중지"
            setOnClickListener { stopHrvService() }
        }

        // [추가됨] 폰으로 테스트 메시지 보내기 버튼
        connectionTestButton = Button(this).apply {
            text = "폰 연결 테스트 (Ping)"
            setOnClickListener { sendTestMessageToPhone() }
        }

        sensorTestButton = Button(this).apply {
            text = "센서 목록 확인"
            setOnClickListener {
                val intent = Intent(this@MainActivity, SensorTestActivity::class.java)
                startActivity(intent)
            }
        }

        // 뷰 추가 순서
        layout.addView(statusText)
        layout.addView(startButton)
        layout.addView(stopButton)
        layout.addView(connectionTestButton) // 버튼 추가
        layout.addView(sensorTestButton)

        // 화면 설정
        setContentView(layout)

        // 권한 확인 및 요청 실행
        checkAndRequestPermissions()
    }

    // [추가됨] 폰으로 텍스트 메시지 전송 함수
    private fun sendTestMessageToPhone() {
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                // 연결된 노드(핸드폰) 찾기
                val nodeClient = Wearable.getNodeClient(this@MainActivity)
                val nodes = Tasks.await(nodeClient.connectedNodes)

                if (nodes.isNotEmpty()) {
                    val messageClient = Wearable.getMessageClient(this@MainActivity)
                    var successCount = 0

                    for (node in nodes) {
                        // "/test_path" 경로로 "Hello Phone" 메시지 전송
                        val sendMessageTask = messageClient.sendMessage(
                            node.id,
                            "/test_path",
                            "Hello Phone (From Watch)".toByteArray()
                        )
                        Tasks.await(sendMessageTask)
                        successCount++
                    }

                    withContext(Dispatchers.Main) {
                        Toast.makeText(applicationContext, "전송 성공 ($successCount 기기)", Toast.LENGTH_SHORT).show()
                        statusText.text = "✅ 테스트 메시지 전송됨\n폰 로그를 확인하세요."
                    }
                } else {
                    withContext(Dispatchers.Main) {
                        statusText.text = "⚠️ 연결된 기기 없음\n블루투스 연결을 확인하세요."
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
                withContext(Dispatchers.Main) {
                    statusText.text = "❌ 전송 실패: ${e.message}"
                }
            }
        }
    }

    private fun checkAndRequestPermissions() {
        val requiredPermissions = mutableListOf(
            Manifest.permission.BODY_SENSORS,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requiredPermissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        val permissionsToRequest = requiredPermissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (permissionsToRequest.isEmpty()) {
            statusText.text = "✅ 준비 완료\n버튼을 눌러 시작하세요"
            startButton.isEnabled = true
        } else {
            statusText.text = "권한 요청 중..."
            permissionsLauncher.launch(permissionsToRequest.toTypedArray())
        }
    }

    private fun startHrvService() {
        val intent = Intent(this, HrvMonitorService::class.java)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }

        statusText.text = "✅ 측정 서비스 실행 중\n(5분 간격 측정)"
        startButton.isEnabled = false
        stopButton.isEnabled = true
    }

    private fun stopHrvService() {
        val intent = Intent(this, HrvMonitorService::class.java)
        stopService(intent)

        statusText.text = "⏹️ 서비스 중지됨"
        startButton.isEnabled = true
        stopButton.isEnabled = false
    }
}