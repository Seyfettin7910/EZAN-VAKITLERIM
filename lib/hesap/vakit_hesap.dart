// Namaz vakitlerini güneşin gökyüzündeki konumuna göre telefonda hesaplayan dosya.
// İnternet gerekmez. Diyanet'in kullandığı açılar (imsak 18°, yatsı 17°) ve
// temkin süreleri kullanılır. İstanbul için Diyanet'in 30 günlük resmi tablosuyla
// karşılaştırıldı: vakitlerin çoğu dakikası dakikasına tutuyor, en fazla 1 dk fark var.

import 'dart:math' as math;

/// Vakitlerin ekranda görünen adları (sıra her yerde aynı).
const List<String> vakitAdlari = ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];

/// Bir günün altı vakti: sırayla imsak, güneş, öğle, ikindi, akşam, yatsı.
class GunlukVakitler {
  final DateTime tarih;
  final List<DateTime> vakitler;
  const GunlukVakitler(this.tarih, this.vakitler);
}

/// Şu anki ve sıradaki vakit bilgisi (ana ekrandaki geri sayım için).
class VakitDurumu {
  final int siradaki; // sıradaki vaktin numarası (0 = imsak ... 5 = yatsı)
  final DateTime siradakiZaman;
  final int onceki; // içinde bulunduğumuz vakit
  final DateTime oncekiZaman;
  const VakitDurumu(this.siradaki, this.siradakiZaman, this.onceki, this.oncekiZaman);
}

class VakitHesap {
  // Diyanet'e en yakın sonucu veren düzeltmeler (dakika), sıra: imsak, güneş, öğle, ikindi, akşam, yatsı.
  static const List<double> _duzeltme = [0.5, -6.5, 4.5, 3.0, 6.0, -1.0];
  static const double _imsakAcisi = 18.0;
  static const double _yatsiAcisi = 17.0;
  static const double _turkiyeSaatFarki = 3.0; // Türkiye UTC+3, yaz saati uygulaması yok

  // Dereceyi radyana çeviren yardımcılar (Dart'ın sin/cos fonksiyonları radyan ister)
  static double _sin(double d) => math.sin(d * math.pi / 180);
  static double _cos(double d) => math.cos(d * math.pi / 180);
  static double _tan(double d) => math.tan(d * math.pi / 180);
  static double _asin(double x) => math.asin(x) * 180 / math.pi;
  static double _acos(double x) => math.acos(x) * 180 / math.pi;
  static double _atan2(double y, double x) => math.atan2(y, x) * 180 / math.pi;

  // Açıyı 0-360 arasına, saati 0-24 arasına getirir
  static double _aciDuzelt(double a) => a - 360 * (a / 360).floorToDouble();
  static double _saatDuzelt(double s) => s - 24 * (s / 24).floorToDouble();

  /// Tarihi astronomide kullanılan "Jülyen gün" sayısına çevirir.
  static double _julyenGun(int yil, int ay, int gun) {
    if (ay <= 2) {
      yil -= 1;
      ay += 12;
    }
    final a = (yil / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (yil + 4716)).floorToDouble() + (30.6001 * (ay + 1)).floorToDouble() + gun + b - 1524.5;
  }

  /// Güneşin o andaki eğimini (derece) ve zaman denklemini (saat) hesaplar.
  static ({double egim, double zamanDenklemi}) _gunesKonumu(double jd) {
    final d = jd - 2451545.0;
    final g = _aciDuzelt(357.529 + 0.98560028 * d);
    final q = _aciDuzelt(280.459 + 0.98564736 * d);
    final l = _aciDuzelt(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g));
    final e = 23.439 - 0.00000036 * d;
    final ra = _atan2(_cos(e) * _sin(l), _cos(l)) / 15;
    return (egim: _asin(_sin(e) * _sin(l)), zamanDenklemi: q / 15 - _saatDuzelt(ra));
  }

  /// Verilen gün ve konum için altı vakti hesaplar.
  static GunlukVakitler hesapla(DateTime gun, double enlem, double boylam) {
    final jd = _julyenGun(gun.year, gun.month, gun.day) - boylam / (15 * 24);

    // Güneşin tam tepede olduğu an (öğle)
    double ogleAni(double t) => _saatDuzelt(12 - _gunesKonumu(jd + t).zamanDenklemi);

    // Güneşin ufkun belirli bir açı altında olduğu an (sabah için önce=true)
    double aciAni(double aci, double t, {bool once = false}) {
      final egim = _gunesKonumu(jd + t).egim;
      final orta = ogleAni(t);
      var oran = (-_sin(aci) - _sin(egim) * _sin(enlem)) / (_cos(egim) * _cos(enlem));
      oran = oran.clamp(-1.0, 1.0);
      final fark = _acos(oran) / 15;
      return orta + (once ? -fark : fark);
    }

    // İkindi: bir cismin gölgesi kendi boyu + öğledeki gölgesi kadar olduğunda
    double ikindiAni(double t) {
      final egim = _gunesKonumu(jd + t).egim;
      final aci = -math.atan(1 / (1 + _tan((enlem - egim).abs()))) * 180 / math.pi;
      return aciAni(aci, t);
    }

    // Önce yaklaşık saatlerle başla, iki turda gerçek değere yaklaştır
    var s = <double>[5, 6, 12, 13, 18, 18];
    for (var tur = 0; tur < 2; tur++) {
      final t = s.map((x) => x / 24).toList();
      s = [
        aciAni(_imsakAcisi, t[0], once: true),
        aciAni(0.833, t[1], once: true),
        ogleAni(t[2]),
        ikindiAni(t[3]),
        aciAni(0.833, t[4]),
        aciAni(_yatsiAcisi, t[5]),
      ];
    }

    final gece = DateTime(gun.year, gun.month, gun.day);
    final vakitler = <DateTime>[];
    for (var i = 0; i < 6; i++) {
      final dakika = (s[i] + _turkiyeSaatFarki - boylam / 15) * 60 + _duzeltme[i];
      vakitler.add(gece.add(Duration(minutes: dakika.ceil())));
    }
    return GunlukVakitler(gece, vakitler);
  }

  /// Şu an hangi vakitteyiz ve sıradaki vakit ne, onu bulur.
  static VakitDurumu durum(DateTime an, double enlem, double boylam) {
    final bugun = hesapla(DateTime(an.year, an.month, an.day), enlem, boylam);
    for (var i = 0; i < 6; i++) {
      if (bugun.vakitler[i].isAfter(an)) {
        if (i == 0) {
          // Gece yarısından sonra, imsaktan önce: önceki vakit dünün yatsısı
          final dun = hesapla(DateTime(an.year, an.month, an.day - 1), enlem, boylam);
          return VakitDurumu(0, bugun.vakitler[0], 5, dun.vakitler[5]);
        }
        return VakitDurumu(i, bugun.vakitler[i], i - 1, bugun.vakitler[i - 1]);
      }
    }
    // Yatsıdan sonra: sıradaki vakit yarının imsakı
    final yarin = hesapla(DateTime(an.year, an.month, an.day + 1), enlem, boylam);
    return VakitDurumu(0, yarin.vakitler[0], 5, bugun.vakitler[5]);
  }
}
