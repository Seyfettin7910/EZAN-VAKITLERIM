// Konum seçme ekranı: GPS ile bul, ya da önce il sonra ilçe seç. Aramada il ve ilçe birlikte aranır.
// Uygulama ilk açıldığında da bu ekran gelir.

import 'package:flutter/material.dart';

import '../servis/durum.dart';
import '../servis/konum_servisi.dart';
import '../tema.dart';
import '../veri/ilceler.dart';
import '../veri/iller.dart';
import '../yardimci.dart';

class KonumSecEkrani extends StatefulWidget {
  final bool ilkAcilis;
  const KonumSecEkrani({super.key, this.ilkAcilis = false});

  @override
  State<KonumSecEkrani> createState() => _KonumSecEkraniState();
}

class _KonumSecEkraniState extends State<KonumSecEkrani> {
  String _arama = '';
  bool _gpsAraniyor = false;
  Il? _secilenIl; // il seçildiyse ilçeleri gösterilir

  // Seçilen konumu kaydeder ve (ilk açılış değilse) önceki ekrana döner
  Future<void> _sec(Konum k) async {
    await durum.konumAyarla(k);
    if (!widget.ilkAcilis && mounted) Navigator.of(context).pop();
  }

  Future<void> _ilceSec(Ilce i) => _sec(Konum(i.tamAd, i.enlem, i.boylam));

  // GPS ile konum bulmayı dener, sorun olursa ekranın altında mesaj gösterir
  Future<void> _gpsIleBul() async {
    setState(() => _gpsAraniyor = true);
    try {
      final k = await KonumServisi.gpsKonumu();
      await _sec(k);
    } catch (hata) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hata.toString())));
      }
    } finally {
      if (mounted) setState(() => _gpsAraniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final il = _secilenIl;
    return PopScope(
      // İlçe listesindeyken geri tuşu il listesine döner
      canPop: il == null,
      onPopInvokedWithResult: (cikti, _) {
        if (!cikti && il != null) setState(() => _secilenIl = null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(il != null ? il.ad : (widget.ilkAcilis ? 'Hoş geldin' : 'Konum seç'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          automaticallyImplyLeading: !widget.ilkAcilis || il != null,
          leading: il != null
              ? IconButton(
                  tooltip: 'İllere dön',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _secilenIl = null),
                )
              : null,
        ),
        body: il != null ? _ilceListesi(il) : _ilListesi(),
      ),
    );
  }

  // İl listesi: üstte GPS düğmesi ve arama (arama ilçeleri de bulur)
  Widget _ilListesi() {
    final aranan = turkceKucuk(_arama.trim());
    final illerSonuc = iller.where((il) => turkceKucuk(il.ad).contains(aranan)).toList();
    final ilceSonuc = aranan.length < 2 || !IlceVerisi.hazir
        ? const <Ilce>[]
        : IlceVerisi.hepsi
            .where((i) => i.ad != 'Merkez' && turkceKucuk(i.ad).contains(aranan))
            .take(40)
            .toList();

    return Column(
      children: [
        if (widget.ilkAcilis)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Vakitleri hesaplamak için konumunu seç. İnternet gerekmez, hesap telefonda yapılır.',
              style: TextStyle(fontSize: 14, color: Renk.soluk),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: _gpsAraniyor ? null : _gpsIleBul,
              style: FilledButton.styleFrom(
                backgroundColor: Renk.ana,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _gpsAraniyor
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.my_location),
              label: Text(_gpsAraniyor ? 'Konum aranıyor…' : 'GPS ile bulunduğum yeri kullan',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (s) => setState(() => _arama = s),
            decoration: InputDecoration(
              labelText: 'İl ya da ilçe ara',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Renk.kart,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final il in illerSonuc)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Renk.etiket,
                    foregroundColor: Renk.yazi,
                    child: Text('${il.plaka}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(il.ad, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (IlceVerisi.ilinIlceleri(il.plaka).isEmpty) {
                      _sec(Konum(il.ad, il.enlem, il.boylam)); // ilçe listesi yoksa il merkezi
                    } else {
                      setState(() => _secilenIl = il);
                    }
                  },
                ),
              if (ilceSonuc.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text('İlçeler', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Renk.altinYazi)),
                ),
              for (final i in ilceSonuc)
                ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: Renk.ana),
                  title: Text(i.ad, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(i.il),
                  trailing: durum.konum?.ad == i.tamAd ? const Icon(Icons.check, color: Renk.ana) : null,
                  onTap: () => _ilceSec(i),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Seçilen ilin ilçeleri
  Widget _ilceListesi(Il il) {
    final ilceler = IlceVerisi.ilinIlceleri(il.plaka);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('${ilceler.length} ilçe · vakitler seçtiğin ilçenin merkezine göre hesaplanır',
              style: const TextStyle(fontSize: 13, color: Renk.soluk)),
        ),
        for (final i in ilceler)
          ListTile(
            leading: Icon(i.ad == 'Merkez' ? Icons.location_city : Icons.location_on_outlined, color: Renk.ana),
            title: Text(i.ad, style: const TextStyle(fontWeight: FontWeight.w600)),
            trailing: durum.konum?.ad == i.tamAd ? const Icon(Icons.check, color: Renk.ana) : null,
            onTap: () => _ilceSec(i),
          ),
      ],
    );
  }
}
