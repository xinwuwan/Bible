#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自动提取应用中出现的【全部】字符，并对 CanvasKit 需要的中文字体做子集化。

================ 为什么需要它 ================
微信 X5 内核下我们强制了 CanvasKit 渲染器（修复英文词距被折叠的问题）。
CanvasKit 不再调用系统字体，而是从 fontFallbackBaseUrl(web/fonts/) 下载
Noto Sans SC / TC 来绘制中文。
- 若打包完整字体：SC 10.5MB + TC 7.1MB = 17.6MB，首屏要等很久 → 白屏。
- 子集化只保留「应用实际用到的字」，把字体压到 ~2MB，首屏快、无空白。
- 但子集必须覆盖所有用到的字，否则新字会变方框(tofu)。本脚本每次部署/构建前
  自动重新提取 + 子集化，保证「之后新增中文文案」也能正确显示。

================ 字符来源（全部扫描，取并集）================
  1) <app>/lib/**/*.dart          —— UI 文案、按钮、经文模块
  2) <app>/assets/**/*            —— 资源 JSON（含已提交的 our_zh.json 译文）
  3) <app>/**/*.db（排除 build）  —— 离线库全文（含全本中文圣经，最关键）
  4) <app>/web/fonts/whitelist.txt —— 已固化的字符白名单
        （来自上次扫描；确保 CI 在拿不到离线库时仍有完整覆盖；本地每次重算刷新）

================ 全字形覆盖原则（重要教训）================
保留所有可打印字符(码点 >= 0x20)，含 ASCII 字母 / 数字 / 标点 / CJK。
早期一次只保留 CJK、排除拉丁，导致数字 / 英文消失（首页年份、卷数、书籍页英文
缺失）——本脚本永不重蹈，始终全量保留。

================ 输出（覆盖原文件，路径/文件名不变，匹配 Flutter 回退 URL）================
  web/fonts/notosanssc/v36/<sc_hash>.ttf
  web/fonts/notosanstc/v35/<tc_hash>.ttf

================ 完整字体缓存 ================
首次运行从 gstatic 下载完整字体到 web/fonts/_full/（下划线前缀 →
不会被部署脚本推送到仓库），之后复用，避免每次重新下载 34MB。

================ 健壮性 ================
- fontTools 缺失时自动 pip install（仅本地；CI 步骤会先装）。
- 完整字体下载失败时【不破坏】已入库的可用子集字体：仅打印告警并退出，
  绝不以退出码 1 中断部署 / 构建（CI 步骤也设 continue-on-error）。
