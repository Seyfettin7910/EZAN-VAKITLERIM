// İnternetten JSON indiren küçük yardımcı (ayet, hadis ve cami bilgisi için).

import 'dart:convert';
import 'dart:io';

/// Adresi indirip JSON olarak çözer. İnternet yoksa ya da sunucu hata verirse hata fırlatır.
Future<dynamic> jsonGetir(Uri adres, {Duration sure = const Duration(seconds: 20)}) async {
  final istemci = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..userAgent = 'EzanVakitlerim/1.2 (github.com/Seyfettin7910/EZAN-VAKITLERIM)';
  try {
    final istek = await istemci.getUrl(adres);
    final yanit = await istek.close().timeout(sure);
    if (yanit.statusCode != 200) throw HttpException('Sunucu cevabı ${yanit.statusCode}', uri: adres);
    return jsonDecode(await yanit.transform(utf8.decoder).join());
  } finally {
    istemci.close();
  }
}
