package com.example.s_dialer

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import android.telecom.TelecomManager
import android.telephony.SubscriptionManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.s_dialer/telephony"
    private var toneGenerator: ToneGenerator? = null
    private var pendingInCallData: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wakeAndUnlockScreen()
        handleInCallIntent(intent)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache engine for DialerInCallService access
        FlutterEngineCache.getInstance().put("main_engine", flutterEngine)

        try {
            toneGenerator = ToneGenerator(AudioManager.STREAM_DTMF, 80)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Primary Telephony MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialCall" -> {
                    val data = pendingInCallData
                    pendingInCallData = null
                    result.success(data)
                }
                "makeCall" -> {
                    val rawNumber = call.argument<String>("number") ?: ""
                    if (rawNumber.isNotEmpty()) {
                        placeCall(rawNumber)
                        result.success(true)
                    } else {
                        result.error("INVALID_NUMBER", "Phone number is empty", null)
                    }
                }
                "sendSms" -> {
                    val number = call.argument<String>("number") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    sendSmsIntent(number, message)
                    result.success(true)
                }
                "playTone" -> {
                    val digit = call.argument<String>("digit") ?: ""
                    playDtmfTone(digit)
                    result.success(true)
                }
                "isDefaultDialer" -> {
                    result.success(isDefaultDialer())
                }
                "requestDefaultDialer" -> {
                    requestDefaultDialerRole()
                    result.success(true)
                }
                "getSimCards" -> {
                    result.success(getSimCardsInfo())
                }
                "getCallLogs" -> {
                    val limit = call.argument<Int>("limit") ?: 250
                    Thread {
                        val logs = fetchCallLogsInBackground(limit)
                        Handler(Looper.getMainLooper()).post {
                            result.success(logs)
                        }
                    }.start()
                }
                "deleteCallLogs" -> {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    Thread {
                        val success = deleteCallLogInBackground(ids)
                        Handler(Looper.getMainLooper()).post {
                            result.success(success)
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }

        // Call Control MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DialerInCallService.CALL_CONTROL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "answer" -> result.success(DialerInCallService.answerCall())
                    "hangup" -> result.success(DialerInCallService.hangupCall(applicationContext))
                    "mute" -> {
                        val muted = call.argument<Boolean>("muted") ?: false
                        result.success(DialerInCallService.setMute(applicationContext, muted))
                    }
                    "speaker" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        result.success(DialerInCallService.setSpeaker(applicationContext, on))
                    }
                    "hold" -> {
                        val hold = call.argument<Boolean>("hold") ?: false
                        result.success(DialerInCallService.setHold(hold))
                    }
                    "playDtmf" -> {
                        val digit = call.argument<String>("digit")?.firstOrNull() ?: '0'
                        result.success(DialerInCallService.playDtmf(digit))
                    }
                    "stopDtmf" -> result.success(DialerInCallService.stopDtmf())
                    "getCallState" -> {
                        val current = DialerInCallService.activeCall
                        if (current != null) {
                            result.success(DialerInCallService.buildCallMap(current))
                        } else {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Call Events Stream Channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DialerInCallService.CALL_EVENT_CHANNEL)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                        DialerInCallService.eventSink = sink
                        DialerInCallService.activeCall?.let {
                            sink.success(DialerInCallService.buildCallMap(it))
                        }
                    }
                    override fun onCancel(args: Any?) {
                        DialerInCallService.eventSink = null
                    }
                }
            )

        // Check if intent launched activity with in-call request
        handleInCallIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        wakeAndUnlockScreen()
        handleInCallIntent(intent)
    }

    private fun wakeAndUnlockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? android.app.KeyguardManager
            keyguardManager?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    private fun handleInCallIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra("action")
        if (action == "show_in_call") {
            val map = mapOf(
                "number" to (intent.getStringExtra("number") ?: ""),
                "name" to intent.getStringExtra("name"),
                "state" to (intent.getStringExtra("state") ?: "ringing")
            )
            pendingInCallData = map
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("showInCallScreen", map)
            }
        }
    }

    private fun placeCall(number: String) {
        val encodedNumber = Uri.encode(number)
        val callUri = Uri.parse("tel:$encodedNumber")
        val telecomManager = getSystemService(Context.TELECOM_SERVICE) as? TelecomManager

        // If app is default dialer, TelecomManager places call directly and routes to DialerInCallService
        if (isDefaultDialer() && telecomManager != null &&
            checkSelfPermission(android.Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
            try {
                telecomManager.placeCall(callUri, null)
                return
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Fallback for non-default dialer or permission issues
        val hasCallPermission = checkSelfPermission(android.Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED
        val intentAction = if (hasCallPermission) Intent.ACTION_CALL else Intent.ACTION_DIAL
        val callIntent = Intent(intentAction, callUri).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(callIntent)
    }

    private fun sendSmsIntent(number: String, message: String) {
        val smsUri = Uri.parse("smsto:${Uri.encode(number)}")
        val smsIntent = Intent(Intent.ACTION_SENDTO, smsUri).apply {
            putExtra("sms_body", message)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(smsIntent)
    }

    private fun playDtmfTone(digit: String) {
        try {
            val tone = when (digit) {
                "1" -> ToneGenerator.TONE_DTMF_1
                "2" -> ToneGenerator.TONE_DTMF_2
                "3" -> ToneGenerator.TONE_DTMF_3
                "4" -> ToneGenerator.TONE_DTMF_4
                "5" -> ToneGenerator.TONE_DTMF_5
                "6" -> ToneGenerator.TONE_DTMF_6
                "7" -> ToneGenerator.TONE_DTMF_7
                "8" -> ToneGenerator.TONE_DTMF_8
                "9" -> ToneGenerator.TONE_DTMF_9
                "0" -> ToneGenerator.TONE_DTMF_0
                "*" -> ToneGenerator.TONE_DTMF_S
                "#" -> ToneGenerator.TONE_DTMF_P
                else -> -1
            }
            if (tone != -1) {
                toneGenerator?.startTone(tone, 150)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun isDefaultDialer(): Boolean {
        val telecomManager = getSystemService(Context.TELECOM_SERVICE) as? TelecomManager ?: return false
        return telecomManager.defaultDialerPackage == packageName
    }

    private fun requestDefaultDialerRole() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
            if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_DIALER)) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_DIALER)
                startActivityForResult(intent, 1001)
                return
            }
        }
        val intent = Intent(TelecomManager.ACTION_CHANGE_DEFAULT_DIALER).apply {
            putExtra(TelecomManager.EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME, packageName)
        }
        startActivity(intent)
    }

    private fun getSimCardsInfo(): List<Map<String, String>> {
        val simList = mutableListOf<Map<String, String>>()
        try {
            if (checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
                val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                val activeList = subscriptionManager?.activeSubscriptionInfoList
                activeList?.forEachIndexed { index, subInfo ->
                    simList.add(mapOf(
                        "slotIndex" to subInfo.simSlotIndex.toString(),
                        "displayName" to (subInfo.displayName?.toString() ?: "SIM ${index + 1}"),
                        "carrier" to (subInfo.carrierName?.toString() ?: "Carrier")
                    ))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return simList
    }

    private fun fetchCallLogsInBackground(limit: Int): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        try {
            if (checkSelfPermission(android.Manifest.permission.READ_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
                return list
            }

            val projection = arrayOf(
                CallLog.Calls._ID,
                CallLog.Calls.NUMBER,
                CallLog.Calls.CACHED_NAME,
                CallLog.Calls.TYPE,
                CallLog.Calls.DATE,
                CallLog.Calls.DURATION,
                CallLog.Calls.PHONE_ACCOUNT_ID
            )

            val sortOrder = "${CallLog.Calls.DATE} DESC"
            contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                projection,
                null,
                null,
                sortOrder
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndex(CallLog.Calls._ID)
                val numberIdx = cursor.getColumnIndex(CallLog.Calls.NUMBER)
                val nameIdx = cursor.getColumnIndex(CallLog.Calls.CACHED_NAME)
                val typeIdx = cursor.getColumnIndex(CallLog.Calls.TYPE)
                val dateIdx = cursor.getColumnIndex(CallLog.Calls.DATE)
                val durationIdx = cursor.getColumnIndex(CallLog.Calls.DURATION)
                val accountIdIdx = cursor.getColumnIndex(CallLog.Calls.PHONE_ACCOUNT_ID)

                while (cursor.moveToNext()) {
                    if (list.size >= limit) break

                    val id = if (idIdx != -1) cursor.getString(idIdx) ?: "" else ""
                    val number = if (numberIdx != -1) cursor.getString(numberIdx) ?: "" else ""
                    val name = if (nameIdx != -1) cursor.getString(nameIdx) else null
                    val type = if (typeIdx != -1) cursor.getInt(typeIdx) else 1
                    val date = if (dateIdx != -1) cursor.getLong(dateIdx) else System.currentTimeMillis()
                    val duration = if (durationIdx != -1) cursor.getInt(durationIdx) else 0
                    val accountId = if (accountIdIdx != -1) cursor.getString(accountIdIdx) else null

                    list.add(mapOf(
                        "id" to id,
                        "number" to number,
                        "name" to name,
                        "type" to type,
                        "timestamp" to date,
                        "duration" to duration,
                        "simDisplayName" to accountId
                    ))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return list
    }

    private fun deleteCallLogInBackground(ids: List<String>): Boolean {
        try {
            if (checkSelfPermission(android.Manifest.permission.WRITE_CALL_LOG) != PackageManager.PERMISSION_GRANTED) {
                return false
            }
            if (ids.isEmpty()) return true
            val placeholders = ids.joinToString(",") { "?" }
            val whereClause = "${CallLog.Calls._ID} IN ($placeholders)"
            contentResolver.delete(
                CallLog.Calls.CONTENT_URI,
                whereClause,
                ids.toTypedArray()
            )
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
