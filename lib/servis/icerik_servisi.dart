// Ayet ve hadis içeriği: her vakit için bir ayet grubu ve bir hadis seçer.
//  - Seçme ayetler ve hadisler uygulamanın içinde (assets/icerik), kaynaklarından birebir çekilmiş halde durur.
//  - Hatim modunda rükûlar internetten (AlQuran Cloud, Diyanet meali) çekilir ve telefonda saklanır.
//  - Önceki / sonraki ayet de internetten çekilir.

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../hesap/vakit_hesap.dart';
import '../veri/sureler.dart';
import 'ag.dart';
import 'durum.dart';

/// Tek bir ayet: numarası, Arapçası ve Diyanet meali.
class Ayet {
  final int no;
  final String ar;
  final String tr;
  const Ayet(this.no, this.ar, this.tr);
  factory Ayet.json(Map<String, dynamic> j) => Ayet(j['no'] as int, j['ar'] as String, j['tr'] as String);
  Map<String, dynamic> json() => {'no': no, 'ar': ar, 'tr': tr};
}

/// Anlam bütünlüğü olan ardışık ayetler (bir seçme grup ya da bir rükû).
class AyetGrubu {
  final int sure;
  final int bas;
  final int son;
  final String? konu;
  final List<Ayet> ayetler;
  const AyetGrubu(this.sure, this.bas, this.son, this.konu, this.ayetler);

  String get sureAdi => sureAdlari[sure - 1];

  /// Örn. "Mü'minûn 23/1-11"
  String get baslik => bas == son ? '$sureAdi $sure/$bas' : '$sureAdi $sure/$bas-$son';

  factory AyetGrubu.json(Map<String, dynamic> j) => AyetGrubu(
        j['sure'] as int,
        j['bas'] as int,
        j['son'] as int,
        j['konu'] as String?,
        (j['ayetler'] as List).map((a) => Ayet.json(a as Map<String, dynamic>)).toList(),
      );
  Map<String, dynamic> json() =>
      {'sure': sure, 'bas': bas, 'son': son, 'konu': konu, 'ayetler': ayetler.map((a) => a.json()).toList()};

  /// Başına ya da sonuna bir ayet eklenmiş yeni grup (önceki/sonraki ayet için).
  AyetGrubu ekle(Ayet ayet) => ayet.no < bas
      ? AyetGrubu(sure, ayet.no, son, konu, [ayet, ...ayetler])
      : AyetGrubu(sure, bas, ayet.no, konu, [...ayetler, ayet]);
}

/// Bir hadis: anlamı, kaynağı ve açıklaması (HadeethEnc).
class Hadis {
  final String baslik;
  final String metin;
  final String aciklama;
  final String kaynak;
  final String derece;
  const Hadis(this.baslik, this.metin, this.aciklama, this.kaynak, this.derece);
  factory Hadis.json(Map<String, dynamic> j) => Hadis(
        (j['baslik'] ?? '') as String,
        (j['metin'] ?? '') as String,
        (j['aciklama'] ?? '') as String,
        (j['kaynak'] ?? '') as String,
        (j['derece'] ?? '') as String,
      );
}

class IcerikServisi {
  static List<AyetGrubu> _secme = [];
  static List<Hadis> _hadisler = [];

  /// Uygulama açılırken içindeki ayet ve hadis dosyalarını okur.
  static Future<void> yukle() async {
    try {
      final a = jsonDecode(await rootBundle.loadString('assets/icerik/ayetler.json')) as List;
      _secme = a.map((x) => AyetGrubu.json(x as Map<String, dynamic>)).toList();
      final h = jsonDecode(await rootBundle.loadString('assets/icerik/hadisler.json')) as List;
      _hadisler = h.map((x) => Hadis.json(x as Map<String, dynamic>)).toList();
    } catch (hata) {
      debugPrint('İçerik okunamadı: $hata');
    }
  }

  /// Her vaktin kendi sıra numarası: gün sayısı × 6 + vakit (0 = imsak … 5 = yatsı).
  static int slot(DateTime gun, int vakit) {
    final gunNo = DateTime.utc(gun.year, gun.month, gun.day).difference(DateTime.utc(2024, 1, 1)).inDays;
    return gunNo * 6 + vakit;
  }

