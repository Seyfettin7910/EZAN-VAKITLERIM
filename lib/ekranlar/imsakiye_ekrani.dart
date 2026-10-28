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
            // Başlık satırı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _satir(
                'Tarih',
                _kisaAdlar,
                stil: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Renk.soluk),
              ),
            ),
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

  // Tablonun bir satırı: solda tarih, yanında altı sütun
  Widget _satir(String ilk, List<String> digerleri, {required TextStyle stil}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text(ilk, style: stil)),
          for (final s in digerleri) Expanded(child: Text(s, style: stil, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
