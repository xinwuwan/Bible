// _test_ocr_route.js —— 一次性验证 server.js 的 /api/ocr 路由逻辑（不调真 LLM）
// 用 mock 上游替代智谱 API：RAG_BASE_URL 指向本地 mock，OCR 请求打过来时
// 校验请求体（model / system prompt / image_url content 结构）再返回转录文本。
const http = require('http');
const { spawn } = require('child_process');

let seenBody = null;
let failMode = null; // null | '500' | 'empty' | 'badjson'

const mockUpstream = http.createServer((req, res) => {
  let b = '';
  req.on('data', (c) => (b += c));
  req.on('end', () => {
    seenBody = JSON.parse(b);
    if (failMode === '500') {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      return res.end('upstream boom');
    }
    if (failMode === 'badjson') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end('{not json');
    }
    const text = failMode === 'empty' ? '' : '首都医科大学三博脑科医院\n诊断证明\n诊断：孤立性纤维性肿瘤';
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
    seenBody = null;
    let r = await post(port, '/api/ocr', { image: 'QUJD', mime: 'image/jpeg' });
    check('正常请求返回 200 + ok', r.status === 200 && r.body && r.body.ok === true, JSON.stringify(r.body));
    check('返回转录文本', r.body && r.body.text.includes('三博脑科'), JSON.stringify(r.body));
    check('上游 model=glm-4v-plus', seenBody && seenBody.model === 'glm-4v-plus', seenBody && seenBody.model);
    check('system prompt 含只转录铁律', seenBody && seenBody.messages[0].content.includes('不得输出任何诊断'), '');
    check('content 含 image_url+text', seenBody && seenBody.messages[1].content.some((c) => c.type === 'image_url') && seenBody.messages[1].content.some((c) => c.type === 'text'), '');
    check('image_url 为 dataURL', seenBody && seenBody.messages[1].content.find((c) => c.type === 'image_url').image_url.url.startsWith('data:image/jpeg;base64,'), '');

    // 2) 已是 dataURL 的图片不重复包装
    seenBody = null;
    r = await post(port, '/api/ocr', { image: 'data:image/png;base64,QUJD' });
    check('dataURL 原样透传', seenBody && seenBody.messages[1].content.find((c) => c.type === 'image_url').image_url.url === 'data:image/png;base64,QUJD', '');

    // 3) 缺 image → 400
    r = await post(port, '/api/ocr', { mime: 'image/jpeg' });
    check('缺 image 返回 400', r.status === 400 && r.body.error.includes('missing image'), JSON.stringify(r.body));

    // 4) 非法 mime → 400
    r = await post(port, '/api/ocr', { image: 'QUJD', mime: 'application/pdf' });
    check('非法 mime 返回 400', r.status === 400, JSON.stringify(r.body));

    // 5) 上游 500 → 502 且 ok:false
    failMode = '500';
    r = await post(port, '/api/ocr', { image: 'QUJD', mime: 'image/jpeg' });
    check('上游 500 → 502 ok:false', r.status === 502 && r.body.ok === false, JSON.stringify(r.body));

    // 6) 上游空文本 → 502
    failMode = 'empty';
    r = await post(port, '/api/ocr', { image: 'QUJD', mime: 'image/jpeg' });
    check('空转录 → 502', r.status === 502 && r.body.error.includes('empty'), JSON.stringify(r.body));

    // 7) 上游坏 JSON → 502（不崩溃）
    failMode = 'badjson';
    r = await post(port, '/api/ocr', { image: 'QUJD', mime: 'image/jpeg' });
    check('坏 JSON 上游 → 502', r.status === 502 && r.body.ok === false, JSON.stringify(r.body));
    failMode = null;

    // 8) RAG 路由不受影响（缺 question → 400）
    r = await post(port, '/api/rag', {});
    check('RAG 路由缺 question 仍 400', r.status === 400, JSON.stringify(r.body));

    // 9) 无效 JSON body → 400
    r = await postRaw(port, '/api/ocr', 'not-json');
    check('无效 JSON → 400', r.status === 400, r.raw);

    // 10) GET / 健康检查
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
