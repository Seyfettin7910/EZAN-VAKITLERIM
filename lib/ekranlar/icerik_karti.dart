// "Bu vaktin ayeti / hadisi" kartı ve tam okuma ekranları.

import 'package:flutter/material.dart';

import '../servis/durum.dart';
import '../servis/icerik_servisi.dart';
import '../tema.dart';
import '../veri/sureler.dart';

/// Bir vaktin ayet grubunu ve hadisini gösteren kart. [koyu] tam ekran uyarı içindir.
class IcerikKarti extends StatefulWidget {
  final int slot;
  final bool koyu;
  const IcerikKarti({super.key, required this.slot, this.koyu = false});

  @override
  State<IcerikKarti> createState() => _IcerikKartiState();
}

class _IcerikKartiState extends State<IcerikKarti> {
  late Future<AyetGrubu?> _ayet;
  bool _hadisSekmesi = false;

  // Kart açılınca bu vaktin ayetini hazırlar (hatim modunda internetten gelebilir)
  @override
  void initState() {
    super.initState();
    _ayet = IcerikServisi.ayet(widget.slot);
  }

  @override
  void didUpdateWidget(IcerikKarti eski) {
    super.didUpdateWidget(eski);
    if (eski.slot != widget.slot) _ayet = IcerikServisi.ayet(widget.slot);
  }

  @override
  Widget build(BuildContext context) {
    final hadis = durum.hadisGoster ? IcerikServisi.hadis(widget.slot) : null;
    final hadisSekmesi = _hadisSekmesi && hadis != null;
    final zemin = widget.koyu ? Renk.zemin : Renk.kart;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Sekme('Ayet', secili: !hadisSekmesi, dokun: () => setState(() => _hadisSekmesi = false)),
              if (hadis != null) _Sekme('Hadis', secili: hadisSekmesi, dokun: () => setState(() => _hadisSekmesi = true)),
              const Spacer(),
              const Text('Bu vaktin', style: TextStyle(fontSize: 12, color: Renk.soluk)),
            ],
          ),
          const SizedBox(height: 6),
          if (hadisSekmesi)
            _HadisOzeti(hadis!)
          else
            FutureBuilder<AyetGrubu?>(
              future: _ayet,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final g = s.data;
                if (g == null) return const Text('Ayet yüklenemedi.', style: TextStyle(color: Renk.soluk));
                return _AyetOzeti(g);
              },
            ),
        ],
      ),
    );
  }
}

class _Sekme extends StatelessWidget {
  final String metin;
  final bool secili;
  final VoidCallback dokun;
  const _Sekme(this.metin, {required this.secili, required this.dokun});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton(
        onPressed: dokun,
        style: TextButton.styleFrom(
          backgroundColor: secili ? Renk.ana : Colors.transparent,
          foregroundColor: secili ? Renk.anaYazi : Renk.soluk,
          minimumSize: const Size(44, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(metin, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Kartta ayet grubunun ilk birkaç ayeti; dokununca tamamı açılır.
class _AyetOzeti extends StatelessWidget {
  final AyetGrubu g;
  const _AyetOzeti(this.g);

  @override
  Widget build(BuildContext context) {
    final ilkler = g.ayetler.take(2).toList();
    final devamiVar = g.ayetler.length > ilkler.length;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AyetOkumaEkrani(grup: g))),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(g.baslik, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Renk.altinYazi)),
          if (g.konu != null) Text(g.konu!, style: const TextStyle(fontSize: 12, color: Renk.soluk)),
          const SizedBox(height: 8),
          if (durum.arapcaGoster)
            Text(
              ilkler.map((a) => '${a.ar} ﴿${a.no}﴾').join(' '),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, height: 1.8, color: Renk.yazi),
            ),
          const SizedBox(height: 6),
          Text(
            ilkler.map((a) => '${a.no}. ${a.tr}').join(' '),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, height: 1.5, color: Renk.yazi),
          ),
          const SizedBox(height: 6),
          Text(devamiVar ? 'Devamını oku (${g.ayetler.length} ayet) ›' : 'Aç ›',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Renk.ana)),
        ],
      ),
    );
  }
}

