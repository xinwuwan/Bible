// rag-worker/test_local.mjs
// 本地验证脚本：用 Node22 全局 fetch/Request/Response 直接驱动 worker.js 的 fetch 处理器，
// 真实调用智谱 glm-4-flash（key 来自环境变量），验证检索→审计→限流→CORS 全链路。
// 运行：RAG_API_KEY=xxx node test_local.mjs

import worker from './worker.js';

const ENV = {
  RAG_API_KEY: process.env.RAG_API_KEY || '',
  RAG_BASE_URL: process.env.RAG_BASE_URL || 'https://open.bigmodel.cn/api/paas/v4',
  RAG_MODEL: process.env.RAG_MODEL || 'glm-4-flash',
};

// 模拟 App 端离线检索后给出的 top-K context（结构对齐 qa_faq.json / health_faq.json）
const CONTEXT = {
  '兽的印记': [
    { kind: 'pastor', answer_zh: '**兽的印记是末世大欺骗的标记，凡接受者将在主再来时面临审判。**', citations: [
      { source_type: 'BIBLE', source_id: 'KJV-REV13:16', ref: 'KJV Revelation 13:16', snippet: 'And he causeth all... to receive a mark in their right hand, or in their foreheads' },
      { source_type: 'BIBLE', source_id: 'KJV-REV14:9', ref: 'KJV Revelation 14:9', snippet: 'If any man worship the beast... the same shall drink... the wrath of God' },
    ] },
  ],
  '头痛': [
    { kind: 'health', answer_zh: '**头痛时先休息、补水，记录诱因；剧烈或伴随神经症状须立即就医。**', citations: [
      { source_type: 'BIBLE', source_id: 'EGW', ref: '诗篇 103:3', snippet: 'He healeth all thy diseases' },
    ] },
  ],
  '拜祖先': [
    { kind: 'pastor', answer_zh: '**信徒当单单敬拜真神，不参与拜偶像与交鬼的仪式。**', citations: [
      { source_type: 'BIBLE', source_id: 'KJV-EXO20:3', ref: 'KJV Exodus 20:3', snippet: 'Thou shalt have no other gods before me' },
    ] },
  ],
};

async function callRag(question, kind, context) {
  const payload = { question, kind, context };
  const req = new Request('https://local.test/api/rag', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: 'https://xinwuwan.github.io' },
    body: JSON.stringify(payload),
  });
  const resp = await worker.fetch(req, ENV, {});
  const cors = resp.headers.get('Access-Control-Allow-Origin');
  let data = null;
  try { data = await resp.json(); } catch {}
  return { status: resp.status, cors, data };
}

const CASES = [
  ['牧师·兽的印记', 'pastor', '兽的印记是什么，666 是什么意思', CONTEXT['兽的印记']],
  ['健康·头痛', 'health', '经常头痛偏头痛怎么办', CONTEXT['头痛']],
  ['牧师·拜祖先（预期触发越界引用审计）', 'pastor', '基督徒可以拜祖先、烧纸钱吗', CONTEXT['拜祖先']],
  ['边界·股票（预期诚实拒绝）', 'pastor', '推荐一支明天会涨的股票', []],
];

let pass = 0;
for (const [name, kind, q, ctx] of CASES) {
  console.log(`\n=== ${name} ===`);
  console.log(`问: ${q}`);
  const r = await callRag(q, kind, ctx);
  console.log(`状态: ${r.status} | CORS: ${r.cors ?? '(无)'}`);
  if (r.data) {
    console.log(`fallback: ${r.data.fallback}`);
    console.log(`回答: ${(r.data.answer || '').slice(0, 200)}`);
    if (r.data.flags && r.data.flags.length) console.log(`合规告警: ${JSON.stringify(r.data.flags)}`);
  }
  if (r.status === 200) pass++;
}

// 限流测试：同 IP 连续请求，超过 RAG_LIMIT 应返回 429（用低阈值避免大量真实调用）
console.log('\n=== 限流压测（同 IP 连续请求，RAG_LIMIT=3） ===');
let limited = 0;
const stressEnv = { ...ENV, RAG_LIMIT: '3' };
for (let i = 0; i < 5; i++) {
  const req = new Request('https://local.test/api/rag', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ question: 'test', kind: 'pastor', context: [] }),
  });
  const resp = await worker.fetch(req, stressEnv, {});
  if (resp.status === 429) limited++;
}
console.log(`触发 429 次数: ${limited}（预期>=1）`);

console.log(`\n[本地验证] HTTP 200 用例: ${pass}/${CASES.length}`);
