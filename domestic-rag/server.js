// domestic-rag/server.js
// ===========================================================================
// 圣经/健康 RAG 后端代理 —— 国内云函数版（阿里云函数计算 FC / 腾讯云 SCF Web函数）
// 由 rag-worker/worker.js 完整移植：零依赖、纯 Node HTTP 服务，监听 9000 端口。
//
// 职责（与 Cloudflare Worker 版一致）：
//   1. 托管大模型 API Key（绝不暴露给前端）
//   2. 限流（按客户端 IP，内存实现）
//   3. 调大模型（默认智谱 glm-4-flash，国内直连）
//   4. 后处理合规审计：CUV 检测 + 引用越界审计
//   5. 返回 { answer, refs_used, flags, fallback }
//   6. v58：诊断材料图片 OCR（/api/ocr，视觉模型纯转录，不解读不诊断）
//
// 部署形态：Web函数 / 自定义运行时，监听端口 9000（阿里云/腾讯云默认均为 9000）。
// 本地运行：RAG_API_KEY=xxx node server.js
// ===========================================================================

'use strict';

const http = require('http');

// ---------------------------------------------------------------------------
// 配置：优先读环境变量；FALLBACK_API_KEY 便于控制台上传时直接内嵌（仅服务端可见）
// ---------------------------------------------------------------------------
const CONFIG = {
  apiKey: process.env.RAG_API_KEY || 'ecff843bce564e3395219a749b59a59c.fkjCmxTXJ3fGez7Y',
  baseUrl: (process.env.RAG_BASE_URL || 'https://open.bigmodel.cn/api/paas/v4').replace(/\/$/, ''),
  model: process.env.RAG_MODEL || 'glm-4-flash',
  limit: Number(process.env.RAG_LIMIT) || 20, // 每分钟每 IP
};

// ---------------------------------------------------------------------------
// 进程级兜底：任何漏网的异步异常只记日志，绝不让进程退出（托管平台重启有延迟）
// ---------------------------------------------------------------------------
process.on('unhandledRejection', (reason) => {
  console.error('unhandledRejection:', reason && reason.stack ? reason.stack : reason);
});

