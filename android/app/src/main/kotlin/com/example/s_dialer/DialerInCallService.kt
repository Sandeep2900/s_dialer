package com.example.s_dialer

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telecom.Call
import android.telecom.CallAudioState
import android.telecom.InCallService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class DialerInCallService : InCallService() {

    companion object {
        const val CALL_EVENT_CHANNEL = "com.example.s_dialer/call_events"
        const val CALL_CONTROL_CHANNEL = "com.example.s_dialer/call_control"

        var instance: DialerInCallService? = null
        var eventSink: EventChannel.EventSink? = null
        var activeCall: Call? = null

        fun sendCallEvent(event: Map<String, Any?>) {
            Handler(Looper.getMainLooper()).post {
                try {
                    eventSink?.success(event)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }

        fun stateToString(state: Int): String = when (state) {
            Call.STATE_DIALING        -> "dialing"
            Call.STATE_RINGING        -> "ringing"
            Call.STATE_ACTIVE         -> "active"
            Call.STATE_HOLDING        -> "holding"
            Call.STATE_CONNECTING     -> "connecting"
            Call.STATE_DISCONNECTING,
            Call.STATE_DISCONNECTED   -> "disconnected"
            else                      -> "disconnected"
        }

        fun resetAudio(context: Context?) {
            try {
                val am = context?.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                am?.let {
                    it.mode = AudioManager.MODE_NORMAL
                    it.isSpeakerphoneOn = false
                    it.isMicrophoneMute = false
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        fun broadcastDisconnected() {
            sendCallEvent(mapOf(
                "state" to "disconnected",
                "number" to "",
                "name" to null,
                "duration" to 0
            ))
        }

        fun buildCallMap(call: Call): Map<String, Any?> {
            val details = call.details
            val number = details?.handle?.schemeSpecificPart ?: ""
            val name   = details?.callerDisplayName?.takeIf { it.isNotEmpty() }
            val connectTime = details?.connectTimeMillis ?: 0L
            val duration = if (connectTime > 0L) ((System.currentTimeMillis() - connectTime) / 1000).toInt() else 0
            return mapOf(
                "state"    to stateToString(call.state),
                "number"   to number,
                "name"     to name,
                "duration" to duration,
            )
        }

        fun answerCall(): Boolean {
            val call = activeCall ?: return false
            try {
                call.answer(0)
                return true
            } catch (e: Exception) {
                e.printStackTrace()
                return false
            }
        }

        fun hangupCall(context: Context? = null): Boolean {
            val call = activeCall
            val ctx = context ?: instance?.applicationContext
            try {
                call?.let {
                    if (it.state == Call.STATE_RINGING) {
                        it.reject(false, null)
                    } else {
                        it.disconnect()
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                activeCall = null
                ctx?.let {
                    CallNotificationManager.cancelCallNotification(it)
                    resetAudio(it)
                }
                broadcastDisconnected()
            }
            return true
        }

        fun setMute(context: Context, muted: Boolean): Boolean {
            try {
                instance?.setMuted(muted)
                val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                am?.isMicrophoneMute = muted
                return true
            } catch (e: Exception) {
                e.printStackTrace()
                return false
            }
        }

        fun setSpeaker(context: Context, on: Boolean): Boolean {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    instance?.setAudioRoute(if (on) CallAudioState.ROUTE_SPEAKER else CallAudioState.ROUTE_EARPIECE)
                }
                val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                am?.let {
                    it.mode = if (on) AudioManager.MODE_IN_COMMUNICATION else AudioManager.MODE_IN_CALL
                    it.isSpeakerphoneOn = on
                }
                return true
            } catch (e: Exception) {
                e.printStackTrace()
                return false
            }
        }

        fun setHold(hold: Boolean): Boolean {
            val call = activeCall ?: return false
            try {
                if (hold) call.hold() else call.unhold()
                return true
            } catch (e: Exception) {
                e.printStackTrace()
                return false
            }
        }

        fun playDtmf(digit: Char): Boolean {
            val call = activeCall ?: return false
            try {
                call.playDtmfTone(digit)
                return true
            } catch (e: Exception) {
                e.printStackTrace()
                return false
            }
        }

        fun stopDtmf(): Boolean {
            val call = activeCall ?: return false
            try {
                call.stopDtmfTone()
                return true
            } catch (e: Exception) {
                e.printStackTrace()
                return false
            }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private val callCallback = object : Call.Callback() {
        override fun onStateChanged(call: Call, state: Int) {
            broadcastCallState(call)
            val map = buildCallMap(call)
            val number = map["number"] as? String ?: ""
            val name = map["name"] as? String

            when (state) {
                Call.STATE_RINGING -> {
                    CallNotificationManager.showIncomingCallNotification(applicationContext, number, name)
                }
                Call.STATE_ACTIVE, Call.STATE_DIALING, Call.STATE_CONNECTING, Call.STATE_HOLDING -> {
                    CallNotificationManager.showOngoingCallNotification(applicationContext, number, name, stateToString(state))
                }
                Call.STATE_DISCONNECTED, Call.STATE_DISCONNECTING -> {
                    CallNotificationManager.cancelCallNotification(applicationContext)
                    resetAudio(applicationContext)
                    if (activeCall == call) {
                        activeCall = null
                    }
                    broadcastDisconnected()
                }
            }
        }
        override fun onDetailsChanged(call: Call, details: Call.Details) {
            broadcastCallState(call)
        }
        override fun onCallDestroyed(call: Call) {
            CallNotificationManager.cancelCallNotification(applicationContext)
            resetAudio(applicationContext)
            if (activeCall == call) {
                activeCall = null
            }
            broadcastDisconnected()
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        CallNotificationManager.initChannels(applicationContext)
        setupChannels()
    }

    override fun onCallAdded(call: Call) {
        super.onCallAdded(call)
        activeCall = call
        call.registerCallback(callCallback)
        broadcastCallState(call)

        val map = buildCallMap(call)
        val number = map["number"] as? String ?: ""
        val name = map["name"] as? String

        if (call.state == Call.STATE_RINGING) {
            CallNotificationManager.showIncomingCallNotification(applicationContext, number, name)
        } else {
            CallNotificationManager.showOngoingCallNotification(applicationContext, number, name, stateToString(call.state))
        }

        // Bring MainActivity to the front
        try {
            val intent = Intent(applicationContext, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                putExtra("action", "show_in_call")
                putExtra("number", call.details?.handle?.schemeSpecificPart ?: "")
                putExtra("name", call.details?.callerDisplayName?.takeIf { it.isNotEmpty() })
                putExtra("state", stateToString(call.state))
            }
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Notify Flutter via telephony channel
        mainHandler.post {
            getFlutterEngine()?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, "com.example.s_dialer/telephony")
                    .invokeMethod("showInCallScreen", buildCallMap(call))
            }
        }
    }

    override fun onCallRemoved(call: Call) {
        super.onCallRemoved(call)
        try {
            call.unregisterCallback(callCallback)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        CallNotificationManager.cancelCallNotification(applicationContext)
        resetAudio(applicationContext)
        if (activeCall == call) {
            activeCall = null
        }
        broadcastDisconnected()
    }

    override fun onDestroy() {
        CallNotificationManager.cancelCallNotification(applicationContext)
        resetAudio(applicationContext)
        if (instance == this) {
            instance = null
        }
        activeCall = null
        super.onDestroy()
    }

    private fun setupChannels() {
        val engine = getFlutterEngine() ?: return
        val messenger = engine.dartExecutor.binaryMessenger

        EventChannel(messenger, CALL_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                    activeCall?.let { sink.success(buildCallMap(it)) }
                }
                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            }
        )

        MethodChannel(messenger, CALL_CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "answer" -> result.success(answerCall())
                "hangup" -> result.success(hangupCall(applicationContext))
                "mute" -> {
                    val muted = call.argument<Boolean>("muted") ?: false
                    result.success(setMute(applicationContext, muted))
                }
                "speaker" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    result.success(setSpeaker(applicationContext, on))
                }
                "hold" -> {
                    val hold = call.argument<Boolean>("hold") ?: false
                    result.success(setHold(hold))
                }
                "playDtmf" -> {
                    val digit = call.argument<String>("digit")?.firstOrNull() ?: '0'
                    result.success(playDtmf(digit))
                }
                "stopDtmf" -> result.success(stopDtmf())
                "getCallState" -> {
                    val current = activeCall
                    if (current != null) {
                        result.success(buildCallMap(current))
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun broadcastCallState(call: Call) {
        sendCallEvent(buildCallMap(call))
    }

    private fun getFlutterEngine(): FlutterEngine? =
        FlutterEngineCache.getInstance().get("main_engine")
}
