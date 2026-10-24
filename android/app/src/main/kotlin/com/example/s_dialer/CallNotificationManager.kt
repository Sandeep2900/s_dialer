package com.example.s_dialer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat

object CallNotificationManager {
    const val CHANNEL_ONGOING_CALL = "s_dialer_ongoing_call"
    const val CHANNEL_INCOMING_CALL = "s_dialer_incoming_call_v3"
    const val NOTIFICATION_ID_ONGOING = 1001
    const val NOTIFICATION_ID_INCOMING = 1002

    fun initChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

            // Channel for ongoing / active calls
            val ongoingChannel = NotificationChannel(
                CHANNEL_ONGOING_CALL,
                "Ongoing Calls",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows status of ongoing calls when minimized"
                setShowBadge(false)
            }

            // Channel for incoming calls (high priority heads-up with ringtone)
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .build()

            val incomingChannel = NotificationChannel(
                CHANNEL_INCOMING_CALL,
                "Incoming Calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows incoming call alerts with answer/decline actions"
                setShowBadge(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 1000, 1000, 1000)
                setSound(ringtoneUri, audioAttributes)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }

            notificationManager.createNotificationChannel(ongoingChannel)
            notificationManager.createNotificationChannel(incomingChannel)
        }
    }

    fun showOngoingCallNotification(
        context: Context,
        number: String,
        name: String?,
        state: String
    ) {
        initChannels(context)

        val title = if (!name.isNullOrEmpty()) name else (if (number.isNotEmpty()) number else "Active Call")
        val contentText = when (state) {
            "dialing", "connecting" -> "Calling... • Tap to view"
            "holding" -> "Call on hold • Tap to view"
            else -> "Ongoing call • Tap to view"
        }

        // Tap notification to return to InCallScreen in MainActivity
        val tapIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra("action", "show_in_call")
            putExtra("number", number)
            putExtra("name", name)
            putExtra("state", state)
        }
        val pendingTapIntent = PendingIntent.getActivity(
            context,
            0,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // End Call action button
        val hangupIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = CallActionReceiver.ACTION_HANGUP
        }
        val pendingHangupIntent = PendingIntent.getBroadcast(
            context,
            1,
            hangupIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Speaker toggle action button
        val speakerIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = CallActionReceiver.ACTION_TOGGLE_SPEAKER
        }
        val pendingSpeakerIntent = PendingIntent.getBroadcast(
            context,
            2,
            speakerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ONGOING_CALL)
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setContentTitle(title)
            .setContentText(contentText)
            .setContentIntent(pendingTapIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "End call", pendingHangupIntent)
            .addAction(android.R.drawable.stat_notify_chat, "Speaker", pendingSpeakerIntent)

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.notify(NOTIFICATION_ID_ONGOING, builder.build())
    }

    fun showIncomingCallNotification(
        context: Context,
        number: String,
        name: String?
    ) {
        initChannels(context)

        val title = if (!name.isNullOrEmpty()) name else (if (number.isNotEmpty()) number else "Incoming Call")
        val contentText = if (!name.isNullOrEmpty() && number.isNotEmpty()) number else "Incoming phone call"

        // Full screen intent opens InCallScreen directly even if screen is locked
        val fullScreenIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra("action", "show_in_call")
            putExtra("number", number)
            putExtra("name", name)
            putExtra("state", "ringing")
        }
        val pendingFullScreenIntent = PendingIntent.getActivity(
            context,
            3,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Answer action button
        val answerIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = CallActionReceiver.ACTION_ANSWER
            putExtra("number", number)
            putExtra("name", name)
        }
        val pendingAnswerIntent = PendingIntent.getBroadcast(
            context,
            4,
            answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Decline action button
        val declineIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = CallActionReceiver.ACTION_DECLINE
        }
        val pendingDeclineIntent = PendingIntent.getBroadcast(
            context,
            5,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_INCOMING_CALL)
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setContentTitle(title)
            .setContentText(contentText)
            .setContentIntent(pendingFullScreenIntent)
            .setFullScreenIntent(pendingFullScreenIntent, true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE))
            .addAction(android.R.drawable.ic_menu_call, "Answer", pendingAnswerIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", pendingDeclineIntent)

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        nm?.notify(NOTIFICATION_ID_INCOMING, builder.build())
    }

    fun cancelCallNotification(context: Context) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        nm.cancel(NOTIFICATION_ID_ONGOING)
        nm.cancel(NOTIFICATION_ID_INCOMING)
    }
}