// ---------------------------------------------------------------------------
// 书卷别名 -> 3 字母标准代码（与 worker.js 完全一致）
// ---------------------------------------------------------------------------
const BOOK = {
  genesis: 'GEN', '创世记': 'GEN', '創世記': 'GEN',
  exodus: 'EXO', '出埃及记': 'EXO', '出埃及記': 'EXO',
  leviticus: 'LEV', '利未记': 'LEV', '利未記': 'LEV',
  numbers: 'NUM', '民数记': 'NUM', '民數記': 'NUM',
  deuteronomy: 'DEU', '申命记': 'DEU', '申命記': 'DEU',
  joshua: 'JOS', '约书亚记': 'JOS', '約書亞記': 'JOS',
  judges: 'JDG', '士师记': 'JDG', '士師記': 'JDG',
  ruth: 'RUT', '路得记': 'RUT', '路得記': 'RUT',
  '1 samuel': '1SA', '撒母耳记上': '1SA', '撒母耳記上': '1SA', '撒上': '1SA',
  '2 samuel': '2SA', '撒母耳记下': '2SA', '撒母耳記下': '2SA', '撒下': '2SA',
  '1 kings': '1KI', '列王纪上': '1KI', '列王紀上': '1KI', '王上': '1KI',
  '2 kings': '2KI', '列王纪下': '2KI', '列王紀下': '2KI', '王下': '2KI',
  '1 chronicles': '1CH', '历代志上': '1CH', '歷代志上': '1CH', '代上': '1CH',
  '2 chronicles': '2CH', '历代志下': '2CH', '歷代志下': '2CH', '代下': '2CH',
  ezra: 'EZR', '以斯拉记': 'EZR', '以斯拉記': 'EZR',
  nehemiah: 'NEH', '尼希米记': 'NEH', '尼希米記': 'NEH',
  esther: 'EST', '以斯帖记': 'EST', '以斯帖記': 'EST',
  job: 'JOB', '约伯记': 'JOB', '約伯記': 'JOB',
  psalms: 'PSA', '诗篇': 'PSA', '詩篇': 'PSA', '诗': 'PSA',
  proverbs: 'PRO', '箴言': 'PRO', '箴': 'PRO',
  ecclesiastes: 'ECC', '传道书': 'ECC', '傳道書': 'ECC',
  'song of solomon': 'SNG', '雅歌': 'SNG',
  isaiah: 'ISA', '以赛亚书': 'ISA', '以賽亞書': 'ISA', '赛': 'ISA',
  jeremiah: 'JER', '耶利米书': 'JER', '耶利米書': 'JER', '耶': 'JER',
  lamentations: 'LAM', '耶利米哀歌': 'LAM',
  ezekiel: 'EZK', '以西结书': 'EZK', '以西結書': 'EZK', '结': 'EZK',
  daniel: 'DAN', '但以理书': 'DAN', '但以理書': 'DAN', '但': 'DAN',
  hosea: 'HOS', '何西阿书': 'HOS', '何西阿書': 'HOS',
  joel: 'JOL', '约珥书': 'JOL', '約珥書': 'JOL',
  amos: 'AMO', '阿摩司书': 'AMO', '阿摩司書': 'AMO',
  obadiah: 'OBA', '俄巴底亚书': 'OBA', '俄巴底亞書': 'OBA',
  jonah: 'JON', '约拿书': 'JON', '約拿書': 'JON', '拿': 'JON',
  micah: 'MIC', '弥迦书': 'MIC', '彌迦書': 'MIC', '弥': 'MIC',
  nahum: 'NAM', '那鸿书': 'NAM', '那鴻書': 'NAM',
  habakkuk: 'HAB', '哈巴谷书': 'HAB', '哈巴谷書': 'HAB',
  zephaniah: 'ZEP', '西番雅书': 'ZEP', '西番雅書': 'ZEP',
  haggai: 'HAG', '哈该书': 'HAG', '哈該書': 'HAG',
  zechariah: 'ZEC', '撒迦利亚书': 'ZEC', '撒迦利亞書': 'ZEC',
  malachi: 'MAL', '玛拉基书': 'MAL', '瑪拉基書': 'MAL',
  matthew: 'MAT', '马太福音': 'MAT', '馬太福音': 'MAT', '太': 'MAT',
  mark: 'MRK', '马可福音': 'MRK', '馬可福音': 'MRK', '可': 'MRK',
  luke: 'LUK', '路加福音': 'LUK', '路加福音': 'LUK', '路': 'LUK',
  john: 'JHN', '约翰福音': 'JHN', '約翰福音': 'JHN', '约': 'JHN',
  acts: 'ACT', '使徒行传': 'ACT', '使徒行傳': 'ACT', '徒': 'ACT',
  romans: 'ROM', '罗马书': 'ROM', '羅馬書': 'ROM', '罗': 'ROM',
  '1 corinthians': '1CO', '哥林多前书': '1CO', '哥林多前書': '1CO', '林前': '1CO',
  '2 corinthians': '2CO', '哥林多后书': '2CO', '哥林多後書': '2CO', '林后': '2CO',
  galatians: 'GAL', '加拉太书': 'GAL', '加拉太書': 'GAL', '加': 'GAL',
  ephesians: 'EPH', '以弗所书': 'EPH', '以弗所書': 'EPH', '弗': 'EPH',
  philippians: 'PHP', '腓立比书': 'PHP', '腓立比書': 'PHP', '腓': 'PHP',
  colossians: 'COL', '歌罗西书': 'COL', '歌羅西書': 'COL', '西': 'COL',
  '1 thessalonians': '1TH', '帖撒罗尼迦前书': '1TH', '帖撒羅尼迦前書': '1TH', '帖前': '1TH',
  '2 thessalonians': '2TH', '帖撒罗尼迦后书': '2TH', '帖撒羅尼迦後書': '2TH', '帖后': '2TH',
  '1 timothy': '1TI', '提摩太前书': '1TI', '提摩太前書': '1TI', '提前': '1TI',
  '2 timothy': '2TI', '提摩太后书': '2TI', '提摩太後書': '2TI', '提后': '2TI',
  titus: 'TIT', '提多书': 'TIT', '提多書': 'TIT', '多': 'TIT',
  philemon: 'PHM', '腓利门书': 'PHM', '腓利門書': 'PHM',
  hebrews: 'HEB', '希伯来书': 'HEB', '希伯來書': 'HEB', '来': 'HEB', '希伯': 'HEB',
  james: 'JAS', '雅各书': 'JAS', '雅各書': 'JAS', '雅': 'JAS',
  '1 peter': '1PE', '彼得前书': '1PE', '彼得前書': '1PE', '彼前': '1PE',
  '2 peter': '2PE', '彼得后书': '2PE', '彼得後書': '2PE', '彼后': '2PE',
  '1 john': '1JN', '约翰一书': '1JN', '約翰一書': '1JN', '约一': '1JN',
  '2 john': '2JN', '约翰二书': '2JN', '約翰二書': '2JN', '约二': '2JN',
  '3 john': '3JN', '约翰三书': '3JN', '約翰三書': '3JN', '约三': '3JN',
  jude: 'JUD', '犹大书': 'JUD', '猶大書': 'JUD',
  revelation: 'REV', '启示录': 'REV', '啟示錄': 'REV', '启': 'REV',
};

