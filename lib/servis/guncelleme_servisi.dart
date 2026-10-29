// Otomatik güncelleme: GitHub'daki son sürümü denetler, APK'yı indirir, bozuk inip inmediğini
// parmak iziyle (SHA-256) kontrol eder ve Android'in kurulum ekranını açar.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../surum.dart';
import 'yerel.dart';

/// GitHub'daki son sürümün bilgisi (surum.json dosyasından okunur).
class YeniSurum {
  final String surum; // örn. 1.2.0
  final int derleme; // GitHub derleme numarası
  final int boyut; // APK boyutu (bayt)
  final String parmakIzi; // APK'nın SHA-256 özeti
  final String notlar; // "Yenilikler" yazısı
  const YeniSurum(this.surum, this.derleme, this.boyut, this.parmakIzi, this.notlar);

  String get boyutMb => (boyut / 1024 / 1024).toStringAsFixed(1);
}

/// Kurulum izni verilmediğinde fırlatılır (kullanıcı ayarlardan izin vermeli).
class KurulumIzniGerekli implements Exception {}

class GuncellemeServisi {
  static Uri _adres(String dosya) => Uri.parse('https://github.com/$depoAdresi/releases/latest/download/$dosya');

  /// İnternetten metin indirir (GitHub yönlendirmelerini kendisi takip eder).
  static Future<String> _metinIndir(Uri adres) async {
    final istemci = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final istek = await istemci.getUrl(adres);
      final yanit = await istek.close().timeout(const Duration(seconds: 20));
      if (yanit.statusCode != 200) throw 'Sunucu cevabı: ${yanit.statusCode}';
      return await yanit.transform(utf8.decoder).join();
    } finally {
      istemci.close();
    }
  }

  /// Yeni sürüm varsa bilgisini döndürür, yoksa null. İnternet yoksa hata fırlatır.
  static Future<YeniSurum?> denetle() async {
    final j = jsonDecode(await _metinIndir(_adres('surum.json'))) as Map<String, dynamic>;
    final yeni = YeniSurum(
      j['surum'] as String,
      (j['derleme'] as num).toInt(),
      (j['boyut'] as num).toInt(),
      j['sha256'] as String,
      (j['notlar'] as String?) ?? '',
    );
    return yeni.derleme > derlemeNo ? yeni : null;
  }

  /// APK'yı indirir, boyutunu ve parmak izini kontrol eder, dosya yolunu döndürür.
  /// [ilerleme] 0 ile 1 arası değerle sık sık çağrılır.
  static Future<String> indir(YeniSurum s, void Function(double) ilerleme) async {
    final klasor = Directory('${await Yerel.onbellekKlasoru()}/guncelleme');
    if (await klasor.exists()) await klasor.delete(recursive: true);
    await klasor.create(recursive: true);
    final dosya = File('${klasor.path}/Ezan-Vakitlerim.apk');

    final istemci = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final istek = await istemci.getUrl(_adres('Ezan-Vakitlerim.apk'));
      final yanit = await istek.close();
      if (yanit.statusCode != 200) throw 'İndirme başarısız (${yanit.statusCode}).';
      final yazici = dosya.openWrite();
      var inen = 0;
      await for (final parca in yanit) {
        yazici.add(parca);
        inen += parca.length;
        if (s.boyut > 0) ilerleme((inen / s.boyut).clamp(0.0, 1.0));
      }
      await yazici.close();
    } finally {
      istemci.close();
    }

    // İnen dosya GitHub'dakiyle birebir aynı mı?
    final boyut = await dosya.length();
    final ozet = (await sha256.bind(dosya.openRead()).first).toString();
    if (boyut != s.boyut || ozet != s.parmakIzi.toLowerCase()) {
      await dosya.delete();
      throw 'Dosya bozuk indi. İnternet bağlantını kontrol edip tekrar dene.';
    }
    return dosya.path;
  }

  /// İndirilen APK için Android'in kurulum ekranını açar.
  static Future<void> kur(String yol) async {
    if (!await Yerel.kurulumIzniVar()) {
      await Yerel.kurulumIzniAc();
      throw KurulumIzniGerekli();
    }
    await Yerel.apkKur(yol);
  }
}
