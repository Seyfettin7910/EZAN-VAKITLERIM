// Ezan Vakitlerim - uygulamanın başladığı dosya.
// Developed by Seyfettin AYDIN

import 'package:flutter/material.dart';

import 'ekranlar/acilis_ekrani.dart';
import 'ekranlar/ana_ekran.dart';
import 'ekranlar/ayarlar_ekrani.dart';
import 'ekranlar/camiler_ekrani.dart';
import 'ekranlar/guncelleme.dart';
import 'ekranlar/imsakiye_ekrani.dart';
import 'ekranlar/kible_ekrani.dart';
import 'ekranlar/konum_sec_ekrani.dart';
import 'ekranlar/tam_ekran.dart';
import 'servis/bildirim_servisi.dart';
import 'servis/durum.dart';
import 'servis/icerik_servisi.dart';
import 'servis/yerel.dart';
import 'tema.dart';

/// Tam ekran uyarıyı her yerden açabilmek için uygulamanın gezinme anahtarı.
final GlobalKey<NavigatorState> gezinme = GlobalKey<NavigatorState>();

/// Uygulama açılınca ilk çalışan fonksiyon: hemen açılış ekranını gösterir,
/// ayarlar ve veriler o ekran görünürken yüklenir (bkz. acilis_ekrani.dart).
void main() {
  final baglanti = WidgetsFlutterBinding.ensureInitialized();
  baglanti.deferFirstFrame(); // logo resmi hazır olunca açılış ekranı izin verir
  runApp(const EzanVakitlerimUygulamasi());
}

class EzanVakitlerimUygulamasi extends StatelessWidget {
  const EzanVakitlerimUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: durum,
      builder: (context, _) => MaterialApp(
        title: 'Ezan Vakitlerim',
        debugShowCheckedModeBanner: false,
        navigatorKey: gezinme,
        theme: uygulamaTemasi(),
        // Ayarlardaki "Yazı boyutu", telefonun kendi yazı boyutunun üstüne eklenir
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final telefon = mq.textScaler.scale(10) / 10;
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(telefon * durum.yaziBoyutu)),
            child: child!,
          );
        },
        home: const AcilisEkrani(),
      ),
    );
  }
}

/// Alt menülü ana iskelet: Vakitler, Kıble, Camiler, İmsakiye, Ayarlar.
class Kabuk extends StatefulWidget {
  /// Uygulama ezan uyarısıyla açıldıysa o vaktin numarası (0-5), değilse -1.
  final int acilisVakti;
  const Kabuk({super.key, this.acilisVakti = -1});

  @override
  State<Kabuk> createState() => _KabukState();
}

class _KabukState extends State<Kabuk> with WidgetsBindingObserver {
  int _sekme = 0;
  bool _tamEkranAcik = false;
  bool _onPlanda = true; // uygulama ekranda mı (arka plana atılınca sayaç ve pusula durur)

  // Uygulama arka plana gidince / geri gelince sekmelere haber verir
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final onde = state == AppLifecycleState.resumed;
    if (onde != _onPlanda) setState(() => _onPlanda = onde);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Ekran ilk çizildikten sonra: tam ekran uyarıyla mı açıldık bak, izin iste,
  // uyarıları tazele, güncellemeden sonraysa yenilikleri göster, yeni sürüm denetle
  @override
  void initState() {
    super.initState();
    final ilkKurulum = durum.konum == null;
    WidgetsBinding.instance.addObserver(this);
    Yerel.tamEkranDinle(_tamEkraniAc);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.acilisVakti >= 0) _tamEkraniAc(widget.acilisVakti);
      await BildirimServisi.izinIste();
      await BildirimServisi.planla();
      IcerikServisi.hatimOncedenIndir();
      if (!mounted || _tamEkranAcik) return;
      await yeniliklerGerekirseGoster(context, ilkKurulum: ilkKurulum);
      if (!mounted || _tamEkranAcik) return;
      await guncellemeDenetle(context);
    });
  }

  // Tam ekran vakit uyarısını açar (zaten açıksa ikinciyi açmaz)
  void _tamEkraniAc(int vakit) {
    if (_tamEkranAcik) return;
    _tamEkranAcik = true;
    gezinme.currentState
        ?.push(MaterialPageRoute(builder: (_) => TamEkranEkrani(vakit: vakit)))
        .whenComplete(() => _tamEkranAcik = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: durum,
      builder: (context, _) {
        // Konum seçilmemişse önce konum ekranı gelir
        if (durum.konum == null) return const KonumSecEkrani(ilkAcilis: true);

        return Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: _sekme,
              children: [
                // Sayaç ve pusula sadece kendi sekmeleri ekrandayken çalışır (pil ve işlemci için)
                AnaEkran(aktif: _sekme == 0 && _onPlanda),
                KibleEkrani(aktif: _sekme == 1 && _onPlanda),
                CamilerEkrani(aktif: _sekme == 2),
                const ImsakiyeEkrani(),
                const AyarlarEkrani(),
              ],
            ),
          ),
          // Alt menü yazıları en fazla %110'a kadar büyür, yoksa beş sekme sığmaz
          bottomNavigationBar: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.of(context).textScaler.clamp(maxScaleFactor: 1.1),
            ),
            child: NavigationBar(
            selectedIndex: _sekme,
            onDestinationSelected: (i) => setState(() => _sekme = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: 'Vakitler'),
              NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Kıble'),
              NavigationDestination(icon: Icon(Icons.mosque_outlined), selectedIcon: Icon(Icons.mosque), label: 'Camiler'),
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'İmsakiye'),
              NavigationDestination(icon: Icon(Icons.tune), label: 'Ayarlar'),
            ],
            ),
          ),
        );
      },
    );
  }
}