/// Kartta hadisin kısa hali; dokununca tamamı ve açıklaması açılır.
class _HadisOzeti extends StatelessWidget {
  final Hadis h;
  const _HadisOzeti(this.h);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HadisOkumaEkrani(hadis: h))),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(h.metin, maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.5, color: Renk.yazi)),
          const SizedBox(height: 6),
          Text(h.kaynak, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Renk.soluk)),
          const SizedBox(height: 4),
          const Text('Tamamını ve açıklamasını oku ›', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Renk.ana)),
        ],
      ),
    );
  }
}

/// Ayet grubunun tamamı; öncesine ve sonrasına ayet eklenebilir.
class AyetOkumaEkrani extends StatefulWidget {
  final AyetGrubu grup;
  const AyetOkumaEkrani({super.key, required this.grup});

  @override
  State<AyetOkumaEkrani> createState() => _AyetOkumaEkraniState();
}

class _AyetOkumaEkraniState extends State<AyetOkumaEkrani> {
  late AyetGrubu _g = widget.grup;
  bool _yukleniyor = false;

  // Önceki ya da sonraki ayeti internetten getirip listeye ekler
  Future<void> _ekle(bool onceki) async {
    final no = onceki ? _g.bas - 1 : _g.son + 1;
    setState(() => _yukleniyor = true);
    try {
      final a = await IcerikServisi.tekAyet(_g.sure, no);
      if (mounted) setState(() => _g = _g.ekle(a));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ayet getirilemedi. İnternet bağlantını kontrol et.')));
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sonAyet = sureAyetSayilari[_g.sure - 1];
    return Scaffold(
      appBar: AppBar(title: Text(_g.baslik, style: const TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          if (_g.konu != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_g.konu!, style: const TextStyle(fontSize: 14, color: Renk.soluk)),
            ),
          if (_g.bas > 1)
            OutlinedButton.icon(
              onPressed: _yukleniyor ? null : () => _ekle(true),
              icon: const Icon(Icons.keyboard_arrow_up),
              label: Text('Önceki ayet (${_g.bas - 1})'),
            ),
          for (final a in _g.ayetler) _AyetSatiri(a),
          if (_g.son < sonAyet)
            OutlinedButton.icon(
              onPressed: _yukleniyor ? null : () => _ekle(false),
              icon: const Icon(Icons.keyboard_arrow_down),
              label: Text('Sonraki ayet (${_g.son + 1})'),
            ),
          if (_yukleniyor) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          const SizedBox(height: 16),
          const Text('Meal: Diyanet İşleri · Kaynak: AlQuran Cloud', style: TextStyle(fontSize: 12, color: Renk.soluk)),
        ],
      ),
    );
  }
}

class _AyetSatiri extends StatelessWidget {
  final Ayet a;
  const _AyetSatiri(this.a);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Renk.kart, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (durum.arapcaGoster)
            Text('${a.ar} ﴿${a.no}﴾',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 22, height: 1.9, color: Renk.yazi)),
          if (durum.arapcaGoster) const SizedBox(height: 8),
          Text('${a.no}. ${a.tr}', style: const TextStyle(fontSize: 16, height: 1.55, color: Renk.yazi)),
        ],
      ),
    );
  }
}

/// Hadisin tamamı, kaynağı ve açıklaması.
class HadisOkumaEkrani extends StatelessWidget {
  final Hadis hadis;
  const HadisOkumaEkrani({super.key, required this.hadis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hadis', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Renk.kart, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hadis.metin, style: const TextStyle(fontSize: 16, height: 1.6, color: Renk.yazi)),
                const SizedBox(height: 10),
                Text('${hadis.kaynak} · ${hadis.derece}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Renk.altinYazi)),
              ],
            ),
          ),
          if (hadis.aciklama.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 18, 4, 6),
              child: Text('Açıklama', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Renk.altinYazi)),
            ),
            Text(hadis.aciklama, style: const TextStyle(fontSize: 15, height: 1.6, color: Renk.yazi)),
          ],
          const SizedBox(height: 16),
          const Text('Kaynak: HadeethEnc (Hadis Ansiklopedisi)', style: TextStyle(fontSize: 12, color: Renk.soluk)),
        ],
      ),
    );
  }
}
