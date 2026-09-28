// Filmstrip shooter (durance-design skill). Real installed Chrome over CDP, scroll in
// steps of 0.85 x viewport height, one JPEG per stop: <outDir>/<prefix>-NN-y<scrollY>.jpg.
// Shoot the reference and ours with IDENTICAL arguments so frame N lines up with frame N.
//
//   node shoot-page.mjs <url> <outDir> <prefix> 1440 900      # desktop
//   node shoot-page.mjs <url> <outDir> <prefix>m 390 844 1    # mobile, DPR 2
//
// Why the installed Chrome and not Chrome for Testing: the downloaded binary cannot load
// localhost on macOS (Local Network privacy gate, no way to approve it headless) and hangs
// instead of failing. Override the binary with CHROME_BIN when not on macOS.
import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';

const [,, url, outDir, prefix = 'shot', wStr = '1440', hStr = '900', mobile = '0'] = process.argv;
const W = +wStr, H = +hStr, PORT = 9345 + Math.floor(Math.random()*200);
mkdirSync(outDir, { recursive: true });
const CHROME = process.env.CHROME_BIN || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const chrome = spawn(CHROME,
  ['--headless=new', `--remote-debugging-port=${PORT}`, `--window-size=${W},${H}`, '--no-first-run', '--no-default-browser-check',
   `--user-data-dir=/tmp/cdp-profile-${PORT}`, '--hide-scrollbars', '--disable-gpu-vsync', 'about:blank'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
let target;
for (let i = 0; i < 60; i++) { try { const r = await fetch(`http://127.0.0.1:${PORT}/json`); const l = await r.json(); target = l.find(t => t.type === 'page'); if (target) break; } catch {} await sleep(250); }
if (!target) { chrome.kill(); throw new Error('no chrome target'); }
const ws = new WebSocket(target.webSocketDebuggerUrl); await new Promise(r => ws.addEventListener('open', r));
let id = 0; const pend = new Map();
ws.addEventListener('message', m => { const d = JSON.parse(m.data); if (d.id && pend.has(d.id)) { pend.get(d.id)(d); pend.delete(d.id); } });
const send = (method, params = {}) => new Promise((res, rej) => { const i = ++id; pend.set(i, d => d.error ? rej(new Error(method + ': ' + JSON.stringify(d.error))) : res(d.result)); ws.send(JSON.stringify({ id: i, method, params })); });
await send('Page.enable'); await send('Runtime.enable');
if (mobile === '1') await send('Emulation.setDeviceMetricsOverride', { width: W, height: H, deviceScaleFactor: 2, mobile: true });
await send('Page.navigate', { url }); await sleep(6000);
const ev = async expr => (await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })).result.value;
const total = await ev('document.documentElement.scrollHeight');
console.log('scrollHeight', total);
let n = 0;
for (let y = 0; y < total && n < 40; y += Math.round(H * 0.85)) {
  await ev(`window.scrollTo({top:${y},behavior:'instant'})`); await sleep(1400);
  const shot = await send('Page.captureScreenshot', { format: 'jpeg', quality: 80 });
  writeFileSync(`${outDir}/${prefix}-${String(n).padStart(2,'0')}-y${y}.jpg`, Buffer.from(shot.data, 'base64'));
  n++;
}
console.log('shots', n);
ws.close(); chrome.kill();
