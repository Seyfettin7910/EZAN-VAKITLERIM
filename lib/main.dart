// Ezan Vakitlerim - uygulamanın başladığı dosya.
// Developed by Seyfettin AYDIN

import 'package:flutter/material.dart';

import 'ekranlar/ana_ekran.dart';
import 'ekranlar/ayarlar_ekrani.dart';
import 'ekranlar/imsakiye_ekrani.dart';
import 'ekranlar/konum_sec_ekrani.dart';
import 'servis/bildirim_servisi.dart';
import 'servis/durum.dart';
import 'tema.dart';

/// Uygulama açılınca ilk çalışan fonksiyon: ayarları okur, bildirimleri hazırlar, ekranı açar.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await durum.yukle();
  await BildirimServisi.baslat();
  runApp(const EzanVakitlerimUygulamasi());
}

class EzanVakitlerimUygulamasi extends StatelessWidget {
  const EzanVakitlerimUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ezan Vakitlerim',
      debugShowCheckedModeBanner: false,
      theme: uygulamaTemasi(),
      home: const Kabuk(),
    );
  }
}

/// Alt menülü ana iskelet: Vakitler, İmsakiye, Ayarlar.
class Kabuk extends StatefulWidget {
  const Kabuk({super.key});

  @override
  State<Kabuk> createState() => _KabukState();
}

class _KabukState extends State<Kabuk> {
  int _sekme = 0;

  // Ekran ilk çizildikten sonra bildirim izni ister ve bildirimleri tazeler
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await BildirimServisi.izinIste();
      await BildirimServisi.planla();
    });
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
              children: const [AnaEkran(), ImsakiyeEkrani(), AyarlarEkrani()],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _sekme,
            onDestinationSelected: (i) => setState(() => _sekme = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: 'Vakitler'),
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'İmsakiye'),
              NavigationDestination(icon: Icon(Icons.tune), label: 'Ayarlar'),
            ],
          ),
        );
      },
    );
  }
}
