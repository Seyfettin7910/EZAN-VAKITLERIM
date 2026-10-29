// Güncelleme penceresi ve "Yenilikler" penceresi.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../servis/durum.dart';
import '../servis/guncelleme_servisi.dart';
import '../surum.dart';
import '../tema.dart';

/// Yeni sürüm var mı diye bakar. [sessiz] ise (açılışta) günde en fazla iki kez bakar,
/// güncelse ya da internet yoksa hiçbir şey göstermez. Elle denetimde sonucu söyler.
Future<void> guncellemeDenetle(BuildContext context, {bool sessiz = true}) async {
  final simdi = DateTime.now().millisecondsSinceEpoch;
  if (sessiz) {
    if (!durum.otomatikGuncelle) return;
    if (simdi - durum.sonDenetim < const Duration(hours: 12).inMilliseconds) return;
  }
  final mesaj = ScaffoldMessenger.maybeOf(context);
  try {
    final yeni = await GuncellemeServisi.denetle();
    await durum.sonDenetimKaydet(simdi);
    if (!context.mounted) return;
    if (yeni != null) {
      await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => GuncellemePenceresi(yeni));
    } else if (!sessiz) {
      mesaj?.showSnackBar(const SnackBar(content: Text('Uygulama güncel, en son sürümü kullanıyorsun.')));
    }
  } catch (_) {
    if (!sessiz) {
      mesaj?.showSnackBar(const SnackBar(content: Text('Güncelleme denetlenemedi. İnternet bağlantını kontrol et.')));
    }
  }
}

/// Güncellemeden sonraki ilk açılışta "Yenilikler" penceresini bir kez gösterir.
Future<void> yeniliklerGerekirseGoster(BuildContext context, {required bool ilkKurulum}) async {
  if (derlemeNo == 0 || durum.sonGorulenDerleme == derlemeNo) return;
  await durum.sonGorulenDerlemeKaydet(derlemeNo);
  if (ilkKurulum || !context.mounted) return;
  await yeniliklerGoster(context);
}

/// Bu sürümde nelerin değiştiğini gösterir (assets/yenilikler.txt).
Future<void> yeniliklerGoster(BuildContext context) async {
  final metin = await rootBundle.loadString('assets/yenilikler.txt');
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Yenilikler · $uygulamaSurumu', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(child: Text(metin.trim(), style: const TextStyle(height: 1.5))),
      actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Tamam'))],
    ),
  );
}

/// Yeni sürümü anlatan, indirip kurmayı sağlayan pencere.
class GuncellemePenceresi extends StatefulWidget {
  final YeniSurum yeni;
  const GuncellemePenceresi(this.yeni, {super.key});

  @override
  State<GuncellemePenceresi> createState() => _GuncellemePenceresiState();
}

class _GuncellemePenceresiState extends State<GuncellemePenceresi> {
  double? _ilerleme; // indirilirken 0-1, indirme yokken null
  String? _hata;
  String? _inenDosya; // indirilip doğrulanmış APK'nın yolu

  // İndirir (daha önce indiyse tekrar indirmez) ve kurulum ekranını açar
  Future<void> _guncelle() async {
    setState(() {
      _hata = null;
      _ilerleme = _inenDosya == null ? 0 : null;
    });
    try {
      _inenDosya ??= await GuncellemeServisi.indir(widget.yeni, (o) {
        if (mounted) setState(() => _ilerleme = o);
      });
      if (mounted) setState(() => _ilerleme = null);
      await GuncellemeServisi.kur(_inenDosya!);
    } on KurulumIzniGerekli {
      if (mounted) {
        setState(() => _hata = 'Açılan ekranda "Bu kaynaktan izin ver"i aç, sonra geri dönüp "Kur"a bas.');
      }
    } catch (hata) {
      if (mounted) {
        setState(() {
          _ilerleme = null;
          _hata = hata.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final indiriliyor = _ilerleme != null;
    return AlertDialog(
      title: Text('Yeni sürüm: ${widget.yeni.surum}', style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Şu anki sürüm $uygulamaSurumu · İndirme ${widget.yeni.boyutMb} MB',
                style: const TextStyle(fontSize: 13, color: Renk.soluk)),
            if (widget.yeni.notlar.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Yenilikler', style: TextStyle(fontWeight: FontWeight.w800, color: Renk.altinYazi)),
              const SizedBox(height: 4),
              Text(widget.yeni.notlar.trim(), style: const TextStyle(height: 1.5)),
            ],
            if (indiriliyor) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _ilerleme, color: Renk.ana, backgroundColor: Renk.etiket),
              const SizedBox(height: 6),
              Text('İndiriliyor… %${((_ilerleme ?? 0) * 100).round()}', style: const TextStyle(fontSize: 13)),
            ],
            if (_hata != null) ...[
              const SizedBox(height: 12),
              Text(_hata!, style: const TextStyle(color: Color(0xFFB3261E))),
            ],
            const SizedBox(height: 12),
            const Text('Ayarların ve konumun silinmez.', style: TextStyle(fontSize: 12, color: Renk.soluk)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: indiriliyor ? null : () => Navigator.pop(context), child: const Text('Sonra')),
        FilledButton(
          onPressed: indiriliyor ? null : _guncelle,
          style: FilledButton.styleFrom(backgroundColor: Renk.ana),
          child: Text(_inenDosya != null ? 'Kur' : 'Güncelle'),
        ),
      ],
    );
  }
}
