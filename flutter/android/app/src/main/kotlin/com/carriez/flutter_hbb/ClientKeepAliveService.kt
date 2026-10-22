package com.carriez.flutter_hbb

// Sinaptic Remoto: mantiene viva la sesión de CONTROL (lado cliente) cuando la app
// pasa a segundo plano. Mientras haya una sesión remota abierta corre como servicio
// en primer plano con la notificación «Sinaptic Remoto conectado»; al ir a segundo
// plano arranca un plazo y, si no se vuelve antes, cierra las sesiones y se detiene.

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import ffi.FFI

class ClientKeepAliveService : Service() {
    companion object {
        private const val TAG = "ClientKeepAlive"
        private const val CHANNEL_ID = "SinapticRemotoCliente"
        private const val NOTIFY_ID = 47110
        private const val EXTRA_BACKGROUND = "background"
        // Tiempo que la sesión aguanta en segundo plano antes de cerrarse.
        const val BACKGROUND_TIMEOUT_MS = 10 * 60 * 1000L
        // Cada cuánto se revisa el plazo. El plazo se mide con elapsedRealtime (cuenta
        // también el sueño profundo); un solo postDelayed de 10 min usa uptimeMillis,
        // que se detiene cuando la CPU duerme, y con la pantalla apagada el plazo real
        // podía alargarse bastante más de 10 min con la sesión abierta.
        private const val CHECK_INTERVAL_MS = 30 * 1000L

        fun update(context: Context, background: Boolean) {
            val intent = Intent(context, ClientKeepAliveService::class.java)
            intent.putExtra(EXTRA_BACKGROUND, background)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "No se pudo arrancar el servicio: $e")
            }
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, ClientKeepAliveService::class.java))
            } catch (e: Exception) {
                Log.e(TAG, "No se pudo detener el servicio: $e")
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val timeoutRunnable = Runnable {
        Log.i(TAG, "Plazo en segundo plano agotado: se cierran las sesiones")
        try {
            FFI.closeAllSessions()
        } catch (e: Throwable) {
            Log.e(TAG, "closeAllSessions: $e")
        }
        stopSelf()
    }

    // Momento (en elapsedRealtime) en que vence el plazo en segundo plano.
    private var deadlineElapsed = 0L
    private val checkRunnable = object : Runnable {
        override fun run() {
            if (SystemClock.elapsedRealtime() >= deadlineElapsed) {
                timeoutRunnable.run()
            } else {
                handler.postDelayed(this, CHECK_INTERVAL_MS)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        showNotification()
        handler.removeCallbacks(checkRunnable)
        val background = intent?.getBooleanExtra(EXTRA_BACKGROUND, false) ?: false
        if (background) {
            deadlineElapsed = SystemClock.elapsedRealtime() + BACKGROUND_TIMEOUT_MS
            handler.postDelayed(checkRunnable, CHECK_INTERVAL_MS)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(checkRunnable)
        super.onDestroy()
    }

    private fun showNotification() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Sesión remota", NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Mantiene abierta la sesión remota en segundo plano"
            nm.createNotificationChannel(channel)
        }
        val launch = Intent(this, MainActivity::class.java)
        launch.action = Intent.ACTION_MAIN
        launch.addCategory(Intent.CATEGORY_LAUNCHER)
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, 1, launch, piFlags)
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setOngoing(true)
            .setSmallIcon(R.mipmap.ic_stat_logo)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentTitle("Sinaptic Remoto conectado")
            .setContentText("Toque para volver a la sesión remota")
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFY_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIFY_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground falló: $e")
            stopSelf()
        }
    }
}
