// Saat, tarih ve süre yazdırma gibi küçük yardımcı fonksiyonlar.

import 'dart:math' as math;

import 'veri/iller.dart';

const List<String> _aylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

/// İki basamaklı yazar: 5 -> "05"
String _iki(int s) => s.toString().padLeft(2, '0');

/// Saati "15:51" biçiminde yazar.
String saatYaz(DateTime z) => '${_iki(z.hour)}:${_iki(z.minute)}';

/// Tarihi "28 Ekim 2026" biçiminde yazar.
String tarihYaz(DateTime z) => '${z.day} ${_aylar[z.month - 1]} ${z.year}';

/// Kısa tarih: "28 Eki"
String kisaTarihYaz(DateTime z) => '${z.day} ${_aylar[z.month - 1].substring(0, 3)}';

/// Kalan süreyi "01:24:37" biçiminde yazar.
String kalanYaz(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${_iki(s ~/ 3600)}:${_iki((s % 3600) ~/ 60)}:${_iki(s % 60)}';
}

/// Kalan süreyi "1 sa 24 dk" biçiminde kısa yazar (bildirim ve widget için).
String kalanKisaYaz(Duration d) {
  final dk = (d.inSeconds / 60).ceil();
  if (dk < 60) return '$dk dk';
  return '${dk ~/ 60} sa ${dk % 60} dk';
}

/// Türkçe harflere uygun küçük harfe çevirir (İ -> i, I -> ı). Aramada kullanılır.
String turkceKucuk(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

/// Verilen koordinata en yakın ili bulur (GPS ile bulunan konuma isim vermek için).
Il enYakinIl(double enlem, double boylam) {
  Il enYakin = iller.first;
  var enKisa = double.infinity;
  for (final il in iller) {
    // Kısa mesafede yeterince doğru, basit uzaklık hesabı
    final dx = (il.boylam - boylam) * math.cos(enlem * math.pi / 180);
    final dy = il.enlem - enlem;
    final uzaklik = dx * dx + dy * dy;
    if (uzaklik < enKisa) {
      enKisa = uzaklik;
      enYakin = il;
    }
  }
  return enYakin;
}
