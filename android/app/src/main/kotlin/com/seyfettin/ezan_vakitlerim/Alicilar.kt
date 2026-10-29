package com.seyfettin.ezan_vakitlerim

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

// Vakit alarmı çalınca Android bu alıcıyı uyandırır; o da ezanı okuyan servisi başlatır.
class EzanAlici : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        EzanServisi.baslat(
            context,
            intent.getIntExtra("vakit", 2),
            intent.getStringExtra("baslik") ?: "Vakit girdi",
            intent.getStringExtra("metin") ?: ""
        )
    }
}

// Telefon açılınca, saat değişince ya da uygulama güncellenince ezan alarmlarını yeniden kurar.
class AcilisAlici : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        EzanZamanlayici.yenidenKur(context)
    }
}

// Sadece bilgisayardan (adb) deneme için: birkaç saniye sonra ezan alarmı kurar.
// Manifest'te DUMP iznine bağlı; telefondaki başka uygulamalar bunu tetikleyemez.
class DenemeAlici : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        EzanZamanlayici.denemeKur(context, intent.getIntExtra("vakit", 3), intent.getIntExtra("saniye", 5))
    }
}
