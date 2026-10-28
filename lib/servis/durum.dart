// Uygulamanın ortak durumu: seçili konum ve hangi vakitlerde bildirim geleceği.
// Değerler telefonda saklanır, uygulama kapanıp açılınca kaybolmaz.
// Bir şey değişince bu nesneyi dinleyen ekranlar kendini yeniler.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bildirim_servisi.dart';

/// Vakitlerin hesaplandığı konum.
class Konum {
  final String ad;
  final double enlem;
  final double boylam;
  final bool gps; // GPS ile mi bulundu, listeden mi seçildi
  const Konum(this.ad, this.enlem, this.boylam, {this.gps = false});
}

class UygulamaDurumu extends ChangeNotifier {
  late SharedPreferences _depo;
  Konum? konum;

  /// Her vakit için bildirim açık mı (sıra: imsak, güneş, öğle, ikindi, akşam, yatsı).
  /// Güneş namaz vakti olmadığı için başta kapalı.
  final List<bool> bildirimler = [true, false, true, true, true, true];

  /// Uygulama açılırken kayıtlı ayarları telefondan okur.
  Future<void> yukle() async {
    _depo = await SharedPreferences.getInstance();
    final ad = _depo.getString('konum_ad');
    final enlem = _depo.getDouble('konum_enlem');
    final boylam = _depo.getDouble('konum_boylam');
    if (ad != null && enlem != null && boylam != null) {
      konum = Konum(ad, enlem, boylam, gps: _depo.getBool('konum_gps') ?? false);
    }
    for (var i = 0; i < 6; i++) {
      bildirimler[i] = _depo.getBool('bildirim_$i') ?? bildirimler[i];
    }
  }

  /// Yeni konumu kaydeder ve bildirimleri yeni vakitlere göre baştan kurar.
  Future<void> konumAyarla(Konum yeni) async {
    konum = yeni;
    await _depo.setString('konum_ad', yeni.ad);
    await _depo.setDouble('konum_enlem', yeni.enlem);
    await _depo.setDouble('konum_boylam', yeni.boylam);
    await _depo.setBool('konum_gps', yeni.gps);
    notifyListeners();
    await BildirimServisi.planla();
  }

  /// Bir vaktin bildirimini açar ya da kapatır.
  Future<void> bildirimAyarla(int vakit, bool acik) async {
    bildirimler[vakit] = acik;
    await _depo.setBool('bildirim_$vakit', acik);
    notifyListeners();
    await BildirimServisi.planla();
  }
}

/// Uygulamanın her yerinden erişilen tek durum nesnesi.
final UygulamaDurumu durum = UygulamaDurumu();
