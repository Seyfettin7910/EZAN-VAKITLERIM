// Uygulamanın renkleri ve genel görünümü (tasarım panosundaki renklerle aynı).

import 'package:flutter/material.dart';

class Renk {
  static const zemin = Color(0xFFF2F5F4);
  static const kart = Color(0xFFFFFFFF);
  static const yazi = Color(0xFF12302E);
  static const soluk = Color(0xFF56706C);
  static const cizgi = Color(0xFFDCE4E2);
  static const ana = Color(0xFF0F4C4A); // çini yeşili
  static const anaYazi = Color(0xFFF2F5F4);
  static const anaSoluk = Color(0xFFB9D3CF);
  static const altin = Color(0xFFE0B054);
  static const altinYazi = Color(0xFF8A6416);
  static const iz = Color(0xFF2A6563);
  static const siradaki = Color(0xFFFFF8EA);
  static const halka = Color(0xFFD9A441);
  static const etiket = Color(0xFFE6EEEC);
}

/// Uygulamanın Material 3 teması.
ThemeData uygulamaTemasi() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Renk.ana,
      primary: Renk.ana,
      surface: Renk.zemin,
    ),
    scaffoldBackgroundColor: Renk.zemin,
    appBarTheme: const AppBarTheme(
      backgroundColor: Renk.zemin,
      foregroundColor: Renk.yazi,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Renk.kart,
      indicatorColor: Renk.etiket,
    ),
  );
}
