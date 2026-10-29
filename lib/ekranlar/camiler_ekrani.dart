// Yakındaki camiler: OpenStreetMap'ten (Overpass) çekilir, mesafeye göre sıralanır.
// Dokununca harita, yol tarifi düğmesiyle yürüyerek yol tarifi açılır.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../servis/ag.dart';
import '../servis/durum.dart';
import '../servis/yerel.dart';
import '../tema.dart';

class Cami {
  final String ad;
  final double enlem;
  final double boylam;
  final double metre; // bulunduğun yere uzaklık
  const Cami(this.ad, this.enlem, this.boylam, this.metre);

  String get uzaklik => metre < 1000 ? '${metre.round()} m' : '${(metre / 1000).toStringAsFixed(1)} km';
}

/// İki nokta arası kuş uçuşu uzaklık (metre).
double uzaklikMetre(double e1, double b1, double e2, double b2) {
  const r = 6371000.0;
  final f1 = e1 * math.pi / 180, f2 = e2 * math.pi / 180;
  final df = (e2 - e1) * math.pi / 180, dl = (b2 - b1) * math.pi / 180;
  final a = math.pow(math.sin(df / 2), 2) + math.cos(f1) * math.cos(f2) * math.pow(math.sin(dl / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

class CamilerEkrani extends StatefulWidget {
  final bool aktif; // sekme ilk görününce aramaya başlar
  const CamilerEkrani({super.key, required this.aktif});

  @override
  State<CamilerEkrani> createState() => _CamilerEkraniState();
}

class _CamilerEkraniState extends State<CamilerEkrani> {
  List<Cami>? _camiler;
  String? _hata;
  bool _araniyor = false;
  int _yaricap = 3000;
  bool _gpsKullanildi = false;

  @override
  void initState() {
    super.initState();
    if (widget.aktif) _ara();
  }

  @override
  void didUpdateWidget(CamilerEkrani eski) {
    super.didUpdateWidget(eski);
    if (widget.aktif && !eski.aktif && _camiler == null && !_araniyor) _ara();
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

  // Yakındaki camileri arar; 3 km içinde yoksa 10 km'ye genişletir
  Future<void> _ara() async {
    setState(() {
      _araniyor = true;
      _hata = null;
    });
    try {
      final (enlem, boylam, gps) = await _konum();
      var liste = await _overpass(enlem, boylam, 3000);
      var yaricap = 3000;
      if (liste.isEmpty) {
        liste = await _overpass(enlem, boylam, 10000);
        yaricap = 10000;
      }
      if (!mounted) return;
      setState(() {
        _camiler = liste;
        _yaricap = yaricap;
        _gpsKullanildi = gps;
      });
    } catch (_) {
      if (mounted) setState(() => _hata = 'Camiler getirilemedi. İnternet bağlantını kontrol edip tekrar dene.');
    } finally {
      if (mounted) setState(() => _araniyor = false);
    }
  }

  // OpenStreetMap'te, verilen yarıçap içindeki camileri sorgular
  Future<List<Cami>> _overpass(double enlem, double boylam, int metre) async {
    final sorgu = '[out:json][timeout:25];('
        'node["amenity"="place_of_worship"]["religion"="muslim"](around:$metre,$enlem,$boylam);'
        'way["amenity"="place_of_worship"]["religion"="muslim"](around:$metre,$enlem,$boylam);'
        'relation["amenity"="place_of_worship"]["religion"="muslim"](around:$metre,$enlem,$boylam);'
        ');out center 80;';
    final j = await jsonGetir(
      Uri.https('overpass-api.de', '/api/interpreter', {'data': sorgu}),
      sure: const Duration(seconds: 30),
    );
    final liste = <Cami>[];
    for (final e in (j['elements'] as List)) {
      final m = e as Map<String, dynamic>;
      final e1 = (m['lat'] ?? m['center']?['lat']) as num?;
      final b1 = (m['lon'] ?? m['center']?['lon']) as num?;
      if (e1 == null || b1 == null) continue;
      final etiket = (m['tags'] as Map<String, dynamic>?) ?? const {};
      final ad = (etiket['name:tr'] ?? etiket['name'] ?? 'Adı bilinmeyen cami') as String;
      liste.add(Cami(ad, e1.toDouble(), b1.toDouble(), uzaklikMetre(enlem, boylam, e1.toDouble(), b1.toDouble())));
    }
    liste.sort((a, b) => a.metre.compareTo(b.metre));
    return liste;
  }

  @override
  Widget build(BuildContext context) {
    final camiler = _camiler;
    return RefreshIndicator(
      onRefresh: _ara,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Yakındaki camiler', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Renk.yazi)),
                ),
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: _araniyor ? null : _ara,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (camiler != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text(
                '${_gpsKullanildi ? 'Bulunduğun yere' : '${durum.konum?.ad ?? ''} merkezine'} ${_yaricap ~/ 1000} km içinde ${camiler.length} cami',
                style: const TextStyle(fontSize: 13, color: Renk.soluk),
              ),
            ),
          if (_araniyor && camiler == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_hata!, style: const TextStyle(color: Color(0xFFB3261E))),
            ),
          if (camiler != null && camiler.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('10 km içinde haritada kayıtlı cami bulunamadı.', style: TextStyle(color: Renk.soluk)),
            ),
          if (camiler != null)
            for (final c in camiler)
              Card(
                elevation: 0,
                color: Renk.kart,
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Renk.etiket,
                    foregroundColor: Renk.ana,
                    child: Icon(Icons.mosque),
                  ),
                  title: Text(c.ad, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(c.uzaklik),
                  onTap: () => Yerel.haritadaAc(c.enlem, c.boylam, c.ad),
                  trailing: IconButton(
                    tooltip: 'Yürüyerek yol tarifi',
                    icon: const Icon(Icons.directions_walk, color: Renk.ana),
                    onPressed: () => Yerel.haritadaAc(c.enlem, c.boylam, c.ad, yolTarifi: true),
                  ),
                ),
              ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Harita verisi: © OpenStreetMap katkıcıları. Listede olmayan bir cami haritaya eklenmemiş olabilir.',
                style: TextStyle(fontSize: 12, color: Renk.soluk)),
          ),
        ],
      ),
    );
  }
}
