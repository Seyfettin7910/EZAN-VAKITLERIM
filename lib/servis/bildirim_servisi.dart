// Vakit girince gelen bildirimleri kuran dosya.
// Önümüzdeki 14 günün vakitleri hesaplanıp her biri için Android'e "şu dakikada göster" denir.
// Telefon kapanıp açılsa da Android bunları hatırlar. Uygulama her açıldığında liste tazelenir.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_veri;
import 'package:timezone/timezone.dart' as tz;

import '../hesap/vakit_hesap.dart';
import '../yardimci.dart';
import 'durum.dart';
import 'yerel.dart';

class BildirimServisi {
  static final FlutterLocalNotificationsPlugin _eklenti = FlutterLocalNotificationsPlugin();
  static const int _gunSayisi = 14; // sesli ezan alarmları (Android tarafı, hafif)
  static const int _bildirimGunSayisi = 7; // normal bildirimler (her biri telefona yazıldığı için daha az gün)
  static Future<void> _zincir = Future.value(); // kurma işleri üst üste binmesin diye sıra
  static int _istekNo = 0;
  static bool _hazir = false; // bildirim sistemi sorunsuz başladı mı

  // Bildirimin görünüşü: yüksek öncelikli, sesli, kendi küçük simgemizle
  static const NotificationDetails _detay = NotificationDetails(
    android: AndroidNotificationDetails(
      'vakit_bildirim',
      'Vakit bildirimleri',
      channelDescription: 'Namaz vakti girince gelen bildirim',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_bildirim',
      color: Color(0xFF0F4C4A),
    ),
  );

  /// Bildirim sistemini hazırlar (uygulama açılırken bir kez çağrılır).
  /// Bir sorun çıkarsa uygulama yine açılır, sadece bildirimler çalışmaz.
  static Future<void> baslat() async {
    try {
      tz_veri.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      const ayar = InitializationSettings(android: AndroidInitializationSettings('ic_bildirim'));
      await _eklenti.initialize(settings: ayar).timeout(const Duration(seconds: 5));
      _hazir = true;
    } catch (hata) {
      debugPrint('Bildirim sistemi başlatılamadı: $hata');
    }
  }

  /// Android 13 ve üstünde kullanıcıdan bildirim izni ister.
  static Future<bool> izinIste() async {
    if (!_hazir) return false;
    try {
      final android = _eklenti.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final sonuc = await android?.requestNotificationsPermission();
      return sonuc ?? true;
    } catch (hata) {
      debugPrint('Bildirim izni istenemedi: $hata');
      return false;
    }
  }

  /// Eski bildirimleri siler, önümüzdeki günlerin bildirimlerini yeniden kurar.
  /// Aynı anda birden çok istek gelirse sırayla çalışır; sırada bekleyen eski istekler atlanır
  /// (en yenisi zaten son ayarlarla kuracak). Böylece işlemci boşuna yorulmaz.
  static Future<void> planla() {
    final no = ++_istekNo;
    final is_ = _zincir.then((_) => no == _istekNo ? _planlaSirayla() : null);
    _zincir = is_.catchError((_) {});
    return is_;
  }

  static Future<void> _planlaSirayla() async {
    // Widget'lar da aynı konuma göre hesaplasın
    final k = durum.konum;
    if (k != null) await Yerel.konumKaydet(k.ad, k.enlem, k.boylam);
    if (!_hazir) {
      // Bildirim sistemi açılamadıysa bile sesli ezan alarmları kurulabilir
      await _sadeceEzanlariKur();
      return;
    }
    try {
      await _planla();
    } catch (hata) {
      debugPrint('Bildirimler kurulamadı: $hata');
    }
  }

  // Bildirim sistemi çalışmadığında yalnızca sesli ezan alarmlarını kurar
  static Future<void> _sadeceEzanlariKur() async {
    final konum = durum.konum;
    if (konum == null || !durum.sesliEzan) return;
    final simdi = DateTime.now();
    final ezanlar = <Map<String, Object>>[];
    for (var g = 0; g < _gunSayisi; g++) {
      final v = VakitHesap.hesapla(DateTime(simdi.year, simdi.month, simdi.day + g), konum.enlem, konum.boylam);
      for (var i = 0; i < 6; i++) {
        final zaman = v.vakitler[i];
        if (i == 1 || !durum.bildirimler[i] || !zaman.isAfter(simdi)) continue;
        ezanlar.add({
          'zaman': zaman.millisecondsSinceEpoch,
          'vakit': i,
          'baslik': '${vakitAdlari[i]} vakti girdi',
          'metin': '${saatYaz(zaman)} · ${konum.ad}',
        });
      }      final t = VakitHesap.teheccud(DateTime(simdi.year, simdi.month, simdi.day + g), konum.enlem, konum.boylam);
      if (durum.teheccud && t.isAfter(simdi)) ezanlar.add(_teheccudOgesi(t, konum.ad));
    }
    await Yerel.ezanlariKur(ezanlar,
        dua: durum.duaOtomatik, sessizdeOku: durum.sessizdeOku, tamEkran: durum.tamEkran, sesSeviyesi: durum.ezanSesi, sesGuclendir: durum.sesGuclendir, teheccudSes: durum.teheccudSes);
  }