// 3 字母标准代码别名
Object.assign(BOOK, {
  gen: 'GEN', exo: 'EXO', lev: 'LEV', num: 'NUM', deu: 'DEU', jos: 'JOS', jdg: 'JDG', rut: 'RUT',
  '1sa': '1SA', '2sa': '2SA', '1ki': '1KI', '2ki': '2KI', '1ch': '1CH', '2ch': '2CH',
  ezr: 'EZR', neh: 'NEH', est: 'EST', psa: 'PSA', pro: 'PRO', ecc: 'ECC', sng: 'SNG',
  isa: 'ISA', jer: 'JER', lam: 'LAM', ezk: 'EZK', dan: 'DAN', hos: 'HOS', jol: 'JOL', amo: 'AMO',
  oba: 'OBA', jon: 'JON', mic: 'MIC', nam: 'NAM', hab: 'HAB', zep: 'ZEP', hag: 'HAG', zec: 'ZEC', mal: 'MAL',
  mat: 'MAT', mrk: 'MRK', luk: 'LUK', jhn: 'JHN', act: 'ACT', rom: 'ROM',
  '1co': '1CO', '2co': '2CO', gal: 'GAL', eph: 'EPH', php: 'PHP', col: 'COL',
  '1th': '1TH', '2th': '2TH', '1ti': '1TI', '2ti': '2TI', tit: 'TIT', phm: 'PHM',
  heb: 'HEB', jas: 'JAS', '1pe': '1PE', '2pe': '2PE', '1jn': '1JN', '2jn': '2JN', '3jn': '3JN', jud: 'JUD', rev: 'REV',
});

const BOOK_ALIASES_SORTED = Object.keys(BOOK).sort((a, b) => b.length - a.length);

// ---------------------------------------------------------------------------
// 引用归一化
// ---------------------------------------------------------------------------
function normalizeRefs(text) {
  const out = new Set();
  if (!text) return out;
  let t = String(text).replace(/KJV-/gi, '').replace(/\s+/g, ' ');
  const enRe = /[A-Za-z]{2,4}\s*\d{1,3}\s*[:：]\s*\d{1,3}/g;
  let m;
  while ((m = enRe.exec(t)) !== null) {
    const mm = m[0].match(/([A-Za-z]{2,4})\s*(\d{1,3})\s*[:：]\s*(\d{1,3})/);
    if (mm) {
      const code = BOOK[mm[1].toLowerCase()];
      if (code) out.add(`${code}:${mm[2]}:${mm[3]}`);
    }
  }
  for (const alias of BOOK_ALIASES_SORTED) {
    if (/[A-Za-z]/.test(alias)) continue;
    const a = alias.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const reColon = new RegExp(a + '\\s*(\\d{1,3})\\s*[:：]\\s*(\\d{1,3})', 'g');
    while ((m = reColon.exec(t)) !== null) out.add(`${BOOK[alias]}:${m[1]}:${m[2]}`);
    const reZh = new RegExp(a + '\\s*第?\\s*(\\d{1,3})\\s*章\\s*第?\\s*(\\d{1,3})\\s*节', 'g');
    while ((m = reZh.exec(t)) !== null) out.add(`${BOOK[alias]}:${m[1]}:${m[2]}`);
  }
  return out;
}

// ---------------------------------------------------------------------------
// 提示词
// ---------------------------------------------------------------------------
const SYSTEM_PROMPT = `你是符合圣经与怀爱伦(EGW)著作立场的基督教信仰/健康顾问。严格遵守以下规则：
1. 只能基于下面<参考资料>回答，不得编造任何经文、人物、事实或引文。
2. 回答时务必标注所依据的参考资料编号（如[资料1]）或具体经文出处。
3. 牧师类问题权威底本为英文 KJV；健康类权威为圣经与怀爱伦(EGW)著作。
4. 严禁引用中文和合本(CUV)作为权威；若需引用经文，使用资料中给出的底本/书卷名。
5. 若<参考资料>不足以回答，必须明确说明"我无法基于现有资料确认"，并引导用户转人工或自行查经，不要猜测。
6. 健康类不提供医疗诊断；涉及具体症状须建议就医或咨询专业医师。
7. 用简体中文、温暖牧养的语气作答，结论先行（可用**加粗**强调要点）。
8. 回答应有结构（围绕问题分点阐述即可），聚焦问题本身；资料与问题部分相关时，
   只采用确实相关的部分，不要把不太相关的资料硬套上去。`;

function buildUserPrompt(question, ctxItems) {
  const ctxLines = [];
  ctxItems.forEach((h, i) => {
    const cites = (h.citations || [])
      .filter((c) => c && c.snippet)
      .map((c) => `[${(c.source_id || c.ref || '').trim()}] ${c.snippet}`)
      .join('；');
    ctxLines.push(
      `[资料${i + 1} | ${h.kind === 'health' ? '健康' : '牧师问答'}]\n结论: ${h.answer_zh || ''}\n权威依据: ${cites || '(无具体经文片段)'}`
    );
  });
  const context = ctxLines.length ? ctxLines.join('\n\n') : '(无相关权威资料)';
  return `<参考资料>\n${context}\n</参考资料>\n\n用户问题: ${question}\n\n请基于上述资料回答，遵守：\n` +
    `1. 结论先行——首句用**加粗**直接回应用户的问题；\n` +
    `2. 每个论点标注依据（如[资料1]及其具体经文/出处），不得引用资料之外的来源；\n` +
    `3. 多条资料相关时综合作答，不要只复述其中一条；\n` +
    `4. 资料不足以回答时，明确说"我无法基于现有资料确认"，并引导用户查经或转人工，绝不编造。`;
}

