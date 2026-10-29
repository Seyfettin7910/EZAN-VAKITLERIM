// Açılış ekranı: logo ortadan yukarı süzülür, altında uygulamanın adı, süs ve vakit ayeti belirir.
// Bu sırada ayarlar ve veriler arkada yüklenir; bitince ana ekrana yumuşakça geçilir.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../servis/bildirim_servisi.dart';
import '../servis/durum.dart';
import '../servis/icerik_servisi.dart';
import '../servis/yerel.dart';
import '../tema.dart';
import '../veri/ilceler.dart';

/// Logo dosyası (telefonun kendi açılış ekranındakiyle aynı resim, geçiş fark edilmesin diye).
const String logoDosyasi = 'assets/logo_on.png';

class AcilisEkrani extends StatefulWidget {
  const AcilisEkrani({super.key});

  @override
  State<AcilisEkrani> createState() => _AcilisEkraniState();
}

class _AcilisEkraniState extends State<AcilisEkrani> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  bool _ilkKareHazir = false;
  final Completer<void> _atla = Completer<void>(); // ekrana dokununca beklemeyi bitirir

  // Yüklemeyi ve animasyonu başlatır
  @override
  void initState() {
    super.initState();
    _yukleVeGec();
  }

  // Logo resmi hazır olmadan ilk kare çizilmesin (yoksa bir an boş yeşil ekran görünür)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ilkKareHazir) return;
    _ilkKareHazir = true;
    var izinVerildi = false;
    void izinVer() {
      if (izinVerildi) return;
      izinVerildi = true;
      WidgetsBinding.instance.allowFirstFrame();
      debugPrint('Açılış ekranı: ilk kare');
      _anim.forward();
    }

    precacheImage(const AssetImage(logoDosyasi), context, onError: (_, _) => izinVer()).then((_) => izinVer());
    Timer(const Duration(milliseconds: 800), izinVer); // resim gecikirse yine de aç
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // Ayarları ve verileri yükler; en az 3,5 saniye bekletir ki ayet rahat okunsun.
  // Ekrana dokunulursa ya da ezan uyarısıyla açıldıysa beklemeden geçer.
  Future<void> _yukleVeGec() async {
    final baslangic = DateTime.now();
    Future<void> guvenli(Future<void> Function() is_) async {
      try {
        await is_();
      } catch (hata) {
        debugPrint('Açılışta yükleme hatası: $hata');
      }
    }

    await guvenli(durum.yukle);
    await guvenli(BildirimServisi.baslat);
    await guvenli(IcerikServisi.yukle);
    await guvenli(IlceVerisi.yukle);
    final vakit = await Yerel.acilisVakti();

    if (vakit < 0) {
      final kalan = const Duration(milliseconds: 3500) - DateTime.now().difference(baslangic);
      if (kalan > Duration.zero) await Future.any([Future.delayed(kalan), _atla.future]);
    }
    if (!mounted) return;
    debugPrint('Açılış ekranı: ${DateTime.now().difference(baslangic).inMilliseconds} ms sonra ana ekrana geçiliyor');
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => Kabuk(acilisVakti: vakit),
      transitionsBuilder: (_, a, _, cocuk) => FadeTransition(opacity: a, child: cocuk),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Yazılar çok büyütülmüşse açılış ekranı taşmasın diye en fazla %130
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Renk.ana,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!_atla.isCompleted) _atla.complete();
            },
            child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              // Logo: ilk 0,8 saniyede ortadan yukarı süzülüp küçülür
              final hareket = Curves.easeInOutCubic.transform((_anim.value / 0.6).clamp(0.0, 1.0));
              // Yazılar: logo yerine otururken belirir
              final yazi = Curves.easeOutCubic.transform(((_anim.value - 0.4) / 0.6).clamp(0.0, 1.0));
              final logoBoyu = 288 - 98 * hareket;
              return Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _ZeminSusu(belirginlik: yazi))),
                  Align(
                    alignment: Alignment(0, -0.48 * hareket),
                    child: Image.asset(logoDosyasi, width: logoBoyu, height: logoBoyu, gaplessPlayback: true),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.42),
                    child: Opacity(
                      opacity: yazi,
                      child: Transform.translate(
                        offset: Offset(0, 24 * (1 - yazi)),
                        child: const _Yazilar(),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Opacity(
                      opacity: yazi * 0.7,
                      child: const Padding(
                        padding: EdgeInsets.only(bottom: 28),
                        child: SafeArea(
                          child: Text('Developed by Seyfettin AYDIN',
                              style: TextStyle(fontSize: 12, letterSpacing: 0.8, color: Renk.anaSoluk)),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          ),
        ),
      ),
    );
  }
}

