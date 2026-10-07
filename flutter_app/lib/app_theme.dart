// app_theme.dart
// 全应用统一设计系统「圣卷 · 经典阅读」
// ============================================================
// 设计语言：
//   · 底色——暖羊皮纸白（阅读器质感，长时间阅读不刺眼）
//   · 主色——沉稳靛蓝（权威、庄重），点缀 antique gold（艺术感）
//   · 经文正文统一使用衬线字体（Georgia + 中文衬线回退），UI 标签用无衬线
//   · 卡片零投影 + 细描边，克制、安静、有书卷气
//
// 合规：本文件只管视觉；权威层级文案（KJV 权威 / 参照标注）由各页面保留。

import 'package:flutter/material.dart';

class AppTheme {
  // ---- 色板 ----
  static const Color primary = Color(0xFF43518F); // 沉稳靛蓝
  static const Color primaryDeep = Color(0xFF32406F); // 深靛（渐变/按压）
  static const Color gold = Color(0xFFB08A3E); // antique gold 点缀
  static const Color bg = Color(0xFFFAF8F3); // 暖羊皮纸底
  static const Color ink = Color(0xFF2D2A26); // 正文墨色
  static const Color inkSoft = Color(0xFF6E6A63); // 次级文字
  static const Color line = Color(0xFFE9E4DA); // 细描边
  static const Color cardBg = Colors.white;

  // 三栏语义色（对照页 KJV / 本应用译文 / 和合本参照）
  static const Color scriptureBlue = Color(0xFF3F51B5);
  static const Color zhTeal = Color(0xFF007781);
  static const Color cuvGrey = Color(0xFF8D8D8D);

  // ---- 字体 ----
  static const String _serif = 'Georgia';
  static const List<String> _serifFallback = [
    'Noto Serif SC',
    'Songti SC',
    'SimSun',
    'serif',
  ];

  /// 经文正文（衬线，阅读优化）
  static TextStyle scripture({
    double size = 15,
    Color color = ink,
    FontWeight weight = FontWeight.w500,
    double height = 1.65,
  }) {
    return TextStyle(
      fontFamily: _serif,
      fontFamilyFallback: _serifFallback,
      fontSize: size,
      height: height,
      color: color,
      fontWeight: weight,
    );
  }

  /// 标题（衬线，书卷气）
  static TextStyle heading({double size = 20, Color color = ink}) {
    return TextStyle(
      fontFamily: _serif,
      fontFamilyFallback: _serifFallback,
      fontSize: size,
      height: 1.35,
      color: color,
      fontWeight: FontWeight.w700,
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: zhTeal,
      surface: cardBg,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: ink),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ink,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: line, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withOpacity(0.12),
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: const WidgetStatePropertyAll<TextStyle>(
          TextStyle(fontSize: 12, color: ink, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(textStyle: TextStyle(color: ink)),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: ink),
        bodyMedium: TextStyle(color: ink),
      ),
    );
  }
}