"""
import os
import sys
import glob
import shutil
import subprocess
import urllib.request

# ---------------- 路径定位 ----------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# tools/subset_fonts.py -> 项目根 = 父目录；flutter_app 在项目根下
ROOT = os.path.dirname(SCRIPT_DIR)
APP = os.path.join(ROOT, "flutter_app")
FONTS = os.path.join(APP, "web", "fonts")

# ---------------- 字体标识（必须与 Flutter 回退请求的文件名一致）----------------
SC_HASH = "k3kCo84MPvpLmixcA63oeAL7Iqp5IZJF9bmaG9_FnYxNbPzS5HE"
TC_HASH = "-nFuOG829Oofr2wohFbTp9ifNAn722rq0MXz76Cy_CpOtma3uNQ"
SC_URL = f"https://fonts.gstatic.com/s/notosanssc/v36/{SC_HASH}.ttf"
TC_URL = f"https://fonts.gstatic.com/s/notosanstc/v35/{TC_HASH}.ttf"

SC_OUT = os.path.join(FONTS, "notosanssc", "v36", SC_HASH + ".ttf")
TC_OUT = os.path.join(FONTS, "notosanstc", "v35", TC_HASH + ".ttf")
CACHE = os.path.join(FONTS, "_full")
WHITELIST = os.path.join(FONTS, "whitelist.txt")
CHARS_TMP = os.path.join(FONTS, "_subset_chars.txt")


def ensure_fonttools():
    try:
        import fontTools  # noqa: F401
        return True
    except Exception:
        pass
    print("  [subset] fontTools 未安装，尝试 pip install ...")
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "--user", "fonttools"],
                       check=True)
        return True
    except Exception as e:
        print("  [subset] WARN: 安装 fontTools 失败：", e)
        return False


def download(url, dest):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.isfile(dest) and os.path.getsize(dest) > 100_000:
        return True
    last = None
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={
                "User-Agent": "Mozilla/5.0 (subset-script)",
                "Accept": "*/*",
            })
            with urllib.request.urlopen(req, timeout=180) as r:
                data = r.read()
            with open(dest, "wb") as f:
                f.write(data)
            if os.path.getsize(dest) > 100_000:
                print(f"  [subset] 下载完成 {os.path.basename(dest)} ({len(data):,}B)")
                return True
            last = f"文件过小 {os.path.getsize(dest)}B"
        except Exception as e:
            last = str(e)
            print(f"  [subset] 下载尝试 {attempt + 1}/4 失败：{e}")
            if attempt < 3:
                import time
                time.sleep(3)
    print("  [subset] WARN: 完整字体下载失败：", last)
    return False


def collect_chars():
    chars = set()
    # 1) Dart 源码
    for f in glob.glob(os.path.join(APP, "lib", "**", "*.dart"), recursive=True):
        try:
            chars.update(open(f, encoding="utf-8", errors="ignore").read())
        except Exception:
            pass
    # 2) 资源（文本文件）
    for f in glob.glob(os.path.join(APP, "assets", "**", "*"), recursive=True):
        if os.path.isfile(f):
            try:
                chars.update(open(f, encoding="utf-8", errors="ignore").read())
            except Exception:
                pass
    # 3) 离线库（SQLite 中 TEXT 以 UTF-8 明文存储；排除 build）
    for f in glob.glob(os.path.join(APP, "**", "*.db"), recursive=True):
        if os.path.sep + "build" + os.path.sep in f.replace("\\", "/"):
            continue
        try:
            chars.update(open(f, "rb").read().decode("utf-8", errors="ignore"))
        except Exception:
            pass
    # 4) 已固化的白名单（CI 无离线库时仍保覆盖）
    if os.path.isfile(WHITELIST):
        try:
            chars.update(open(WHITELIST, encoding="utf-8", errors="ignore").read())
        except Exception:
            pass
    # 仅保留可打印字符（含空格/ASCII/CJK/符号），排除控制字符
    keep = set(c for c in chars if ord(c) >= 0x20)
    return keep


def write_whitelist(keep):
    with open(WHITELIST, "w", encoding="utf-8") as out:
        out.write("".join(sorted(keep)))
    print(f"  [subset] 白名单已写入 {os.path.relpath(WHITELIST, ROOT)} "
          f"（{len(keep):,} 字符）")


def subset_one(src, dst, chars_file):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    cmd = [sys.executable, "-m", "fontTools.subset", src,
           "--text-file=" + chars_file,
           "--no-hinting",
           "--output-file=" + dst]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print("  [subset] WARN: 子集化失败：", (r.stderr or r.stdout)[-500:])
        return False
    return True


def verify(dst, label, tests):
    try:
        from fontTools.ttLib import TTFont
        cmap = set(TTFont(dst).getBestCmap().keys())
        missing = [c for c in tests if ord(c) not in cmap]
        print(f"  [subset] {label}: {len(cmap):,} 字形；抽查缺字 = {missing or '无'}")
        return not missing
    except Exception as e:
        print("  [subset] WARN: 校验失败：", e)
        return False


def main():
    if not os.path.isdir(APP):
        print(f"[subset] 未找到 flutter_app 目录：{APP}")
        sys.exit(0)  # 不致命：交给后续流程

    if not ensure_fonttools():
        print("[subset] 跳过子集化（缺少 fontTools，保留现有字体）")
        sys.exit(0)

    print("[subset] 提取应用全部字符 ...")
    keep = collect_chars()
    if not keep:
        print("[subset] 未提取到任何字符，跳过")
        sys.exit(0)

    write_whitelist(keep)

    with open(CHARS_TMP, "w", encoding="utf-8") as out:
        out.write("".join(sorted(keep)))

    ok = True
    try:
        # 完整字体（缓存）
        sc_full = os.path.join(CACHE, "sc_full.ttf")
        tc_full = os.path.join(CACHE, "tc_full.ttf")
        if not (download(SC_URL, sc_full) and download(TC_URL, tc_full)):
            print("[subset] 完整字体不可用，保留现有已入库子集字体（不覆盖、不报错）")
            return

        print("[subset] 子集化 Noto Sans SC ...")
        ok &= subset_one(sc_full, SC_OUT, CHARS_TMP)
        print("[subset] 子集化 Noto Sans TC ...")
        ok &= subset_one(tc_full, TC_OUT, CHARS_TMP)
    finally:
        if os.path.isfile(CHARS_TMP):
            os.remove(CHARS_TMP)

    if ok:
        # SC 用简体界面串校验；TC 用繁体(和合本)串校验（码点不同，勿混用）
        verify(SC_OUT, "SC", "0123456789Steps to Christ ABCabc真理对照圣经怀著创世记出埃及记和合本")
        verify(TC_OUT, "TC", "0123456789Steps to Christ ABCabc真理對照聖經懷著創世記出埃及記和合本")
        print(f"[subset] 完成：SC={os.path.getsize(SC_OUT):,}B  TC={os.path.getsize(TC_OUT):,}B")
    else:
        print("[subset] 子集化未完全成功，现有字体可能未更新（请检查网络后重试）")


if __name__ == "__main__":
    main()
