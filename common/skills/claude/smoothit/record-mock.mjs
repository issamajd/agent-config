// record-mock.mjs: record an HTML motion mock with the same gestures every time.
//
//   node record-mock.mjs <mock.html> <out-dir> [--viewport 402x874]
//
// Run it from a directory where `playwright` or `@playwright/test` is installed
// (a web app in the repo usually has it); nothing is installed for you.
//
// The mock marks its touch targets with `data-target`, in order (the tabs of a
// tab bar, the stops of a slider). Two or more are needed. The gestures, the
// ones motion.md asks for, using targets T0, T1 and the last one, Tn:
//   1 tap T1
//   2 press and hold T0 for 1.5 s
//   3 slow drag T0 -> Tn over 1.6 s
//   4 fast flick Tn -> T0 in 150 ms
//   5 interrupt: drag T0 toward the middle of T1 and Tn, reverse back to T1,
//     release, then tap Tn 120 ms later while it settles
//
// Writes video.webm, timeline.tsv (start, end, label per gesture, seconds from
// the start of the video, for motion-report.sh --timeline) and prints the
// timeline. A translucent red dot drawn by the recorder, not the mock, shows
// where the pointer is while it is down.
//
// Playwright draws video at CSS-pixel scale whatever the device scale factor,
// so this records at 1x; crop and upscale in motion-report.sh. Drags follow
// the wall clock, so each takes the time it asks for however slow a step is.
import { createRequire } from 'node:module';
import { mkdirSync, readdirSync, renameSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const [mock, out] = args;
if (!mock || !out) {
  console.error('usage: node record-mock.mjs <mock.html> <out-dir> [--viewport WxH]');
  process.exit(2);
}
const vpArg = args.indexOf('--viewport');
const [W, H] = (vpArg > -1 ? args[vpArg + 1] : '402x874').split('x').map(Number);

const require = createRequire(path.join(process.cwd(), 'package.json'));
let chromium;
for (const name of ['playwright', '@playwright/test']) {
  try { ({ chromium } = require(name)); break; } catch {}
}
if (!chromium) {
  console.error('record-mock: run this from a directory with playwright or @playwright/test installed');
  process.exit(2);
}

mkdirSync(out, { recursive: true });
const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: W, height: H },
  deviceScaleFactor: 1,
  recordVideo: { dir: out, size: { width: W, height: H } },
});
const t0 = Date.now();
const page = await context.newPage();
await page.addInitScript(() => {
  addEventListener('DOMContentLoaded', () => {
    const dot = document.createElement('div');
    dot.style.cssText = 'position:fixed;width:34px;height:34px;margin:-17px 0 0 -17px;border-radius:50%;background:rgba(255,40,40,.35);border:2px solid rgba(255,40,40,.8);pointer-events:none;z-index:2147483647;display:none';
    document.body.appendChild(dot);
    addEventListener('pointerdown', (e) => { dot.style.display = 'block'; dot.style.left = e.clientX + 'px'; dot.style.top = e.clientY + 'px'; }, true);
    addEventListener('pointermove', (e) => { dot.style.left = e.clientX + 'px'; dot.style.top = e.clientY + 'px'; }, true);
    addEventListener('pointerup', () => { dot.style.display = 'none'; }, true);
  });
});
await page.goto('file://' + path.resolve(mock));
await page.waitForTimeout(1500);

const targets = await page.$$eval('[data-target]', (els) =>
  els.map((el) => { const r = el.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; }));
if (targets.length < 2) {
  console.error('record-mock: the mock needs two or more [data-target] elements');
  await context.close(); await browser.close();
  process.exit(2);
}
const T0 = targets[0], T1 = targets[1], Tn = targets[targets.length - 1];
const mid = { x: (T1.x + Tn.x) / 2, y: (T1.y + Tn.y) / 2 };

const now = () => (Date.now() - t0) / 1000;
const rows = [];
async function gesture(label, run) {
  const start = now();
  await run();
  rows.push([start.toFixed(2), now().toFixed(2), label]);
  await page.waitForTimeout(1300);
}
const m = page.mouse;
async function drag(from, to, ms) {
  const start = Date.now();
  for (;;) {
    const k = Math.min(1, (Date.now() - start) / ms);
    await m.move(from.x + (to.x - from.x) * k, from.y + (to.y - from.y) * k);
    if (k === 1) break;
    await page.waitForTimeout(8);
  }
}

await gesture('1 tap T1', async () => { await m.move(T1.x, T1.y); await m.down(); await page.waitForTimeout(90); await m.up(); });
await gesture('2 hold T0 1.5 s', async () => { await m.move(T0.x, T0.y); await m.down(); await page.waitForTimeout(1500); await m.up(); });
await gesture('3 slow drag T0 -> Tn 1.6 s', async () => { await m.move(T0.x, T0.y); await m.down(); await drag(T0, Tn, 1600); await m.up(); });
await gesture('4 fast flick Tn -> T0 150 ms', async () => { await m.move(Tn.x, Tn.y); await m.down(); await drag(Tn, T0, 150); await m.up(); });
await gesture('5 interrupt: drag, reverse to T1, release, tap Tn while settling', async () => {
  await m.move(T0.x, T0.y); await m.down();
  await drag(T0, mid, 450); await drag(mid, T1, 250); await m.up();
  await page.waitForTimeout(120);
  await m.move(Tn.x, Tn.y); await m.down(); await page.waitForTimeout(80); await m.up();
});
await page.waitForTimeout(700);

await context.close();
await browser.close();
const webm = readdirSync(out).find((f) => f.endsWith('.webm') && f !== 'video.webm');
renameSync(path.join(out, webm), path.join(out, 'video.webm'));
const tsv = rows.map((r) => r.join('\t')).join('\n') + '\n';
writeFileSync(path.join(out, 'timeline.tsv'), tsv);
process.stdout.write(tsv);
