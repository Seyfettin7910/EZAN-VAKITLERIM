// Yakındaki camileri OpenStreetMap'ten (Overpass) bulur, yürüyüş yolunu hesaplatır.
// Sunucu meşgulse sıradaki yedek sunucuya sorar; hiçbiri cevap vermezse en son bulunan liste gösterilir.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ag.dart';

class Cami {
  final String ad;
  final double enlem;
  final double boylam;
  final double metre; // aramanın yapıldığı yere uzaklık
  const Cami(this.ad, this.enlem, this.boylam, this.metre);

  LatLng get nokta => LatLng(enlem, boylam);
  String get uzaklik => mesafeYaz(metre);
}

/// "850 m" ya da "1,4 km" biçiminde yazar.
String mesafeYaz(double metre) =>
    metre < 1000 ? '${metre.round()} m' : '${(metre / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

/// İki nokta arası kuş uçuşu uzaklık (metre).
double uzaklikMetre(double e1, double b1, double e2, double b2) {
  const r = 6371000.0;
  final f1 = e1 * math.pi / 180, f2 = e2 * math.pi / 180;
  final df = (e2 - e1) * math.pi / 180, dl = (b2 - b1) * math.pi / 180;
  final a = math.pow(math.sin(df / 2), 2) + math.cos(f1) * math.cos(f2) * math.pow(math.sin(dl / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Bir cami aramasının sonucu.
class CamiSonucu {
  final double enlem, boylam; // aramanın merkezi
  final int yaricap; // metre
  final bool gps; // merkez canlı konum mu, seçili konum mu
  final List<Cami> camiler;
  final DateTime zaman;
  final bool eski; // internete ulaşılamadı, en son bulunan liste
  const CamiSonucu(this.enlem, this.boylam, this.yaricap, this.gps, this.camiler, this.zaman, {this.eski = false});
}

/// Hiçbir sunucu cevap vermediğinde fırlatılır; [internetYok] ise telefon internete hiç çıkamadı.
class CamiHatasi implements Exception {
  final bool internetYok;
  const CamiHatasi(this.internetYok);
}

/// Yürüyüş yolu: çizgi noktaları, uzunluk (m) ve süre (sn).
class YuruyusYolu {
  final List<LatLng> noktalar;
  final double metre;
  final double saniye;
  const YuruyusYolu(this.noktalar, this.metre, this.saniye);

  String get ozet => '${mesafeYaz(metre)} · yürüyerek ${(saniye / 60).ceil()} dk';
}

class CamiServisi {
  // Aynı OpenStreetMap verisini veren sunucular; ilki meşgulse sıradakine sorulur
  static const _sunucular = [
    'overpass-api.de',
    'overpass.private.coffee',
    'overpass.kumi.systems',
    'maps.mail.ru',
  ];
  static const _sunucuYollari = {'maps.mail.ru': '/osm/tools/overpass/api/interpreter'};
  static const _sonListeAnahtari = 'son_camiler';

  /// Yakındaki camileri arar; 3 km içinde yoksa 10 km'ye genişletir.
  /// İnternete ulaşılamazsa en son bulunan listeyi ([CamiSonucu.eski]) döndürür, o da yoksa [CamiHatasi] fırlatır.
  static Future<CamiSonucu> ara(double enlem, double boylam, {required bool gps}) async {
    try {
      var yaricap = 3000;
      var liste = await _overpass(enlem, boylam, yaricap);
      if (liste.isEmpty) {
        yaricap = 10000;
        liste = await _overpass(enlem, boylam, yaricap);
      }
      final sonuc = CamiSonucu(enlem, boylam, yaricap, gps, liste, DateTime.now());
      await _sakla(sonuc);
      return sonuc;
    } on CamiHatasi {
      final eski = await _sonListe();
      if (eski != null) return eski;
      rethrow;
    }
  }

  // Sunucuları sırayla dener; biri cevap verince onun listesini döndürür
  static Future<List<Cami>> _overpass(double enlem, double boylam, int metre) async {
    final sorgu = '[out:json][timeout:20];('
        'node["amenity"="place_of_worship"]["religion"="muslim"](around:$metre,$enlem,$boylam);'
        'way["amenity"="place_of_worship"]["religion"="muslim"](around:$metre,$enlem,$boylam);'
        'relation["amenity"="place_of_worship"]["religion"="muslim"](around:$metre,$enlem,$boylam);'
        ');out center 80;';
    var hepsiBaglantiHatasi = true;
    for (final sunucu in _sunucular) {
      try {
        final j = await jsonGetir(
          Uri.https(sunucu, _sunucuYollari[sunucu] ?? '/api/interpreter', {'data': sorgu}),
          sure: const Duration(seconds: 20),
        );
        return _cozumle(j, enlem, boylam);
      } on SocketException {
        // bu sunucuya bağlanılamadı (ya da internet yok); sıradakini dene
      } catch (_) {
        hepsiBaglantiHatasi = false; // sunucu cevap verdi ama meşgul / hatalı
      }
    }
    throw CamiHatasi(hepsiBaglantiHatasi);
  }

  static List<Cami> _cozumle(dynamic j, double enlem, double boylam) {
    final liste = <Cami>[];
    for (final e in (j['elements'] as List)) {
      final m = e as Map<String, dynamic>;
      final e1 = (m['lat'] ?? m['center']?['lat']) as num?;
      final b1 = (m['lon'] ?? m['center']?['lon']) as num?;
      if (e1 == null || b1 == null) continue;
      final etiket = (m['tags'] as Map<String, dynamic>?) ?? const {};
      final ad = (etiket['name:tr'] ?? etiket['name'] ?? 'Adı bilinmeyen cami') as String;
      liste.add(Cami(ad, e1.toDouble(), b1.toDouble(), uzaklikMetre(enlem, boylam, e1.toDouble(), b1.toDouble())));
    }
    liste.sort((a, b) => a.metre.compareTo(b.metre));
    return liste;
  }

  // Son bulunan listeyi telefona yazar (internet olmayınca gösterilsin diye)
  static Future<void> _sakla(CamiSonucu s) async {
    try {
      final depo = await SharedPreferences.getInstance();
      await depo.setString(
        _sonListeAnahtari,
        jsonEncode({
          'enlem': s.enlem,
          'boylam': s.boylam,
          'yaricap': s.yaricap,
          'gps': s.gps,
          'zaman': s.zaman.millisecondsSinceEpoch,
          'liste': [for (final c in s.camiler) [c.ad, c.enlem, c.boylam]],
        }),
      );
    } catch (_) {}
  }

  static Future<CamiSonucu?> _sonListe() async {
    try {
      final depo = await SharedPreferences.getInstance();
      final metin = depo.getString(_sonListeAnahtari);
      if (metin == null) return null;
      final j = jsonDecode(metin) as Map<String, dynamic>;
      final e = (j['enlem'] as num).toDouble(), b = (j['boylam'] as num).toDouble();
      final liste = [
        for (final c in (j['liste'] as List))
          Cami(c[0] as String, (c[1] as num).toDouble(), (c[2] as num).toDouble(),
              uzaklikMetre(e, b, (c[1] as num).toDouble(), (c[2] as num).toDouble())),
      ];
      return CamiSonucu(e, b, j['yaricap'] as int, j['gps'] as bool, liste,
          DateTime.fromMillisecondsSinceEpoch(j['zaman'] as int), eski: true);
    } catch (_) {
      return null;
    }
  }

  /// İki nokta arası yürüyüş yolunu OpenStreetMap yol verisinden hesaplatır (FOSSGIS yol sunucusu).
  static Future<YuruyusYolu> yuruyusYolu(LatLng nereden, LatLng nereye) async {
    final j = await jsonGetir(
      Uri.https(
        'routing.openstreetmap.de',
        '/routed-foot/route/v1/driving/${nereden.longitude},${nereden.latitude};${nereye.longitude},${nereye.latitude}',
        {'overview': 'full', 'geometries': 'geojson'},
      ),
      sure: const Duration(seconds: 20),
    );
    if (j['code'] != 'Ok' || (j['routes'] as List).isEmpty) throw const HttpException('Yol bulunamadı');
    final yol = (j['routes'] as List).first as Map<String, dynamic>;
    final noktalar = [
      for (final k in (yol['geometry']['coordinates'] as List))
        LatLng(((k as List)[1] as num).toDouble(), (k[0] as num).toDouble()),
    ];
    return YuruyusYolu(noktalar, (yol['distance'] as num).toDouble(), (yol['duration'] as num).toDouble());
  }
}
