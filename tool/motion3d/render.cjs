// 3D 动作示范离线渲染：起本地静态服务 → 无头 Chrome 打开 scene.html → 逐帧截透明 PNG。
// 用法：node tool/motion3d/render.cjs <exercise> <outDir> [fps=30] [size=640] [still=秒]
// 依赖装在 out/motion3d/node_modules（three@0.170.0、playwright-core@1.48.2），模型是 Quaternius
// Universal Base Characters（CC0），放在 out/models/quaternius-ubc（不进仓库）。环境变量 SCENE_QUERY 追加页面参数（如 yaw=55、shadow=0）。
const http = require('http');
const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '../..');
const { chromium } = require(path.join(ROOT, 'out/motion3d/node_modules/playwright-core'));
const [ex = 'squat', outDir = 'out/motion3d/frames', fps = '30', size = '640', still] = process.argv.slice(2);
const extra = process.env.SCENE_QUERY ? '&' + process.env.SCENE_QUERY : '';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.gltf': 'model/gltf+json', '.bin': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const file = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(ROOT) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
server.listen(0, async () => {
  const port = server.address().port;
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true, args: ['--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: +size, height: +size }, deviceScaleFactor: 1 });
  page.on('console', m => console.log('[page]', m.text()));
  page.on('pageerror', e => console.log('[error]', e.message));
  page.on('crash', () => console.log('[crash]'));
  page.on('response', r => r.status() >= 400 && console.log('[http]', r.status(), r.url()));
  page.on('requestfailed', r => console.log('[failed]', r.url()));
  await page.goto(`http://127.0.0.1:${port}/tool/motion3d/scene.html?ex=${ex}&size=${size}${extra}`);
  await page.waitForFunction(() => window.ready === true, null, { timeout: 30000 });
  fs.mkdirSync(outDir, { recursive: true });
  const period = await page.evaluate(() => window.period);
  const times = still !== undefined ? [+still] : Array.from({ length: Math.round(period * fps) }, (_, i) => i / fps);
  for (let i = 0; i < times.length; i++) {
    await page.evaluate(t => window.renderAt(t), times[i]);
    await page.screenshot({ path: path.join(outDir, String(i).padStart(4, '0') + '.png'), omitBackground: true });
  }
  fs.writeFileSync(path.join(outDir, 'meta.json'), JSON.stringify(await page.evaluate(() => window.meta)));
  console.log('frames', times.length, 'period', period);
  await browser.close();
  server.close();
});
