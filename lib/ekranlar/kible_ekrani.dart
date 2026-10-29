// Kıble pusulası: telefonun pusula sensörüyle Kâbe'nin yönünü gösterir.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../servis/durum.dart';
import '../servis/yerel.dart';
import '../tema.dart';

/// Kâbe'nin koordinatı
const double _kabeEnlem = 21.4225;
const double _kabeBoylam = 39.8262;

/// Kuzeyden saat yönünde kıble açısı (derece).
double kibleAcisi(double enlem, double boylam) {
  final f1 = enlem * math.pi / 180, f2 = _kabeEnlem * math.pi / 180;
  final dl = (_kabeBoylam - boylam) * math.pi / 180;
  final y = math.sin(dl) * math.cos(f2);
  final x = math.cos(f1) * math.sin(f2) - math.sin(f1) * math.cos(f2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Kâbe'ye kuş uçuşu uzaklık (km).
double kabeUzakligi(double enlem, double boylam) {
  const r = 6371.0;
  final f1 = enlem * math.pi / 180, f2 = _kabeEnlem * math.pi / 180;
  final df = f2 - f1, dl = (_kabeBoylam - boylam) * math.pi / 180;
  final a = math.pow(math.sin(df / 2), 2) + math.cos(f1) * math.cos(f2) * math.pow(math.sin(dl / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

class KibleEkrani extends StatefulWidget {
  final bool aktif; // sekme görünürken true; değilse sensör kapatılır (pil için)
  const KibleEkrani({super.key, required this.aktif});

  @override
  State<KibleEkrani> createState() => _KibleEkraniState();
}

class _KibleEkraniState extends State<KibleEkrani> {
  StreamSubscription<Map<dynamic, dynamic>>? _abone;
  double? _yon; // telefonun baktığı yön (derece, yumuşatılmış)
  int _dogruluk = 3;
  String? _hata;
  bool _hizali = false;

  @override
  void initState() {
    super.initState();
    if (widget.aktif) _dinle();
  }

  @override
  void didUpdateWidget(KibleEkrani eski) {
    super.didUpdateWidget(eski);
    if (widget.aktif && !eski.aktif) _dinle();
    if (!widget.aktif && eski.aktif) _birak();
  }

  @override
  void dispose() {
    _birak();
    super.dispose();
  }

  // Pusula sensörünü dinlemeye başlar; ani zıplamalar olmasın diye yönü yumuşatır
  void _dinle() {
    final k = durum.konum;
    if (k == null) return;
    _abone = Yerel.pusula(k.enlem, k.boylam).listen((o) {
      final yeni = (o['aci'] as num).toDouble();
      final onceki = _yon;
      double sonuc;
      if (onceki == null) {
        sonuc = yeni;
      } else {
        // 359° ile 1° arasında dönerken ters yöne dönmesin diye farkı -180..180 arasına getir
        final fark = ((yeni - onceki + 540) % 360) - 180;
        sonuc = (onceki + fark * 0.25 + 360) % 360;
      }
      setState(() {
        _yon = sonuc;
        _dogruluk = (o['dogruluk'] as num?)?.toInt() ?? 3;
        _hata = null;
      });
    }, onError: (e) {
      setState(() => _hata = 'Bu telefonda pusula sensörü bulunamadı.');
    });
  }

  void _birak() {
    _abone?.cancel();
    _abone = null;
  }

  @override
  Widget build(BuildContext context) {
    final k = durum.konum;
    if (k == null) return const SizedBox.shrink();
    final kible = kibleAcisi(k.enlem, k.boylam);
    final uzaklik = kabeUzakligi(k.enlem, k.boylam);
    final yon = _yon;
    // Kıbleye kaç derece kaldı (-180..180)
    final fark = yon == null ? null : ((kible - yon + 540) % 360) - 180;
    final hizali = fark != null && fark.abs() <= 3;
    if (hizali && !_hizali) HapticFeedback.mediumImpact();
    _hizali = hizali;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        const Text('Kıble', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Renk.yazi)),
        const SizedBox(height: 4),
        Text('${k.ad} · Kâbe\'ye ${uzaklik.round()} km', style: const TextStyle(fontSize: 13, color: Renk.soluk)),
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: CustomPaint(painter: _PusulaCizimi(yon: yon ?? 0, kible: kible, hizali: hizali)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${kible.round()}°',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: hizali ? Renk.ana : Renk.altinYazi),
        ),
        Text(
          _hata ??
              (fark == null
                  ? 'Pusula hazırlanıyor…'
                  : hizali
                      ? 'Kıbleye dönüksün'
                      : (fark > 0 ? '${fark.round()}° sağa dön' : '${(-fark).round()}° sola dön')),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Renk.yazi),
        ),
        const SizedBox(height: 4),
        const Text('Kuzeyden saat yönünde kıble açısı', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Renk.soluk)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Renk.kart, borderRadius: BorderRadius.circular(16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_dogruluk < 2 ? Icons.warning_amber_rounded : Icons.stay_current_portrait, color: Renk.altinYazi),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _dogruluk < 2
                      ? 'Pusula ayarsız görünüyor. Telefonu havada birkaç kez 8 çizerek salla.'
                      : 'Telefonu yere paralel tut, metal eşya ve mıknatıstan uzak dur. Kâbe simgesi tam üstte durduğunda kıbleye dönmüşsün.',
                  style: const TextStyle(fontSize: 14, height: 1.45, color: Renk.yazi),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pusula kadranı: kuzey gerçek kuzeye bakar, Kâbe simgesi kıble yönündedir.
/// Telefonun baktığı yön her zaman en üstteki işarettir.
class _PusulaCizimi extends CustomPainter {
  final double yon;
  final double kible;
  final bool hizali;
  _PusulaCizimi({required this.yon, required this.kible, required this.hizali});

  @override
  void paint(Canvas canvas, Size size) {
    final m = size.center(Offset.zero);
    final r = size.width / 2 - 6;

    // Zemin
    canvas.drawCircle(m, r, Paint()..color = Renk.kart);
    canvas.drawCircle(m, r, Paint()
      ..color = hizali ? Renk.ana : Renk.cizgi
      ..style = PaintingStyle.stroke
      ..strokeWidth = hizali ? 4 : 2);

    // Telefonun baktığı yönü gösteren sabit üst işaret
    final ust = Path()
      ..moveTo(m.dx, m.dy - r - 4)
      ..lineTo(m.dx - 9, m.dy - r + 12)
      ..lineTo(m.dx + 9, m.dy - r + 12)
      ..close();
    canvas.drawPath(ust, Paint()..color = Renk.yazi);

    canvas.save();
    canvas.translate(m.dx, m.dy);
    canvas.rotate(-yon * math.pi / 180); // kadranı telefonun yönüne göre çevir

    // Çentikler (her 30°)
    final cizgi = Paint()
      ..color = Renk.soluk
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var d = 0; d < 360; d += 30) {
      final a = d * math.pi / 180;
      final ic = d % 90 == 0 ? r - 22 : r - 14;
      canvas.drawLine(Offset(math.sin(a) * ic, -math.cos(a) * ic), Offset(math.sin(a) * (r - 4), -math.cos(a) * (r - 4)), cizgi);
    }
    // Yön harfleri
    const harfler = {'K': 0.0, 'D': 90.0, 'G': 180.0, 'B': 270.0};
    harfler.forEach((h, d) {
      final a = d * math.pi / 180;
      final tp = TextPainter(
        text: TextSpan(text: h, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: h == 'K' ? const Color(0xFFB3261E) : Renk.soluk)),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = Offset(math.sin(a) * (r - 40), -math.cos(a) * (r - 40));
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    });

    // Kıble iğnesi ve Kâbe simgesi
    final ka = kible * math.pi / 180;
    final uc = Offset(math.sin(ka) * (r - 62), -math.cos(ka) * (r - 62));
    canvas.drawLine(Offset.zero, uc, Paint()
      ..color = Renk.altin
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round);
    final kabe = Offset(math.sin(ka) * (r - 46), -math.cos(ka) * (r - 46));
    canvas.save();
    canvas.translate(kabe.dx, kabe.dy);
    canvas.rotate(ka);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -12, 24, 24), const Radius.circular(3)), Paint()..color = Renk.yazi);
    canvas.drawRect(const Rect.fromLTWH(-12, -7, 24, 4), Paint()..color = Renk.altin);
    canvas.restore();

    canvas.restore();
    // Orta nokta
    canvas.drawCircle(m, 9, Paint()..color = Renk.yazi);
    canvas.drawCircle(m, 3.5, Paint()..color = Renk.kart);
  }

  @override
  bool shouldRepaint(_PusulaCizimi eski) => eski.yon != yon || eski.kible != kible || eski.hizali != hizali;
}
