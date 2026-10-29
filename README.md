# Ezan Vakitlerim

Ücretsiz ve reklamsız namaz vakitleri uygulaması (Android).

**İndir (hep son sürüm):** [Ezan-Vakitlerim.apk](https://github.com/Seyfettin7910/EZAN-VAKITLERIM/releases/latest/download/Ezan-Vakitlerim.apk)

## Neler var (1.1.0)
- Sesli ezan (sabah vaktinde sabah ezanı), ardından otomatik sesli ezan duası
- Tam ekran vakit uyarısı (kilit ekranında da), "Durdur" düğmesi
- Vakitten önce hatırlatma (10 / 15 / 30 / 45 dk)
- Otomatik güncelleme: yeni sürüm çıkınca uygulama haber verir, indirilen dosya doğrulanır
- Sıradaki vakte saniye saniye geri sayım, günün altı vakti, her vakit için uyarı aç/kapat
- GPS ile ya da 81 il içinden konum seçimi, 30 günlük imsakiye

## Teşekkür
Uygulamanın yapımında katkısı olan müezzinlerimize çok teşekkür ederiz. Allah onlardan razı olsun.

## Vakitler nasıl hesaplanıyor?
Vakitler telefonda, güneşin konumuna göre Diyanet'in açılarıyla (imsak 18°, yatsı 17°) ve temkin süreleriyle hesaplanır. İstanbul için Diyanet'in 30 günlük resmi tablosuyla karşılaştırıldı: vakitlerin çoğu birebir tutuyor, en fazla 1 dakika fark var.

## Klasörler
- `lib/hesap` – vakit hesabı
- `lib/ekranlar` – ekranlar
- `lib/servis` – konum, bildirim ve ayarlar
- `lib/veri` – 81 ilin koordinatları, ezan duası
- `android/app/src/main/kotlin` – sesli ezan servisi, alarm, tam ekran, güncelleme kurulumu
- `android/app/src/main/res/raw` – ezan ve ezan duası sesleri
- `.github/workflows/apk.yml` – her güncellemede APK'yı derleyen iş

Developed by Seyfettin AYDIN
