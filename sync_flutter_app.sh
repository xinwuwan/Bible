#!/usr/bin/env bash
# sync_flutter_app.sh
# 把工作区根目录平铺的 .dart 源文件同步进 flutter_app/ 工程（lib/ 与 test/），
# 便于用真实 Flutter SDK 做 `dart analyze` / `flutter test`。
#
# 用法：bash sync_flutter_app.sh
#
# 前置：已装 Flutter（本工作区实测装在 ~/workbuddy/binaries/flutter/flutter）。
# 注意 flutter_app/ 目前只有 lib/ test/ assets/ pubspec.yaml（最小结构，够 analyze/test）。
# 若要真正打包（apk/exe/web），先在 flutter_app/ 里跑：
#   flutter create --project-name faith_compare_app --org com.example .
# 补齐各平台目录（该命令在本机生成较慢，建议后台跑）。

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W 2>/dev/null || pwd)"
APP="$PROJECT_ROOT/flutter_app"

mkdir -p "$APP/lib" "$APP/test/helpers" "$APP/assets"

cp "$PROJECT_ROOT"/*.dart "$APP/lib/"
cp "$PROJECT_ROOT"/test/*.dart "$APP/test/"
cp "$PROJECT_ROOT"/test/helpers/*.dart "$APP/test/helpers/"
cp "$PROJECT_ROOT/pubspec_example.yaml" "$APP/pubspec.yaml"

# 资产：离线库 + 注记（缺失会让 analyze 报资产未找到）
[ -f "$PROJECT_ROOT/app_offline.db" ] && cp "$PROJECT_ROOT/app_offline.db" "$APP/assets/"
[ -f "$PROJECT_ROOT/assets/notes.json" ] && cp "$PROJECT_ROOT/assets/notes.json" "$APP/assets/"

echo "[同步完成] $APP"
echo "  lib/  : $(ls "$APP/lib" | wc -l) 个 dart"
echo "  test/ : $(ls "$APP/test"/*.dart 2>/dev/null | wc -l) 个测试"

# ---------- 本机验证命令（flutter pub get 会挂，改用 dart pub）----------
FLUTTER_ROOT_DEFAULT="$HOME/.workbuddy/binaries/flutter/flutter"
FL="${FLUTTER_ROOT:-$FLUTTER_ROOT_DEFAULT}"
DART="$FL/bin/cache/dart-sdk/bin/dart"

if [ -x "$DART" ]; then
  echo
  echo "依赖解析（绕过会挂起的 flutter pub get）:"
  echo "  export FLUTTER_ROOT=\"$FL\""
  echo "  cd \"$APP\" && \"$DART\" pub get"
  echo
  echo "静态分析:"
  echo "  cd \"$APP\" && \"$DART\" analyze"
else
  echo
  echo "[提示] 未在 $FL 找到 Dart，请设置 FLUTTER_ROOT 环境变量"
fi
