package com.seyfettin.ezan_vakitlerim

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Uygulamanın tek ekranı. Flutter ile Android arasındaki köprüyü ("yerel" kanalı) burada kurar.
class MainActivity : FlutterActivity() {

    private var kanal: MethodChannel? = null
    private var bekleyenVakit: Int = -1 // tam ekran uyarıyla açıldıysa hangi vakit

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        tamEkranNiyeti(intent)?.let { bekleyenVakit = it }
    }

    // Uygulama zaten açıkken tam ekran uyarı gelirse Flutter'a haber verir
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        tamEkranNiyeti(intent)?.let { vakit ->
            bekleyenVakit = -1
            kanal?.invokeMethod("tamEkranAc", vakit)
        }
    }

    // Açılış isteği tam ekran uyarıdan geldiyse ekranı kilidin üstünde açar ve vakti döndürür
    private fun tamEkranNiyeti(niyet: Intent?): Int? {
        val vakit = niyet?.getIntExtra("tam_ekran_vakit", -1) ?: -1
        if (vakit < 0) return null
        niyet?.removeExtra("tam_ekran_vakit")
        kilitUstunde(true)
        return vakit
    }

    // Ekranı kilit ekranının üstünde gösterir ve ekranı yakar (ya da bunu geri alır)
    private fun kilitUstunde(acik: Boolean) {
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(acik)
            setTurnScreenOn(acik)
        } else {
            @Suppress("DEPRECATION")
            val bayraklar = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (acik) window.addFlags(bayraklar) else window.clearFlags(bayraklar)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val k = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ezan_vakitlerim/yerel")
        kanal = k
        k.setMethodCallHandler { cagri, sonuc ->
            try {
                when (cagri.method) {
                    // Ezan alarmlarını ve ezan ayarlarını kurar
                    "ezanlariKur" -> {
                        @Suppress("UNCHECKED_CAST")
                        val liste = cagri.argument<List<Map<String, Any?>>>("liste") ?: emptyList()
                        EzanZamanlayici.ayarla(
                            this,
                            cagri.argument<Boolean>("dua") ?: true,
                            cagri.argument<Boolean>("sessizdeOku") ?: false,
                            cagri.argument<Boolean>("tamEkran") ?: true
                        )
                        EzanZamanlayici.kur(this, liste)
                        sonuc.success(null)
                    }
                    "ezanlariSil" -> { EzanZamanlayici.sil(this); sonuc.success(null) }
                    "ezanDurumu" -> sonuc.success(mapOf("durum" to EzanServisi.durum, "vakit" to EzanServisi.calanVakit))
                    "ezanDurdur" -> { EzanServisi.durdur(this); sonuc.success(null) }
                    "sesiDene" -> {
                        EzanServisi.baslat(this, cagri.argument<Int>("vakit") ?: 3, "Ses denemesi", "Ezan sesi deneniyor")
                        sonuc.success(null)
                    }
                    "acilisVakti" -> { sonuc.success(bekleyenVakit); bekleyenVakit = -1 }
                    // Tam ekran uyarı kapatılınca: kilit üstü ayarını geri al, kilitliyse uygulamayı arkaya at
                    "kilitUstunuKapat" -> {
                        kilitUstunde(false)
                        val kilit = getSystemService(KeyguardManager::class.java)
                        if (kilit.isKeyguardLocked) moveTaskToBack(true)
                        sonuc.success(null)
                    }
                    "tamEkranIzniVar" -> {
                        val nm = getSystemService(NotificationManager::class.java)
                        sonuc.success(if (Build.VERSION.SDK_INT >= 34) nm.canUseFullScreenIntent() else true)
                    }
                    "tamEkranIzniAc" -> {
                        if (Build.VERSION.SDK_INT >= 34) {
                            startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName")))
                        }
                        sonuc.success(null)
                    }
                    "pilKisitlamasiYok" -> {
                        val pm = getSystemService(PowerManager::class.java)
                        sonuc.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "pilAyariAc" -> {
                        @Suppress("BatteryLife")
                        val niyet = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))
                        startActivity(niyet)
                        sonuc.success(null)
                    }
                    "kurulumIzniVar" -> {
                        sonuc.success(if (Build.VERSION.SDK_INT >= 26) packageManager.canRequestPackageInstalls() else true)
                    }
                    "kurulumIzniAc" -> {
                        if (Build.VERSION.SDK_INT >= 26) {
                            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                        }
                        sonuc.success(null)
                    }
                    // İndirilen güncelleme dosyasını Android'in kurulum ekranıyla açar
                    "apkKur" -> {
                        val dosya = File(cagri.argument<String>("yol")!!)
                        val adres = FileProvider.getUriForFile(this, "$packageName.dosyalar", dosya)
                        val niyet = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(adres, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(niyet)
                        sonuc.success(null)
                    }
                    "onbellekKlasoru" -> sonuc.success(cacheDir.absolutePath)
                    else -> sonuc.notImplemented()
                }
            } catch (e: Exception) {
                sonuc.error("hata", e.message, null)
            }
        }
    }
}
