// Flutter ile Android tarafı (Kotlin) arasındaki köprü.
// Sesli ezan, tam ekran uyarı, izin ekranları ve güncelleme kurulumu Android tarafında yapılır.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

class Yerel {
  static const MethodChannel _kanal = MethodChannel('ezan_vakitlerim/yerel');

  /// Uygulama açıkken tam ekran uyarı gelirse Android bu fonksiyonu çağırır.
  static void tamEkranDinle(void Function(int vakit) dinleyici) {
    _kanal.setMethodCallHandler((cagri) async {
      if (cagri.method == 'tamEkranAc') dinleyici(cagri.arguments as int);
    });
  }

  // Hata olursa uygulamayı çökertmeden varsayılan değeri döndüren yardımcı
  static Future<T> _cagir<T>(String ad, T varsayilan, [Map<String, dynamic>? arg]) async {
    try {
      final sonuc = await _kanal.invokeMethod<T>(ad, arg);
      return sonuc ?? varsayilan;
    } catch (hata) {
      debugPrint('Yerel çağrı hatası ($ad): $hata');
      return varsayilan;
    }
  }

  /// Ezan alarmlarını kurar. Her öğe: zaman (ms), vakit (0-5), baslik, metin.
  static Future<void> ezanlariKur(List<Map<String, Object>> liste,
          {required bool dua, required bool sessizdeOku, required bool tamEkran}) =>
      _cagir<void>('ezanlariKur', null, {'liste': liste, 'dua': dua, 'sessizdeOku': sessizdeOku, 'tamEkran': tamEkran});

  static Future<void> ezanlariSil() => _cagir<void>('ezanlariSil', null);

  /// Şu an ne çalıyor: "ezan", "dua" ya da null.
  static Future<String?> ezanDurumu() async {
    final m = await _cagir<Map>('ezanDurumu', const {});
    return m['durum'] as String?;
  }

  static Future<void> ezanDurdur() => _cagir<void>('ezanDurdur', null);
  static Future<void> sesiDene(int vakit) => _cagir<void>('sesiDene', null, {'vakit': vakit});

  /// Uygulama tam ekran uyarıyla açıldıysa vakit numarası, değilse -1.
  static Future<int> acilisVakti() => _cagir<int>('acilisVakti', -1);
  static Future<void> kilitUstunuKapat() => _cagir<void>('kilitUstunuKapat', null);

  static Future<bool> tamEkranIzniVar() => _cagir<bool>('tamEkranIzniVar', true);
  static Future<void> tamEkranIzniAc() => _cagir<void>('tamEkranIzniAc', null);
  static Future<bool> pilKisitlamasiYok() => _cagir<bool>('pilKisitlamasiYok', true);
  static Future<void> pilAyariAc() => _cagir<void>('pilAyariAc', null);
  static Future<bool> kurulumIzniVar() => _cagir<bool>('kurulumIzniVar', true);
  static Future<void> kurulumIzniAc() => _cagir<void>('kurulumIzniAc', null);
  static Future<void> apkKur(String yol) => _cagir<void>('apkKur', null, {'yol': yol});
  static Future<String> onbellekKlasoru() => _cagir<String>('onbellekKlasoru', '');

  /// Widget'ların kullanacağı konumu Android tarafına bildirir.
  static Future<void> konumKaydet(String ad, double enlem, double boylam) =>
      _cagir<void>('konumKaydet', null, {'ad': ad, 'enlem': enlem, 'boylam': boylam});

  /// Bir yeri harita uygulamasında açar; [yolTarifi] ise yürüyerek yol tarifi verir.
  static Future<void> haritadaAc(double enlem, double boylam, String ad, {bool yolTarifi = false}) =>
      _cagir<void>('haritadaAc', null, {'enlem': enlem, 'boylam': boylam, 'ad': ad, 'yolTarifi': yolTarifi});

  static const EventChannel _pusula = EventChannel('ezan_vakitlerim/pusula');

  /// Pusula yönü akışı: her olay {aci: derece (gerçek kuzeye göre), dogruluk: 0-3}.
  static Stream<Map<dynamic, dynamic>> pusula(double enlem, double boylam) =>
      _pusula.receiveBroadcastStream({'enlem': enlem, 'boylam': boylam}).map((o) => o as Map<dynamic, dynamic>);
}
