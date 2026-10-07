# 真理对照 App —— 发布与上线指南

> 这是一份给**不懂编程**的朋友看的操作手册。照着做就行，不用理解原理。

---

## 这是什么？

一个给**全球华人基督徒**用的网页应用（手机、电脑浏览器都能打开），包含三个模块：

- **对照**：英文 KJV 圣经原文 + 中文和合本参照，并排阅读
- **问答**：信仰问答（已内置离线知识库，**链接里就能真实回答**，无需任何服务器）
- **健康**：NEWSTART 八项健康生活方式（营养 / 运动 / 水 / 阳光 / 节制 / 空气 / 休息 / 信靠）

它**完全免费、开源**，通过 GitHub Pages 变成一个**全世界都能打开的网址**。你不用花一分钱，也不用买服务器。

> ⚠️ 关于内容权威性的说明（项目铁律）：圣经英文底本只用 **KJV（英王钦定本）原版**；中文和合本**仅作参照展示**，不是权威译文；**怀爱伦(EGW)著作**只引用**官方公共版权档案中逐字核对的原文**，绝不臆造；健康建议**绝不替代医生的诊断**。未经验证审核的健康条目不会出现在应用里。

---

## 你不需要会编程

整个发布过程就是三件事：
1. 注册一个**免费**账号
2. **双击**一个文件
3. **填三项**信息

把代码"编译成网站"这件事，由 GitHub 的免费服务器帮你自动完成，你本机**不需要安装 Flutter**（那个东西很大很麻烦）。

---

## 第一步：准备（一次性，约 5 分钟）

### 1. 安装 Git（让电脑能上传文件）
- 打开 `https://git-scm.com/download/win`
- 下载 Windows 版，打开后一路点"下一步"安装即可。

### 2. 注册 GitHub 账号（免费）
- 打开 `https://github.com`
- 点 "Sign up"，用邮箱注册。
- **用户名建议用英文**，例如 `zhangshan`。记住它，后面要用。

---

## 第二步：发布出链接（约 3 分钟）

### 3. 在 GitHub 新建一个空仓库
- 登录后，右上角点 **"＋" → New repository**
- **Repository name** 填一个英文名字，例如 `faith-compare-app`
- **不要**勾选 "Add a README file"（保持空仓库）
- 点 **Create repository**

### 4. 建一个访问令牌（PAT）—— 一次性
- 登录后，点右上角头像 → **Settings**
- 左侧最下面 **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**
- Token name：随便填（如 `publish`）
- Repository access：选 **Only select repositories** → 选你刚建的仓库
- 下面 Repository permissions → **Contents** → 选 **Read and write**
- 拉到最下面点 **Generate token**
- ⚠️ **立刻复制**那串 `github_pat_xxxx` 令牌（它**只显示这一次**！）

### 5. 双击发布脚本
- 打开你电脑上的这个文件夹：
  `C:\Users\xinwu\WorkBuddy\2026-10-05-14-30-06\`
- 双击 **`publish_to_github.bat`**
- 弹出的黑窗口会依次问你三项，填完按回车：
  - `GitHub username:` 你的用户名（如 `zhangshan`）
  - `GitHub repo name:` 仓库名（如 `faith-compare-app`）
  - `GitHub PAT:` 在窗口里**右键粘贴**刚才复制的令牌，回车
- 它会自动上传，最后黑窗口会显示你的链接地址。

### 6. 开启网页托管
- 回到 github.com 你的仓库页面 → **Settings → Pages**
- **Source** 选 **"GitHub Actions"** → Save
  （注意：是 "GitHub Actions"，**不是** "Deploy from a branch"）

### 7. 等待出链接
- 等约 **2 分钟**（GitHub 在后台编译网站）
- 你的网址就是：
  **`https://<你的用户名>.github.io/<仓库名>/`**
- 把这个链接发给任何华人，浏览器打开即用（手机 / 电脑都行）。

---

## 以后怎么更新内容？

改完内容后，**再双击一次 `publish_to_github.bat`** 即可。GitHub 会自动重新生成网站，链接不变。

---

## 常见问题

- **黑窗口报红字 / 失败？** 把里面的红字发给我，我帮你看。
- **链接打开是 404？** 确认第 6 步 Source 选的是 **"GitHub Actions"**（不是 Deploy from a branch）；再等 1–2 分钟。
- **链接打开是白屏？** 多半是网站还在编译（仓库的 **Actions** 标签页能看到进度条），或第 6 步没设对。
- **网页里经文是空的 / 只有几节？** 这是发布时自动抓取全本经文没成功。把情况发我，我帮你换源或手动灌入。
- **我电脑里找不到那个文件夹？** 那是本项目的工作目录。如果你换了电脑，需要把整个项目文件夹复制过去，再双击 `publish_to_github.bat`。

---

## 给想了解技术的人（可跳过）

- 网站内容（全本 KJV + 和合本）在**每次发布时**由 GitHub 服务器自动从公共领域源抓取并打包进应用，**不需要你手动准备经文文件**。
- 应用源码在 `flutter_app/` 目录；自动发布配置在 `.github/workflows/deploy-web.yml`。
- **发布前会自动跑测试闸门**（数据层、离线问答、后端契约/API 测试），任一项不过就不会发布坏版本——你不用担心"更新后链接坏掉"。
- 模块 B 的问答知识库已内置到网页里，**离线即可真实回答 28 类常见信仰问题**（安息日、得救、洗礼、再临、死亡、十一奉献、洁净食物、地狱、婚姻、末世预兆、查案审判、144000、复活、圣经权威、圣灵印记、禁食、与世界分别、健康等），全部以 KJV 为底本并附真实经文引用。
- （可选）若想把模块 B 的真实大模型问答后端独立部署，`.github/workflows/build-backend.yml` 会在 `backend/` 改动时自动构建镜像并推送到 GitHub 容器仓库（GHCR），详见 `backend/README.md`。
- 在本地预览全本经文可双击 `fetch_kjv.bat`（需联网）。
- 所有脚本均为纯 Python / 批处理，无第三方付费依赖。

---

## 文件清单（本目录）

| 文件 | 作用 |
|------|------|
| `publish_to_github.bat` | **你主要用这个**：一键上传并触发发布 |
| `fetch_kjv.bat` | 本机预览：下载全本 KJV |
| `flutter_app/` | 应用全部源码 |
| `.github/workflows/deploy-web.yml` | 自动构建 + 部署配置（含发布前测试闸门） |
| `.github/workflows/build-backend.yml` | （可选）后端镜像自动构建并推送 GHCR |
| `fetch_kjv.py` / `fetch_cuv.py` | 抓取 KJV / 和合本 的脚本（CI 自动调用） |
| `backend/` | （可选）模块 B 真·大模型问答后端，详见 `backend/README.md` |
| `README.md` | 本说明 |