// ---------------------------------------------------------------------------
// 后处理合规审计
// ---------------------------------------------------------------------------
const CUV_HINTS = ['和合本', '和合本修订版', '新标点和合本', '圣经和合本', '国语和合本', '文理本'];

function postCheck(answer, ctxItems) {
  const flags = [];
  if (!answer) return flags;
  for (const h of CUV_HINTS) {
    if (answer.includes(h)) flags.push(`疑似CUV特征: ${h}`);
  }
  const ctxRefs = new Set();
  for (const h of ctxItems) {
    for (const c of h.citations || []) {
      for (const field of [c.source_id, c.ref]) {
        if (field) for (const r of normalizeRefs(field)) ctxRefs.add(r);
      }
    }
  }
  const ansRefsRaw = [];
  const enRaw = answer.match(/[A-Za-z]{2,4}\s*\d{1,3}\s*[:：]\s*\d{1,3}/g) || [];
  ansRefsRaw.push(...enRaw);
  for (const alias of BOOK_ALIASES_SORTED) {
    if (/[A-Za-z]/.test(alias)) continue;
    const a = alias.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const re = new RegExp(a + '\\s*\\d{1,3}\\s*[:：]\\s*\\d{1,3}|' + a + '\\s*第?\\s*\\d{1,3}\\s*章\\s*第?\\s*\\d{1,3}\\s*节', 'g');
    const ms = answer.match(re) || [];
    ansRefsRaw.push(...ms);
  }
  for (const raw of ansRefsRaw) {
    const norm = [...normalizeRefs(raw)];
    const ok = norm.some((r) => ctxRefs.has(r));
    if (!ok) flags.push(`越界引用(不在context): ${raw.trim()}`);
  }
  return flags;
}

// ---------------------------------------------------------------------------
// 限流（内存实现，按 IP）
// ---------------------------------------------------------------------------
const MEM_BUCKETS = new Map();
const WINDOW_MS = 60_000;

function rateLimited(ip) {
  const now = Date.now();
  const w = MEM_BUCKETS.get(ip);
  if (!w || now - w.ts > WINDOW_MS) {
    MEM_BUCKETS.set(ip, { count: 1, ts: now });
    return false;
  }
  if (w.count >= CONFIG.limit) return true;
  w.count += 1;
  return false;
}

const HONEST_FALLBACK = `**亲爱的，这个问题我暂时没有在已审核的权威资料中检索到确切依据；` +
  `我不愿凭空揣测、更不愿误导你，所以诚实地把不知道的留给你我都不敢妄言之处。** ` +
  `你可以：① 直接输入经文引用（如「路加福音3:23」），我立刻陪你查考并附权威出处；` +
  `② 换一个角度再问；③ 点击下方「转人工顾问」，由真实的牧者亲自回复你。`;

