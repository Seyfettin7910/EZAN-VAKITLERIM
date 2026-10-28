// Konum seçme ekranı: GPS ile bul ya da 81 il içinden seç.
// Uygulama ilk açıldığında da bu ekran gelir.

import 'package:flutter/material.dart';

import '../servis/durum.dart';
import '../servis/konum_servisi.dart';
import '../tema.dart';
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

  // Seçilen konumu kaydeder ve (ilk açılış değilse) önceki ekrana döner
  Future<void> _sec(Konum k) async {
    await durum.konumAyarla(k);
    if (!widget.ilkAcilis && mounted) Navigator.of(context).pop();
  }

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
    final aranan = turkceKucuk(_arama.trim());
    final liste = iller.where((il) => turkceKucuk(il.ad).contains(aranan)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ilkAcilis ? 'Hoş geldin' : 'Konum seç', style: const TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: !widget.ilkAcilis,
      ),
      body: Column(
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
                labelText: 'İl ara',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Renk.kart,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: liste.length,
              itemBuilder: (context, i) {
                final il = liste[i];
                final secili = durum.konum?.ad == il.ad;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Renk.etiket,
                    foregroundColor: Renk.yazi,
                    child: Text('${il.plaka}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(il.ad, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: secili ? const Icon(Icons.check, color: Renk.ana) : null,
                  onTap: () => _sec(Konum(il.ad, il.enlem, il.boylam)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