/// Logonun altındaki yazılar: uygulamanın adı, süslü ayraç ve vakit ayeti (Nisâ 103).
class _Yazilar extends StatelessWidget {
  const _Yazilar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Ezan Vakitlerim',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: Renk.anaYazi,
                shadows: [Shadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 3))],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _Ayrac(),
          const SizedBox(height: 18),
          const Text(
            'إِنَّ ٱلصَّلَوٰةَ كَانَتْ عَلَى ٱلْمُؤْمِنِينَ كِتَٰبًۭا مَّوْقُوتًۭا',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 22, height: 1.7, color: Renk.altin),
          ),
          const SizedBox(height: 8),
          const Text(
            '“Namaz şüphesiz, inananlara belirli vakitlerde farz kılınmıştır.”',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w500, color: Renk.anaYazi),
          ),
          const SizedBox(height: 6),
          const Text('Nisâ Sûresi, 103', style: TextStyle(fontSize: 12.5, letterSpacing: 0.5, color: Renk.anaSoluk)),
        ],
      ),
    );
  }
}

/// İki yanı incelerek kaybolan altın çizgi, ortasında sekiz köşeli yıldız ve iki küçük nokta.
class _Ayrac extends StatelessWidget {
  const _Ayrac();

  @override
  Widget build(BuildContext context) {
    Widget cizgi(bool sol) => Container(
          width: 64,
          height: 1.6,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: sol ? [Renk.altin.withValues(alpha: 0), Renk.altin] : [Renk.altin, Renk.altin.withValues(alpha: 0)],
            ),
          ),
        );
    Widget nokta() => Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: const BoxDecoration(color: Renk.altin, shape: BoxShape.circle),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        cizgi(true),
        nokta(),
        const SizedBox(width: 18, height: 18, child: CustomPaint(painter: _Yildiz(renk: Renk.altin))),
        nokta(),
        cizgi(false),
      ],
    );
  }
}

/// Sekiz köşeli yıldız (üst üste konmuş iki kare) - geleneksel çini süsü.
class _Yildiz extends CustomPainter {
  final Color renk;
  final bool dolu;
  const _Yildiz({required this.renk, this.dolu = true});

  @override
  void paint(Canvas canvas, Size size) {
    final boya = Paint()
      ..color = renk
      ..style = dolu ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1;
    final m = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final yol = Path();
    for (var i = 0; i < 16; i++) {
      // Sırayla uç ve iç köşe noktaları
      final aci = -math.pi / 2 + i * math.pi / 8;
      final u = i.isEven ? r : r * 0.62;
      final p = m + Offset(math.cos(aci) * u, math.sin(aci) * u);
      i == 0 ? yol.moveTo(p.dx, p.dy) : yol.lineTo(p.dx, p.dy);
    }
    yol.close();
    canvas.drawPath(yol, boya);
  }

  @override
  bool shouldRepaint(_Yildiz eski) => eski.renk != renk || eski.dolu != dolu;
}

/// Zemin: ortada hafif aydınlık, üstte ve altta silik çini yıldız deseni.
class _ZeminSusu extends CustomPainter {
  final double belirginlik; // 0-1, yazılarla birlikte belirir
  const _ZeminSusu({required this.belirginlik});

  @override
  void paint(Canvas canvas, Size size) {
    // Ortadaki yumuşak ışık
    final isik = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF1C6B67).withValues(alpha: 0.9 * belirginlik), const Color(0x000F4C4A)],
      ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.4), radius: size.width * 0.9));
    canvas.drawRect(Offset.zero & size, isik);

    // Silik yıldız deseni: ekranın üstünde ve altında, ortaya doğru kaybolarak
    const aralik = 46.0;
    for (var y = aralik / 2; y < size.height; y += aralik) {
      final kenaraYakinlik = (1 - (y / size.height - 0.5).abs() * 2).clamp(0.0, 1.0); // ortada 1, kenarda 0
      final saydamlik = (1 - kenaraYakinlik) * 0.16 * belirginlik;
      if (saydamlik < 0.01) continue;
      final kaydir = ((y / aralik).floor().isOdd) ? aralik / 2 : 0.0;
      for (var x = -aralik / 2 + kaydir; x < size.width + aralik; x += aralik) {
        canvas.save();
        canvas.translate(x - 9, y - 9);
        _Yildiz(renk: Renk.altin.withValues(alpha: saydamlik), dolu: false).paint(canvas, const Size(18, 18));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ZeminSusu eski) => eski.belirginlik != belirginlik;
}
