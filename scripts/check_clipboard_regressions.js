#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const servicePath = name => path.join(__dirname, '..', 'Titonium/Services/Clipboard', name);
const h = vm.createContext({});
vm.runInContext(fs.readFileSync(servicePath('ClipboardHistory.js'), 'utf8').replace(/^\.pragma library\s*/, ''), h);
const a = h.createImageRecord('/cache/a.png', 10, 10, 30, '', 1);
const b = h.createImageRecord('/cache/b.png', 10, 10, 30, '', 2);
const cases = {
 'same dimensions survive reload': () => assert.equal(h.normalizeDocument({schemaVersion: 1, items: [a, b]}).length, 2),
 'text matching image label stays text': () => { const x = h.record([a], a.text, 3); assert.equal(x.length, 2); assert.equal(x[0].kind, 'plain'); },
 'missing digests do not merge images': () => assert.equal(h.recordImage([a], b.imagePath, 10, 10, 30, '', 2).length, 2),
 'UTF-8 oversized text rejected': () => assert.equal(h.record([], '😀'.repeat(17000), 1).length, 0),
 'oversized persisted text rejected': () => assert.equal(h.normalizeDocument({schemaVersion: 1, items: [h.createRecord('x'.repeat(65537), 1)]}).length, 0),
 'serialized history bounded including escaped bytes': () => { let x = []; for (let i=0;i<60;i++) x = h.record(x, String(i)+'\u0000'.repeat(60000), i); assert.ok(Buffer.byteLength(JSON.stringify({schemaVersion: 1, items: x})) <= 1048576); },
 'cleanup retains referenced paths': () => assert.deepEqual(Array.from(h.removedImagePaths([a,b], [a])), [b.imagePath]),
};
let failed=0;
for (const [name,test] of Object.entries(cases)) { try {test(); console.log('PASS '+name);} catch(e) {failed++; console.error('FAIL '+name+': '+e.message);} }
process.exitCode=failed ? 1 : 0;

// Exercise actual service functions without constructing QML or touching the clipboard.
const qml = fs.readFileSync(servicePath('ClipboardService.qml'), 'utf8');
function serviceFunction(name) {
 const start = qml.indexOf('    function '+name+'(');
 assert.ok(start >= 0, 'service function '+name+' exists');
 const open = qml.indexOf('{', start); let level=1, end=open+1;
 for (; level && end<qml.length; end++) { if(qml[end]==='{') level++; if(qml[end]==='}') level--; }
 return qml.slice(start,end).replace(/:\s*(string|bool|void|int)\b/g, '');
}
try {
 const state = {items: [], available:true, error:'', writing:false, dirty:false, retiredPaths:[], cleanupPaths:[], runtimePath:'/tmp/unused', ioScript:'/tmp/unused'};
 const sandbox = vm.createContext({root:state, ClipboardHistory:h, historyFile:{setText:()=>{}}, Logger:{error:()=>{}}, copyImageProcess:{running:true,command:[]}, cleanupProcess:{running:false,command:[]}});
 for (const name of ['copyImage','finishImageCopy','persist','finishSave','commitItems','startCleanup']) {vm.runInContext(serviceFunction(name), sandbox); state[name]=sandbox[name];}
 assert.equal(state.copyImage('/tmp/fake.png'),false,'busy copy rejected');
 state.finishImageCopy(1); assert.equal(state.available,false); assert.equal(state.error,'clipboard.error.unavailable');
 state.finishImageCopy(0); assert.equal(state.available,true); assert.equal(state.error,'');
 state.items=[a]; state.commitItems([]); assert.equal(sandbox.cleanupProcess.running,false,'no delete before save');
 state.finishSave(false,'fake failure'); assert.equal(sandbox.cleanupProcess.running,false,'no delete on save failure');
 state.persist(); state.finishSave(true,''); assert.equal(sandbox.cleanupProcess.running,true,'delete after successful save');
 const snapshots=[]; sandbox.historyFile.setText=value=>snapshots.push(JSON.parse(value));
 state.items=[]; state.writing=false; state.commitItems([a]); state.commitItems([b]);
 state.finishSave(false,'fake first write failure');
 assert.equal(snapshots.length,2,'newer pending snapshot is submitted after prior save failure');
 assert.equal(snapshots[1].items[0].imagePath,b.imagePath);
 console.log('PASS service busy/failure and save-gated cleanup');
} catch(e) {process.exitCode=1; console.error('FAIL service lifecycle: '+e.message);}
