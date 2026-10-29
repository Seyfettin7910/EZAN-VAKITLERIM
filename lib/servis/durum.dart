// Uygulamanın ortak durumu: seçili konum, bildirim ve ezan ayarları.
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

/// "Vakitten önce hatırlat" seçenekleri (dakika, 0 = kapalı).
const List<int> hatirlatmaSecenekleri = [0, 10, 15, 30, 45];

class UygulamaDurumu extends ChangeNotifier {
  late SharedPreferences _depo;
  Konum? konum;

  /// Her vakit için uyarı açık mı (sıra: imsak, güneş, öğle, ikindi, akşam, yatsı).
  /// Güneş namaz vakti olmadığı için başta kapalı.
  final List<bool> bildirimler = [true, false, true, true, true, true];

  bool sesliEzan = true; // zili açık vakitlerde ezan okunsun
  bool duaOtomatik = true; // ezan bitince ezan duası okunsun
  bool tamEkran = true; // vakit girince tam ekran uyarı açılsın
  bool sessizdeOku = false; // telefon sessizdeyken de ezan okunsun
  int hatirlatmaDk = 0; // vakitten kaç dakika önce hatırlatılsın
  bool otomatikGuncelle = true; // açılışta yeni sürüm denetlensin

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
    sesliEzan = _depo.getBool('sesli_ezan') ?? sesliEzan;
    duaOtomatik = _depo.getBool('dua_otomatik') ?? duaOtomatik;
    tamEkran = _depo.getBool('tam_ekran') ?? tamEkran;
    sessizdeOku = _depo.getBool('sessizde_oku') ?? sessizdeOku;
    hatirlatmaDk = _depo.getInt('hatirlatma_dk') ?? hatirlatmaDk;
    otomatikGuncelle = _depo.getBool('otomatik_guncelle') ?? otomatikGuncelle;
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

  /// Bir vaktin uyarısını (bildirim / ezan) açar ya da kapatır.
  Future<void> bildirimAyarla(int vakit, bool acik) async {
    bildirimler[vakit] = acik;
    await _depo.setBool('bildirim_$vakit', acik);
    notifyListeners();
    await BildirimServisi.planla();
  }

  /// Ezan ve uyarı ayarlarından birini değiştirir, kaydeder ve uyarıları yeniden kurar.
  Future<void> ezanAyarla({bool? sesli, bool? dua, bool? tam, bool? sessiz, int? hatirlatma}) async {
    if (sesli != null) {
      sesliEzan = sesli;
      await _depo.setBool('sesli_ezan', sesli);
    }
    if (dua != null) {
      duaOtomatik = dua;
      await _depo.setBool('dua_otomatik', dua);
    }
    if (tam != null) {
      tamEkran = tam;
      await _depo.setBool('tam_ekran', tam);
    }
    if (sessiz != null) {
      sessizdeOku = sessiz;
      await _depo.setBool('sessizde_oku', sessiz);
    }
    if (hatirlatma != null) {
      hatirlatmaDk = hatirlatma;
      await _depo.setInt('hatirlatma_dk', hatirlatma);
    }
    notifyListeners();
    await BildirimServisi.planla();
  }

  /// Otomatik güncelleme denetimini açar/kapatır.
  Future<void> otomatikGuncelleAyarla(bool acik) async {
    otomatikGuncelle = acik;
    await _depo.setBool('otomatik_guncelle', acik);
    notifyListeners();
  }

  // Güncelleme denetiminin ve "yenilikler" penceresinin hatırladığı küçük değerler
  int get sonDenetim => _depo.getInt('son_guncelleme_denetimi') ?? 0;
  Future<void> sonDenetimKaydet(int ms) => _depo.setInt('son_guncelleme_denetimi', ms);
  int get sonGorulenDerleme => _depo.getInt('son_gorulen_derleme') ?? 0;
  Future<void> sonGorulenDerlemeKaydet(int no) => _depo.setInt('son_gorulen_derleme', no);
}

/// Uygulamanın her yerinden erişilen tek durum nesnesi.
final UygulamaDurumu durum = UygulamaDurumu();
