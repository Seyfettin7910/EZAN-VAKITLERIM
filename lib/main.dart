// Ezan Vakitlerim - uygulamanın başladığı dosya.
// Developed by Seyfettin AYDIN

import 'package:flutter/material.dart';

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
import 'veri/ilceler.dart';

/// Tam ekran uyarıyı her yerden açabilmek için uygulamanın gezinme anahtarı.
final GlobalKey<NavigatorState> gezinme = GlobalKey<NavigatorState>();

/// Uygulama açılınca ilk çalışan fonksiyon: ayarları okur, bildirimleri hazırlar, ekranı açar.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await durum.yukle();
  await BildirimServisi.baslat();
  await IcerikServisi.yukle();
  await IlceVerisi.yukle();
  runApp(const EzanVakitlerimUygulamasi());
}

class EzanVakitlerimUygulamasi extends StatelessWidget {
  const EzanVakitlerimUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ezan Vakitlerim',
      debugShowCheckedModeBanner: false,
      navigatorKey: gezinme,
      theme: uygulamaTemasi(),
      home: const Kabuk(),
    );
  }
}

/// Alt menülü ana iskelet: Vakitler, Kıble, Camiler, İmsakiye, Ayarlar.
class Kabuk extends StatefulWidget {
  const Kabuk({super.key});

  @override
  State<Kabuk> createState() => _KabukState();
}

class _KabukState extends State<Kabuk> {
  int _sekme = 0;
  bool _tamEkranAcik = false;

  // Ekran ilk çizildikten sonra: tam ekran uyarıyla mı açıldık bak, izin iste,
  // uyarıları tazele, güncellemeden sonraysa yenilikleri göster, yeni sürüm denetle
  @override
  void initState() {
    super.initState();
    final ilkKurulum = durum.konum == null;
    Yerel.tamEkranDinle(_tamEkraniAc);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vakit = await Yerel.acilisVakti();
      if (vakit >= 0) _tamEkraniAc(vakit);
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
                const AnaEkran(),
                KibleEkrani(aktif: _sekme == 1), // pusula sadece bu sekme açıkken çalışır
                CamilerEkrani(aktif: _sekme == 2),
                const ImsakiyeEkrani(),
                const AyarlarEkrani(),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
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
        );
      },
    );
  }
}
