// _test_ocr_route.js —— 一次性验证 server.js 的 /api/ocr 路由逻辑（不调真 LLM）
// 用 mock 上游替代智谱 API：RAG_BASE_URL 指向本地 mock，OCR 请求打过来时
// 校验请求体（model / system prompt / image_url content 结构）再返回转录文本。
// v59 新增：验证默认使用免费视觉模型链、以及 429「余额不足」时自动切换模型。
const http = require('http');
const { spawn } = require('child_process');

let seenBodies = [];
let requestCount = 0;
let failMode = null; // null | '500' | 'empty' | 'badjson' | '429-once' | '429-all'

function reset() {
  seenBodies = [];
  requestCount = 0;
  failMode = null;
}

const OCR_TEXT = '首都医科大学三博脑科医院\n诊断证明\n诊断：孤立性纤维性肿瘤';

const mockUpstream = http.createServer((req, res) => {
  let b = '';
  req.on('data', (c) => (b += c));
  req.on('end', () => {
    let parsed = null;
    try { parsed = JSON.parse(b); } catch (_) {}
    seenBodies.push(parsed);
    requestCount += 1;

    const balanceFailed = failMode === '429-all' ||
      (failMode === '429-once' && requestCount === 1);
    if (balanceFailed) {
      res.writeHead(429, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({
        error: { code: '1113', message: '余额不足或无可用资源包,请充值。' },
      }));
    }
    if (failMode === '500') {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      return res.end('upstream boom');
    }
    if (failMode === 'badjson') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end('{not json');
    }
    const text = failMode === 'empty' ? '' : OCR_TEXT;
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ choices: [{ message: { content: text } }] }));
  });
});

function post(port, path, obj) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(obj);
    const req = http.request(
      { host: '127.0.0.1', port, path, method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } },
      (res) => {
        let b = '';
        res.on('data', (c) => (b += c));
        res.on('end', () => {
          let j = null;
          try { j = JSON.parse(b); } catch (_) {}
          resolve({ status: res.statusCode, body: j, raw: b });
        });
      }
    );
    req.on('error', reject);
    req.end(data);
  });
}

function postRaw(port, path, raw) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      { host: '127.0.0.1', port, path, method: 'POST', headers: { 'Content-Type': 'application/json' } },
      (res) => {
        let b = '';
        res.on('data', (c) => (b += c));
        res.on('end', () => resolve({ status: res.statusCode, raw: b }));
      }
    );
    req.on('error', reject);
    req.end(raw);
  });
}

const modelsSeen = () => seenBodies.filter(Boolean).map((b) => b.model);

