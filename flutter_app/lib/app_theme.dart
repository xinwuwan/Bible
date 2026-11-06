// app_theme.dart
// 全应用统一设计系统「圣卷 · 经典阅读」
// ============================================================
// 设计语言：
//   · 底色——暖羊皮纸白（阅读器质感，长时间阅读不刺眼）
//   · 主色——沉稳靛蓝（权威、庄重），点缀 antique gold（艺术感）
//   · 英文经文用系统无衬线（绝不用中文衬线，避免半角空格过窄导致单词粘连）；
//     中文正文用衬线 + 中文回退；UI 标签用无衬线
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

  // 三栏语义色（对照页 KJV 权威底本 / 本应用译文 / 和合本仅参照）
  static const Color scriptureBlue = Color(0xFF3F51B5);
  static const Color zhTeal = Color(0xFF007781);
  static const Color cuvGrey = Color(0xFF8D8D8D);

  // ---- 字体 ----
  static const String _serif = 'Georgia';
  // 注意顺序：英文优先字体必须排在 CJK 字体之前，否则缺少 Georgia 的设备
  // （如 Android 手机）会把英文用「中文衬线字体」的拉丁字形渲染——其半角
  // 空格极窄、字距偏紧，导致英文单词粘连（"beginningGod"）。CJK 字体应只
  // 作为中文（无拉丁字形）的兜底，绝不能承接拉丁字符。
  static const List<String> _serifFallback = [
    'Times New Roman',
    'serif',
    'Noto Serif SC',
    'Songti SC',
    'SimSun',
  ];

  /// 经文正文（衬线，阅读优化，中英混排通用）
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

  /// 英文经文专用样式。
  /// 已知教训（踩坑全过程）：
  ///   1) 内置 Tinos 字体 → 线上字体文件 404，英文被迫回退到回退链末尾的 `serif`；
  ///   2) 安卓上 `serif` 解析为思源宋体等「中文衬线」，其半角空格极窄、字距偏紧，
  ///      把 "In the beginning" 挤成 "Inthebeginning"——字母紧挨、单词边界不清。
  /// 因此本样式**三道保险**杜绝粘连：
  ///   · fontFamily 留空 ⇒ 走系统默认字体（安卓 Roboto / iOS 苹方-SF / Web 浏览器默认），
  ///     这些系统字体对拉丁字母的半角空格宽度都正常；
  ///   · 回退链只放拉丁无衬线（Helvetica/Arial）并以 CSS 通用族 'sans-serif' 收尾，
  ///     **绝不**出现 'serif' 通用族（那是安卓中文衬线的入口）；
  ///   · 再叠加 wordSpacing/letterSpacing，即便个别环境字体偏紧也能清晰分词、拉开字距。
  static TextStyle scriptureEn({
    double size = 15,
    Color color = ink,
    FontWeight weight = FontWeight.w500,
    double height = 1.75,
  }) {
    return TextStyle(
      // 系统默认字体（拉丁无衬线，半角空格正常）；回退链纯拉丁无衬线，无 CJK 衬线。
      // 微信 X5 下入口脚本会运行时请求 CanvasKit（Skia 直接绘制），彻底绕开 X5 对
      // html 渲染器 DOM 文本「字体放大/词间空格折叠」的缺陷；词距/字距由 Skia 精确绘制。
      fontFamily: null,
      fontFamilyFallback: const ['Helvetica', 'Arial', 'sans-serif'],
      fontSize: size,
      height: height,
      color: color,
      fontWeight: weight,
      wordSpacing: 2.2, // 额外加宽词间距（逻辑像素）：清晰分词、宽松易读
      letterSpacing: 0.2, // 轻微字距：进一步拉开字母，提升可读性
    );
  }

  /// 阅读字号自适应系数：依据屏幕宽度缩放，适配各种手机（小屏略小、大屏略大）。
  /// 系统「显示大小 / 字体大小 / 无障碍」设置由 Flutter 的 textScaleFactor 自动叠加，
  /// 无需在此处理——即使用户把系统字号调大，正文也会同步放大，不会被锁死。
  static double readingScale(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 560) return 1.12; // 平板 / 大屏
    if (w >= 430) return 1.04; // 大手机
    if (w >= 380) return 1.0; // 主流手机
    if (w >= 340) return 0.94; // 小屏手机
    return 0.88; // 超小屏
  }

  /// 标题（衬线，书卷气）
  ///
  /// 字重约定（重要）：微信 X5 / CanvasKit 下，仓库只自托管了**单字重(400)**
  /// 的 Noto Sans SC / TC 回退字体，没有 600/700 的真实粗体文件。对中文请求
  /// w600/w700/bold 时 Skia 会做「合成加粗(faux bold)」——重复描边让笔画密集
  /// 的字（典型如「问」门框内的「口」）糊成黑块。曾实测「牧师问答」标题的
  /// 「问」字内部变成实心方块。故全应用中文标题统一不超过 w500，层级感由
  /// 字号、字距、颜色表达；纯数字/拉丁文本可用 w700（拉丁有真实粗体字形）。
  static TextStyle heading({double size = 20, Color color = ink}) {
    return TextStyle(
      fontFamily: _serif,
      fontFamilyFallback: _serifFallback,
      fontSize: size,
      height: 1.35,
      color: color,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
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
        // w500 而非 w600：避免单字重 CJK 回退字体在 CanvasKit 下合成加粗，
        // 导致「牧师问答」等标题中的「问」字内部笔画糊成黑块。
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: ink,
          letterSpacing: 0.6,
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
        // 不写死 height：默认高度会随标签字号自适应（大字号无障碍），
        // 固定值会把放大的标签文字挤出可见区。
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
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
