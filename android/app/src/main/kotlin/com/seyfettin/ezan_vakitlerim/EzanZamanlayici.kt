package com.seyfettin.ezan_vakitlerim

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

// Ezan alarmlarını Android'in alarm sistemine kuran, silen ve telefon açılınca yeniden kuran yardımcı.
// Liste telefonda saklanır; telefon yeniden başlayınca buradan okunup alarmlar tekrar kurulur.
object EzanZamanlayici {
    const val DEPO = "ezan_zamanlayici"
    const val EYLEM = "com.seyfettin.ezan_vakitlerim.EZAN_VAKTI"
    private const val ANAHTAR_LISTE = "liste"
    private const val ANAHTAR_SAYI = "sayi"

    // Ezan ayarlarını (dua, sessizde oku, tam ekran, ses seviyesi, güçlendirme) saklar; servis çalarken bunları okur
    fun ayarla(context: Context, dua: Boolean, sessizdeOku: Boolean, tamEkran: Boolean, sesSeviyesi: Int, sesGuclendir: Boolean) {
        context.getSharedPreferences(DEPO, Context.MODE_PRIVATE).edit()
            .putInt("sesSeviyesi", sesSeviyesi)
            .putBoolean("sesGuclendir", sesGuclendir)
            .putBoolean("dua", dua)
            .putBoolean("sessizdeOku", sessizdeOku)
            .putBoolean("tamEkran", tamEkran)
            .apply()
    }

    // Flutter'dan gelen ezan listesini kaydeder ve alarmları baştan kurar
    fun kur(context: Context, liste: List<Map<String, Any?>>) {
        sil(context)
        val dizi = JSONArray()
        for (oge in liste) {
            val j = JSONObject()
            j.put("zaman", (oge["zaman"] as Number).toLong())
            j.put("vakit", (oge["vakit"] as Number).toInt())
            j.put("baslik", oge["baslik"] as String)
            j.put("metin", oge["metin"] as String)
            dizi.put(j)
        }
        context.getSharedPreferences(DEPO, Context.MODE_PRIVATE).edit()
            .putString(ANAHTAR_LISTE, dizi.toString())
            .apply()
        alarmlariKur(context, dizi)
    }

    // Telefon açılınca ya da uygulama güncellenince kayıtlı listeden alarmları yeniden kurar
    fun yenidenKur(context: Context) {
        val metin = context.getSharedPreferences(DEPO, Context.MODE_PRIVATE).getString(ANAHTAR_LISTE, null) ?: return
        alarmlariKur(context, JSONArray(metin))
    }

    // Kurulu bütün ezan alarmlarını iptal eder
    fun sil(context: Context) {
        val depo = context.getSharedPreferences(DEPO, Context.MODE_PRIVATE)
        val am = context.getSystemService(AlarmManager::class.java)
        val sayi = maxOf(depo.getInt(ANAHTAR_SAYI, 0), 100)
        for (i in 0 until sayi) {
            val pi = PendingIntent.getBroadcast(
                context, i, Intent(context, EzanAlici::class.java).setAction(EYLEM),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pi != null) {
                am.cancel(pi)
                pi.cancel()
            }
        }
        depo.edit().putInt(ANAHTAR_SAYI, 0).apply()
    }

    // Listedeki gelecek her vakit için "tam zamanında uyandır" alarmı kurar
    private fun alarmlariKur(context: Context, dizi: JSONArray) {
        val am = context.getSystemService(AlarmManager::class.java)
        val simdi = System.currentTimeMillis()
        for (i in 0 until dizi.length()) {
            val j = dizi.getJSONObject(i)
            val zaman = j.getLong("zaman")
            if (zaman <= simdi) continue
            val niyet = Intent(context, EzanAlici::class.java)
                .setAction(EYLEM)
                .putExtra("vakit", j.getInt("vakit"))
                .putExtra("baslik", j.getString("baslik"))
                .putExtra("metin", j.getString("metin"))
            val pi = PendingIntent.getBroadcast(
                context, i, niyet,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            try {
                if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, zaman, pi)
                } else {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, zaman, pi)
                }
            } catch (e: SecurityException) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, zaman, pi)
            }
        }
        context.getSharedPreferences(DEPO, Context.MODE_PRIVATE).edit()
            .putInt(ANAHTAR_SAYI, dizi.length())
            .apply()
    }

    // Deneme için: birkaç saniye sonrasına tek bir ezan alarmı kurar (gerçek alarm yolunu dener)
    fun denemeKur(context: Context, vakit: Int, saniyeSonra: Int) {
        val am = context.getSystemService(AlarmManager::class.java)
        val niyet = Intent(context, EzanAlici::class.java)
            .setAction(EYLEM + ".DENEME")
            .putExtra("vakit", vakit)
            .putExtra("baslik", "Ses denemesi")
            .putExtra("metin", "Ezan sesi deneniyor")
        val pi = PendingIntent.getBroadcast(
            context, 9999, niyet,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val zaman = System.currentTimeMillis() + saniyeSonra * 1000L
        try {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, zaman, pi)
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, zaman, pi)
        }
    }
}
