#!/usr/bin/env bash
# ==============================================================================
# run_pipeline.sh — 一键构建（M1 数据层 → M2 离线包）
# ==============================================================================
# 完整路径 (Postgres):  依赖安装 → 建库 DDL → KJV 向量化采集 → EGW 向量化采集 → 离线包
# 离线演示 (--offline): 仅用中间 JSON 生成 app_offline.db（零外部依赖，不需 DB/模型）
#
# 关键合规约束（贯穿全程，请勿绕过）:
#   1. 所有 ingest 只处理英文权威原版（KJV / EGW 生前 PD），绝不碰任何中文译本；
#   2. 离线包里的 our_zh 仅来自本应用自产译文，cuv_ref_text 仅作参照，均不参与推理；
#   3. 中文译文 / 译本对照由神学顾问在审核台录入，本管道只搬运、不生成译文。
#
# 用法示例:
#   bash run_pipeline.sh                 # 完整 Postgres 路径（需 DATABASE_URL 可达）
#   bash run_pipeline.sh --offline       # 零依赖演示：用 offline_sample.json 生成离线包
#   bash run_pipeline.sh --dry-run       # 仅打印将要执行的命令，不真正运行
#   bash run_pipeline.sh --skip-embed    # 入库但不生成向量（快速校验管道连通性）
#   bash run_pipeline.sh --list-works    # 仅打印建议采集的 EGW 生前 PD 著作清单
# ==============================================================================
set -euo pipefail

# ----------------------------- 配置（可被环境变量覆盖）------------------------
# 本机 managed Python（不存在时回退到 python3）
PYTHON_MANAGED="${PYTHON_MANAGED:-C:/Users/xinwu/.workbuddy/binaries/python/versions/3.13.12/python.exe}"
# 用 pwd -W 取 Windows 原生路径（C:/...），保证传给原生 python.exe / psql 时路径正确
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -W)"
VENV_DIR="${PROJECT_ROOT}/venv"
DATABASE_URL="${DATABASE_URL:-postgresql://app:app@localhost:5432/faith_app}"

# 数据源（用户需自备 KJV JSON；EGW 用自带示例；离线演示用自带 JSON）
KJV_JSON="${KJV_JSON:-data/kjv.json}"
EGW_TEXT="${EGW_TEXT:-egw_sample.txt}"
EGW_WORK_ID="${EGW_WORK_ID:-SC}"
EGW_TITLE="${EGW_TITLE:-Steps to Christ}"
EGW_YEAR="${EGW_YEAR:-1892}"
OFFLINE_JSON="${OFFLINE_JSON:-offline_sample.json}"
OUT_DB="${OUT_DB:-app_offline.db}"
DDL_FILE="${DDL_FILE:-001_init_schema.sql}"

# 依赖 / 模型
PIP_INDEX="${PIP_INDEX:-https://mirrors.aliyun.com/pypi/simple/}"
PIP_TRUSTED="${PIP_TRUSTED:-mirrors.aliyun.com}"
# 国内访问 HuggingFace 走镜像，避免官方源不通
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
EMBED_MODEL="${EMBED_MODEL:-BAAI/bge-small-zh-v1.5}"

# ----------------------------- 运行模式开关 -----------------------------------
DRY_RUN=0
SKIP_INSTALL=0
SKIP_EMBED=0
OFFLINE=0
LIST_WORKS=0
# 解析参数
for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=1 ;;
    --skip-install) SKIP_INSTALL=1 ;;
    --skip-embed)  SKIP_EMBED=1 ;;
    --offline)     OFFLINE=1 ;;
    --list-works)  LIST_WORKS=1 ;;
    -h|--help)
      grep -E '^#' "$0" | sed 's/^#\{1,2\} //' | sed '/^=.*=$/d'
      exit 0 ;;
    *) echo "[错误] 未知参数: $arg（用 --help 查看用法）" >&2; exit 2 ;;
  esac
done

# ----------------------------- 公共函数 ---------------------------------------
log_step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
log_ok()   { printf '\033[1;32m[完成]\033[0m %s\n' "$1"; }
run() {
  # 打印并执行命令；DRY_RUN 时只打印
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  $ %s\n' "$*"
  else
    echo "  \$ $*"
    eval "$@"
  fi
}

# 选定 Python 解释器：优先用本脚本自建的 venv
if [ -x "$PYTHON_MANAGED" ]; then
  BASE_PY="$PYTHON_MANAGED"
else
  BASE_PY="python3"
fi
PYTHON="${VENV_DIR}/Scripts/python.exe"

