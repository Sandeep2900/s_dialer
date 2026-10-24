package com.example.s_dialer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager

class CallActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_HANGUP = "com.example.s_dialer.ACTION_HANGUP"
        const val ACTION_ANSWER = "com.example.s_dialer.ACTION_ANSWER"
        const val ACTION_DECLINE = "com.example.s_dialer.ACTION_DECLINE"
        const val ACTION_TOGGLE_SPEAKER = "com.example.s_dialer.ACTION_TOGGLE_SPEAKER"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            ACTION_HANGUP, ACTION_DECLINE -> {
                DialerInCallService.hangupCall(context)
                CallNotificationManager.cancelCallNotification(context)
            }
            ACTION_ANSWER -> {
                DialerInCallService.answerCall()
                val active = DialerInCallService.activeCall
                val number = active?.details?.handle?.schemeSpecificPart ?: intent.getStringExtra("number") ?: ""
                val name = active?.details?.callerDisplayName ?: intent.getStringExtra("name")
                CallNotificationManager.showOngoingCallNotification(context, number, name, "active")

                val activityIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                    putExtra("action", "show_in_call")
                    putExtra("number", number)
                    putExtra("name", name)
                    putExtra("state", "active")
                }
                context.startActivity(activityIntent)
            }
            ACTION_TOGGLE_SPEAKER -> {
                val am = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                am?.let {
                    val newOn = !it.isSpeakerphoneOn
                    DialerInCallService.setSpeaker(context, newOn)
                }
            }
        }
    }
}