// ---------------------------------------------------------------------------
// LLM 调用（Node 18+ 自带 fetch）
// ---------------------------------------------------------------------------
async function callLLM(system, user) {
  const body = JSON.stringify({
    model: CONFIG.model,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
    temperature: 0.2,
  });
  // 超时保护：托管平台反向代理窗口有限，LLM 挂死必须按时返回兜底，绝不让网关 502
  const timeoutMs = Number(process.env.RAG_TIMEOUT_MS) || 25000;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const r = await fetch(CONFIG.baseUrl + '/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${CONFIG.apiKey}`,
        'Content-Type': 'application/json',
      },
      body,
      signal: ctrl.signal,
    });
    if (!r.ok) {
      const txt = await r.text();
      return { ok: false, error: `LLM ${r.status}: ${txt.slice(0, 200)}` };
    }
    const d = await r.json();
    const text = (d && d.choices && d.choices[0] && d.choices[0].message && d.choices[0].message.content) || '';
    return { ok: true, text };
  } catch (e) {
    const msg = (e && e.name === 'AbortError')
      ? `LLM timeout after ${timeoutMs}ms`
      : `LLM call failed: ${(e && e.message) || e}`;
    return { ok: false, error: msg };
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------------------
// v58：诊断材料图片 OCR（POST /api/ocr）
//
// 背景：医药布道模块上传诊断证明图片后，附件解析层对图片一律返回「需手动
// 誊写」占位（extractedText 为空），导致材料识别器无文本可处理、表单无法
// 自动填写。这里补上图片文字提取环节：调用智谱视觉模型（glm-4v-plus）把
// 图片文字逐字转录为纯文本。
//
// 合规铁律：**只转录、不解读**——模型不得输出任何诊断、医学解读或建议，
// 不得推测补全看不清的文字。转录文本回传前端后，交由本地识别器
// （MaterialRecognizer）提取字段，最终由用户核实后提交。
// ---------------------------------------------------------------------------
const OCR_SYSTEM_PROMPT = `你是医疗材料文字转录引擎。唯一任务：把用户图片中的文字逐字转录为纯文本。
严格遵守：
1. 只转录图片中真实可见的文字，不得推测、补全、改写、翻译或总结；
2. 保持原有换行与段落顺序；无法辨认的字用「□」代替，绝不允许猜测其内容；
3. 不得输出任何诊断结论、医学解读、治疗建议或其他图片之外的文字；
4. 不要客套话，直接输出转录文本。`;

async function callVisionLLM(imageUrl) {
  const model = process.env.OCR_MODEL || 'glm-4v-plus';
  const body = JSON.stringify({
    model,
    messages: [
      { role: 'system', content: OCR_SYSTEM_PROMPT },
      {
        role: 'user',
        content: [
          { type: 'image_url', image_url: { url: imageUrl } },
          { type: 'text', text: '请转录这张医疗材料图片中的全部文字。' },
        ],
      },
    ],
    temperature: 0.1,
  });
  // 超时保护：托管平台反向代理窗口有限，视觉模型挂死必须按时返回错误，
  // 绝不让网关 502（服务本身 400/502 正常，别误判挂了）。
  const timeoutMs = Number(process.env.OCR_TIMEOUT_MS) || 30000;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const r = await fetch(CONFIG.baseUrl + '/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${CONFIG.apiKey}`,
        'Content-Type': 'application/json',
      },
      body,
      signal: ctrl.signal,
    });
    if (!r.ok) {
      const txt = await r.text();
      return { ok: false, error: `OCR LLM ${r.status}: ${txt.slice(0, 200)}` };
    }
    const d = await r.json();
    const text = (d && d.choices && d.choices[0] && d.choices[0].message && d.choices[0].message.content) || '';
    return { ok: true, text: String(text).slice(0, 8000) };
  } catch (e) {
    const msg = (e && e.name === 'AbortError')
      ? `OCR timeout after ${timeoutMs}ms`
      : `OCR call failed: ${(e && e.message) || e}`;
    return { ok: false, error: msg };
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------------------
// SDA 圣经注释按节抽取（v53）
//
// 背景：App 原先把用户跳转到第三方镜像 bible-strong.app 的注释页，用户要求
// 「点击后在当条经文下方内联显示，不外跳」。该站无 CORS 头且有
// X-Frame-Options: SAMEORIGIN，前端直抓/iframe 均被浏览器拦截，只能由服务端
// 代理抓取、解析、清洗后返回纯文本 JSON。
// 页面（Next.js RSC）内嵌 sections 数组：
//   {slug:"1-1",startVerse:1,endVerse:1,html:"\x3Cp>In the beginning..."}
// 按节精准抽取；同一节可能含多条（正文注释 + Ellen G. White 评注），全部返回。
// ---------------------------------------------------------------------------
const SDABC_OSIS = {
  GEN: 'gen', EXO: 'exod', LEV: 'lev', NUM: 'num', DEU: 'deut',
  JOS: 'josh', JDG: 'judg', RUT: 'ruth', '1SA': '1sam', '2SA': '2sam',
  '1KI': '1kgs', '2KI': '2kgs', '1CH': '1chr', '2CH': '2chr', EZR: 'ezra',
  NEH: 'neh', EST: 'esth', JOB: 'job', PSA: 'ps', PRO: 'prov', ECC: 'eccl',
  SNG: 'song', ISA: 'isa', JER: 'jer', LAM: 'lam', EZK: 'ezek', DAN: 'dan',
  HOS: 'hos', JOL: 'joel', AMO: 'amos', OBA: 'obad', JON: 'jonah', MIC: 'mic',
  NAM: 'nah', HAB: 'hab', ZEP: 'zeph', HAG: 'hag', ZEC: 'zech', MAL: 'mal',
  MAT: 'matt', MRK: 'mark', LUK: 'luke', JHN: 'john', ACT: 'acts',
  ROM: 'rom', '1CO': '1cor', '2CO': '2cor', GAL: 'gal', EPH: 'eph',
  PHP: 'phil', COL: 'col', '1TH': '1thess', '2TH': '2thess', '1TI': '1tim',
  '2TI': '2tim', TIT: 'titus', PHM: 'phlm', HEB: 'heb', JAS: 'jas',
  '1PE': '1pet', '2PE': '2pet', '1JN': '1john', '2JN': '2john',
  '3JN': '3john', JUD: 'jude', REV: 'rev',
};

function unescapeRsc(s) {
  return String(s || '')
    .replace(/\\x3C/g, '<').replace(/\\x3E/g, '>').replace(/\\x26/g, '&')
    .replace(/\\x3D/g, '=').replace(/\\x22/g, '"').replace(/\\x27/g, "'")
    .replace(/\\x2F/g, '/').replace(/\\u003c/g, '<').replace(/\\u003e/g, '>')
    .replace(/\\n/g, '\n').replace(/\\t/g, ' ').replace(/\\r/g, '')
    .replace(/\\\\/g, '\\');
}

function htmlToText(h) {
  let t = unescapeRsc(h);
  t = t.replace(/<\/(p|div|li|h[1-6]|blockquote)>/gi, '\n');
  t = t.replace(/<br\s*\/?>/gi, '\n');
  t = t.replace(/<[^>]+>/g, '');
  t = t.replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'");
  t = t.replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n');
  return t.trim();
}

async function fetchCommentary(bookCode, chapter, verse) {
  const osis = SDABC_OSIS[String(bookCode || '').toUpperCase()];
  if (!osis) return { ok: false, error: `unknown book: ${bookCode}` };
  const url = `https://bible-strong.app/commentary/en/sdabc/${osis}/${chapter}`;
  const timeoutMs = Number(process.env.RAG_COMM_TIMEOUT_MS) || 20000;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const r = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; bible-app/1.0)' },
      signal: ctrl.signal,
    });
    if (!r.ok) return { ok: false, error: `upstream ${r.status}` };
    const html = await r.text();
    const re = /\{slug:"([0-9\-]+)",startVerse:(\d+),endVerse:(\d+),html:"((?:[^"\\]|\\.)*)"\}/g;
    const parts = [];
    let m;
    while ((m = re.exec(html)) !== null) {
      const sv = parseInt(m[2], 10);
      const ev = parseInt(m[3], 10);
      if (verse >= sv && verse <= ev) {
        const text = htmlToText(m[4]);
        if (text) parts.push(text);
      }
    }
    if (!parts.length) {
      return { ok: false, error: `no commentary section for ${bookCode} ${chapter}:${verse}` };
    }
    return {
      ok: true,
      ref: `${bookCode.toUpperCase()} ${chapter}:${verse}`,
      text: parts.join('\n\n'),
      source: 'SDA Bible Commentary (bible-strong.app 镜像)',
      url,
    };
  } catch (e) {
    const msg = (e && e.name === 'AbortError')
      ? `commentary timeout after ${timeoutMs}ms`
      : `commentary fetch failed: ${(e && e.message) || e}`;
    return { ok: false, error: msg };
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------------------
// v54：SDA 圣经注释·简体中文版（read.sdabible.org tRPC 代理）
//
// 背景：用户要求注释可切换英文/中文。bible-strong 镜像仅英/法文；简体中文版
// 取自复临官方阅读站 read.sdabible.org（SDA聖經註釋+）。其前端为 React SPA，
// 数据走 tRPC v10（httpBatchLink + superjson transformer）：
//   GET /api/trpc/bible.chapterCommentaries?batch=1
//       &input={"0":{"json":{"book":<slug>,"chapter":N,"locale":"cn",
//                            "sourceId":<id>,"interfaceLanguage":"cn"}}}
// 响应：[{result:{data:{json:[{verseNumber,startVerseNumber,endVerseNumber,
//                            sourceLabel,sourceHtml}, …]}]}}]（sourceHtml 为
// 简单 HTML：p/strong/br，复用 htmlToText 清洗）。
// 两类源：
//   legacy              —— 《圣经注释》（SDA Bible Commentary 简体中译，主源）
//   egw-<slug>-cn-sda5  —— 《怀爱伦注释》（该节相关怀著引文，与英文版结构对齐）
// 按 [startVerse, endVerse] 区间命中即收（同节可多条；startVerse=0 为章末
// 「补充注释」，属章级内容，不随单节返回）。
// ---------------------------------------------------------------------------
const SDAB_SLUG = {
  GEN: 'genesis', EXO: 'exodus', LEV: 'leviticus', NUM: 'numbers',
  DEU: 'deuteronomy', JOS: 'joshua', JDG: 'judges', RUT: 'ruth',
  '1SA': '1-samuel', '2SA': '2-samuel', '1KI': '1-kings', '2KI': '2-kings',
  '1CH': '1-chronicles', '2CH': '2-chronicles', EZR: 'ezra', NEH: 'nehemiah',
  EST: 'esther', JOB: 'job', PSA: 'psalms', PRO: 'proverbs',
  ECC: 'ecclesiastes', SNG: 'song-of-solomon', ISA: 'isaiah', JER: 'jeremiah',
  LAM: 'lamentations', EZK: 'ezekiel', DAN: 'daniel', HOS: 'hosea',
  JOL: 'joel', AMO: 'amos', OBA: 'obadiah', JON: 'jonah', MIC: 'micah',
  NAM: 'nahum', HAB: 'habakkuk', ZEP: 'zephaniah', HAG: 'haggai',
  ZEC: 'zechariah', MAL: 'malachi', MAT: 'matthew', MRK: 'mark',
  LUK: 'luke', JHN: 'john', ACT: 'acts', ROM: 'romans',
  '1CO': '1-corinthians', '2CO': '2-corinthians', GAL: 'galatians',
  EPH: 'ephesians', PHP: 'philippians', COL: 'colossians',
  '1TH': '1-thessalonians', '2TH': '2-thessalonians', '1TI': '1-timothy',
  '2TI': '2-timothy', TIT: 'titus', PHM: 'philemon', HEB: 'hebrews',
  JAS: 'james', '1PE': '1-peter', '2PE': '2-peter', '1JN': '1-john',
  '2JN': '2-john', '3JN': '3-john', JUD: 'jude', REV: 'revelation',
};

/// 调用 read.sdabible.org 的 bible.chapterCommentaries，返回该章全部注释条目。
async function fetchTrpcCommentary(bookSlug, chapter, sourceId, timeoutMs) {
  const input = JSON.stringify({
    '0': {
      json: {
        book: bookSlug,
        chapter,
        locale: 'cn',
        sourceId,
        interfaceLanguage: 'cn',
      },
    },
  });
  const base = process.env.SDAB_TRPC_BASE || 'https://read.sdabible.org';
  const url = base + '/api/trpc/bible.chapterCommentaries'
      + '?batch=1&input=' + encodeURIComponent(input);
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const r = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (compatible; bible-app/1.0)' },
      signal: ctrl.signal,
    });
    if (!r.ok) return { ok: false, error: `trpc upstream ${r.status}` };
    const data = await r.json();
    const first = Array.isArray(data) ? data[0] : null;
    if (!first || first.error) {
      const msg = (first && first.error && first.error.json)
        ? first.error.json.message : 'trpc error';
      return { ok: false, error: String(msg).slice(0, 200) };
    }
    const verses = first.result && first.result.data && first.result.data.json;
    if (!Array.isArray(verses)) return { ok: false, error: 'trpc bad payload' };
    return { ok: true, verses };
  } catch (e) {
    const msg = (e && e.name === 'AbortError')
      ? `commentary timeout after ${timeoutMs}ms`
      : `commentary fetch failed: ${(e && e.message) || e}`;
    return { ok: false, error: msg };
  } finally {
    clearTimeout(timer);
  }
}

