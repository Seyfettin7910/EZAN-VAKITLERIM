package com.seyfettin.ezan_vakitlerim

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel

// Telefonun pusula sensöründen kuzeye göre yönü okur ve Flutter'a sürekli gönderir.
// Manyetik kuzey ile gerçek kuzey arasındaki fark (sapma) konuma göre düzeltilir.
class Pusula(private val context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val yonetici = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var akis: EventChannel.EventSink? = null
    private var sapma = 0f
    private var dogruluk = SensorManager.SENSOR_STATUS_ACCURACY_HIGH
    private var sonGonderim = 0L
    private val matris = FloatArray(9)
    private val yonler = FloatArray(3)

    // Flutter dinlemeye başlayınca sensörü açar
    override fun onListen(argumanlar: Any?, olaylar: EventChannel.EventSink) {
        akis = olaylar
        val a = argumanlar as? Map<*, *>
        val enlem = (a?.get("enlem") as? Number)?.toFloat()
        val boylam = (a?.get("boylam") as? Number)?.toFloat()
        if (enlem != null && boylam != null) {
            sapma = GeomagneticField(enlem, boylam, 0f, System.currentTimeMillis()).declination
        }
        val sensor = yonetici.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        if (sensor == null) {
            olaylar.error("sensor_yok", "Bu telefonda pusula sensörü yok", null)
            return
        }
        yonetici.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
    }

    // Flutter dinlemeyi bırakınca sensörü kapatır (pil için)
    override fun onCancel(argumanlar: Any?) {
        yonetici.unregisterListener(this)
        akis = null
    }

    override fun onSensorChanged(olay: SensorEvent) {
        val simdi = System.currentTimeMillis()
        if (simdi - sonGonderim < 50) return // saniyede en fazla 20 kez
        sonGonderim = simdi
        SensorManager.getRotationMatrixFromVector(matris, olay.values)
        SensorManager.getOrientation(matris, yonler)
        var aci = Math.toDegrees(yonler[0].toDouble()) + sapma
        aci = (aci % 360 + 360) % 360
        akis?.success(mapOf("aci" to aci, "dogruluk" to dogruluk))
    }

    override fun onAccuracyChanged(sensor: Sensor, deger: Int) {
        dogruluk = deger
    }
}
