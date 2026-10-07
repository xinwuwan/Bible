@echo off
REM ============================================================
REM  从 KJV 英文直译生成中文译文（our_zh.json）
REM  用法：把下面 LLM_API_KEY 改成你的密钥，双击运行即可。
REM  脚本会断点续译（已译章节自动跳过），可反复运行补全。
REM ============================================================
set LLM_API_KEY=sk-YOUR_KEY_HERE
set LLM_BASE_URL=https://api.openai.com/v1
set LLM_MODEL=gpt-4o-mini

python translate_kjv.py
python translate_kjv.py --apply
echo.
echo 翻译完成！our_zh.json 已生成或更新。
echo 接下来请提交并推送：
echo   git add flutter_app/assets/web/our_zh.json
echo   git commit -m "translate: more KJV chapters"
echo   git push
pause
