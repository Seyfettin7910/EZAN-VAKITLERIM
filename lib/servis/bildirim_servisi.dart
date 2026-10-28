// Vakit girince gelen bildirimleri kuran dosya.
// Önümüzdeki 14 günün vakitleri hesaplanıp her biri için Android'e "şu dakikada göster" denir.
// Telefon kapanıp açılsa da Android bunları hatırlar. Uygulama her açıldığında liste tazelenir.

import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_veri;
import 'package:timezone/timezone.dart' as tz;

import '../hesap/vakit_hesap.dart';
import '../yardimci.dart';
import 'durum.dart';

class BildirimServisi {
  static final FlutterLocalNotificationsPlugin _eklenti = FlutterLocalNotificationsPlugin();
  static const int _gunSayisi = 14;

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
  static Future<void> baslat() async {
    tz_veri.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    const ayar = InitializationSettings(android: AndroidInitializationSettings('ic_bildirim'));
    await _eklenti.initialize(settings: ayar);
  }

  /// Android 13 ve üstünde kullanıcıdan bildirim izni ister.
  static Future<bool> izinIste() async {
    final android = _eklenti.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final sonuc = await android?.requestNotificationsPermission();
    return sonuc ?? true;
  }

  /// Eski bildirimleri siler, önümüzdeki günlerin bildirimlerini yeniden kurar.
  static Future<void> planla() async {
    await _eklenti.cancelAll();
    final konum = durum.konum;
    if (konum == null) return;

    final simdi = DateTime.now();
    var numara = 0;
    for (var g = 0; g < _gunSayisi; g++) {
      final gun = DateTime(simdi.year, simdi.month, simdi.day + g);
      final v = VakitHesap.hesapla(gun, konum.enlem, konum.boylam);
      for (var i = 0; i < 6; i++) {
        numara++;
        if (!durum.bildirimler[i]) continue;
        final zaman = v.vakitler[i];
        if (!zaman.isAfter(simdi)) continue; // geçmiş vakit kurulmaz
        await _eklenti.zonedSchedule(
          id: numara,
          title: i == 1 ? 'Güneş doğdu' : '${vakitAdlari[i]} vakti girdi',
          body: '${saatYaz(zaman)} · ${konum.ad}',
          scheduledDate: tz.TZDateTime.from(zaman, tz.local),
          notificationDetails: _detay,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }
}
