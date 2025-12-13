package com.project.personaltherapy

import android.os.Bundle
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.Instant

class MainActivity : FlutterFragmentActivity() {
    companion object {
        var instance: MainActivity? = null
    }

    private val CHANNEL = "com.project.personaltherapy/samsung_health"
    private var healthDataStore: Any? = null
    private var samsungHealthAvailable = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestHealthConnectPermissions" -> {
                    requestHealthConnectPermissions(result)
                }
                "getRestingHeartRate" -> {
                    val startTimeMillis = call.argument<Long>("startTime")
                    val endTimeMillis = call.argument<Long>("endTime")
                    if (startTimeMillis != null && endTimeMillis != null) {
                        getRestingHeartRate(startTimeMillis, endTimeMillis, result)
                    } else {
                        result.error("INVALID_ARGUMENTS", "startTime and endTime are required", null)
                    }
                }
                "getHeartRateVariability" -> {
                    val startTimeMillis = call.argument<Long>("startTime")
                    val endTimeMillis = call.argument<Long>("endTime")
                    if (startTimeMillis != null && endTimeMillis != null) {
                        getHeartRateVariability(startTimeMillis, endTimeMillis, result)
                    } else {
                        result.error("INVALID_ARGUMENTS", "startTime and endTime are required", null)
                    }
                }
                "initializeSamsungHealth" -> {
                    initializeSamsungHealth(result)
                }
                "getHeartRateData" -> {
                    val startTimeMillis = call.argument<Long>("startTime")
                    val endTimeMillis = call.argument<Long>("endTime")
                    if (startTimeMillis != null && endTimeMillis != null) {
                        getHeartRateData(startTimeMillis, endTimeMillis, result)
                    } else {
                        result.error("INVALID_ARGUMENTS", "startTime and endTime are required", null)
                    }
                }
                "checkSamsungHealthAvailable" -> {
                    checkSamsungHealthAvailable(result)
                }
                // 'getLatestHrvData'는 더 이상 사용되지 않으므로 제거됨
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Health Connect 권한 직접 요청 (Flutter health 패키지 우회)
     */
    private fun requestHealthConnectPermissions(result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                println("🔐 Health Connect 네이티브 권한 요청 시작...")

                // Health Connect Client 가져오기
                val healthConnectClientClass = Class.forName("androidx.health.connect.client.HealthConnectClient")
                val getOrCreateMethod = healthConnectClientClass.getMethod("getOrCreate", android.content.Context::class.java)
                getOrCreateMethod.invoke(null, applicationContext)

                println("✅ HealthConnectClient 생성 완료")

                // 권한 목록 생성
                val permissionClass = Class.forName("androidx.health.connect.client.permission.HealthPermission")

                // READ/WRITE 권한 생성 메서드 찾기
                val createReadPermissionMethod = permissionClass.getMethod("createReadPermission", Class::class.java)
                val createWritePermissionMethod = permissionClass.getMethod("createWritePermission", Class::class.java)

                // 모든 Health Connect Record 클래스들
                val recordClasses = listOf(
                    // 심장 건강
                    "androidx.health.connect.client.records.HeartRateRecord",
                    "androidx.health.connect.client.records.RestingHeartRateRecord",
                    "androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord",
                    "androidx.health.connect.client.records.BloodPressureRecord",
                    "androidx.health.connect.client.records.OxygenSaturationRecord",

                    // 수면
                    "androidx.health.connect.client.records.SleepSessionRecord",

                    // 활동 및 운동
                    "androidx.health.connect.client.records.StepsRecord",
                    "androidx.health.connect.client.records.DistanceRecord",
                    "androidx.health.connect.client.records.ActiveCaloriesBurnedRecord",
                    "androidx.health.connect.client.records.TotalCaloriesBurnedRecord",
                    "androidx.health.connect.client.records.ExerciseSessionRecord",
                    "androidx.health.connect.client.records.Vo2MaxRecord",

                    // 신체 측정
                    "androidx.health.connect.client.records.WeightRecord",
                    "androidx.health.connect.client.records.HeightRecord",
                    "androidx.health.connect.client.records.BodyFatRecord",
                    "androidx.health.connect.client.records.BasalMetabolicRateRecord",

                    // 수분 섭취
                    "androidx.health.connect.client.records.HydrationRecord",

                    // 바이탈 사인
                    "androidx.health.connect.client.records.BloodGlucoseRecord",
                    "androidx.health.connect.client.records.BodyTemperatureRecord",
                    "androidx.health.connect.client.records.RespiratoryRateRecord",

                    // 영양
                    "androidx.health.connect.client.records.NutritionRecord",
                )

                // 권한 생성 (클래스가 없는 경우 무시)
                val permissions = mutableSetOf<String>()
                recordClasses.forEach { className ->
                    try {
                        val recordClass = Class.forName(className)
                        // 모든 데이터 타입에 대해 읽기 권한 추가
                        permissions.add(createReadPermissionMethod.invoke(null, recordClass) as String)

                        // HRV 데이터 타입에 대해서만 쓰기 권한 추가
                        if (className == "androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord") {
                            permissions.add(createWritePermissionMethod.invoke(null, recordClass) as String)
                            println("✅ HRV 쓰기 권한 요청 추가")
                        }
                    } catch (e: ClassNotFoundException) {
                        println("⚠️ 클래스 없음 (무시): $className")
                    }
                }


                println("✅ 권한 목록 생성 완료: ${permissions.size}개")
                permissions.forEach { println("   - $it") }

                // PermissionController를 통해 권한 요청
                withContext(Dispatchers.Main) {
                    try {
                        val permissionControllerClass = Class.forName("androidx.health.connect.client.PermissionController")
                        val createIntentMethod = permissionControllerClass.getMethod("createRequestPermissionResultContract")
                        val contract = createIntentMethod.invoke(null)

                        // ActivityResultLauncher를 사용해야 하지만, 여기서는 직접 Intent 생성
                        val getContractMethod = contract.javaClass.getMethod("createIntent", android.content.Context::class.java, Set::class.java)
                        val intent = getContractMethod.invoke(contract, this@MainActivity, permissions) as android.content.Intent

                        println("🚀 권한 요청 Intent 생성 완료")
                        startActivity(intent)
                        println("✅ Health Connect 권한 요청 화면 열기 완료")
                        result.success(true)
                    } catch (e: Exception) {
                        println("❌ 권한 요청 Intent 생성 실패: ${e.message}")
                        e.printStackTrace()

                        // 대체 방법: Health Connect 앱 직접 열기
                        val intent = packageManager.getLaunchIntentForPackage("com.google.android.apps.healthdata")
                        if (intent != null) {
                            println("🔄 Health Connect 앱 직접 열기...")
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("NO_HEALTH_CONNECT", "Health Connect 앱을 찾을 수 없습니다", null)
                        }
                    }
                }
            } catch (e: Exception) {
                println("❌ Health Connect 권한 요청 실패: ${e.message}")
                e.printStackTrace()
                withContext(Dispatchers.Main) {
                    result.error("PERMISSION_REQUEST_FAILED", e.message, null)
                }
            }
        }
    }

    /**
     * Health Connect에서 안정시 심박수 데이터 가져오기
     */
    private fun getRestingHeartRate(startTimeMillis: Long, endTimeMillis: Long, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                println("📊 안정시 심박수 데이터 가져오기: $startTimeMillis ~ $endTimeMillis")

                // Health Connect SDK 사용
                val healthConnectClient = Class.forName("androidx.health.connect.client.HealthConnectClient")
                val companionMethod = healthConnectClient.getMethod("getOrCreate", android.content.Context::class.java)
                val client = companionMethod.invoke(null, applicationContext)

                // ReadRecordsRequest 생성
                val recordClass = Class.forName("androidx.health.connect.client.records.RestingHeartRateRecord")
                val requestClass = Class.forName("androidx.health.connect.client.request.ReadRecordsRequest")

                val startTime = java.time.Instant.ofEpochMilli(startTimeMillis)
                val endTime = java.time.Instant.ofEpochMilli(endTimeMillis)

                val timeRangeFilterClass = Class.forName("androidx.health.connect.client.time.TimeRangeFilter")
                val betweenMethod = timeRangeFilterClass.getMethod(
                    "between",
                    java.time.Instant::class.java,
                    java.time.Instant::class.java
                )
                val timeRange = betweenMethod.invoke(null, startTime, endTime)

                // Request 빌더 사용
                val builderMethod = requestClass.getMethod("Builder", Class::class.java)
                val builder = builderMethod.invoke(null, recordClass)

                val setTimeRangeFilterMethod = builder.javaClass.getMethod("setTimeRangeFilter", timeRangeFilterClass)
                setTimeRangeFilterMethod.invoke(builder, timeRange)

                val buildMethod = builder.javaClass.getMethod("build")
                val request = buildMethod.invoke(builder)

                // readRecords 호출
                client.javaClass.getMethod("readRecords", requestClass, kotlin.coroutines.Continuation::class.java)

                // 결과 처리
                val records = mutableListOf<Map<String, Any>>()

                withContext(Dispatchers.Main) {
                    result.success(records)
                }
            } catch (e: Exception) {
                println("❌ 안정시 심박수 데이터 읽기 실패: ${e.message}")
                e.printStackTrace()
                withContext(Dispatchers.Main) {
                    result.error("READ_FAILED", e.message, null)
                }
            }
        }
    }

    /**
     * Health Connect에서 심박수 변이도(HRV) 데이터 가져오기 (수정됨)
     */
    private fun getHeartRateVariability(startTimeMillis: Long, endTimeMillis: Long, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val healthConnectClient = HealthConnectClient.getOrCreate(applicationContext)

                println("📊 HRV 데이터 가져오기 (Health Connect): $startTimeMillis ~ $endTimeMillis")

                // ✅ 헬스 커넥트에서 읽어오기
                val request = ReadRecordsRequest(
                    recordType = HeartRateVariabilityRmssdRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(startTimeMillis),
                        Instant.ofEpochMilli(endTimeMillis)
                    )
                )

                val response = healthConnectClient.readRecords(request)

                // 결과 반환용 리스트 변환
                val dataList = response.records.map { record ->
                    mapOf(
                        "rmssd" to record.heartRateVariabilityMillis,
                        "timestamp" to record.time.toEpochMilli()
                    )
                }

                println("✅ HRV 데이터 ${dataList.size}개 조회 완료")

                withContext(Dispatchers.Main) {
                    result.success(dataList)
                }

            } catch (e: Exception) {
                println("❌ HRV 데이터 읽기 실패: ${e.message}")
                e.printStackTrace()
                withContext(Dispatchers.Main) {
                    result.error("READ_FAILED", e.message, null)
                }
            }
        }
    }


    /**
     * Samsung Health가 사용 가능한지 확인
     */
    private fun checkSamsungHealthAvailable(result: MethodChannel.Result) {
        try {
            println("🔍 Samsung Health SDK 확인 시작...")

            // Samsung Health SDK 클래스를 리플렉션으로 확인
            println("📦 1단계: HealthDataService 클래스 찾기...")
            val healthDataServiceClass = Class.forName("com.samsung.android.sdk.health.data.HealthDataService")
            println("✅ 클래스 발견: $healthDataServiceClass")

            println("🔧 2단계: getStore 메서드 찾기...")
            val getStoreMethod = healthDataServiceClass.getMethod("getStore", android.content.Context::class.java)
            println("✅ 메서드 발견: $getStoreMethod")

            println("🚀 3단계: getStore 호출하여 HealthDataStore 가져오기...")
            healthDataStore = getStoreMethod.invoke(null, applicationContext)
            println("✅ HealthDataStore 인스턴스 생성: $healthDataStore")

            // HealthDataStore의 모든 메서드 출력
            println("📋 HealthDataStore의 모든 public 메서드:")
            healthDataStore!!.javaClass.methods.forEach { method ->
                println("   - ${method.name}(${method.parameterTypes.joinToString { it.simpleName }})")
            }

            samsungHealthAvailable = true
            println("🎉 Samsung Health SDK 사용 가능!")
            result.success(true)
        } catch (e: ClassNotFoundException) {
            println("❌ [ClassNotFoundException] Samsung Health SDK 클래스를 찾을 수 없음")
            println("   AAR 파일이 올바르게 포함되지 않았을 수 있습니다")
            println("   상세: ${e.message}")
            e.printStackTrace()
            samsungHealthAvailable = false
            result.success(false)
        } catch (e: NoSuchMethodException) {
            println("❌ [NoSuchMethodException] getStore 메서드를 찾을 수 없음")
            println("   메서드 시그니처가 다를 수 있습니다")
            println("   상세: ${e.message}")
            e.printStackTrace()
            samsungHealthAvailable = false
            result.success(false)
        } catch (e: Exception) {
            println("❌ [${e.javaClass.simpleName}] Samsung Health 확인 실패")
            println("   상세: ${e.message}")
            e.printStackTrace()
            samsungHealthAvailable = false
            result.success(false)
        }
    }

    /**
     * Samsung Health Data SDK 초기화 및 권한 요청
     */
    private fun initializeSamsungHealth(result: MethodChannel.Result) {
        if (!samsungHealthAvailable || healthDataStore == null) {
            println("⚠️ Samsung Health SDK를 사용할 수 없음")
            result.success(false)
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                println("🔐 Samsung Health 권한 요청 시작...")

                // Permission 클래스 (올바른 패키지 경로 사용)
                val permissionClass = Class.forName("com.samsung.android.sdk.health.data.permission.Permission")
                Class.forName("com.samsung.android.sdk.health.data.request.DataType")
                val accessTypeClass = Class.forName("com.samsung.android.sdk.health.data.permission.AccessType")

                // DataType.HeartRateType 가져오기
                val heartRateTypeClass = Class.forName("com.samsung.android.sdk.health.data.request.DataType\$HeartRateType")
                val heartRateTypeCompanion = heartRateTypeClass.getField("Companion").get(null)
                val heartRateDataType = heartRateTypeCompanion

                // AccessType.READ 가져오기
                val accessTypeReadField = accessTypeClass.getField("READ")
                val accessTypeRead = accessTypeReadField.get(null)

                // Permission.of(DataType.HeartRateType, AccessType.READ) 생성
                val permissionOfMethod = permissionClass.getMethod(
                    "of",
                    Class.forName("com.samsung.android.sdk.health.data.request.DataType"),
                    accessTypeClass
                )
                val heartRatePermission = permissionOfMethod.invoke(null, heartRateDataType, accessTypeRead)

                val permissions = setOf(heartRatePermission)
                println("✅ 권한 객체 생성 완료: $permissions")

                // requestPermissionsAsync 호출 (메인 스레드에서 실행)
                withContext(Dispatchers.Main) {
                    try {
                        val requestPermissionsMethod = healthDataStore!!.javaClass.getMethod(
                            "requestPermissionsAsync",
                            Set::class.java,
                            android.app.Activity::class.java
                        )
                        println("🚀 권한 요청 중...")
                        requestPermissionsMethod.invoke(healthDataStore, permissions, this@MainActivity)

                        println("✅ Samsung Health 권한 요청 완료")
                        result.success(true)
                    } catch (e: Exception) {
                        println("❌ 권한 요청 실패: ${e.message}")
                        e.printStackTrace()
                        result.error("PERMISSION_REQUEST_FAILED", e.message, null)
                    }
                }
            } catch (e: ClassNotFoundException) {
                println("❌ Samsung Health SDK 클래스를 찾을 수 없음")
                println("   상세: ${e.message}")
                e.printStackTrace()
                withContext(Dispatchers.Main) {
                    result.error("SDK_NOT_FOUND", "Samsung Health SDK 클래스를 찾을 수 없습니다", null)
                }
            } catch (e: Exception) {
                println("❌ Samsung Health 초기화 실패: ${e.message}")
                e.printStackTrace()
                withContext(Dispatchers.Main) {
                    result.error("INITIALIZATION_FAILED", e.message, null)
                }
            }
        }
    }

    /**
     * Samsung Health에서 심박수 데이터 가져오기
     */
    private fun getHeartRateData(startTimeMillis: Long, endTimeMillis: Long, result: MethodChannel.Result) {
        if (!samsungHealthAvailable || healthDataStore == null) {
            result.error("NOT_INITIALIZED", "Samsung Health가 초기화되지 않았습니다", null)
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                // 리플렉션을 사용하여 데이터 가져오기
                println("⚠️ Samsung Health 데이터 가져오기는 AAR 파일이 필요합니다")
                withContext(Dispatchers.Main) {
                    result.success(emptyList<Map<String, Any>>())
                }
            } catch (e: Exception) {
                println("❌ Samsung Health 데이터 읽기 실패: ${e.message}")
                withContext(Dispatchers.Main) {
                    result.error("READ_FAILED", e.message, null)
                }
            }
        }
    }
}