/// 从章注释条目中抽出覆盖 [verse] 的文本（跳过章级 startVerse=0 条目）。
function collectVerseText(verses, verse) {
  const parts = [];
  for (const v of verses || []) {
    const sv = Number(v.startVerseNumber);
    const ev = Number(v.endVerseNumber);
    if (!(sv >= 1 && verse >= sv && verse <= ev)) continue;
    const text = htmlToText(v.sourceHtml || '');
    if (text) parts.push(text);
  }
  return parts;
}

/// 简体中文注释：legacy《圣经注释》主源 + egw《怀爱伦注释》附源（失败不阻塞）。
async function fetchChineseCommentary(bookCode, chapter, verse) {
  const slug = SDAB_SLUG[String(bookCode || '').toUpperCase()];
  if (!slug) return { ok: false, error: `unknown book: ${bookCode}` };
  const timeoutMs = Number(process.env.RAG_COMM_TIMEOUT_MS) || 20000;
  const main = await fetchTrpcCommentary(slug, chapter, 'legacy', timeoutMs);
  if (!main.ok) return main;
  const parts = collectVerseText(main.verses, verse);
  if (!parts.length) {
    return {
      ok: false,
      error: `no commentary section for ${bookCode} ${chapter}:${verse}`,
    };
  }
  const egw = await fetchTrpcCommentary(
    slug, chapter, `egw-${slug}-cn-sda5`, timeoutMs);
  if (egw.ok) {
    for (const t of collectVerseText(egw.verses, verse)) parts.push(t);
  }
  return {
    ok: true,
    ref: `${bookCode.toUpperCase()} ${chapter}:${verse}`,
    text: parts.join('\n\n'),
    source: 'SDA 圣经注释（简体中文 · read.sdabible.org）',
    url: `https://read.sdabible.org/read/${slug}/${chapter}`,
  };
}

