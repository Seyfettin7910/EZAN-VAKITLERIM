package com.seyfettin.ezan_vakitlerim

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

// Ana ekran widget'ları: küçük (2×2) ve orta (4×2).
// Vakitleri kendileri hesaplar; geri sayım Android'in kendi sayacıyla canlı akar,
// vakit değişince ve gece yarısı kendilerini yeniler.

class KucukWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, yonetici: AppWidgetManager, kimlikler: IntArray) {
        WidgetGuncelleyici.hepsiniGuncelle(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == WidgetGuncelleyici.EYLEM) WidgetGuncelleyici.hepsiniGuncelle(context)
        else super.onReceive(context, intent)
    }
}

class OrtaWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, yonetici: AppWidgetManager, kimlikler: IntArray) {
        WidgetGuncelleyici.hepsiniGuncelle(context)
    }
}

object WidgetGuncelleyici {
    const val EYLEM = "com.seyfettin.ezan_vakitlerim.WIDGET_GUNCELLE"
    private val saatBicimi = SimpleDateFormat("HH:mm", Locale("tr"))
    private val sutunlar = intArrayOf(R.id.w_s0, R.id.w_s1, R.id.w_s2, R.id.w_s3, R.id.w_s4, R.id.w_s5)
    private val adYazilari = intArrayOf(R.id.w_a0, R.id.w_a1, R.id.w_a2, R.id.w_a3, R.id.w_a4, R.id.w_a5)
    private val saatYazilari = intArrayOf(R.id.w_t0, R.id.w_t1, R.id.w_t2, R.id.w_t3, R.id.w_t4, R.id.w_t5)

    // Flutter konum değişince çağırır; widget'lar bu konuma göre hesaplar
    fun konumKaydet(context: Context, ad: String, enlem: Double, boylam: Double) {
        context.getSharedPreferences(EzanZamanlayici.DEPO, Context.MODE_PRIVATE).edit()
            .putString("w_ad", ad)
            .putString("w_enlem", enlem.toString())
            .putString("w_boylam", boylam.toString())
            .apply()
        hepsiniGuncelle(context)
    }

    // Ekrandaki bütün widget'ları yeniden çizer ve bir sonraki yenilemeyi kurar
    fun hepsiniGuncelle(context: Context) {
        val yonetici = AppWidgetManager.getInstance(context)
        val kucukler = yonetici.getAppWidgetIds(ComponentName(context, KucukWidget::class.java))
        val ortalar = yonetici.getAppWidgetIds(ComponentName(context, OrtaWidget::class.java))
        if (kucukler.isEmpty() && ortalar.isEmpty()) return

        val depo = context.getSharedPreferences(EzanZamanlayici.DEPO, Context.MODE_PRIVATE)
        val enlem = depo.getString("w_enlem", null)?.toDoubleOrNull()
        val boylam = depo.getString("w_boylam", null)?.toDoubleOrNull()
        val konumAdi = depo.getString("w_ad", "") ?: ""
        val acilis = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (enlem == null || boylam == null) {
            // Henüz konum seçilmemiş
            for (k in kucukler) {
                val g = RemoteViews(context.packageName, R.layout.widget_kucuk)
                g.setTextViewText(R.id.w_ad, "Ezan Vakitlerim")
                g.setTextViewText(R.id.w_saat, "--:--")
                g.setTextViewText(R.id.w_konum, "Konum seçmek için dokun")
                g.setOnClickPendingIntent(R.id.w_kok, acilis)
                yonetici.updateAppWidget(k, g)
            }
            for (k in ortalar) {
                val g = RemoteViews(context.packageName, R.layout.widget_orta)
                g.setTextViewText(R.id.w_baslik, "Konum seçmek için dokun")
                for (i in 0 until 6) {
                    g.setTextViewText(adYazilari[i], VakitHesap.adlar[i])
                    g.setTextViewText(saatYazilari[i], "--:--")
                    g.setInt(sutunlar[i], "setBackgroundResource", 0)
                }
                g.setOnClickPendingIntent(R.id.w_kok, acilis)
                yonetici.updateAppWidget(k, g)
            }
            return
        }

        val simdi = System.currentTimeMillis()
        val bugun = VakitHesap.gunun(simdi, enlem, boylam)
        var sira = bugun.indexOfFirst { it > simdi }
        val siradakiBugun = sira >= 0
        val siradakiZaman: Long
        if (siradakiBugun) {
            siradakiZaman = bugun[sira]
        } else {
            sira = 0
            siradakiZaman = VakitHesap.gunun(simdi, enlem, boylam, 1)[0]
        }
        // Sayaç "şu andan" değil "telefon açıldığından beri geçen süreden" sayar
        val sayacTabani = SystemClock.elapsedRealtime() + (siradakiZaman - simdi)
        val siradakiAd = VakitHesap.adlar[sira]
        val siradakiSaat = saatBicimi.format(siradakiZaman)

        for (k in kucukler) {
            val g = RemoteViews(context.packageName, R.layout.widget_kucuk)
            g.setTextViewText(R.id.w_ad, siradakiAd)
            g.setTextViewText(R.id.w_saat, siradakiSaat)
            g.setChronometer(R.id.w_kalan, sayacTabani, null, true)
            g.setChronometerCountDown(R.id.w_kalan, true)
            g.setTextViewText(R.id.w_konum, konumAdi)
            g.setOnClickPendingIntent(R.id.w_kok, acilis)
            yonetici.updateAppWidget(k, g)
        }

        for (k in ortalar) {
            val g = RemoteViews(context.packageName, R.layout.widget_orta)
            g.setTextViewText(R.id.w_baslik, "$siradakiAd $siradakiSaat")
            g.setChronometer(R.id.w_kalan, sayacTabani, "%s kaldı", true)
            g.setChronometerCountDown(R.id.w_kalan, true)
            // Yatsıdan sonra bugünün vakitleri bitti: yarının vakitleri gösterilir, imsak vurgulanır
            val gosterilen = if (siradakiBugun) bugun else VakitHesap.gunun(simdi, enlem, boylam, 1)
            for (i in 0 until 6) {
                g.setTextViewText(adYazilari[i], VakitHesap.adlar[i])
                g.setTextViewText(saatYazilari[i], saatBicimi.format(gosterilen[i]))
                val vurgu = i == sira
                g.setInt(sutunlar[i], "setBackgroundResource", if (vurgu) R.drawable.widget_siradaki else 0)
                val gecti = gosterilen[i] <= simdi
                // Geçen vakitler biraz açık ama hâlâ rahat okunur; gelecek vakitler koyu
                val renk = if (gecti) 0xFF4A5B58.toInt() else 0xFF0B2321.toInt()
                g.setTextColor(adYazilari[i], renk)
                g.setTextColor(saatYazilari[i], renk)
            }
            g.setOnClickPendingIntent(R.id.w_kok, acilis)
            yonetici.updateAppWidget(k, g)
        }

        // Sıradaki vakit girince ya da gece yarısı (hangisi önceyse) yeniden çiz
        val geceYarisi = Calendar.getInstance().apply {
            timeInMillis = simdi
            add(Calendar.DAY_OF_MONTH, 1)
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 5); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val sonraki = minOf(siradakiZaman + 1_000L, geceYarisi)
        val pi = PendingIntent.getBroadcast(
            context, 7100,
            Intent(context, KucukWidget::class.java).setAction(EYLEM),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // Telefonu uyandırmayan alarm: telefon uykudaysa ekran açılınca yeniler
        context.getSystemService(AlarmManager::class.java).set(AlarmManager.RTC, sonraki, pi)
    }
}
