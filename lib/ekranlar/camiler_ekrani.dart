// Yakındaki camiler: liste ya da harita görünümü. Veri ve harita OpenStreetMap'ten gelir.
// Bir camiye dokununca haritada gösterilir; "Yol tarifi" yürüyüş yolunu haritaya çizer.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../servis/cami_servisi.dart';
import '../servis/durum.dart';
import '../servis/yerel.dart';
import '../tema.dart';
import '../yardimci.dart';

class CamilerEkrani extends StatefulWidget {
  final bool aktif; // sekme ilk görününce aramaya başlar
  const CamilerEkrani({super.key, required this.aktif});

  @override
  State<CamilerEkrani> createState() => _CamilerEkraniState();
}

class _CamilerEkraniState extends State<CamilerEkrani> {
  CamiSonucu? _sonuc;
  String? _hata;
  bool _araniyor = false;
  bool _harita = false; // false: liste, true: harita
  Cami? _secili;
  YuruyusYolu? _yol;
  bool _yolAraniyor = false;
  MapController _haritaKontrol = MapController();
  bool _haritaHazir = false;
  int _haritaNo = 0; // her yeni harita kurulumunda artar (harita baştan çizilsin diye)

  // Harita görünümü yeniden açılırken yeni bir harita denetleyicisi hazırlar
  void _yeniHarita() {
    _haritaKontrol = MapController();
    _haritaHazir = false;
    _haritaNo++;
  }

  @override
  void initState() {
    super.initState();
    if (widget.aktif) _ara();
  }

  @override
  void didUpdateWidget(CamilerEkrani eski) {
    super.didUpdateWidget(eski);
    if (widget.aktif && !eski.aktif && _sonuc == null && !_araniyor) _ara();
  }