  /// İçinde bulunduğumuz vaktin sıra numarası.
  static int simdikiSlot() {
    final k = durum.konum;
    final simdi = DateTime.now();
    if (k == null) return slot(simdi, 0);
    final d = VakitHesap.durum(simdi, k.enlem, k.boylam);
    return slot(d.oncekiZaman, d.onceki);
  }

  // Aynı konular art arda gelmesin diye listeyi karıştırarak dolaşır (her öğe döngüde bir kez gelir)
  static int _sira(int slot, int uzunluk) => ((slot * 7919) % uzunluk + uzunluk) % uzunluk;

  static Hadis? hadis(int slot) => _hadisler.isEmpty ? null : _hadisler[_sira(slot, _hadisler.length)];

  static AyetGrubu? _secmeAyet(int slot) => _secme.isEmpty ? null : _secme[_sira(slot, _secme.length)];

  /// Hatim modunda bu vaktin rükû numarası (1 … 556).
  static int rukuNo(int slot) => ((slot - durum.hatimBaslangic) % rukuSayisi + rukuSayisi) % rukuSayisi + 1;

  /// Bu vaktin ayet grubu. Hatim modunda rükû internetten gelir; gelmezse seçme ayet gösterilir.
  static Future<AyetGrubu?> ayet(int slot) async {
    if (durum.ayetModu == 'hatim') {
      final r = await ruku(rukuNo(slot));
      if (r != null) return r;
    }
    return _secmeAyet(slot);
  }

  /// Bir rükûyu önce telefonda arar, yoksa internetten indirip saklar.
  static Future<AyetGrubu?> ruku(int no) async {
    final depo = await SharedPreferences.getInstance();
    final kayitli = depo.getString('ruku_$no');
    if (kayitli != null) return AyetGrubu.json(jsonDecode(kayitli) as Map<String, dynamic>);
    try {
      final ar = await jsonGetir(Uri.parse('https://api.alquran.cloud/v1/ruku/$no/quran-uthmani'));
      final tr = await jsonGetir(Uri.parse('https://api.alquran.cloud/v1/ruku/$no/tr.diyanet'));
      final arA = (ar['data']['ayahs'] as List);
      final trA = (tr['data']['ayahs'] as List);
      if (arA.isEmpty || arA.length != trA.length) return null;
      final sure = arA.first['surah']['number'] as int;
      final ayetler = <Ayet>[];
      for (var i = 0; i < arA.length; i++) {
        final n = arA[i]['numberInSurah'] as int;
        ayetler.add(Ayet(n, _besmelesiz(sure, n, arA[i]['text'] as String), (trA[i]['text'] as String).trim()));
      }
      final grup = AyetGrubu(sure, ayetler.first.no, ayetler.last.no, null, ayetler);
      await depo.setString('ruku_$no', jsonEncode(grup.json()));
      return grup;
    } catch (hata) {
      debugPrint('Rükû $no indirilemedi: $hata');
      return null;
    }
  }

  /// Hatim modundaysa önümüzdeki 2 günün rükûlarını önceden indirir (internet yokken de okunsun).
  static Future<void> hatimOncedenIndir() async {
    if (durum.ayetModu != 'hatim') return;
    final s = simdikiSlot();
    for (var i = 0; i < 12; i++) {
      await ruku(rukuNo(s + i));
    }
  }

  /// Tek bir ayeti internetten çeker (önceki / sonraki ayet için).
  static Future<Ayet> tekAyet(int sure, int no) async {
    final j = await jsonGetir(Uri.parse('https://api.alquran.cloud/v1/ayah/$sure:$no/editions/quran-uthmani,tr.diyanet'));
    final liste = j['data'] as List;
    String metin(String baski) =>
        (liste.firstWhere((b) => b['edition']['identifier'] == baski)['text'] as String).trim();
    return Ayet(no, _besmelesiz(sure, no, metin('quran-uthmani')), metin('tr.diyanet'));
  }

  // Sûrelerin 1. ayetinin başındaki besmele ayetten sayılmaz (Fâtiha hariç).
  // Kaynak besmeleyi farklı harf biçimleriyle yazabildiği için ilk dört kelime atılır.
  static String _besmelesiz(int sure, int no, String metin) {
    metin = metin.replaceAll('\uFEFF', '').trim();
    if (no == 1 && sure != 1 && metin.startsWith('بِسْمِ')) {
      return metin.split(RegExp(r'\s+')).skip(4).join(' ');
    }
    return metin;
  }
}
