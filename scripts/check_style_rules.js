#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const file = path.resolve(__dirname, '../Titonium/Shared/StyleRules.js');
assert.ok(fs.existsSync(file), 'production style state resolver exists');
const r = vm.createContext({});
vm.runInContext(fs.readFileSync(file,'utf8').replace(/^\.pragma.*$/mg,''),r);
const colors={surface:'#20242b',surfaceElevated:'#292e37',surfaceInteractive:'#343a44',textPrimary:'#f2f4f7',textDisabled:'#707985',border:'#4a5360',accent:'#5b9cff',accentText:'#07111f',focus:'#8bb8ff',danger:'#f06a75'};
const t=(id)=>({mode:'dark',colors,material:{backgroundOpacity:1,borderStrength:1,shadowStrength:.7,sheenStrength:.7,radiusScale:1},design:{renderer:id,depthTreatment:id==='neumorphism'?'dual-shadow':id==='material'?'elevation':'none',controlMotion:{durationMs:140,curve:'standard',pressScale:.98}},motionScale:1,reducedMotion:false});
assert.equal(r.paint(t('neumorphism'),'field',{}).inset,true);
assert.equal(r.paint(t('neumorphism'),'button',{}).inset,false);
assert.equal(r.paint(t('neumorphism'),'button',{pressed:true}).inset,true);
assert.equal(r.paint(t('modern-flat'),'button',{hovered:true}).shadowStrength,0);
assert.equal(r.paint(t('modern-flat'),'button',{}).sheenStrength,0);
assert.ok(r.paint(t('material'),'button',{pressed:true}).stateLayerOpacity > r.paint(t('material'),'button',{hovered:true}).stateLayerOpacity);
assert.equal(r.paint(t('material'),'button',{enabled:false,hovered:true,pressed:true}).stateLayerOpacity,0);
assert.equal(r.paint(t('material'),'button',{selected:true}).indicator,true);
assert.equal(r.paint(t('neumorphism'),'button',{selected:true}).indicator,true);
assert.equal(r.paint(t('modern-flat'),'button',{primary:true}).foreground,colors.accentText);
const quiet=r.paint(t('modern-flat'),'button',{quiet:true});
assert.equal(quiet.fill,'transparent');
assert.equal(quiet.shadowStrength,0);
assert.equal(r.paint(t('material'),'button',{danger:true}).foreground,colors.danger);
const before=JSON.stringify(t('neumorphism'));r.paint(t('neumorphism'),'field',{pressed:true});assert.equal(JSON.stringify(t('neumorphism')),before);
const reduced={...t('liquid-glass'),reducedMotion:true};
assert.equal(r.controlMotion(reduced).durationMs,0);assert.equal(r.controlMotion(reduced).pressScale,1);
assert.equal(r.controlMotion({...t('material'),motionScale:1.5}).durationMs,210);
assert.equal(r.paint({...t('glassmorphism'),material:{backgroundOpacity:.3}},'panel',{}).opacity,.85);
assert.equal(r.paint(t('material'),'button',{focused:true}).focus,colors.focus);
console.log('PASS style state hierarchy, inset transitions, disabled/selected, fallback alpha and control motion');

assert.equal(r.paint(t('material'),'button',{enabled:false,focused:true}).focused,false);
assert.equal(r.paint(t('material'),'button',{quiet:true}).borderStrength,0);
assert.ok(r.paint(t('neumorphism'),'field',{}).depthStrength>0);
assert.equal(r.paint(t('neumorphism'),'field',{}).shadowStrength,0);

for (const id of ['glassmorphism','liquid-glass']) {
    assert.equal(r.paint(t(id),'button',{quiet:true}).sheenStrength,0);
    assert.equal(r.paint(t(id),'button',{quiet:true,enabled:false,hovered:true,pressed:true}).sheenStrength,0);
    assert.ok(r.paint(t(id),'button',{quiet:true,hovered:true}).sheenStrength>0);
}