// ---------------------------------------------------------------------------
// HTTP 服务
// ---------------------------------------------------------------------------
function jsonRes(res, status, obj, origin) {
  const payload = JSON.stringify(obj);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': origin || '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    Vary: 'Origin',
  });
  res.end(payload);
}

function clientIp(req) {
  const xff = req.headers['x-forwarded-for'];
  if (typeof xff === 'string' && xff.length) return xff.split(',')[0].trim();
  if (req.headers['x-real-ip']) return String(req.headers['x-real-ip']);
  return (req.socket && req.socket.remoteAddress) || 'unknown';
}

const server = http.createServer(async (req, res) => {
  const origin = req.headers.origin;

  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': origin || '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      Vary: 'Origin',
    });
    return res.end();
  }

  if (req.method === 'GET') {
    // v53：SDA 圣经注释按节抽取（服务端代理，返回纯文本 JSON）
    const u = new URL(req.url, 'http://x');
    if (u.pathname.replace(/\/+$/, '') === '/api/commentary') {
      const book = (u.searchParams.get('book') || u.searchParams.get('ref') || '').trim();
      let bk = book, ch = u.searchParams.get('chapter'), vs = u.searchParams.get('verse');
      const refM = book.match(/^([0-9]?[A-Za-z]{2,4})\s*(\d{1,3})\s*[:：]\s*(\d{1,3})$/);
      if (refM) { bk = refM[1]; ch = refM[2]; vs = refM[3]; }
      const chN = parseInt(ch || '', 10);
      const vsN = parseInt(vs || '', 10);
      if (!bk || !Number.isFinite(chN) || !Number.isFinite(vsN)) {
        return jsonRes(res, 400, { ok: false, error: 'need book+chapter+verse (or ref=GEN 1:1)' }, origin);
      }
      // v54：语言切换。lang=zh/cn → 简体中文（read.sdabible.org tRPC）；
      // 其余（默认 en）→ 英文原著（bible-strong.app 镜像）。
      const lang = (u.searchParams.get('lang') || 'en').toLowerCase();
      const out = (lang === 'zh' || lang === 'cn' || lang === 'zh-cn')
        ? await fetchChineseCommentary(bk, chN, vsN)
        : await fetchCommentary(bk, chN, vsN);
      return jsonRes(res, out.ok ? 200 : 502, out, origin);
    }
    return jsonRes(res, 200, { service: 'bible-rag-proxy', ok: true, model: CONFIG.model }, origin);
  }

  if (req.method !== 'POST') {
    return jsonRes(res, 404, { error: 'Not Found' }, origin);
  }

  if (!CONFIG.apiKey) {
    return jsonRes(res, 500, { error: 'server misconfigured: missing RAG_API_KEY' }, origin);
  }

  if (rateLimited(clientIp(req))) {
    return jsonRes(res, 429, { error: 'rate limited, try later' }, origin);
  }

  let body = '';
  // v58：/api/ocr 携带 base64 图片（几 MB 量级），单独放宽上限；其余维持 256KB
  const isOcrPath = req.url && req.url.split('?')[0].replace(/\/+$/, '') === '/api/ocr';
  const bodyLimit = isOcrPath ? 8 * 1024 * 1024 : 256 * 1024;
  req.on('data', (chunk) => {
    body += chunk;
    if (body.length > bodyLimit) req.destroy();
  });
  req.on('error', () => {});
  req.on('end', async () => {
    let parsed;
    try {
      parsed = JSON.parse(body || '{}');
    } catch {
      return jsonRes(res, 400, { error: 'invalid json' }, origin);
    }

    // v58：图片 OCR（先于 RAG 分支处理：入参是 image 而非 question）
    if (isOcrPath) {
      let image = String(parsed.image || '').trim();
      if (!image) {
        return jsonRes(res, 400, { ok: false, error: 'missing image (base64)' }, origin);
      }
      const mime = String(parsed.mime || 'image/jpeg').toLowerCase();
      if (!/^image\/(jpeg|jpg|png|webp|bmp)$/.test(mime)) {
        return jsonRes(res, 400, { ok: false, error: `unsupported mime: ${mime}` }, origin);
      }
      if (!image.startsWith('data:')) image = `data:${mime};base64,${image}`;
      const llmResp = await callVisionLLM(image);
      if (!llmResp.ok) {
        return jsonRes(res, 502, { ok: false, error: llmResp.error }, origin);
      }
      const text = String(llmResp.text || '').trim();
      if (!text) {
        return jsonRes(res, 502, { ok: false, error: 'OCR returned empty text' }, origin);
      }
      return jsonRes(res, 200, { ok: true, text }, origin);
    }

    const question = String(parsed.question || '').trim();
    let ctxItems = Array.isArray(parsed.context) ? parsed.context.slice(0, 8) : [];

    if (!question) {
      return jsonRes(res, 400, { error: 'missing question' }, origin);
    }
    ctxItems = ctxItems
      .filter((h) => h && typeof h === 'object')
      .map((h) => ({
        kind: h.kind === 'health' ? 'health' : 'pastor',
        answer_zh: String(h.answer_zh || '').slice(0, 2000),
        citations: Array.isArray(h.citations) ? h.citations.slice(0, 6) : [],
      }));

    const user = buildUserPrompt(question, ctxItems);
    const llmResp = await callLLM(SYSTEM_PROMPT, user);
    if (!llmResp.ok) {
      return jsonRes(res, 200, { answer: HONEST_FALLBACK, flags: [llmResp.error], fallback: true }, origin);
    }

    const flags = postCheck(llmResp.text, ctxItems);
    if (flags.some((f) => f.startsWith('疑似CUV特征'))) {
      return jsonRes(res, 200, { answer: HONEST_FALLBACK, flags, fallback: true }, origin);
    }
    return jsonRes(res, 200, { answer: llmResp.text, flags, fallback: false }, origin);
  });
});

const PORT = Number(process.env.FC_SERVER_PORT) || Number(process.env.PORT) || 9000;
server.listen(PORT, () => {
  console.log(`bible-rag-proxy listening on :${PORT} (model=${CONFIG.model})`);
});
