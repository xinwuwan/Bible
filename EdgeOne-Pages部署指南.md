# EdgeOne Pages 部署指南（国内 CDN，1 秒打开）

> 目标：把「真理对照」部署到腾讯云 EdgeOne Pages，国内访问走腾讯 CDN 节点，
> 首次打开 1 秒内。GitHub Pages 保留作海外备份，两条线互不影响。
> 全部操作一次性完成，之后每次 push 代码自动部署。

## 费用说明（先看这个，安心）

- **EdgeOne Pages 公测期：免费版长期有效，不限量流量和请求**
- 平台分配的二级域名（xxx.edgeone.app 之类）**无需备案**
- 只有将来绑定自己的域名 + 选国内加速区域才涉及备案——我们现在用二级域名，不碰备案
- 全程不需要买任何资源，不产生费用

## 第 1 步：注册并实名腾讯云（约 5 分钟）

1. 打开 https://cloud.tencent.com/register 用微信/QQ/手机号注册
2. 实名认证（国内云的法定要求）：
   - 个人认证：微信扫码 + 身份证 + 人脸（几分钟通过）
   - 你阿里云已经实名过了，信息都有，不麻烦

## 第 2 步：开通 EdgeOne Pages（免费）

1. 打开 EdgeOne 控制台：https://edgeone.cloud.tencent.com
2. 首次进入点「**立即开通**」（0 元，只是激活服务）
3. 切换到上方 **Pages** Tab → 点「**创建项目**」
4. **项目名填 `truth-compare`**（和流水线里的参数对应，填错会多出一个项目）
5. 创建方式选「**直接上传**」或先跳过——**我们不用控制台的 Git 导入**
   （我们的构建在 GitHub Actions 里跑，带数据闸门，比控制台构建更稳）

## 第 3 步：创建 API Token

1. EdgeOne Pages 控制台 → 「**API Token**」→ 创建
2. 复制生成的 Token（只显示一次，保存好）

## 第 4 步：把 Token 配到 GitHub（密钥不经过我，最安全）

1. 打开你的仓库 https://github.com/xinwuwan/Bible
2. **Settings → Secrets and variables → Actions → New repository secret**
3. Name 填：`EDGEONE_API_TOKEN`
4. Value 填：第 3 步复制的 Token
5. 保存

## 第 5 步：触发部署

- 直接 push 任意改动到 main（或去 Actions 页面手动 Run workflow）
- 看 `Deploy Flutter Web to GitHub Pages` 工作流，新增的
  「**Deploy to EdgeOne Pages**」步骤变绿勾即成功
- 如果该步骤显示 skipped（灰色）= 没配 Secret 或配错了名字，回第 4 步检查

## 第 6 步：拿域名，发朋友

1. EdgeOne Pages 控制台 → 项目 `truth-compare` → 域名管理
2. 复制平台分配的域名（形如 `https://truth-compare-xxxx.edgeone.app`）
3. **以后推广就用这个域名**——国内秒开；GitHub Pages 链接留作备用

## 常见问题

**Q: 没配 Token 之前 CI 会红吗？**
不会。部署步骤检测到没配 Secret 会自动跳过，GitHub Pages 照常部署。

**Q: EdgeOne 和 GitHub Pages 内容会不同步吗？**
不会。每次 push 同一次构建出两份产物（一份给 GH Pages 用 /Bible/ 路径，
一份给 EdgeOne 用根路径），版本号一致。

**Q: 公测免费以后会不会收费？**
可能商业化，但腾讯云对已有免费项目通常是「老政策保留 + 新政策可选」。
即使将来收费，GitHub Pages 备份随时能切回，代码零改动。

**Q: RAG 问答还能用吗？**
能。RAG 后端（阿里云函数）和静态托管是两回事，互不影响；
App 里配的是函数地址，换域名不影响。
