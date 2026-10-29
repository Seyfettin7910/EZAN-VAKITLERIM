// Ayarlar: konum, sesli ezan ve uyarılar, telefon izinleri, güncelleme ve hakkında.

import 'package:flutter/material.dart';

import '../hesap/vakit_hesap.dart';
import '../servis/bildirim_servisi.dart';
import '../servis/durum.dart';
import '../servis/yerel.dart';
import '../surum.dart';
import '../tema.dart';
import 'guncelleme.dart';
import 'konum_sec_ekrani.dart';
import 'tam_ekran.dart';

class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key});

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> with WidgetsBindingObserver {
  bool _tamEkranIzni = true;
  bool _pilSerbest = true;

  // Ekran açılınca ve telefon ayarlarından geri dönünce izinlerin durumunu tazeler
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _izinleriOku();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _izinleriOku();
  }

  Future<void> _izinleriOku() async {
    final tam = await Yerel.tamEkranIzniVar();
    final pil = await Yerel.pilKisitlamasiYok();
    if (mounted) {
      setState(() {
        _tamEkranIzni = tam;
        _pilSerbest = pil;
      });
    }
  }

  // Bildirim iznini tekrar ister ve sonucu ekranın altında gösterir
  Future<void> _izinKontrol() async {
    final verildi = await BildirimServisi.izinIste();
    await BildirimServisi.planla();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(verildi
          ? 'Bildirim izni açık, önümüzdeki 14 günün uyarıları kuruldu.'
          : 'Bildirim izni kapalı. Telefon ayarlarından açabilirsin.'),
    ));
  }

  // Ezanı hemen okutur ve tam ekran uyarıyı açar (sesi denemek için)
  Future<void> _sesiDene() async {
    await Yerel.sesiDene(3);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TamEkranEkrani(vakit: 3)));
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

            const _Baslik('Ezan ve uyarı'),
            _Kart(children: [
              _Anahtar(
                baslik: 'Vakitlerde sesli ezan',
                aciklama: 'Uyarısı açık vakitlerde ezan okunur (güneş hariç)',
                deger: durum.sesliEzan,
                degisti: (v) => durum.ezanAyarla(sesli: v),
              ),
              _Anahtar(
                baslik: 'Ezan duası otomatik',
                aciklama: 'Ezan bitince ezan duası sesli okunur',
                deger: durum.duaOtomatik,
                degisti: durum.sesliEzan ? (v) => durum.ezanAyarla(dua: v) : null,
              ),
              _Anahtar(
                baslik: 'Tam ekran uyarı',
                aciklama: 'Vakit girince ekran açılır, kilitliyken de',
                deger: durum.tamEkran,
                degisti: durum.sesliEzan ? (v) => durum.ezanAyarla(tam: v) : null,
              ),
              _Anahtar(
                baslik: 'Sessizdeyken de oku',
                aciklama: 'Telefon sessiz ya da titreşimdeyken de ezan okunur',
                deger: durum.sessizdeOku,
                degisti: durum.sesliEzan ? (v) => durum.ezanAyarla(sessiz: v) : null,
              ),
              ListTile(
                title: const Text('Vakitten önce hatırlat', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Uyarısı açık vakitler için'),
                trailing: DropdownButton<int>(
                  value: durum.hatirlatmaDk,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final dk in hatirlatmaSecenekleri)
                      DropdownMenuItem(value: dk, child: Text(dk == 0 ? 'Kapalı' : '$dk dk önce')),
                  ],
                  onChanged: (dk) => durum.ezanAyarla(hatirlatma: dk),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.play_circle_outline, color: Renk.ana),
                title: const Text('Sesi dene', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Ezanı şimdi okutur, durdurabilirsin'),
                onTap: _sesiDene,
              ),
            ]),

            const _Baslik('Hangi vakitlerde uyarı'),
            _Kart(children: [
              for (var i = 0; i < 6; i++)
                SwitchListTile(
                  title: Text(vakitAdlari[i], style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: i == 0 && durum.sesliEzan ? const Text('Sabah ezanı okunur') : null,
                  value: durum.bildirimler[i],
                  activeTrackColor: Renk.ana,
                  onChanged: (acik) => durum.bildirimAyarla(i, acik),
                ),
            ]),

            const _Baslik('Telefon izinleri'),
            _Kart(children: [
              ListTile(
                leading: const Icon(Icons.notifications_outlined, color: Renk.ana),
                title: const Text('Bildirim izni', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Kontrol et ve uyarıları yeniden kur'),
                onTap: _izinKontrol,
              ),
              ListTile(
                leading: Icon(_tamEkranIzni ? Icons.check_circle : Icons.error_outline,
                    color: _tamEkranIzni ? Renk.ana : const Color(0xFFB3261E)),
                title: const Text('Tam ekran uyarı izni', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_tamEkranIzni ? 'Açık' : 'Kapalı: dokun, açılan ekranda izin ver'),
                onTap: _tamEkranIzni ? null : Yerel.tamEkranIzniAc,
              ),
              ListTile(
                leading: Icon(_pilSerbest ? Icons.check_circle : Icons.battery_alert_outlined,
                    color: _pilSerbest ? Renk.ana : const Color(0xFFB3261E)),
                title: const Text('Pil tasarrufu', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_pilSerbest
                    ? 'Ezan gecikmez'
                    : 'Telefon ezanı geciktirebilir: dokun ve "İzin ver" de'),
                onTap: _pilSerbest ? null : Yerel.pilAyariAc,
              ),
            ]),

            const _Baslik('Güncelleme'),
            _Kart(children: [
              _Anahtar(
                baslik: 'Otomatik denetle',
                aciklama: 'Uygulama açılınca yeni sürüm var mı bakar',
                deger: durum.otomatikGuncelle,
                degisti: durum.otomatikGuncelleAyarla,
              ),
              ListTile(
                leading: const Icon(Icons.system_update_outlined, color: Renk.ana),
                title: const Text('Şimdi denetle', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => guncellemeDenetle(context, sessiz: false),
              ),
              ListTile(
                leading: const Icon(Icons.new_releases_outlined, color: Renk.ana),
                title: const Text('Bu sürümde neler var', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => yeniliklerGoster(context),
              ),
            ]),

            const _Baslik('Hakkında'),
            const _Kart(children: [
              ListTile(
                title: Text('Ezan Vakitlerim', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Sürüm $uygulamaSurumu (derleme $derlemeNo) · Ücretsiz ve reklamsız'),
              ),
              ListTile(
                title: Text('Vakit hesabı', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Telefonda, Diyanet açılarıyla hesaplanır. Resmi takvimden en fazla 1 dakika farklı olabilir.'),
              ),
              ListTile(
                leading: Icon(Icons.favorite_outline, color: Renk.altinYazi),
                title: Text('Teşekkür', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Uygulamanın yapımında katkısı olan müezzinlerimize çok teşekkür ederiz. Allah onlardan razı olsun.'),
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

/// Açıklamalı aç/kapa satırı.
class _Anahtar extends StatelessWidget {
  final String baslik;
  final String aciklama;
  final bool deger;
  final ValueChanged<bool>? degisti; // null ise soluk ve dokunulamaz
  const _Anahtar({required this.baslik, required this.aciklama, required this.deger, required this.degisti});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(aciklama),
      value: deger,
      activeTrackColor: Renk.ana,
      onChanged: degisti,
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
