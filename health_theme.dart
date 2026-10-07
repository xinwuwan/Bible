// health_theme.dart
// 模块 C 健康（NEWSTART）的「表现层」属性：图标与主题色。
// 与 health_models.dart 分离，使数据模型保持纯 Dart（不依赖渲染层），
// 从而可在无 Flutter 引擎的环境下做单元测试 / 直接执行逻辑校验。
import 'package:flutter/material.dart';
import 'health_models.dart';

/// NEWSTART 八支柱的图标（仅 UI 使用）
extension NewstartCodeThemeX on NewstartCode {
  IconData get icon {
    switch (this) {
      case NewstartCode.nut:
        return Icons.restaurant_outlined;
      case NewstartCode.exe:
        return Icons.directions_walk;
      case NewstartCode.wat:
        return Icons.water_drop_outlined;
      case NewstartCode.sun:
        return Icons.wb_sunny_outlined;
      case NewstartCode.tem:
        return Icons.balance_outlined;
      case NewstartCode.air:
        return Icons.air;
      case NewstartCode.res:
        return Icons.nightlight_outlined;
      case NewstartCode.tru:
        return Icons.volunteer_activism_outlined;
    }
  }

  /// 主题色（浅色主题下均可读）
  Color get color {
    switch (this) {
      case NewstartCode.nut:
        return const Color(0xFF4C7F3A);
      case NewstartCode.exe:
        return const Color(0xFF2F6FB0);
      case NewstartCode.wat:
        return const Color(0xFF0E7C86);
      case NewstartCode.sun:
        return const Color(0xFFB8860B);
      case NewstartCode.tem:
        return const Color(0xFF7A5AA8);
      case NewstartCode.air:
        return const Color(0xFF3E8E8E);
      case NewstartCode.res:
        return const Color(0xFF4A5A8C);
      case NewstartCode.tru:
        return const Color(0xFF9C4F63);
    }
  }
}
