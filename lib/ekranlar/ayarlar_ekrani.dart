// Ayarlar: konum, vakit bildirimleri ve hakkında bilgisi.

import 'package:flutter/material.dart';

import '../hesap/vakit_hesap.dart';
import '../servis/bildirim_servisi.dart';
import '../servis/durum.dart';
import '../surum.dart';
import '../tema.dart';
import 'konum_sec_ekrani.dart';

class AyarlarEkrani extends StatelessWidget {
  const AyarlarEkrani({super.key});

  // Bildirim iznini tekrar ister ve sonucu ekranın altında gösterir
  Future<void> _izinKontrol(BuildContext context) async {
    final verildi = await BildirimServisi.izinIste();
    await BildirimServisi.planla();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(verildi
          ? 'Bildirim izni açık, önümüzdeki 14 günün bildirimleri kuruldu.'
          : 'Bildirim izni kapalı. Telefon ayarlarından açabilirsin.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: durum,
      builder: (context, _) {
        final konum = durum.konum!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text('Ayarlar', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Renk.yazi)),
            ),
            const _Baslik('Konum'),
            _Kart(children: [
              ListTile(
                leading: Icon(konum.gps ? Icons.my_location : Icons.location_on_outlined, color: Renk.ana),
                title: Text(konum.ad, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(konum.gps ? 'GPS ile bulundu' : 'İl merkezine göre'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KonumSecEkrani())),
              ),
            ]),
            const _Baslik('Vakit bildirimleri'),
            _Kart(children: [
              for (var i = 0; i < 6; i++)
                SwitchListTile(
                  title: Text(vakitAdlari[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                  value: durum.bildirimler[i],
                  activeTrackColor: Renk.ana,
                  onChanged: (acik) => durum.bildirimAyarla(i, acik),
                ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined, color: Renk.ana),
                title: const Text('Bildirim iznini kontrol et', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => _izinKontrol(context),
              ),
            ]),
            const _Baslik('Hakkında'),
            const _Kart(children: [
              ListTile(
                title: Text('Ezan Vakitlerim', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Sürüm $uygulamaSurumu · Ücretsiz ve reklamsız'),
              ),
              ListTile(
                title: Text('Vakit hesabı', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Telefonda, Diyanet açılarıyla hesaplanır. Resmi takvimden en fazla 1 dakika farklı olabilir.'),
              ),
            ]),
            const SizedBox(height: 18),
            const Text(
              'Developed by Seyfettin AYDIN',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Renk.soluk),
            ),
          ],
        );
      },
    );
  }
}

/// Bölüm başlığı (altın renkli küçük yazı).
class _Baslik extends StatelessWidget {
  final String metin;
  const _Baslik(this.metin);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
      child: Text(metin, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Renk.altinYazi)),
    );
  }
}

/// Ayar satırlarını toplayan beyaz yuvarlak köşeli kart.
class _Kart extends StatelessWidget {
  final List<Widget> children;
  const _Kart({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Renk.kart,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(children: children),
    );
  }
}
