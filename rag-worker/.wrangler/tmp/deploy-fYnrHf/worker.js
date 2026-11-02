var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// worker.js
var BOOK = {
  // 旧约
  genesis: "GEN",
  "\u521B\u4E16\u8BB0": "GEN",
  "\u5275\u4E16\u8A18": "GEN",
  exodus: "EXO",
  "\u51FA\u57C3\u53CA\u8BB0": "EXO",
  "\u51FA\u57C3\u53CA\u8A18": "EXO",
  leviticus: "LEV",
  "\u5229\u672A\u8BB0": "LEV",
  "\u5229\u672A\u8A18": "LEV",
  numbers: "NUM",
  "\u6C11\u6570\u8BB0": "NUM",
  "\u6C11\u6578\u8A18": "NUM",
  deuteronomy: "DEU",
  "\u7533\u547D\u8BB0": "DEU",
  "\u7533\u547D\u8A18": "DEU",
  joshua: "JOS",
  "\u7EA6\u4E66\u4E9A\u8BB0": "JOS",
  "\u7D04\u66F8\u4E9E\u8A18": "JOS",
  judges: "JDG",
  "\u58EB\u5E08\u8BB0": "JDG",
  "\u58EB\u5E2B\u8A18": "JDG",
  ruth: "RUT",
  "\u8DEF\u5F97\u8BB0": "RUT",
  "\u8DEF\u5F97\u8A18": "RUT",
  "1 samuel": "1SA",
  "\u6492\u6BCD\u8033\u8BB0\u4E0A": "1SA",
  "\u6492\u6BCD\u8033\u8A18\u4E0A": "1SA",
  "\u6492\u4E0A": "1SA",
  "2 samuel": "2SA",
  "\u6492\u6BCD\u8033\u8BB0\u4E0B": "2SA",
  "\u6492\u6BCD\u8033\u8A18\u4E0B": "2SA",
  "\u6492\u4E0B": "2SA",
  "1 kings": "1KI",
  "\u5217\u738B\u7EAA\u4E0A": "1KI",
  "\u5217\u738B\u7D00\u4E0A": "1KI",
  "\u738B\u4E0A": "1KI",
  "2 kings": "2KI",
  "\u5217\u738B\u7EAA\u4E0B": "2KI",
  "\u5217\u738B\u7D00\u4E0B": "2KI",
  "\u738B\u4E0B": "2KI",
  "1 chronicles": "1CH",
  "\u5386\u4EE3\u5FD7\u4E0A": "1CH",
  "\u6B77\u4EE3\u5FD7\u4E0A": "1CH",
  "\u4EE3\u4E0A": "1CH",
  "2 chronicles": "2CH",
  "\u5386\u4EE3\u5FD7\u4E0B": "2CH",
  "\u6B77\u4EE3\u5FD7\u4E0B": "2CH",
  "\u4EE3\u4E0B": "2CH",
  ezra: "EZR",
  "\u4EE5\u65AF\u62C9\u8BB0": "EZR",
  "\u4EE5\u65AF\u62C9\u8A18": "EZR",
  nehemiah: "NEH",
  "\u5C3C\u5E0C\u7C73\u8BB0": "NEH",
  "\u5C3C\u5E0C\u7C73\u8A18": "NEH",
  esther: "EST",
  "\u4EE5\u65AF\u5E16\u8BB0": "EST",
  "\u4EE5\u65AF\u5E16\u8A18": "EST",
  job: "JOB",
  "\u7EA6\u4F2F\u8BB0": "JOB",
  "\u7D04\u4F2F\u8A18": "JOB",
  psalms: "PSA",
  "\u8BD7\u7BC7": "PSA",
  "\u8A69\u7BC7": "PSA",
  "\u8BD7": "PSA",
  proverbs: "PRO",
  "\u7BB4\u8A00": "PRO",
  "\u7BB4": "PRO",
  ecclesiastes: "ECC",
  "\u4F20\u9053\u4E66": "ECC",
  "\u50B3\u9053\u66F8": "ECC",
  "song of solomon": "SNG",
  "\u96C5\u6B4C": "SNG",
  isaiah: "ISA",
  "\u4EE5\u8D5B\u4E9A\u4E66": "ISA",
  "\u4EE5\u8CFD\u4E9E\u66F8": "ISA",
  "\u8D5B": "ISA",
  jeremiah: "JER",
  "\u8036\u5229\u7C73\u4E66": "JER",
  "\u8036\u5229\u7C73\u66F8": "JER",
  "\u8036": "JER",
  lamentations: "LAM",
  "\u8036\u5229\u7C73\u54C0\u6B4C": "LAM",
  "\u8036\u5229\u7C73\u54C0\u6B4C": "LAM",
  ezekiel: "EZK",
  "\u4EE5\u897F\u7ED3\u4E66": "EZK",
  "\u4EE5\u897F\u7D50\u66F8": "EZK",
  "\u7ED3": "EZK",
  daniel: "DAN",
  "\u4F46\u4EE5\u7406\u4E66": "DAN",
  "\u4F46\u4EE5\u7406\u66F8": "DAN",
  "\u4F46": "DAN",
  hosea: "HOS",
  "\u4F55\u897F\u963F\u4E66": "HOS",
  "\u4F55\u897F\u963F\u66F8": "HOS",
  joel: "JOL",
  "\u7EA6\u73E5\u4E66": "JOL",
  "\u7D04\u73E5\u66F8": "JOL",
  amos: "AMO",
  "\u963F\u6469\u53F8\u4E66": "AMO",
  "\u963F\u6469\u53F8\u66F8": "AMO",
  obadiah: "OBA",
  "\u4FC4\u5DF4\u5E95\u4E9A\u4E66": "OBA",
  "\u4FC4\u5DF4\u5E95\u4E9E\u66F8": "OBA",
  jonah: "JON",
  "\u7EA6\u62FF\u4E66": "JON",
  "\u7D04\u62FF\u66F8": "JON",
  "\u62FF": "JON",
  micah: "MIC",
  "\u5F25\u8FE6\u4E66": "MIC",
  "\u5F4C\u8FE6\u66F8": "MIC",
  "\u5F25": "MIC",
  nahum: "NAM",
  "\u90A3\u9E3F\u4E66": "NAM",
  "\u90A3\u9D3B\u66F8": "NAM",
  habakkuk: "HAB",
  "\u54C8\u5DF4\u8C37\u4E66": "HAB",
  "\u54C8\u5DF4\u8C37\u66F8": "HAB",
  zephaniah: "ZEP",
  "\u897F\u756A\u96C5\u4E66": "ZEP",
  "\u897F\u756A\u96C5\u66F8": "ZEP",
  haggai: "HAG",
  "\u54C8\u8BE5\u4E66": "HAG",
  "\u54C8\u8A72\u66F8": "HAG",
  zechariah: "ZEC",
  "\u6492\u8FE6\u5229\u4E9A\u4E66": "ZEC",
  "\u6492\u8FE6\u5229\u4E9E\u66F8": "ZEC",
  malachi: "MAL",
  "\u739B\u62C9\u57FA\u4E66": "MAL",
  "\u746A\u62C9\u57FA\u66F8": "MAL",
  // 新约
  matthew: "MAT",
  "\u9A6C\u592A\u798F\u97F3": "MAT",
  "\u99AC\u592A\u798F\u97F3": "MAT",
  "\u592A": "MAT",
  mark: "MRK",
  "\u9A6C\u53EF\u798F\u97F3": "MRK",
  "\u99AC\u53EF\u798F\u97F3": "MRK",
  "\u53EF": "MRK",
  luke: "LUK",
  "\u8DEF\u52A0\u798F\u97F3": "LUK",
  "\u8DEF\u52A0\u798F\u97F3": "LUK",
  "\u8DEF": "LUK",
  john: "JHN",
  "\u7EA6\u7FF0\u798F\u97F3": "JHN",
  "\u7D04\u7FF0\u798F\u97F3": "JHN",
  "\u7EA6": "JHN",
  acts: "ACT",
  "\u4F7F\u5F92\u884C\u4F20": "ACT",
  "\u4F7F\u5F92\u884C\u50B3": "ACT",
  "\u5F92": "ACT",
  romans: "ROM",
  "\u7F57\u9A6C\u4E66": "ROM",
  "\u7F85\u99AC\u66F8": "ROM",
  "\u7F57": "ROM",
  "1 corinthians": "1CO",
  "\u54E5\u6797\u591A\u524D\u4E66": "1CO",
  "\u54E5\u6797\u591A\u524D\u66F8": "1CO",
  "\u6797\u524D": "1CO",
  "2 corinthians": "2CO",
  "\u54E5\u6797\u591A\u540E\u4E66": "2CO",
  "\u54E5\u6797\u591A\u5F8C\u66F8": "2CO",
  "\u6797\u540E": "2CO",
  galatians: "GAL",
  "\u52A0\u62C9\u592A\u4E66": "GAL",
  "\u52A0\u62C9\u592A\u66F8": "GAL",
  "\u52A0": "GAL",
  ephesians: "EPH",
  "\u4EE5\u5F17\u6240\u4E66": "EPH",
  "\u4EE5\u5F17\u6240\u66F8": "EPH",
  "\u5F17": "EPH",
  philippians: "PHP",
  "\u8153\u7ACB\u6BD4\u4E66": "PHP",
  "\u8153\u7ACB\u6BD4\u66F8": "PHP",
  "\u8153": "PHP",
  colossians: "COL",
  "\u6B4C\u7F57\u897F\u4E66": "COL",
  "\u6B4C\u7F85\u897F\u66F8": "COL",
  "\u897F": "COL",
  "1 thessalonians": "1TH",
  "\u5E16\u6492\u7F57\u5C3C\u8FE6\u524D\u4E66": "1TH",
  "\u5E16\u6492\u7F85\u5C3C\u8FE6\u524D\u66F8": "1TH",
  "\u5E16\u524D": "1TH",
  "2 thessalonians": "2TH",
  "\u5E16\u6492\u7F57\u5C3C\u8FE6\u540E\u4E66": "2TH",
  "\u5E16\u6492\u7F85\u5C3C\u8FE6\u5F8C\u66F8": "2TH",
  "\u5E16\u540E": "2TH",
  "1 timothy": "1TI",
  "\u63D0\u6469\u592A\u524D\u4E66": "1TI",
  "\u63D0\u6469\u592A\u524D\u66F8": "1TI",
  "\u63D0\u524D": "1TI",
  "2 timothy": "2TI",
  "\u63D0\u6469\u592A\u540E\u4E66": "2TI",
  "\u63D0\u6469\u592A\u5F8C\u66F8": "2TI",
  "\u63D0\u540E": "2TI",
  titus: "TIT",
  "\u63D0\u591A\u4E66": "TIT",
  "\u63D0\u591A\u66F8": "TIT",
  "\u591A": "TIT",
  philemon: "PHM",
  "\u8153\u5229\u95E8\u4E66": "PHM",
  "\u8153\u5229\u9580\u66F8": "PHM",
  hebrews: "HEB",
  "\u5E0C\u4F2F\u6765\u4E66": "HEB",
  "\u5E0C\u4F2F\u4F86\u66F8": "HEB",
  "\u6765": "HEB",
  "\u5E0C\u4F2F": "HEB",
  james: "JAS",
  "\u96C5\u5404\u4E66": "JAS",
  "\u96C5\u5404\u66F8": "JAS",
  "\u96C5": "JAS",
  "1 peter": "1PE",
  "\u5F7C\u5F97\u524D\u4E66": "1PE",
  "\u5F7C\u5F97\u524D\u66F8": "1PE",
  "\u5F7C\u524D": "1PE",
  "2 peter": "2PE",
  "\u5F7C\u5F97\u540E\u4E66": "2PE",
  "\u5F7C\u5F97\u5F8C\u66F8": "2PE",
  "\u5F7C\u540E": "2PE",
  "1 john": "1JN",
  "\u7EA6\u7FF0\u4E00\u4E66": "1JN",
  "\u7D04\u7FF0\u4E00\u66F8": "1JN",
  "\u7EA6\u4E00": "1JN",
  "2 john": "2JN",
  "\u7EA6\u7FF0\u4E8C\u4E66": "2JN",
  "\u7D04\u7FF0\u4E8C\u66F8": "2JN",
  "\u7EA6\u4E8C": "2JN",
  "3 john": "3JN",
  "\u7EA6\u7FF0\u4E09\u4E66": "3JN",
  "\u7D04\u7FF0\u4E09\u66F8": "3JN",
  "\u7EA6\u4E09": "3JN",
  jude: "JUD",
  "\u72B9\u5927\u4E66": "JUD",
  "\u7336\u5927\u66F8": "JUD",
  revelation: "REV",
  "\u542F\u793A\u5F55": "REV",
  "\u555F\u793A\u9304": "REV",
  "\u542F": "REV"
};
Object.assign(BOOK, {
  gen: "GEN",
  exo: "EXO",
  lev: "LEV",
  num: "NUM",
  deu: "DEU",
  jos: "JOS",
  jdg: "JDG",
  rut: "RUT",
  "1sa": "1SA",
  "2sa": "2SA",
  "1ki": "1KI",
  "2ki": "2KI",
  "1ch": "1CH",
  "2ch": "2CH",
  ezr: "EZR",
  neh: "NEH",
  est: "EST",
  job: "JOB",
  psa: "PSA",
  pro: "PRO",
  ecc: "ECC",
  sng: "SNG",
  isa: "ISA",
  jer: "JER",
  lam: "LAM",
  ezk: "EZK",
  dan: "DAN",
  hos: "HOS",
  jol: "JOL",
  amo: "AMO",
  oba: "OBA",
  jon: "JON",
  mic: "MIC",
  nam: "NAM",
  hab: "HAB",
  zep: "ZEP",
  hag: "HAG",
  zec: "ZEC",
  mal: "MAL",
  mat: "MAT",
  mrk: "MRK",
  luk: "LUK",
  jhn: "JHN",
  act: "ACT",
  rom: "ROM",
  "1co": "1CO",
  "2co": "2CO",
  gal: "GAL",
  eph: "EPH",
  php: "PHP",
  col: "COL",
  "1th": "1TH",
  "2th": "2TH",
  "1ti": "1TI",
  "2ti": "2TI",
  tit: "TIT",
  phm: "PHM",
  heb: "HEB",
  jas: "JAS",
  "1pe": "1PE",
  "2pe": "2PE",
  "1jn": "1JN",
  "2jn": "2JN",
  "3jn": "3JN",
  jud: "JUD",
  rev: "REV"
});
var BOOK_ALIASES_SORTED = Object.keys(BOOK).sort((a, b) => b.length - a.length);
function normalizeRefs(text) {
  const out = /* @__PURE__ */ new Set();
  if (!text) return out;
  let t = String(text).replace(/KJV-/gi, "").replace(/\s+/g, " ");
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
    const a = alias.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const reColon = new RegExp(a + "\\s*(\\d{1,3})\\s*[:\uFF1A]\\s*(\\d{1,3})", "g");
    while ((m = reColon.exec(t)) !== null) out.add(`${BOOK[alias]}:${m[1]}:${m[2]}`);
    const reZh = new RegExp(a + "\\s*\u7B2C?\\s*(\\d{1,3})\\s*\u7AE0\\s*\u7B2C?\\s*(\\d{1,3})\\s*\u8282", "g");
    while ((m = reZh.exec(t)) !== null) out.add(`${BOOK[alias]}:${m[1]}:${m[2]}`);
  }
  return out;
}
__name(normalizeRefs, "normalizeRefs");
var SYSTEM_PROMPT = `\u4F60\u662F\u7B26\u5408\u5723\u7ECF\u4E0E\u6000\u7231\u4F26(EGW)\u8457\u4F5C\u7ACB\u573A\u7684\u57FA\u7763\u6559\u4FE1\u4EF0/\u5065\u5EB7\u987E\u95EE\u3002\u4E25\u683C\u9075\u5B88\u4EE5\u4E0B\u89C4\u5219\uFF1A
1. \u53EA\u80FD\u57FA\u4E8E\u4E0B\u9762<\u53C2\u8003\u8D44\u6599>\u56DE\u7B54\uFF0C\u4E0D\u5F97\u7F16\u9020\u4EFB\u4F55\u7ECF\u6587\u3001\u4EBA\u7269\u3001\u4E8B\u5B9E\u6216\u5F15\u6587\u3002
2. \u56DE\u7B54\u65F6\u52A1\u5FC5\u6807\u6CE8\u6240\u4F9D\u636E\u7684\u53C2\u8003\u8D44\u6599\u7F16\u53F7\uFF08\u5982[\u8D44\u65991]\uFF09\u6216\u5177\u4F53\u7ECF\u6587\u51FA\u5904\u3002
3. \u7267\u5E08\u7C7B\u95EE\u9898\u6743\u5A01\u5E95\u672C\u4E3A\u82F1\u6587 KJV\uFF1B\u5065\u5EB7\u7C7B\u6743\u5A01\u4E3A\u5723\u7ECF\u4E0E\u6000\u7231\u4F26(EGW)\u8457\u4F5C\u3002
4. \u4E25\u7981\u5F15\u7528\u4E2D\u6587\u548C\u5408\u672C(CUV)\u4F5C\u4E3A\u6743\u5A01\uFF1B\u82E5\u9700\u5F15\u7528\u7ECF\u6587\uFF0C\u4F7F\u7528\u8D44\u6599\u4E2D\u7ED9\u51FA\u7684\u5E95\u672C/\u4E66\u5377\u540D\u3002
5. \u82E5<\u53C2\u8003\u8D44\u6599>\u4E0D\u8DB3\u4EE5\u56DE\u7B54\uFF0C\u5FC5\u987B\u660E\u786E\u8BF4\u660E"\u6211\u65E0\u6CD5\u57FA\u4E8E\u73B0\u6709\u8D44\u6599\u786E\u8BA4"\uFF0C\u5E76\u5F15\u5BFC\u7528\u6237\u8F6C\u4EBA\u5DE5\u6216\u81EA\u884C\u67E5\u7ECF\uFF0C\u4E0D\u8981\u731C\u6D4B\u3002
6. \u5065\u5EB7\u7C7B\u4E0D\u63D0\u4F9B\u533B\u7597\u8BCA\u65AD\uFF1B\u6D89\u53CA\u5177\u4F53\u75C7\u72B6\u987B\u5EFA\u8BAE\u5C31\u533B\u6216\u54A8\u8BE2\u4E13\u4E1A\u533B\u5E08\u3002
7. \u7528\u7B80\u4F53\u4E2D\u6587\u3001\u6E29\u6696\u7267\u517B\u7684\u8BED\u6C14\u4F5C\u7B54\uFF0C\u7ED3\u8BBA\u5148\u884C\uFF08\u53EF\u7528**\u52A0\u7C97**\u5F3A\u8C03\u8981\u70B9\uFF09\u3002`;
function buildUserPrompt(question, ctxItems) {
  const ctxLines = [];
  ctxItems.forEach((h, i) => {
    const cites = (h.citations || []).filter((c) => c && c.snippet).map((c) => `[${(c.source_id || c.ref || "").trim()}] ${c.snippet}`).join("\uFF1B");
    ctxLines.push(
      `[\u8D44\u6599${i + 1} | ${h.kind === "health" ? "\u5065\u5EB7" : "\u7267\u5E08\u95EE\u7B54"}]
\u7ED3\u8BBA: ${h.answer_zh || ""}
\u6743\u5A01\u4F9D\u636E: ${cites || "(\u65E0\u5177\u4F53\u7ECF\u6587\u7247\u6BB5)"}`
    );
  });
  const context = ctxLines.length ? ctxLines.join("\n\n") : "(\u65E0\u76F8\u5173\u6743\u5A01\u8D44\u6599)";
  return `<\u53C2\u8003\u8D44\u6599>
${context}
</\u53C2\u8003\u8D44\u6599>

\u7528\u6237\u95EE\u9898: ${question}

\u8BF7\u57FA\u4E8E\u4E0A\u8FF0\u8D44\u6599\u56DE\u7B54\uFF0C\u5E76\u6807\u6CE8\u6765\u6E90\u3002`;
}
__name(buildUserPrompt, "buildUserPrompt");
var CUV_HINTS = ["\u548C\u5408\u672C", "\u548C\u5408\u672C\u4FEE\u8BA2\u7248", "\u65B0\u6807\u70B9\u548C\u5408\u672C", "\u5723\u7ECF\u548C\u5408\u672C", "\u56FD\u8BED\u548C\u5408\u672C", "\u6587\u7406\u672C"];
function postCheck(answer, ctxItems) {
  const flags = [];
  if (!answer) return flags;
  for (const h of CUV_HINTS) {
    if (answer.includes(h)) flags.push(`\u7591\u4F3CCUV\u7279\u5F81: ${h}`);
  }
  const ctxRefs = /* @__PURE__ */ new Set();
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
    const a = alias.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const re = new RegExp(a + "\\s*\\d{1,3}\\s*[:\uFF1A]\\s*\\d{1,3}|" + a + "\\s*\u7B2C?\\s*\\d{1,3}\\s*\u7AE0\\s*\u7B2C?\\s*\\d{1,3}\\s*\u8282", "g");
    const ms = answer.match(re) || [];
    ansRefsRaw.push(...ms);
  }
  for (const raw of ansRefsRaw) {
    const norm = [...normalizeRefs(raw)];
    const ok = norm.some((r) => ctxRefs.has(r));
    if (!ok) flags.push(`\u8D8A\u754C\u5F15\u7528(\u4E0D\u5728context): ${raw.trim()}`);
  }
  return flags;
}
__name(postCheck, "postCheck");
var MEM_BUCKETS = /* @__PURE__ */ new Map();
var WINDOW_MS = 6e4;
async function rateLimited(ip, env) {
  const now = Date.now();
  const LIMIT = Number(env && env.RAG_LIMIT) || 20;
  if (env && env.RAG_KV) {
    const key = `rl:${ip}`;
    let rec = await env.RAG_KV.get(key, { type: "json" });
    if (!rec || now - rec.ts > WINDOW_MS) rec = { count: 0, ts: now };
    if (rec.count >= LIMIT) return true;
    rec.count += 1;
    await env.RAG_KV.put(key, JSON.stringify(rec), { expirationTtl: 120 });
    return false;
  }
  const w = MEM_BUCKETS.get(ip);
  if (!w || now - w.ts > WINDOW_MS) {
    MEM_BUCKETS.set(ip, { count: 1, ts: now });
    return false;
  }
  if (w.count >= LIMIT) return true;
  w.count += 1;
  return false;
}
__name(rateLimited, "rateLimited");
function clientIp(request) {
  return request.headers.get("CF-Connecting-IP") || request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
}
__name(clientIp, "clientIp");
function corsHeaders(origin) {
  return {
    "Access-Control-Allow-Origin": origin || "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Vary": "Origin"
  };
}
__name(corsHeaders, "corsHeaders");
var HONEST_FALLBACK = `**\u4EB2\u7231\u7684\uFF0C\u8FD9\u4E2A\u95EE\u9898\u6211\u6682\u65F6\u6CA1\u6709\u5728\u5DF2\u5BA1\u6838\u7684\u6743\u5A01\u8D44\u6599\u4E2D\u68C0\u7D22\u5230\u786E\u5207\u4F9D\u636E\uFF1B\u6211\u4E0D\u613F\u51ED\u7A7A\u63E3\u6D4B\u3001\u66F4\u4E0D\u613F\u8BEF\u5BFC\u4F60\uFF0C\u6240\u4EE5\u8BDA\u5B9E\u5730\u628A\u4E0D\u77E5\u9053\u7684\u7559\u7ED9\u4F60\u6211\u90FD\u4E0D\u6562\u5984\u8A00\u4E4B\u5904\u3002** \u4F60\u53EF\u4EE5\uFF1A\u2460 \u76F4\u63A5\u8F93\u5165\u7ECF\u6587\u5F15\u7528\uFF08\u5982\u300C\u8DEF\u52A0\u798F\u97F33:23\u300D\uFF09\uFF0C\u6211\u7ACB\u523B\u966A\u4F60\u67E5\u8003\u5E76\u9644\u6743\u5A01\u51FA\u5904\uFF1B\u2461 \u6362\u4E00\u4E2A\u89D2\u5EA6\u518D\u95EE\uFF1B\u2462 \u70B9\u51FB\u4E0B\u65B9\u300C\u8F6C\u4EBA\u5DE5\u987E\u95EE\u300D\uFF0C\u7531\u771F\u5B9E\u7684\u7267\u8005\u4EB2\u81EA\u56DE\u590D\u4F60\u3002`;
var worker_default = {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const origin = request.headers.get("Origin");
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }
    if (request.method === "GET" && url.pathname === "/") {
      return new Response(
        JSON.stringify({ service: "bible-rag-proxy", ok: true, model: env.RAG_MODEL || "glm-4-flash" }),
        { status: 200, headers: { "content-type": "application/json" } }
      );
    }
    if (request.method !== "POST" || url.pathname !== "/api/rag") {
      return new Response(JSON.stringify({ error: "Not Found" }), {
        status: 404,
        headers: { "content-type": "application/json", ...corsHeaders(origin) }
      });
    }
    if (!env.RAG_API_KEY) {
      return new Response(JSON.stringify({ error: "server misconfigured: missing RAG_API_KEY" }), {
        status: 500,
        headers: { "content-type": "application/json", ...corsHeaders(origin) }
      });
    }
    if (await rateLimited(clientIp(request), env)) {
      return new Response(JSON.stringify({ error: "rate limited, try later" }), {
        status: 429,
        headers: { "content-type": "application/json", ...corsHeaders(origin) }
      });
    }
    let body;
    try {
      body = await request.json();
    } catch {
      return new Response(JSON.stringify({ error: "invalid json" }), {
        status: 400,
        headers: { "content-type": "application/json", ...corsHeaders(origin) }
      });
    }
    const question = (body.question || "").toString().trim();
    let ctxItems = Array.isArray(body.context) ? body.context.slice(0, 8) : [];
    const kind = body.kind === "health" ? "health" : "pastor";
    if (!question) {
      return new Response(JSON.stringify({ error: "missing question" }), {
        status: 400,
        headers: { "content-type": "application/json", ...corsHeaders(origin) }
      });
    }
    ctxItems = ctxItems.filter((h) => h && typeof h === "object").map((h) => ({
      kind: h.kind === "health" ? "health" : "pastor",
      answer_zh: (h.answer_zh || "").toString().slice(0, 2e3),
      citations: Array.isArray(h.citations) ? h.citations.slice(0, 6) : []
    }));
    const sys = SYSTEM_PROMPT;
    const user = buildUserPrompt(question, ctxItems);
    const llmResp = await callLLM(env, sys, user);
    if (!llmResp.ok) {
      return new Response(
        JSON.stringify({ answer: HONEST_FALLBACK, flags: [llmResp.error], fallback: true }),
        { status: 200, headers: { "content-type": "application/json", ...corsHeaders(origin) } }
      );
    }
    const flags = postCheck(llmResp.text, ctxItems);
    if (flags.some((f) => f.startsWith("\u7591\u4F3CCUV\u7279\u5F81"))) {
      return new Response(
        JSON.stringify({ answer: HONEST_FALLBACK, flags, fallback: true }),
        { status: 200, headers: { "content-type": "application/json", ...corsHeaders(origin) } }
      );
    }
    return new Response(
      JSON.stringify({ answer: llmResp.text, flags, fallback: false }),
      { status: 200, headers: { "content-type": "application/json", ...corsHeaders(origin) } }
    );
  }
};
async function callLLM(env, system, user) {
  const base = (env.RAG_BASE_URL || "https://api.openai.com/v1").replace(/\/$/, "");
  const model = env.RAG_MODEL || "gpt-4o-mini";
  const key = env.RAG_API_KEY;
  const body = JSON.stringify({
    model,
    messages: [
      { role: "system", content: system },
      { role: "user", content: user }
    ],
    temperature: 0.2
  });
  try {
    const r = await fetch(base + "/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json"
      },
      body
    });
    if (!r.ok) {
      const txt = await r.text();
      return { ok: false, error: `LLM ${r.status}: ${txt.slice(0, 200)}` };
    }
    const d = await r.json();
    const text = d?.choices?.[0]?.message?.content ?? "";
    return { ok: true, text };
  } catch (e) {
    return { ok: false, error: `LLM call failed: ${e.message || e}` };
  }
}
__name(callLLM, "callLLM");
export {
  worker_default as default
};
//# sourceMappingURL=worker.js.map