# ----------------------------- 仅列著作清单 -----------------------------------
if [ "$LIST_WORKS" -eq 1 ]; then
  log_step "列出 EGW 生前 PD 建议采集清单"
  # 需要 venv 里有 embed_util 依赖；清单打印不依赖模型，但需 psycopg 导入守卫在脚本内已处理
  run "\"$PYTHON\"" "${PROJECT_ROOT}/ingest_egw.py" --list-works
  exit 0
fi

# ----------------------------- 离线演示路径 -----------------------------------
if [ "$OFFLINE" -eq 1 ]; then
  log_step "离线演示模式：仅从中间 JSON 生成离线包（不碰 Postgres / 不加载模型）"
  if [ ! -f "${PROJECT_ROOT}/${OFFLINE_JSON}" ]; then
    echo "[错误] 找不到 ${OFFLINE_JSON}，无法离线演示" >&2; exit 3
  fi
  # 离线打包只用标准库，venv 不存在时回退到系统/托管 python
  if [ -x "$PYTHON" ]; then OFFLINE_PY="$PYTHON"; else OFFLINE_PY="$BASE_PY"; fi
  run "\"$OFFLINE_PY\"" "${PROJECT_ROOT}/build_offline_db.py" \
      --from-json "${PROJECT_ROOT}/${OFFLINE_JSON}" \
      --out "${PROJECT_ROOT}/${OUT_DB}"
  log_ok "离线包已生成: ${OUT_DB}（用 Flutter 侧 offline_db_helper.dart 验证检索）"
  exit 0
fi

# ============================ 完整 Postgres 路径 =============================
log_step "完整路径：依赖安装 → 建库 → KJV 采集 → EGW 采集 → 离线包"

# 1) 准备 venv + 依赖
if [ "$SKIP_INSTALL" -ne 1 ]; then
  if [ ! -x "$PYTHON" ]; then
    log_step "创建虚拟环境 ${VENV_DIR}"
    run "\"$BASE_PY\"" -m venv "\"$VENV_DIR\""
  fi
  log_step "安装依赖（阿里云源）"
  run "\"$PYTHON\"" -m pip install --trusted-host "${PIP_TRUSTED}" \
      -i "${PIP_INDEX}" -r "${PROJECT_ROOT}/requirements.txt"
else
  log_step "跳过依赖安装（SKIP_INSTALL=1），假定 venv 已就绪"
  if [ ! -x "$PYTHON" ]; then
    echo "[错误] venv 不存在且 SKIP_INSTALL=1，无法继续" >&2; exit 4
  fi
fi

# 2) 建库 DDL
log_step "执行建库 DDL: ${DDL_FILE}"
if command -v psql >/dev/null 2>&1; then
  run psql "\"${DATABASE_URL}\"" -f "\"${PROJECT_ROOT}/${DDL_FILE}\""
else
  echo "[警告] 未找到 psql，跳过自动建库；请手动执行:" >&2
  echo "         psql \"${DATABASE_URL}\" -f ${DDL_FILE}" >&2
fi

# 3) KJV 向量化采集
log_step "KJV 采集 + 切片 + 向量化"
if [ ! -f "${PROJECT_ROOT}/${KJV_JSON}" ]; then
  echo "[错误] 找不到 ${KJV_JSON}；请自备 KJV JSON（美区 PD），或用 --offline 演示" >&2
  exit 3
fi
KJV_ARGS=(--input "${PROJECT_ROOT}/${KJV_JSON}" --db-url "${DATABASE_URL}")
[ "$SKIP_EMBED" -eq 1 ] && KJV_ARGS+=(--skip-embed)
run "\"$PYTHON\"" "${PROJECT_ROOT}/ingest_kjv.py" "${KJV_ARGS[@]}"

# 4) EGW 向量化采集（用自带示例文本演示；正式请用真实 PD 著作）
log_step "EGW 生前 PD 单篇采集 + 切片 + 向量化"
EGW_ARGS=(--text "${PROJECT_ROOT}/${EGW_TEXT}" --work-id "${EGW_WORK_ID}" \
          --title "${EGW_TITLE}" --year "${EGW_YEAR}" --db-url "${DATABASE_URL}")
[ "$SKIP_EMBED" -eq 1 ] && EGW_ARGS+=(--skip-embed)
run "\"$PYTHON\"" "${PROJECT_ROOT}/ingest_egw.py" "${EGW_ARGS[@]}"

# 5) 离线包
log_step "生成 Flutter 离线预置包: ${OUT_DB}"
run "\"$PYTHON\"" "${PROJECT_ROOT}/build_offline_db.py" \
    --db-url "${DATABASE_URL}" --out "${PROJECT_ROOT}/${OUT_DB}"

log_ok "流水线完成。下一步：把 ${OUT_DB} 放入 Flutter assets/ 并按 offline_db_helper.dart 读取。"
echo "合规提醒：EGW 各 work 的 pd_confirmed 须由法务逐本裁定后再置 True 发布。"
