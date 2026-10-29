import { readFileSync, writeFileSync, existsSync, readdirSync, statSync, unlinkSync } from 'node:fs';
import { gzipSync, gunzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dist = path.resolve(process.argv[2] ?? path.join(project, '../sites/wildbound-first-expedition/dist'));
const enginePath = path.join(dist, 'index.wasm');
let engine;
if (existsSync(enginePath)) {
  engine = readFileSync(enginePath);
  const compressed = gzipSync(engine, { level: 9, mtime: 0 });
  if (!gunzipSync(compressed).equals(engine)) throw new Error('Engine compression failed verification');
  writeFileSync(enginePath + '.gz', compressed);
  unlinkSync(enginePath);
} else engine = gunzipSync(readFileSync(enginePath + '.gz'));
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const pack = readFileSync(path.join(dist, 'index.pck'));
const info = {
  version: '0.6.1-playtest',
  source_commit: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: project, encoding: 'utf8' }).trim(),
  source_dirty: Boolean(execFileSync('git', ['status', '--porcelain'], { cwd: project, encoding: 'utf8' }).trim()),
  engine_version: '4.7.2.stable',
  engine_sha256: hash(engine), game_pack_sha256: hash(pack),
  game_pack_bytes: pack.length, engine_gzip_bytes: statSync(enginePath + '.gz').size,
};
writeFileSync(path.join(dist, 'build-info.json'), JSON.stringify(info, null, 2) + '\n');
writeFileSync(path.join(dist, 'manifest.webmanifest'), JSON.stringify({
  name:'WILDBOUND - First Expedition', short_name:'WILDBOUND', start_url:'./', scope:'./',
  display:'standalone', orientation:'any', background_color:'#172d27', theme_color:'#172d27',
  icons:[{src:'wildbound.svg',sizes:'any',type:'image/svg+xml'}],
}, null, 2) + '\n');
writeFileSync(path.join(dist, 'wildbound.svg'), '<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192"><rect width="192" height="192" rx="32" fill="#172d27"/><path d="M34 48l26 98 36-68 36 68 26-98" fill="none" stroke="#dfbd75" stroke-width="13"/></svg>\n');
writeFileSync(path.join(dist, '.nojekyll'), '');
writeFileSync(path.join(dist, 'feedback.html'), readFileSync(path.join(project, 'web/feedback.html')));
for (const name of readdirSync(dist)) {
  if (statSync(path.join(dist, name)).size > 25 * 1024 * 1024) throw new Error(`Asset exceeds static host limit: ${name}`);
}
console.log(JSON.stringify(info));
