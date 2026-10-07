# ==============================================================================
# Makefile — 一键构建（与 run_pipeline.sh 共享同一套配置）
# ==============================================================================
# 用法:
#   make                 # 完整 Postgres 路径：install → schema → ingest-kjv → ingest-egw → offline
#   make offline         # 零依赖演示：用 offline_sample.json 生成 app_offline.db
#   make install         # 仅建 venv + 装依赖
#   make list-works      # 仅列出 EGW 生前 PD 建议采集清单
#   make clean           # 删除生成的离线包
#
# 变量可用命令行覆盖，例如:
#   make ingest-kjv KJV_JSON=data/kjv.json
#   make offline OFFLINE_JSON=offline_sample.json OUT_DB=app_offline.db
#
# 注意: recipe 使用 .RECIPEPREFIX '>' 以避免 Makefile 的 tab 缩进陷阱。
# ==============================================================================
.RECIPEPREFIX = >

PYTHON_MANAGED ?= C:/Users/xinwu/.workbuddy/binaries/python/versions/3.13.12/python.exe
PROJECT_ROOT  := $(CURDIR)
VENV_DIR      ?= $(PROJECT_ROOT)/venv
DATABASE_URL  ?= postgresql://app:app@localhost:5432/faith_app
KJV_JSON      ?= data/kjv.json
EGW_TEXT      ?= egw_sample.txt
EGW_WORK_ID   ?= SC
EGW_TITLE     ?= Steps to Christ
EGW_YEAR      ?= 1892
OFFLINE_JSON  ?= offline_sample.json
OUT_DB        ?= app_offline.db
DDL_FILE      ?= 001_init_schema.sql
PIP_INDEX     ?= https://mirrors.aliyun.com/pypi/simple/
PIP_TRUSTED   ?= mirrors.aliyun.com
EMBED_MODEL   ?= BAAI/bge-small-zh-v1.5

# 选定解释器: venv 优先，回退到 managed python 或 python3
ifeq ($(wildcard $(VENV_DIR)/Scripts/python.exe),)
> PYTHON := $(PYTHON_MANAGED)
else
> PYTHON := $(VENV_DIR)/Scripts/python.exe
endif
export HF_ENDPOINT ?= https://hf-mirror.com

.PHONY: all install schema ingest-kjv ingest-egw offline list-works clean help

all: install schema ingest-kjv ingest-egw offline

help:
> @echo "Targets: all install schema ingest-kjv ingest-egw offline list-works clean"
> @echo "示例: make offline  /  make ingest-kjv KJV_JSON=data/kjv.json"

install:
> @echo "==> 创建 venv + 安装依赖"
> $(PYTHON) -m venv "$(VENV_DIR)" || python3 -m venv "$(VENV_DIR)"
> "$(VENV_DIR)/Scripts/python.exe" -m pip install --trusted-host $(PIP_TRUSTED) -i $(PIP_INDEX) -r requirements.txt

schema:
> @echo "==> 执行建库 DDL"
> psql "$(DATABASE_URL)" -f "$(DDL_FILE)"

ingest-kjv:
> @echo "==> KJV 采集 + 向量化"
> "$(VENV_DIR)/Scripts/python.exe" ingest_kjv.py --input "$(KJV_JSON)" --db-url "$(DATABASE_URL)"

ingest-egw:
> @echo "==> EGW 生前 PD 单篇采集 + 向量化"
> "$(VENV_DIR)/Scripts/python.exe" ingest_egw.py --text "$(EGW_TEXT)" --work-id "$(EGW_WORK_ID)" --title "$(EGW_TITLE)" --year "$(EGW_YEAR)" --db-url "$(DATABASE_URL)"

offline:
> @echo "==> 生成离线包"
> "$(VENV_DIR)/Scripts/python.exe" build_offline_db.py --from-json "$(OFFLINE_JSON)" --out "$(OUT_DB)"

list-works:
> @echo "==> EGW 生前 PD 建议采集清单"
> "$(VENV_DIR)/Scripts/python.exe" ingest_egw.py --list-works

clean:
> @echo "==> 清理生成的离线包"
> rm -f "$(OUT_DB)"
