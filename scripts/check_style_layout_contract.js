#!/usr/bin/env node
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
// Compare all path commands to the exact snapshot, not a copied geometry algorithm.
for(const name of ['ConnectedPillShape','AnchoredMenuPillShape']) {
 const rel='Titonium/Shared/'+name+'.qml';
 const expected=JSON.parse(fs.readFileSync(path.join(root,'tests/fixtures/style-layout-paths.json'),'utf8')).sha256[name];
 const current=fs.readFileSync(path.join(root,rel),'utf8');
 const commands=s=>s.slice(s.indexOf('            pathHints:'));
 assert.equal(crypto.createHash('sha256').update(commands(current)).digest('hex'),expected,name+' path topology and geometry must stay identical');
 assert.ok(current.includes('Theme.chassis'),'chassis consumes design style treatment');
}
console.log('PASS unchanged Connected path commands with design style paint');
