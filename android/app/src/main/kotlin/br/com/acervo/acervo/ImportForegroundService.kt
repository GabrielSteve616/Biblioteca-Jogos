package br.com.acervo.acervo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.os.PowerManager

/** Keeps the Flutter process alive while an explicitly requested import runs. */
class ImportForegroundService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private val notificationId = 2401
    private val channel = "biblioteca_importacoes"
    private val handler = Handler(Looper.getMainLooper())
    private var lastDone = 0
    private var lastTotal = 0
    private val stale = Runnable {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, notification("Importação pausada. Abra a Biblioteca para retomar.", lastDone, lastTotal, true))
        stopForeground(STOP_FOREGROUND_DETACH)
        stopSelf()
    }

    private fun notification(message: String, done: Int, total: Int, finished: Boolean = false): Notification {
        val target = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(this, 0, target,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel) else Notification.Builder(this)
        return builder.setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Biblioteca")
            .setContentText(message)
            .setContentIntent(pending)
            .setOngoing(!finished)
            .setAutoCancel(finished)
            .setOnlyAlertOnce(true)
            .setProgress(if (finished) 0 else total.coerceAtLeast(1), if (finished) 0 else done.coerceAtLeast(0), false)
            .build()
    }

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel(channel, "Importação de jogos", NotificationManager.IMPORTANCE_LOW))
        }
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "biblioteca:importacao").apply { setReferenceCounted(false) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val total = intent?.getIntExtra("total", 0) ?: 0
        val done = intent?.getIntExtra("done", 0) ?: 0
        lastDone = done
        lastTotal = total
        handler.removeCallbacks(stale)
        when (intent?.action) {
            "finish" -> {
                val success = intent.getBooleanExtra("success", false)
                val message = if (success) "$total jogos importados" else "Importação pausada. Abra a Biblioteca para retomar."
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(notificationId, notification(message, total, total, true))
                if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_DETACH) else @Suppress("DEPRECATION") stopForeground(false)
                stopSelf()
            }
            else -> {
                wakeLock?.acquire(30 * 60 * 1000L)
                val message = "Importando jogos: $done/$total"
                startForeground(notificationId, notification(message, done, total))
                handler.postDelayed(stale, 90_000L)
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(stale)
        if (wakeLock?.isHeld == true) wakeLock?.release()
        wakeLock = null
        super.onDestroy()
    }
    override fun onBind(intent: Intent?): IBinder? = null
}
