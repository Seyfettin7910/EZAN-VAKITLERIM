# Ezan Vakitlerim

Ücretsiz ve reklamsız namaz vakitleri uygulaması (Android).

**İndir (hep son sürüm):** [Ezan-Vakitlerim.apk](https://github.com/Seyfettin7910/EZAN-VAKITLERIM/releases/latest/download/Ezan-Vakitlerim.apk)

## Neler var (1.0.0)
- Sıradaki vakte saniye saniye geri sayım
- Günün altı vakti, her vakit için bildirim aç/kapat
- GPS ile ya da 81 il içinden konum seçimi
- 30 günlük imsakiye
- Vakit girince bildirim (internet gerekmez)

## Vakitler nasıl hesaplanıyor?
Vakitler telefonda, güneşin konumuna göre Diyanet'in açılarıyla (imsak 18°, yatsı 17°) ve temkin süreleriyle hesaplanır. İstanbul için Diyanet'in 30 günlük resmi tablosuyla karşılaştırıldı: vakitlerin çoğu birebir tutuyor, en fazla 1 dakika fark var.

## Klasörler
- `lib/hesap` – vakit hesabı
- `lib/ekranlar` – ekranlar
- `lib/servis` – konum, bildirim ve ayarlar
- `lib/veri` – 81 ilin koordinatları
- `.github/workflows/apk.yml` – her güncellemede APK'yı derleyen iş

Developed by Seyfettin AYDIN
