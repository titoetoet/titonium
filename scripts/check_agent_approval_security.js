#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const base = path.join(__dirname, '..', 'Titonium/Services/AgentApproval');
const rules = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(base, 'ApprovalRules.js'), 'utf8').replace(/^\.pragma library\s*/, ''), rules);
const service = fs.readFileSync(path.join(base, 'AgentApprovalService.qml'), 'utf8');
const chat = (id, threadId) => rules.normalize({source:'chatgpt',requestId:id,method:'item/commandExecution/requestApproval',params:{threadId,command:'echo fixture',cwd:'/same/repo'}});
const agy = (id, conversationId) => rules.normalize({source:'antigravity',requestId:id,conversationId,toolCall:{name:'run_command',args:{CommandLine:'echo fixture',Cwd:'/same/repo'}}});
function fixture() {
 const root={pending:[],clients:{},sessionGrants:{},sessionGrantOrder:[],popupScreenNameFor:()=>'',syncCenterAttention(){},updatePopupScreenAfterRemoval(){},persistGrants(){}};
 root.attentionCalls=[];
 const context=vm.createContext({root,ApprovalRules:rules,I18n:{tr:key=>key},CenterAttentionService:{
  clear:key=>root.attentionCalls.push({type:'clear',key}),
  publish:event=>root.attentionCalls.push({type:'publish',key:event.id})
 }});
 for(const m of service.matchAll(/^    function (\w+)\(([^)]*)\): \w+ \{\n([\s\S]*?)^    \}/gm))
  if(['receive','decide','rememberSessionGrant','disconnected','syncCenterAttention'].includes(m[1])) root[m[1]]=vm.runInContext(`(function(${m[2].replace(/:\s*\w+/g,'')}){${m[3]}})`,context);
 return root;
}
let failures=0;
function test(name,run){try{run();console.log('PASS '+name);}catch(e){failures++;console.error('FAIL '+name+': '+e.message);}}
test('ChatGPT grant identity uses its actual thread ID',()=>assert.equal(chat('a','thread-a').conversationId,'thread-a'));
test('different threads and sources never share session grants',()=>{
 const a=rules.sessionKeys(chat('a','thread-a'));
 for(const other of [chat('b','thread-b'),agy('c','thread-a')]) assert.equal(a.some(k=>rules.sessionKeys(other).includes(k)),false);
});
test('missing or malformed session identity cannot create reusable grants',()=>{
 for(const d of [chat('a',undefined),chat('b',{}),agy('c',''),agy('d',{})]) assert.equal(rules.sessionKeys(d).length,0);
});
test('unknown decisions never generate an approval',()=>{
 for(const decision of ['', 'denny', 'ALLOW_ONCE', null, {}])
  for(const source of ['chatgpt','antigravity']) assert.ok(!['allow','accept','acceptForSession'].includes(rules.decisionPayload(source,decision,agy('a','c')).decision));
});
test('invalid service decision leaves the pending request undecided',()=>{
 const root=fixture(), descriptor=agy('a','c'), responses=[];
 root.pending=[descriptor]; root.clients.a={write(value){responses.push(value);},flush(){}};
 assert.equal(root.decide('a','denny'),false);
 assert.equal(responses.length,0); assert.equal(root.pending.length,1);
});
test('same source and session reuse approval; unrelated and legacy grants stay pending',()=>{
 const root=fixture(); root.rememberSessionGrant(chat('a','thread-a'));
 let responses=[];const client=()=>({write(s){responses.push(JSON.parse(s));},flush(){}});
 root.receive(client(),JSON.stringify(chat('b','thread-a').raw));
 assert.equal(responses[0].decision,'acceptForSession');
 responses=[];
 root.sessionGrants={...root.sessionGrants,'scope:/same/repo':true,'conv:thread-b':true};
 root.receive(client(),JSON.stringify(chat('c','thread-b').raw));
 root.receive(client(),JSON.stringify(agy('d','thread-a').raw));
 assert.equal(responses.length,0);assert.equal(root.pending.length,2);
});
test('malformed requests are rejected without enqueuing',()=>{
 const root=fixture(); let responses=[];
 for(const payload of [null,[],{}, {source:'unknown',requestId:'x'},{source:'chatgpt',requestId:{}}]) root.receive({write(v){responses.push(JSON.parse(v));},flush(){}},JSON.stringify(payload));
 assert.equal(root.pending.length,0);assert.equal(responses.length,5);
});
test('disconnect removes every request from that socket and preserves other clients',()=>{
 const root=fixture(), first={write(){},flush(){}}, other={write(){},flush(){}};
 root.receive(first,JSON.stringify(chat('one','thread-a').raw));
 root.receive(first,JSON.stringify(chat('two','thread-a').raw));
 root.receive(other,JSON.stringify(chat('three','thread-b').raw));
 root.disconnected(first);
 assert.deepEqual(Array.from(root.pending,d=>d.requestId),['three']);
 assert.deepEqual(Object.keys(root.clients),['three']);
 assert.deepEqual(root.attentionCalls.at(-1),{type:'publish',key:'agent:approval'});
 root.disconnected(other);
 assert.equal(root.pending.length,0);assert.deepEqual(Object.keys(root.clients),[]);
 assert.deepEqual(root.attentionCalls.at(-1),{type:'clear',key:'agent:approval'});
 assert.ok(root.attentionCalls.every(call=>call.key==='agent:approval'));
 const calls=root.attentionCalls.length;
 root.disconnected(first);
 assert.equal(root.attentionCalls.length,calls,'stale disconnect is inert');
});
process.exitCode=failures?1:0;
