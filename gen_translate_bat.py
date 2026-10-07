# -*- coding: utf-8 -*-
"""生成 run_translate.bat（GBK 编码 + CRLF），供用户双击在本机从 KJV 直译。

Windows cmd 默认代码页 936，.bat 必须是 GBK 且 CRLF 换行，否则中文乱码、LF 断行错乱。
用本脚本在 bytes 层面精确控制编码与换行，避免 Write 工具默认 UTF-8/LF 的坑。
"""
content = (
    "@echo off\r\n"
    "REM ============================================================\r\n"
    "REM  从 KJV 英文直译生成中文译文（our_zh.json）\r\n"
    "REM  用法：把下面 LLM_API_KEY 改成你的密钥，双击运行即可。\r\n"
    "REM  脚本会断点续译（已译章节自动跳过），可反复运行补全。\r\n"
    "REM ============================================================\r\n"
    "set LLM_API_KEY=sk-YOUR_KEY_HERE\r\n"
    "set LLM_BASE_URL=https://api.openai.com/v1\r\n"
    "set LLM_MODEL=gpt-4o-mini\r\n"
    "\r\n"
    "python translate_kjv.py\r\n"
    "python translate_kjv.py --apply\r\n"
    "echo.\r\n"
    "echo 翻译完成！our_zh.json 已生成或更新。\r\n"
    "echo 接下来请提交并推送：\r\n"
    "echo   git add flutter_app/assets/web/our_zh.json\r\n"
    "echo   git commit -m \"translate: more KJV chapters\"\r\n"
    "echo   git push\r\n"
    "pause\r\n"
)

with open("run_translate.bat", "wb") as f:
    f.write(content.encode("gbk"))

# 字节级校验：纯 GBK 可解码 + 无孤立 LF
raw = open("run_translate.bat", "rb").read()
try:
    raw.decode("gbk")
    ascii_only = all(b < 128 for b in raw)
except UnicodeDecodeError as e:
    raise SystemExit("GBK 解码失败: " + str(e))
lone_lf = raw.count(b"\n") - raw.count(b"\r\n")
print("run_translate.bat 生成完成 | 大小=%d 字节 | 纯ASCII=%s | 孤立LF=%d"
      % (len(raw), ascii_only, lone_lf))
assert lone_lf == 0, "存在孤立 LF，换行错误"
assert not ascii_only, "应为 GBK 中文内容"
