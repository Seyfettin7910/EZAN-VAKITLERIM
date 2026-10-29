package com.seyfettin.ezan_vakitlerim

import java.util.Calendar
import kotlin.math.acos
import kotlin.math.asin
import kotlin.math.atan
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.sin
import kotlin.math.tan

// Widget'ların kullandığı vakit hesabı. Flutter tarafındaki lib/hesap/vakit_hesap.dart ile birebir aynıdır
// (Diyanet açıları: imsak 18°, yatsı 17°, aynı temkin düzeltmeleri). Böylece widget uygulama açılmasa da doğru kalır.
object VakitHesap {
    val adlar = arrayOf("İmsak", "Güneş", "Öğle", "İkindi", "Akşam", "Yatsı")
    private val duzeltme = doubleArrayOf(0.5, -6.5, 4.5, 3.0, 6.0, -1.0)
    private const val IMSAK_ACISI = 18.0
    private const val YATSI_ACISI = 17.0
    private const val TURKIYE_SAAT_FARKI = 3.0

    private fun r(d: Double) = Math.toRadians(d)
    private fun dSin(d: Double) = sin(r(d))
    private fun dCos(d: Double) = cos(r(d))
    private fun dTan(d: Double) = tan(r(d))
    private fun dAsin(x: Double) = Math.toDegrees(asin(x))
    private fun dAcos(x: Double) = Math.toDegrees(acos(x))
    private fun dAtan2(y: Double, x: Double) = Math.toDegrees(atan2(y, x))
    private fun aciDuzelt(a: Double) = a - 360.0 * floor(a / 360.0)
    private fun saatDuzelt(s: Double) = s - 24.0 * floor(s / 24.0)

    private fun julyenGun(yil0: Int, ay0: Int, gun: Int): Double {
        var yil = yil0
        var ay = ay0
        if (ay <= 2) { yil -= 1; ay += 12 }
        val a = floor(yil / 100.0)
        val b = 2 - a + floor(a / 4.0)
        return floor(365.25 * (yil + 4716)) + floor(30.6001 * (ay + 1)) + gun + b - 1524.5
    }

    // Güneşin eğimi (derece) ve zaman denklemi (saat)
    private fun gunes(jd: Double): Pair<Double, Double> {
        val d = jd - 2451545.0
        val g = aciDuzelt(357.529 + 0.98560028 * d)
        val q = aciDuzelt(280.459 + 0.98564736 * d)
        val l = aciDuzelt(q + 1.915 * dSin(g) + 0.020 * dSin(2 * g))
        val e = 23.439 - 0.00000036 * d
        val ra = dAtan2(dCos(e) * dSin(l), dCos(l)) / 15.0
        return Pair(dAsin(dSin(e) * dSin(l)), q / 15.0 - saatDuzelt(ra))
    }

    /** Verilen günün (yıl, ay, gün) altı vaktini, gece yarısından itibaren milisaniye olarak değil,
     *  doğrudan zaman damgası (epoch ms) olarak döndürür. */
    fun hesapla(yil: Int, ay: Int, gun: Int, enlem: Double, boylam: Double): LongArray {
        val jd = julyenGun(yil, ay, gun) - boylam / (15.0 * 24.0)
        fun ogle(t: Double) = saatDuzelt(12 - gunes(jd + t).second)
        fun aciAni(aci: Double, t: Double, once: Boolean): Double {
            val egim = gunes(jd + t).first
            var oran = (-dSin(aci) - dSin(egim) * dSin(enlem)) / (dCos(egim) * dCos(enlem))
            oran = oran.coerceIn(-1.0, 1.0)
            val fark = dAcos(oran) / 15.0
            return ogle(t) + if (once) -fark else fark
        }
        fun ikindi(t: Double): Double {
            val egim = gunes(jd + t).first
            val aci = -Math.toDegrees(atan(1.0 / (1.0 + dTan(Math.abs(enlem - egim)))))
            return aciAni(aci, t, false)
        }
        var s = doubleArrayOf(5.0, 6.0, 12.0, 13.0, 18.0, 18.0)
        repeat(2) {
            val t = s.map { it / 24.0 }
            s = doubleArrayOf(
                aciAni(IMSAK_ACISI, t[0], true), aciAni(0.833, t[1], true), ogle(t[2]),
                ikindi(t[3]), aciAni(0.833, t[4], false), aciAni(YATSI_ACISI, t[5], false)
            )
        }
        val gece = Calendar.getInstance().apply {
            clear()
            set(yil, ay - 1, gun, 0, 0, 0)
        }.timeInMillis
        return LongArray(6) { i ->
            val dakika = (s[i] + TURKIYE_SAAT_FARKI - boylam / 15.0) * 60.0 + duzeltme[i]
            gece + ceil(dakika).toLong() * 60_000L
        }
    }

    /** Bir zaman damgasının ait olduğu günün vakitleri. */
    fun gunun(zaman: Long, enlem: Double, boylam: Double, gunFarki: Int = 0): LongArray {
        val c = Calendar.getInstance().apply { timeInMillis = zaman; add(Calendar.DAY_OF_MONTH, gunFarki) }
        return hesapla(c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH), enlem, boylam)
    }
}
