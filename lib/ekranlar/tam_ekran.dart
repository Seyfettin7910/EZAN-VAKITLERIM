// Tam ekran vakit uyarısı: vakit girince (kilit ekranında da) açılır.
// Ezan okunurken "Durdur" düğmesi vardır; dua başlayınca ezan duasının yazısı görünür.

import 'dart:async';

import 'package:flutter/material.dart';

import '../hesap/vakit_hesap.dart';
import '../servis/durum.dart';
import '../servis/icerik_servisi.dart';
import '../servis/yerel.dart';
import '../tema.dart';
import '../veri/ezan_duasi.dart';
import '../yardimci.dart';
import 'icerik_karti.dart';

class TamEkranEkrani extends StatefulWidget {
  final int vakit; // 0 = imsak ... 5 = yatsı
  const TamEkranEkrani({super.key, required this.vakit});

  @override
  State<TamEkranEkrani> createState() => _TamEkranEkraniState();
}

class _TamEkranEkraniState extends State<TamEkranEkrani> {
  static const _zemin = Color(0xFF0B2E2D);
  static const _kart = Color(0xFF17403F);

  Timer? _sayac;
  String? _calan; // "ezan", "dua" ya da null
  bool _duaGoster = false;

  // Her saniye Android'e "ne çalıyor?" diye sorar, ekranı ona göre günceller
  @override
  void initState() {
    super.initState();
    _durumSor();
    _sayac = Timer.periodic(const Duration(seconds: 1), (_) => _durumSor());
  }

  Future<void> _durumSor() async {
    final d = await Yerel.ezanDurumu();
    if (!mounted) return;
    setState(() {
      _calan = d;
      if (d == 'dua') _duaGoster = true;
    });
  }

  @override
  void dispose() {
    _sayac?.cancel();
    super.dispose();
  }

  // Ekranı kapatır; kilit ekranından açıldıysa telefonu kilit ekranına bırakır
  Future<void> _kapat() async {
    await Yerel.kilitUstunuKapat();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final konum = durum.konum;
    final simdi = DateTime.now();
    final zaman = konum == null ? simdi : VakitHesap.hesapla(simdi, konum.enlem, konum.boylam).vakitler[widget.vakit];
    final baslik = widget.vakit == 1 ? 'Güneş doğdu' : '${vakitAdlari[widget.vakit]} vakti girdi';

    final caliyor = _calan != null;
    final durumYazisi = switch (_calan) {
      'ezan' => 'Ezan okunuyor',
      'dua' => 'Ezan duası okunuyor',
      _ => 'Okuma bitti',
    };

    return Scaffold(
      backgroundColor: _zemin,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Row(
              children: [
                const Icon(Icons.mosque, color: Renk.altin, size: 26),
                const SizedBox(width: 8),
                const Text('Ezan Vakitlerim', style: TextStyle(color: Renk.anaYazi, fontWeight: FontWeight.w700)),
                const Spacer(),
                Flexible(
                  child: Text(konum?.ad ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Renk.anaSoluk, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Text(tarihYaz(simdi), textAlign: TextAlign.center, style: const TextStyle(color: Renk.anaSoluk, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(baslik, textAlign: TextAlign.center, style: const TextStyle(color: Renk.anaYazi, fontSize: 34, fontWeight: FontWeight.w800)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                saatYaz(zaman),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Renk.altin, fontSize: 64, fontWeight: FontWeight.w800, height: 1.1),
              ),
            ),
            const SizedBox(height: 24),

            // Ezan durumu ve Durdur düğmesi
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: BoxDecoration(color: _kart, borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  Icon(caliyor ? Icons.graphic_eq : Icons.check_circle_outline, color: Renk.altin),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(durumYazisi, style: const TextStyle(color: Renk.anaYazi, fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  if (caliyor)
                    FilledButton(
                      onPressed: () async {
                        await Yerel.ezanDurdur();
                        await _durumSor();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Renk.altin,
                        foregroundColor: _zemin,
                        minimumSize: const Size(120, 60),
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Durdur', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bu vaktin ayeti ve hadisi
            if (durum.icerikTamEkran) ...[
              IcerikKarti(slot: IcerikServisi.slot(simdi, widget.vakit), koyu: true),
              const SizedBox(height: 16),
            ],

            // Ezan duası: dua başlayınca kendiliğinden açılır, istenirse elle de açılır
            if (_duaGoster)
              const _EzanDuasiKarti()
            else
              TextButton.icon(
                onPressed: () => setState(() => _duaGoster = true),
                style: TextButton.styleFrom(foregroundColor: Renk.altin, minimumSize: const Size(44, 48)),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Ezan duasını göster', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 60,
              child: OutlinedButton(
                onPressed: _kapat,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Renk.anaYazi,
                  side: const BorderSide(color: Color(0xFF3C6C6A), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Kapat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ezan duasının Arapçası, okunuşu, anlamı ve kaynağı.
class _EzanDuasiKarti extends StatelessWidget {
  const _EzanDuasiKarti();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Renk.zemin, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ezan duası', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Renk.altinYazi)),
          const SizedBox(height: 10),
          const Text(
            ezanDuasiArapca,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, height: 1.9, color: Renk.yazi),
          ),
          const SizedBox(height: 12),
          const Text('Okunuşu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Renk.altinYazi)),
          const SizedBox(height: 4),
          const Text(ezanDuasiOkunus, style: TextStyle(fontSize: 15, height: 1.5, fontStyle: FontStyle.italic, color: Renk.yazi)),
          const SizedBox(height: 12),
          const Text('Anlamı', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Renk.altinYazi)),
          const SizedBox(height: 4),
          const Text(ezanDuasiAnlam, style: TextStyle(fontSize: 15, height: 1.5, color: Renk.yazi)),
          const SizedBox(height: 8),
          Text(ezanDuasiKaynak, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Renk.soluk)),
        ],
      ),
    );
  }
}