(async () => {
  await new Promise((r) => mockUpstream.listen(0, r));
  const mockPort = mockUpstream.address().port;

  const env = {
    ...process.env,
    RAG_API_KEY: 'test-key',
    RAG_BASE_URL: `http://127.0.0.1:${mockPort}/api/paas/v4`,
    RAG_LIMIT: '1000',
  };
  const child = spawn(process.execPath, ['server.js'], { env, stdio: 'pipe' });
  let srvOut = '';
  child.stdout.on('data', (d) => (srvOut += d));
  child.stderr.on('data', (d) => (srvOut += d));
  await new Promise((r) => setTimeout(r, 800));
  const port = 9000;

  const results = [];
  const check = (name, cond, extra) => {
    results.push([name, !!cond, extra || '']);
    console.log((cond ? 'PASS' : 'FAIL') + ' | ' + name + (cond ? '' : ' | ' + extra));
  };

  try {
    // 1) 正常 OCR：base64（非 dataURL）→ 应构造 dataURL 并返回转录文本
    reset();
    let r = await post(port, '/api/ocr', { image: 'QUJD', mime: 'image/jpeg' });
    check('正常请求返回 200 + ok', r.status === 200 && r.body && r.body.ok === true, JSON.stringify(r.body));
    check('返回转录文本', r.body && r.body.text.includes('三博脑科'), JSON.stringify(r.body));
    check('默认首选实测可用的免费模型 glm-4.1v-thinking-flash', seenBodies[0] && seenBodies[0].model === 'glm-4.1v-thinking-flash', modelsSeen().join(','));
    check('响应回带实际命中模型', r.body && r.body.model === 'glm-4.1v-thinking-flash', r.body && r.body.model);
    check('不再使用付费 glm-4v-plus', !modelsSeen().includes('glm-4v-plus'), modelsSeen().join(','));
    check('system prompt 含只转录铁律', seenBodies[0] && seenBodies[0].messages[0].content.includes('不得输出任何诊断'), '');
    check('content 含 image_url+text', seenBodies[0] && seenBodies[0].messages[1].content.some((c) => c.type === 'image_url') && seenBodies[0].messages[1].content.some((c) => c.type === 'text'), '');
    check('image_url 为 dataURL', seenBodies[0] && seenBodies[0].messages[1].content.find((c) => c.type === 'image_url').image_url.url.startsWith('data:image/jpeg;base64,'), '');

    // 2) 已是 dataURL 的图片不重复包装
    reset();
    r = await post(port, '/api/ocr', { image: 'data:image/png;base64,QUJD' });
    check('dataURL 原样透传', seenBodies[0] && seenBodies[0].messages[1].content.find((c) => c.type === 'image_url').image_url.url === 'data:image/png;base64,QUJD', '');

    // 3) 缺 image → 400
    reset();
    r = await post(port, '/api/ocr', { mime: 'image/jpeg' });
    check('缺 image 返回 400', r.status === 400 && r.body.error.includes('missing image'), JSON.stringify(r.body));

    // 4) 非法 mime → 400
    reset();
    r = await post(port, '/api/ocr', { image: 'QUJD', mime: 'application/pdf' });
    check('非法 mime 返回 400', r.status === 400, JSON.stringify(r.body));

    // 5) 上游 429「余额不足」只出现一次 → 自动切下一个免费模型并成功
    reset();
    failMode = '429-once';
    r = await post(port, '/api/ocr', { image: 'QUJD', mime: 'image/jpeg' });
    check('429 余额不足自动 fallback 后成功', r.status === 200 && r.body && r.body.ok === true, JSON.stringify(r.body));
    check('fallback 次序 = 4.1v-thinking-flash → 4.6v-flash',
      modelsSeen().length === 2 && modelsSeen()[0] === 'glm-4.1v-thinking-flash' && modelsSeen()[1] === 'glm-4.6v-flash',
      modelsSeen().join(','));
    check('fallback 返回文本来自第二个模型', r.body && r.body.model === 'glm-4.6v-flash' && r.body.text.includes('三博脑科'), JSON.stringify(r.body));

    // 6) 三个免费模型全部 429 → 502，且确实挨个试过
    reset();
    failMode = '429-all';
    r = await post(port, '/api/ocr', { image: 'QUJD', mime: 'image/jpeg' });
    check('全部模型余额不足 → 502 ok:false', r.status === 502 && r.body.ok === false, JSON.stringify(r.body));
    check('三个免费模型都被尝试过', modelsSeen().length === 3 && modelsSeen().join(',') === 'glm-4.1v-thinking-flash,glm-4.6v-flash,glm-4v-flash', modelsSeen().join(','));

    // 7) 上游 500 → 502 且 ok:false
    reset();
    failMode = '500';
    r = await post(port, '/api/ocr', { image: 'QUJD', mime: 'image/jpeg' });
    check('上游 500 → 502 ok:false', r.status === 502 && r.body.ok === false, JSON.stringify(r.body));

    // 8) 上游空文本 → 502
    reset();
    failMode = 'empty';
    r = await post(port, '/api/ocr', { image: 'QUJD', mime: 'image/jpeg' });
    check('空转录 → 502', r.status === 502 && r.body.error.includes('empty'), JSON.stringify(r.body));

    // 9) 上游坏 JSON → 502（不崩溃）
    reset();
    failMode = 'badjson';
    r = await post(port, '/api/ocr', { image: 'QUJD', mime: 'image/jpeg' });
    check('坏 JSON 上游 → 502', r.status === 502 && r.body.ok === false, JSON.stringify(r.body));
    reset();

    // 10) RAG 路由不受影响（缺 question → 400）
    r = await post(port, '/api/rag', {});
    check('RAG 路由缺 question 仍 400', r.status === 400, JSON.stringify(r.body));

    // 11) 无效 JSON body → 400
    r = await postRaw(port, '/api/ocr', 'not-json');
    check('无效 JSON → 400', r.status === 400, r.raw);

    // 12) GET / 健康检查
    const getRes = await new Promise((resolve, reject) => {
      const req = http.request({ host: '127.0.0.1', port, path: '/', method: 'GET' }, (res) => {
        let b = '';
        res.on('data', (c) => (b += c));
        res.on('end', () => resolve({ status: res.statusCode, body: b }));
      });
      req.on('error', reject);
      req.end();
    });
    check('GET / 服务正常', getRes.status === 200 && getRes.body.includes('bible-rag-proxy'), getRes.body);

    check('服务进程未退出（unhandledRejection 兜底）', child.exitCode === null, 'exitCode=' + child.exitCode);
  } catch (e) {
    console.log('FAIL | 异常: ' + (e && e.message));
    results.push(['exception', false, String(e && e.message)]);
  } finally {
    child.kill();
    mockUpstream.close();
  }

  const failed = results.filter((r) => !r[1]).length;
  console.log(`\nRESULT: ${results.length - failed}/${results.length} passed`);
  process.exit(failed ? 1 : 0);
})();