  // Asıl kurma işi (hatası planla() içinde yakalanır).
  // Zili açık vakitlerde: sesli ezan açıksa ezan alarmı, kapalıysa normal bildirim kurulur.
  // Hatırlatma seçiliyse vakitten X dakika önce ayrıca "... kaldı" bildirimi gelir.
  static Future<void> _planla() async {
    await _eklenti.cancelAll();
    final konum = durum.konum;
    if (konum == null) {
      await Yerel.ezanlariSil();
      return;
    }

    final simdi = DateTime.now();
    final ezanlar = <Map<String, Object>>[];
    var numara = 0;
    for (var g = 0; g < _gunSayisi; g++) {
      final gun = DateTime(simdi.year, simdi.month, simdi.day + g);
      final v = VakitHesap.hesapla(gun, konum.enlem, konum.boylam);
      for (var i = 0; i < 6; i++) {
        numara++;
        if (!durum.bildirimler[i]) continue;
        final zaman = v.vakitler[i];
        final baslik = i == 1 ? 'Güneş doğdu' : '${vakitAdlari[i]} vakti girdi';
        final metin = '${saatYaz(zaman)} · ${konum.ad}';

        final bildirimGunu = g < _bildirimGunSayisi;

        // Vakitten önce hatırlatma
        final dk = durum.hatirlatmaDk;
        final hatirlatmaZamani = zaman.subtract(Duration(minutes: dk));
        if (bildirimGunu && dk > 0 && hatirlatmaZamani.isAfter(simdi)) {
          await _eklenti.zonedSchedule(
            id: 1000 + numara,
            title: i == 1 ? 'Güneşin doğmasına $dk dakika kaldı' : '${vakitAdlari[i]} vaktine $dk dakika kaldı',
            body: '${vakitAdlari[i]} ${saatYaz(zaman)} · ${konum.ad}',
            scheduledDate: tz.TZDateTime.from(hatirlatmaZamani, tz.local),
            notificationDetails: _detay,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }

        if (!zaman.isAfter(simdi)) continue; // geçmiş vakit kurulmaz
        if (durum.sesliEzan && i != 1) {
          // Güneş dışındaki vakitlerde ezanı Android tarafındaki servis okur
          ezanlar.add({'zaman': zaman.millisecondsSinceEpoch, 'vakit': i, 'baslik': baslik, 'metin': metin});
        } else if (bildirimGunu) {
          await _eklenti.zonedSchedule(
            id: numara,
            title: baslik,
            body: metin,
            scheduledDate: tz.TZDateTime.from(zaman, tz.local),
            notificationDetails: _detay,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
      }

      // Teheccüd: bu günün sabahından önceki gecenin son üçte biri
      final t = VakitHesap.teheccud(gun, konum.enlem, konum.boylam);
      if (durum.teheccud && t.isAfter(simdi)) {
        if (durum.sesliEzan) {
          ezanlar.add(_teheccudOgesi(t, konum.ad));
        } else if (g < _bildirimGunSayisi) {
          await _eklenti.zonedSchedule(
            id: 3000 + g,
            title: 'Teheccüd vakti',
            body: 'Gecenin son üçte biri girdi · ${saatYaz(t)} · ${konum.ad}',
            scheduledDate: tz.TZDateTime.from(t, tz.local),
            notificationDetails: _detay,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
      }
    }
    await Yerel.ezanlariKur(ezanlar,
        dua: durum.duaOtomatik, sessizdeOku: durum.sessizdeOku, tamEkran: durum.tamEkran, sesSeviyesi: durum.ezanSesi, sesGuclendir: durum.sesGuclendir, teheccudSes: durum.teheccudSes);
  }

  // Teheccüd ezanı alarmı (Android tarafında 6 numaralı vakit olarak okunur, kendi ses seviyesiyle)
  static Map<String, Object> _teheccudOgesi(DateTime t, String yer) => {
        'zaman': t.millisecondsSinceEpoch,
        'vakit': 6,
        'baslik': 'Teheccüd vakti',
        'metin': 'Gecenin son üçte biri girdi · ${saatYaz(t)} · $yer',
      };
}
