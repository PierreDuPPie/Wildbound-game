import {execFileSync} from 'node:child_process';
import {readFileSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const files=execFileSync('git',['ls-files','--cached','--others','--exclude-standard','-z'],{cwd:project,encoding:'utf8'}).split('\0');
const hash=createHash('sha256');
for(const file of [...new Set(files)].sort()){
  const absolute=path.join(project,file);
  if(!existsSync(absolute)||file.startsWith('scratch_')||!(/\.(gd|tscn|tres|json|gdshader|png|svg|jpg|wav|cfg|godot|html|mjs|ps1)$/.test(file)))continue;
  const data=readFileSync(absolute);
  hash.update(file+'\0');hash.update(data);hash.update('\0');
}
console.log(hash.digest('hex'));
