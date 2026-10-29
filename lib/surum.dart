// Ayarlar > Hakkında kısmında görünen sürüm. pubspec.yaml'daki "version" ile aynı tutulur.
const String uygulamaSurumu = '1.2.2';

/// GitHub'ın verdiği derleme numarası (derlerken --dart-define=DERLEME_NO=... ile gelir).
/// Güncelleme denetimi, telefondaki sürümün yenisini bu numarayla anlar.
const int derlemeNo = int.fromEnvironment('DERLEME_NO', defaultValue: 0);

/// Depo adresi (güncelleme denetimi buradan yapılır).
const String depoAdresi = 'Seyfettin7910/EZAN-VAKITLERIM';
