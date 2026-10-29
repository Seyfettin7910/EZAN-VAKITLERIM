// Türkiye'nin 81 ili ve 973 ilçesi, ilçe merkezlerinin koordinatlarıyla.
// Veri OpenStreetMap idari sınırlarından tool/ilce_uret.py ile üretilir (assets/veri/ilceler.json).

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

class Ilce {
  final int plaka;
  final String il;
  final String ad; // "Merkez" ise ilin merkez ilçesi
  final double enlem;
  final double boylam;
  const Ilce(this.plaka, this.il, this.ad, this.enlem, this.boylam);

  /// Ekranda görünen ad: "İvrindi, Balıkesir" ya da "Uşak Merkez"
  String get tamAd => ad == 'Merkez' ? '$il Merkez' : '$ad, $il';
}

class IlceVerisi {
  static final Map<int, List<Ilce>> _ile = {};
  static final List<Ilce> _hepsi = [];

  /// Uygulama açılırken ilçe listesini okur.
  static Future<void> yukle() async {
    try {
      final liste = jsonDecode(await rootBundle.loadString('assets/veri/ilceler.json')) as List;
      for (final il in liste) {
        final plaka = il['plaka'] as int;
        final ad = il['il'] as String;
        final ilceler = [
          for (final x in il['ilceler'] as List)
            Ilce(plaka, ad, x['ad'] as String, (x['enlem'] as num).toDouble(), (x['boylam'] as num).toDouble()),
        ];
        _ile[plaka] = ilceler;
        _hepsi.addAll(ilceler);
      }
    } catch (hata) {
      debugPrint('İlçe listesi okunamadı: $hata');
    }
  }

  static bool get hazir => _hepsi.isNotEmpty;

  /// Bir ilin ilçeleri (Merkez en başta, sonra alfabetik).
  static List<Ilce> ilinIlceleri(int plaka) => _ile[plaka] ?? const [];

  static List<Ilce> get hepsi => _hepsi;

  /// Koordinata en yakın ilçe (GPS ile bulunan konuma ad vermek için).
  static Ilce? enYakin(double enlem, double boylam) {
    Ilce? enIyi;
    var enKisa = double.infinity;
    final k = math.cos(enlem * math.pi / 180);
    for (final i in _hepsi) {
      final dx = (i.boylam - boylam) * k;
      final dy = i.enlem - enlem;
      final u = dx * dx + dy * dy;
      if (u < enKisa) {
        enKisa = u;
        enIyi = i;
      }
    }
    return enIyi;
  }
}
