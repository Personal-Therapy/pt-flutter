package com.example.untitled

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 아주 간단한 설명 화면
        val textView = TextView(this).apply {
            text = "이 앱은 건강 데이터를 기반으로 한 맞춤형 심리 케어 기능을 제공합니다.\n" +
                    "심박수, 걸음 수, 수면 데이터는 스트레스 지수 계산에 사용됩니다."
            textSize = 16f
            setPadding(40, 100, 40, 100)
        }

        setContentView(textView)
    }
}
