package com.seyfettin.ezan_vakitlerim

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

// Ezanı ve ardından ezan duasını okuyan arka plan servisi.
// Uygulama kapalı olsa da çalışır; okurken bildirim çubuğunda "Durdur" düğmeli bir bildirim durur.
class EzanServisi : Service() {

    companion object {
        private const val KANAL = "ezan_kanal"
        private const val BILDIRIM_ID = 7001
        private const val EYLEM_BASLAT = "com.seyfettin.ezan_vakitlerim.EZAN_BASLAT"
        private const val EYLEM_DURDUR = "com.seyfettin.ezan_vakitlerim.EZAN_DURDUR"

        // Şu an ne çalıyor: "ezan", "dua" ya da null (uygulama ekranı bunu okur)
        @Volatile var durum: String? = null
        @Volatile var calanVakit: Int = -1

        // Servisi başlatır (alarm çalınca ya da "sesi dene" denince)
        fun baslat(context: Context, vakit: Int, baslik: String, metin: String) {
            val niyet = Intent(context, EzanServisi::class.java)
                .setAction(EYLEM_BASLAT)
                .putExtra("vakit", vakit)
                .putExtra("baslik", baslik)
                .putExtra("metin", metin)
            ContextCompat.startForegroundService(context, niyet)
        }

        // Çalan ezanı/duayı durdurur
        fun durdur(context: Context) {
            if (durum == null) return
            try {
                context.startService(Intent(context, EzanServisi::class.java).setAction(EYLEM_DURDUR))
            } catch (e: Exception) {
                // Servis zaten kapanmışsa sorun değil
            }
        }
    }

