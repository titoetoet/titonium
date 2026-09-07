const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const rules = vm.createContext({});
vm.runInContext(fs.readFileSync('Titonium/Services/Audio/AudioRules.js','utf8').replace(/^\.pragma library\s*/, ''), rules);
assert.equal(typeof rules.captureSessions, 'function');
const microphone = {id:7,ready:true,isStream:true,audio:{muted:false},properties:{'media.class':'Stream/Input/Audio','object.serial':'70'},description:'Meeting'};
let state = rules.captureSessions([], [microphone], 100);
assert.equal(state.length,1); assert.equal(state[0].startedAt,100);
assert.equal(rules.captureSessions(state,[microphone],200)[0].startedAt,100);
assert.equal(rules.captureSessions(state,[{...microphone,properties:{...microphone.properties,'object.serial':'71'}}],200)[0].startedAt,200);
for (const props of [{'stream.monitor':'true'},{'stream.capture.sink':true},{'media.category':'Monitor'}])
 assert.equal(rules.captureSessions([], [{...microphone,properties:{...microphone.properties,...props}}],100).length,0);
assert.equal(rules.captureSessions(state,[],300).length,0);
console.log('PASS microphone capture sessions exclude output/peak monitors and preserve identity');