  // Şu anki konumu bulur: GPS izni varsa canlı konum, yoksa seçili konum
  Future<(double, double, bool)> _konum() async {
    try {
      final izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.always || izin == LocationPermission.whileInUse) {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
        );
        return (p.latitude, p.longitude, true);
      }
    } catch (_) {
      // GPS alınamazsa seçili konuma düş
    }
    final k = durum.konum!;
    return (k.enlem, k.boylam, false);
  }

  // Camileri arar (sunucu meşgulse yedeklere sorar, internet yoksa son listeyi gösterir)
  Future<void> _ara() async {
    setState(() {
      _araniyor = true;
      _hata = null;
    });
    try {
      final (enlem, boylam, gps) = await _konum();
      final sonuc = await CamiServisi.ara(enlem, boylam, gps: gps);
      if (!mounted) return;
      setState(() {
        _sonuc = sonuc;
        _secili = null;
        _yol = null;
        _yeniHarita(); // yeni sonuçla harita baştan kurulur
      });
    } on CamiHatasi catch (h) {
      if (mounted) {
        setState(() => _hata = h.internetYok
            ? 'İnternete bağlanılamadı. Bağlantını kontrol edip yenile düğmesine bas.'
            : 'Cami sunucuları şu an çok yoğun. Biraz sonra yenile düğmesine bas.');
      }
    } catch (_) {
      if (mounted) setState(() => _hata = 'Camiler getirilemedi. Biraz sonra tekrar dene.');
    } finally {
      if (mounted) setState(() => _araniyor = false);
    }
  }

  // Bir camiyi seçer, haritaya geçip onu ortalar
  void _sec(Cami c) {
    setState(() {
      if (!_harita) _yeniHarita();
      _secili = c;
      _yol = null;
      _harita = true;
    });
    if (_haritaHazir) _haritaKontrol.move(c.nokta, 16.5);
  }

  // Seçili camiye yürüyüş yolunu hesaplatıp haritaya çizer
  Future<void> _yolTarifi(Cami c) async {
    final s = _sonuc;
    if (s == null) return;
    setState(() {
      if (!_harita) _yeniHarita();
      _secili = c;
      _harita = true;
      _yolAraniyor = true;
    });
    try {
      final yol = await CamiServisi.yuruyusYolu(LatLng(s.enlem, s.boylam), c.nokta);
      if (!mounted) return;
      setState(() => _yol = yol);
      if (_haritaHazir) _haritaKontrol.fitCamera(_yolCercevesi(yol));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yol tarifi alınamadı. İnternet bağlantını kontrol et.')),
        );
      }
    } finally {
      if (mounted) setState(() => _yolAraniyor = false);
    }
  }

  CameraFit _yolCercevesi(YuruyusYolu yol) => CameraFit.coordinates(
        coordinates: yol.noktalar,
        padding: const EdgeInsets.fromLTRB(48, 48, 48, 230),
        maxZoom: 17.5,
      );

  @override
  Widget build(BuildContext context) {
    final s = _sonuc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 4),
          child: Row(
            children: [
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('Yakındaki camiler', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Renk.yazi)),
                ),
              ),
              IconButton(
                tooltip: 'Yenile',
                onPressed: _araniyor ? null : _ara,
                icon: _araniyor
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        // Liste / Harita seçimi
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.view_list), label: Text('Liste')),
              ButtonSegment(value: true, icon: Icon(Icons.map_outlined), label: Text('Harita')),
            ],
            selected: {_harita},
            showSelectedIcon: false,
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(0, 50)),
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            onSelectionChanged: (secim) => setState(() {
              if (secim.first && !_harita) _yeniHarita();
              _harita = secim.first;
            }),
          ),
        ),
        if (s != null) _bilgiSatiri(s),
        if (_hata != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Text(_hata!, style: const TextStyle(fontSize: 15, color: Color(0xFFB3261E))),
          ),
        Expanded(
          child: s == null
              ? (_araniyor ? const Center(child: CircularProgressIndicator()) : _kaynakNotu())
              : (_harita ? _haritaGorunumu(s) : _listeGorunumu(s)),
        ),
      ],
    );
  }

  // "Bulunduğun yere 3 km içinde 12 cami" (internet yoksa son aramanın tarihi)
  Widget _bilgiSatiri(CamiSonucu s) {
    final yer = s.gps ? 'Bulunduğun yere' : '${durum.konum?.ad ?? ''} merkezine';
    final metin = '$yer ${s.yaricap ~/ 1000} km içinde ${s.camiler.length} cami';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
      child: Text(
        s.eski ? '$metin · İnternet olmadığı için ${tarihYaz(s.zaman)} tarihli son liste gösteriliyor' : metin,
        style: TextStyle(fontSize: 13, color: s.eski ? Renk.altinYazi : Renk.soluk),
      ),
    );
  }

  Widget _kaynakNotu() => const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Harita verisi: © OpenStreetMap katkıcıları. Listede olmayan bir cami haritaya eklenmemiş olabilir.',
            style: TextStyle(fontSize: 12, color: Renk.soluk)),
      );

  Widget _listeGorunumu(CamiSonucu s) {
    return RefreshIndicator(
      onRefresh: _ara,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (s.camiler.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('10 km içinde haritada kayıtlı cami bulunamadı.', style: TextStyle(color: Renk.soluk)),
            ),
          for (final c in s.camiler)
            Card(
              elevation: 0,
              color: Renk.kart,
              margin: const EdgeInsets.symmetric(vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                minVerticalPadding: 12,
                leading: const CircleAvatar(backgroundColor: Renk.etiket, foregroundColor: Renk.ana, child: Icon(Icons.mosque)),
                title: Text(c.ad, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                subtitle: Text(c.uzaklik, style: const TextStyle(fontSize: 14)),
                onTap: () => _sec(c),
                trailing: IconButton(
                  tooltip: 'Yürüyerek yol tarifi',
                  iconSize: 28,
                  icon: const Icon(Icons.directions_walk, color: Renk.ana),
                  onPressed: () => _yolTarifi(c),
                ),
              ),
            ),
          _kaynakNotu(),
        ],
      ),
    );
  }

  Widget _haritaGorunumu(CamiSonucu s) {
    final ben = LatLng(s.enlem, s.boylam);
    final secili = _secili;
    final yol = _yol;

    // Harita ilk açılışta neyi göstersin: çizili yol, seçili cami ya da sen + en yakın camiler
    var merkez = ben;
    var yakinlik = 15.0;
    CameraFit? cerceve;
    if (yol != null) {
      cerceve = _yolCercevesi(yol);
    } else if (secili != null) {
      merkez = secili.nokta;
      yakinlik = 16.5;
    } else if (s.camiler.isNotEmpty) {
      cerceve = CameraFit.coordinates(
        coordinates: [ben, for (final c in s.camiler.take(8)) c.nokta],
        padding: const EdgeInsets.all(56),
        maxZoom: 16.5,
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: FlutterMap(
            key: ValueKey(_haritaNo),
            mapController: _haritaKontrol,
            options: MapOptions(
              initialCenter: merkez,
              initialZoom: yakinlik,
              initialCameraFit: cerceve,
              onMapReady: () => _haritaHazir = true,
              minZoom: 5,
              maxZoom: 19,
              // Harita döndürülmesin (yaşlılar için kafa karıştırmasın)
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (_, _) => setState(() {
                _secili = null;
                _yol = null;
              }),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.seyfettin.ezan_vakitlerim',
                maxNativeZoom: 19,
              ),
              CircleLayer(circles: [
                CircleMarker(
                  point: ben,
                  radius: s.yaricap.toDouble(),
                  useRadiusInMeter: true,
                  color: Renk.ana.withValues(alpha: 0.05),
                  borderColor: Renk.ana.withValues(alpha: 0.35),
                  borderStrokeWidth: 1.5,
                ),
              ]),
              if (yol != null)
                PolylineLayer(polylines: [
                  Polyline(points: yol.noktalar, strokeWidth: 9, color: Colors.white),
                  Polyline(points: yol.noktalar, strokeWidth: 5.5, color: const Color(0xFF1565C0)),
                ]),
              MarkerLayer(markers: [
                for (final c in s.camiler)
                  Marker(
                    point: c.nokta,
                    width: identical(c, secili) ? 54 : 42,
                    height: identical(c, secili) ? 54 : 42,
                    child: GestureDetector(onTap: () => _sec(c), child: _CamiIsareti(secili: identical(c, secili))),
                  ),
                Marker(point: ben, width: 26, height: 26, child: const _BenIsareti()),
              ]),
              const SimpleAttributionWidget(source: Text('OpenStreetMap katkıcıları')),
            ],
          ),
        ),
        // Konumuma dön düğmesi
        Positioned(
          right: 14,
          top: 14,
          child: FloatingActionButton.small(
            heroTag: 'konumuma-don',
            tooltip: 'Konumuma dön',
            backgroundColor: Renk.kart,
            foregroundColor: Renk.ana,
            onPressed: () {
              if (_haritaHazir) _haritaKontrol.move(ben, 15.5);
            },
            child: const Icon(Icons.my_location),
          ),
        ),
        if (secili != null) Positioned(left: 12, right: 12, bottom: 12, child: _seciliKart(secili, yol)),
        if (s.camiler.isEmpty)
          const Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('10 km içinde haritada kayıtlı cami bulunamadı.'),
              ),
            ),
          ),
      ],
    );
  }

  // Haritanın altında seçili caminin kartı: adı, uzaklığı, yol tarifi
  Widget _seciliKart(Cami c, YuruyusYolu? yol) {
    return Material(
      elevation: 6,
      color: Renk.kart,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mosque, color: Renk.ana, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(c.ad,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Renk.yazi)),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _secili = null;
                    _yol = null;
                  }),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 10),
              child: Text(
                yol != null ? yol.ozet : 'Kuş uçuşu ${c.uzaklik}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: yol != null ? FontWeight.w700 : FontWeight.w500,
                    color: yol != null ? const Color(0xFF1565C0) : Renk.soluk),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 52), backgroundColor: Renk.ana),
                    onPressed: _yolAraniyor || yol != null ? null : () => _yolTarifi(c),
                    icon: _yolAraniyor
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Icon(Icons.directions_walk),
                    label: Text(yol != null ? 'Yol çizildi' : 'Yol tarifi', style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Telefondaki harita uygulamasında aç',
                  iconSize: 26,
                  style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
                  onPressed: () => Yerel.haritadaAc(c.enlem, c.boylam, c.ad),
                  icon: const Icon(Icons.open_in_new),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Haritada cami işareti: yeşil yuvarlak içinde cami simgesi (seçiliyse altın çerçeveli, büyük).
class _CamiIsareti extends StatelessWidget {
  final bool secili;
  const _CamiIsareti({required this.secili});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Renk.ana,
        shape: BoxShape.circle,
        border: Border.all(color: secili ? Renk.altin : Colors.white, width: secili ? 4 : 2.5),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Icon(Icons.mosque, color: Colors.white, size: secili ? 26 : 20),
    );
  }
}

/// Haritada "sen buradasın" noktası.
class _BenIsareti extends StatelessWidget {
  const _BenIsareti();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3.5),
        boxShadow: const [BoxShadow(color: Color(0x551E88E5), blurRadius: 10, spreadRadius: 4)],
      ),
    );
  }
}
