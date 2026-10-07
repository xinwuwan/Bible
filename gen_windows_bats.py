# gen_windows_bats.py
# 生成两个本机一键脚本（CRLF + 纯 ASCII，规避中文乱码/转义坑）：
#   fetch_kjv.bat        - 下载全本 KJV 写入 app_data.json
#   publish_to_github.bat - 推送到 GitHub（触发 Actions 自动构建 + 部署出链接）
# 仅用于用户在真实 Windows 机器双击运行；沙箱内不依赖 flask/flutter CLI。

ROOT = r"C:/Users/xinwu/WorkBuddy/2026-10-05-14-30-06"

FETCH_BAT = (
    "@echo off\n"
    "REM fetch_kjv.bat - download full KJV + CUV into app_data.json (run on your PC)\n"
    "python3 fetch_kjv.py\n"
    "if %ERRORLEVEL% NEQ 0 (\n"
    "  echo KJV_FETCH_FAILED\n"
    "  pause\n"
    "  exit /b 1\n"
    ")\n"
    "python3 fetch_cuv.py\n"
    "if %ERRORLEVEL% NEQ 0 (\n"
    "  echo CUV_FETCH_FAILED (KJV still OK)\n"
    ")\n"
    "echo DONE: app_data.json updated (KJV + CUV)\n"
    "pause\n"
)

PUBLISH_BAT = (
    "@echo off\n"
    "REM publish_to_github.bat - push to GitHub -> auto build+deploy -> get URL\n"
    "REM 1) Create an empty repo on github.com (green New button). Note its name.\n"
    "REM 2) Make a fine-grained PAT with 'contents: write' at github.com/settings/tokens\n"
    "set /p GHUSER=GitHub username: \n"
    "set /p GHREPO=GitHub repo name: \n"
    "set /p GHTOKEN=GitHub PAT (contents:write): \n"
    "git init\n"
    "git config user.name \"%GHUSER%\"\n"
    "git config user.email \"%GHUSER%@users.noreply.github.com\"\n"
    "git branch -M main\n"
    "git remote remove origin 2>nul\n"
    "git remote add origin https://%GHUSER%:%GHTOKEN%@github.com/%GHUSER%/%GHREPO%.git\n"
    "git add -A\n"
    "git commit -m \"deploy\"\n"
    "git push -u origin main\n"
    "echo.\n"
    "echo Your link will be: https://%GHUSER%.github.io/%GHREPO%/\n"
    "echo Go to repo Settings > Pages > Source = GitHub Actions, then wait ~2 min.\n"
    "pause\n"
)


def write_bat(path, content):
    # 强制 CRLF + ASCII
    data = content.replace("\n", "\r\n").encode("ascii")
    with open(path, "wb") as f:
        f.write(data)
    with open(path, "rb") as f:
        d = f.read()
    print(f"wrote {path}: {len(d)} bytes; CRLF lines={d.count(bchr)} loneLF={d.count(b'\\n')-d.count(bchr)} ascii={all(b<128 for b in d)}")


bchr = b"\r\n"


def main():
    write_bat(f"{ROOT}/fetch_kjv.bat", FETCH_BAT)
    write_bat(f"{ROOT}/publish_to_github.bat", PUBLISH_BAT)


if __name__ == "__main__":
    main()
