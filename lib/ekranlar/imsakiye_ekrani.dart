// İmsakiye: bugünden başlayarak 30 günün vakitleri tablo halinde.

import 'package:flutter/material.dart';

import '../hesap/vakit_hesap.dart';
import '../servis/durum.dart';
import '../tema.dart';
import '../yardimci.dart';

class ImsakiyeEkrani extends StatelessWidget {
  const ImsakiyeEkrani({super.key});

  static const _kisaAdlar = ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: durum,
      builder: (context, _) {
        final konum = durum.konum!;
        final simdi = DateTime.now();
        final gunler = List.generate(30, (g) {
          return VakitHesap.hesapla(DateTime(simdi.year, simdi.month, simdi.day + g), konum.enlem, konum.boylam);
        });

        // Yazı büyütülmüşse tablo yerine gün gün kart gösterilir (sütunlar sıkışmasın, iri okunsun)
        final buyukYazi = MediaQuery.textScalerOf(context).scale(10) > 11.5;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: const Text('İmsakiye', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Renk.yazi)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text('${konum.ad} · 30 gün', style: const TextStyle(fontSize: 13, color: Renk.soluk)),
            ),
            if (buyukYazi)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: gunler.length,
                  itemBuilder: (context, i) => _gunKarti(gunler[i], bugun: i == 0),
                ),
              ),
            // Başlık satırı
            if (!buyukYazi)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _satir(
                'Tarih',
                _kisaAdlar,
                stil: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Renk.soluk),
              ),
            ),
            if (!buyukYazi)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: gunler.length,
                itemBuilder: (context, i) {
                  final gun = gunler[i];
                  final bugun = i == 0;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: bugun ? Renk.siradaki : Renk.kart,
                      border: bugun ? Border.all(color: Renk.halka, width: 1.5) : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _satir(
                      kisaTarihYaz(gun.tarih),
                      gun.vakitler.map(saatYaz).toList(),
                      stil: TextStyle(
                        fontSize: 13,
                        fontWeight: bugun ? FontWeight.w800 : FontWeight.w600,
                        color: Renk.yazi,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Büyük yazı için bir günün kartı: üstte tarih, altında 3 + 3 vakit
  Widget _gunKarti(GunlukVakitler gun, {required bool bugun}) {
    Widget vakit(int i) => Expanded(
          child: Column(
            children: [
              Text(_kisaAdlar[i], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Renk.soluk)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(saatYaz(gun.vakitler[i]),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Renk.yazi,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ),
            ],
          ),
        );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: bugun ? Renk.siradaki : Renk.kart,
        border: bugun ? Border.all(color: Renk.halka, width: 2) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(bugun ? 'Bugün · ${tarihYaz(gun.tarih)}' : tarihYaz(gun.tarih),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Renk.yazi)),
          const SizedBox(height: 8),
          Row(children: [vakit(0), vakit(1), vakit(2)]),
          const SizedBox(height: 8),
          Row(children: [vakit(3), vakit(4), vakit(5)]),
        ],
      ),
    );
  }

  // Tablonun bir satırı: solda tarih, yanında altı sütun
  Widget _satir(String ilk, List<String> digerleri, {required TextStyle stil}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 52, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(ilk, style: stil))),
          for (final s in digerleri)
            Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text(s, style: stil, textAlign: TextAlign.center))),
        ],
      ),
    );
  }
}