    private var oynatici: MediaPlayer? = null
    private var odakIstegi: AudioFocusRequest? = null
    private var baslik = ""
    private var metin = ""
    private var vakit = 2

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            EYLEM_DURDUR -> bitir(kullaniciDurdurdu = true)
            EYLEM_BASLAT -> {
                vakit = intent.getIntExtra("vakit", 2)
                baslik = intent.getStringExtra("baslik") ?: "Vakit girdi"
                metin = intent.getStringExtra("metin") ?: ""
                kanalKur()
                onPlanaGec(bildirimYap("Ezan okunuyor · $metin", caliyor = true))

                val ayar = getSharedPreferences(EzanZamanlayici.DEPO, Context.MODE_PRIVATE)
                val ses = getSystemService(AudioManager::class.java)
                val telefonSessiz = ses.ringerMode != AudioManager.RINGER_MODE_NORMAL
                if (telefonSessiz && !ayar.getBoolean("sessizdeOku", false)) {
                    // Telefon sessizde: ezan okunmaz, sadece bildirim kalır
                    bitir(kullaniciDurdurdu = false)
                } else {
                    ezanOku(duaOkunsunMu = ayar.getBoolean("dua", true))
                }
            }
            else -> stopSelf()
        }
        return START_NOT_STICKY
    }

    // Sabah vaktinde sabah ezanını, diğer vakitlerde ezanı okur; bitince istenirse duaya geçer
    private fun ezanOku(duaOkunsunMu: Boolean) {
        calanVakit = vakit
        durum = "ezan"
        sesOdagiAl()
        val dosya = if (vakit == 0) R.raw.ezan_sabah else R.raw.ezan
        cal(dosya) {
            if (duaOkunsunMu) {
                durum = "dua"
                bildirimGuncelle(bildirimYap("Ezan duası okunuyor · $metin", caliyor = true))
                cal(R.raw.ezan_duasi) { bitir(kullaniciDurdurdu = false) }
            } else {
                bitir(kullaniciDurdurdu = false)
            }
        }
    }

    // Bir ses dosyasını alarm sesi olarak çalar; bitince "sonra" işini yapar
    private fun cal(dosya: Int, sonra: () -> Unit) {
        oynatici?.release()
        try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            resources.openRawResourceFd(dosya).use { fd ->
                mp.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
            }
            mp.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            mp.setOnCompletionListener { sonra() }
            mp.setOnErrorListener { _, _, _ ->
                bitir(kullaniciDurdurdu = false)
                true
            }
            mp.prepare()
            mp.start()
            oynatici = mp
        } catch (e: Exception) {
            bitir(kullaniciDurdurdu = false)
        }
    }

    // Müzik vs. çalıyorsa ezan boyunca durmasını ister
    private fun sesOdagiAl() {
        val ses = getSystemService(AudioManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            val istek = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build()
                )
                .build()
            ses.requestAudioFocus(istek)
            odakIstegi = istek
        } else {
            @Suppress("DEPRECATION")
            ses.requestAudioFocus(null, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        }
    }

    private fun sesOdaginiBirak() {
        val ses = getSystemService(AudioManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            odakIstegi?.let { ses.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            ses.abandonAudioFocus(null)
        }
        odakIstegi = null
    }

    // Sesi kapatır, servisi bitirir. Kendiliğinden bittiyse sade bir "vakit girdi" bildirimi bırakır.
    private fun bitir(kullaniciDurdurdu: Boolean) {
        oynatici?.let {
            try { it.stop() } catch (e: Exception) { }
            it.release()
        }
        oynatici = null
        sesOdaginiBirak()
        durum = null
        if (kullaniciDurdurdu) {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        } else {
            bildirimGuncelle(bildirimYap(metin, caliyor = false))
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_DETACH)
        }
        stopSelf()
    }

    // Ezan bildirim kanalını oluşturur (sesi biz çaldığımız için kanalın kendi sesi yok)
    private fun kanalKur() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(KANAL) != null) return
        val kanal = NotificationChannel(KANAL, "Sesli ezan", NotificationManager.IMPORTANCE_HIGH)
        kanal.description = "Vakit girince ezan okunurken görünen bildirim"
        kanal.setSound(null, null)
        kanal.lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        nm.createNotificationChannel(kanal)
    }

    // Bildirimi hazırlar: başlık, saat, tam ekran açılış ve okurken "Durdur" düğmesi
    private fun bildirimYap(yazi: String, caliyor: Boolean): android.app.Notification {
        val ayar = getSharedPreferences(EzanZamanlayici.DEPO, Context.MODE_PRIVATE)
        val acilis = Intent(this, MainActivity::class.java)
            .putExtra("tam_ekran_vakit", vakit)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val acilisNiyeti = PendingIntent.getActivity(
            this, 100 + vakit, acilis,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = NotificationCompat.Builder(this, KANAL)
            .setSmallIcon(R.drawable.ic_bildirim)
            .setColor(0xFF0F4C4A.toInt())
            .setContentTitle(baslik)
            .setContentText(yazi)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(acilisNiyeti)
            .setOngoing(caliyor)
            .setAutoCancel(!caliyor)
            .setOnlyAlertOnce(true)
        if (caliyor) {
            val durdurNiyeti = PendingIntent.getService(
                this, 1, Intent(this, EzanServisi::class.java).setAction(EYLEM_DURDUR),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            b.addAction(0, "Durdur", durdurNiyeti)
            if (ayar.getBoolean("tamEkran", true)) {
                b.setFullScreenIntent(acilisNiyeti, true)
            }
        }
        return b.build()
    }

    private fun onPlanaGec(bildirim: android.app.Notification) {
        val tur = if (Build.VERSION.SDK_INT >= 29) ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK else 0
        ServiceCompat.startForeground(this, BILDIRIM_ID, bildirim, tur)
    }

    private fun bildirimGuncelle(bildirim: android.app.Notification) {
        getSystemService(NotificationManager::class.java).notify(BILDIRIM_ID, bildirim)
    }

    override fun onDestroy() {
        oynatici?.release()
        oynatici = null
        durum = null
        super.onDestroy()
    }
}
