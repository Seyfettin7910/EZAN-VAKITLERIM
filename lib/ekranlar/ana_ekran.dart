// Ana ekran: konum, sıradaki vakte geri sayım ve günün altı vakti.

import 'dart:async';

import 'package:flutter/material.dart';

import '../hesap/vakit_hesap.dart';
import '../servis/durum.dart';
import '../servis/icerik_servisi.dart';
import '../tema.dart';
import '../yardimci.dart';
import 'icerik_karti.dart';
import 'konum_sec_ekrani.dart';

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});

  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  Timer? _sayac;

  // Ekran açılınca her saniye kendini yenileyen sayacı başlatır (geri sayım için)
  @override
  void initState() {
    super.initState();
    _sayac = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  // Ekran kapanınca sayacı durdurur, boşuna pil yemesin
  @override
  void dispose() {
    _sayac?.cancel();
    super.dispose();
  }

  // Konum seçme ekranını açar
  void _konumDegistir() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KonumSecEkrani()));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: durum,
      builder: (context, _) {
        final konum = durum.konum!;
        final simdi = DateTime.now();
        final bugun = VakitHesap.hesapla(simdi, konum.enlem, konum.boylam);
        final d = VakitHesap.durum(simdi, konum.enlem, konum.boylam);

        // Önceki vakitten sıradakine ne kadar yol alındı (ilerleme çubuğu için, 0-1 arası)
        final toplam = d.siradakiZaman.difference(d.oncekiZaman).inSeconds;
        final gecen = simdi.difference(d.oncekiZaman).inSeconds;
        final ilerleme = toplam > 0 ? (gecen / toplam).clamp(0.0, 1.0) : 0.0;

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _ust(konum, simdi),
            _geriSayimKarti(d, simdi, ilerleme),
            const SizedBox(height: 16),
            _vakitListesi(bugun, d, simdi),
            if (durum.icerikAnaEkran) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: IcerikKarti(slot: IcerikServisi.slot(d.oncekiZaman, d.onceki)),
              ),
            ],
          ],
        );
      },
    );
  }

  // Üst kısım: konum adı (dokununca değiştirilir) ve tarih
  Widget _ust(Konum konum, DateTime simdi) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: _konumDegistir,
            style: TextButton.styleFrom(foregroundColor: Renk.yazi, minimumSize: const Size(44, 44)),
            icon: Icon(konum.gps ? Icons.my_location : Icons.location_on_outlined, size: 20),
            label: Text(konum.ad, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(tarihYaz(simdi), style: const TextStyle(fontSize: 13, color: Renk.soluk)),
          ),
        ],
      ),
    );
  }

  // Yeşil kart: sıradaki vakit, saati, kalan süre ve ilerleme çubuğu
  Widget _geriSayimKarti(VakitDurumu d, DateTime simdi, double ilerleme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(color: Renk.ana, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sıradaki vakit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Renk.anaSoluk)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(vakitAdlari[d.siradaki], style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Renk.anaYazi)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(saatYaz(d.siradakiZaman), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Renk.altin)),
            ],
          ),
          const SizedBox(height: 6),
          // Yazı boyutu büyütülse de kartın içine sığsın diye gerekirse kendini küçültür
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kalanYaz(d.siradakiZaman.difference(simdi)),
              style: const TextStyle(
                fontSize: 54,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: Renk.anaYazi,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ilerleme,
              minHeight: 6,
              backgroundColor: Renk.iz,
              color: Renk.altin,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${vakitAdlari[d.onceki]} ${saatYaz(d.oncekiZaman)}', style: const TextStyle(fontSize: 12, color: Renk.anaSoluk)),
              const Spacer(),
              Text('${vakitAdlari[d.siradaki]} ${saatYaz(d.siradakiZaman)}', style: const TextStyle(fontSize: 12, color: Renk.anaSoluk)),
            ],
          ),
        ],
      ),
    );
  }

  // Beyaz kart: günün altı vakti, her birinin yanında bildirim zili
  Widget _vakitListesi(GunlukVakitler bugun, VakitDurumu d, DateTime simdi) {
    bool ayniGun(DateTime a) => a.year == simdi.year && a.month == simdi.month && a.day == simdi.day;
    final siradakiBugun = ayniGun(d.siradakiZaman);
    final oncekiBugun = ayniGun(d.oncekiZaman);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Renk.kart, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          for (var i = 0; i < 6; i++)
            _vakitSatiri(
              i,
              bugun.vakitler[i],
              siradaki: siradakiBugun && d.siradaki == i,
              suAn: oncekiBugun && d.onceki == i,
              gecti: bugun.vakitler[i].isBefore(simdi) && !(oncekiBugun && d.onceki == i),
            ),
        ],
      ),
    );
  }

  // Tek vakit satırı: adı, saati, durum etiketi ve bildirim zili
  Widget _vakitSatiri(int i, DateTime zaman, {required bool siradaki, required bool suAn, required bool gecti}) {
    final yaziRengi = gecti ? Renk.soluk : Renk.yazi;
    final acik = durum.bildirimler[i];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: siradaki ? Renk.siradaki : null,
        border: siradaki ? Border.all(color: Renk.halka, width: 1.5) : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              vakitAdlari[i],
              style: TextStyle(fontSize: 16, fontWeight: siradaki ? FontWeight.w800 : FontWeight.w600, color: yaziRengi),
            ),
          ),
          if (suAn) const _Etiket('Şu an', zemin: Renk.etiket, renk: Renk.yazi),
          if (siradaki) const _Etiket('Sıradaki', renk: Renk.altinYazi),
          const SizedBox(width: 8),
          Text(
            saatYaz(zaman),
            style: TextStyle(
              fontSize: 17,
              fontWeight: siradaki ? FontWeight.w800 : FontWeight.w700,
              color: yaziRengi,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          // Zil: açıkken sesli ezan varsa hoparlör, yoksa zil simgesi görünür
          IconButton(
            tooltip: acik ? '${vakitAdlari[i]} uyarısını kapat' : '${vakitAdlari[i]} uyarısını aç',
            onPressed: () => durum.bildirimAyarla(i, !acik),
            icon: Icon(
              !acik
                  ? Icons.notifications_off_outlined
                  : (durum.sesliEzan && i != 1 ? Icons.volume_up_outlined : Icons.notifications_active_outlined),
              color: acik ? (siradaki ? Renk.altinYazi : Renk.yazi) : Renk.soluk,
            ),
          ),
        ],
      ),
    );
  }
}

/// Satırdaki küçük "Şu an" / "Sıradaki" etiketi.
class _Etiket extends StatelessWidget {
  final String metin;
  final Color? zemin;
  final Color renk;
  const _Etiket(this.metin, {this.zemin, required this.renk});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(8)),
      child: Text(metin, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: renk)),
    );
  }
}
