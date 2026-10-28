// GPS ile telefonun bulunduğu yeri bulan dosya.

import 'package:geolocator/geolocator.dart';

import '../yardimci.dart';
import 'durum.dart';

class KonumServisi {
  /// GPS'ten konumu alır. Bir sorun olursa kullanıcıya gösterilecek Türkçe mesajla hata fırlatır.
  static Future<Konum> gpsKonumu() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Telefonun konum (GPS) özelliği kapalı. Açıp tekrar dene.';
    }

    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }
    if (izin == LocationPermission.denied) {
      throw 'Konum izni verilmedi.';
    }
    if (izin == LocationPermission.deniedForever) {
      throw 'Konum izni kalıcı olarak kapalı. Telefon ayarlarından izin verebilirsin.';
    }

    Position? konum;
    try {
      konum = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      // Yeni konum gelmezse telefonun bildiği son konumu dene
      konum = await Geolocator.getLastKnownPosition();
    }
    if (konum == null) {
      throw 'Konum bulunamadı. Açık havada tekrar dene.';
    }

    final il = enYakinIl(konum.latitude, konum.longitude);
    return Konum('Konumum (${il.ad})', konum.latitude, konum.longitude, gps: true);
  }
}
