#!/usr/bin/env node
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const dir = path.join(root, 'Titonium/Services/Appearance');
assert.ok(fs.existsSync(path.join(dir, 'AppearanceRules.js')), 'Appearance resolver exists');
const legacyCatalog = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(dir, 'LegacyThemeCatalog.js'), 'utf8').replace(/^\.pragma.*$/mg, ''), legacyCatalog);
const catalog = vm.createContext({LegacyThemeCatalog:legacyCatalog});
vm.runInContext(fs.readFileSync(path.join(dir, 'ThemeCatalog.js'), 'utf8').replace(/^\.(pragma|import).*$/mg, ''), catalog);
const rules = vm.createContext({ ThemeCatalog: catalog });
vm.runInContext(fs.readFileSync(path.join(dir, 'AppearanceRules.js'), 'utf8').replace(/^\.(pragma|import).*$/mg, ''), rules);
const plain = x => JSON.parse(JSON.stringify(x));
assert.equal(rules.resolve({mode:'system'}, 'unknown', false).mode, 'dark');
assert.equal(rules.resolve({mode:'light'}, 'dark', false).mode, 'light');
for (const theme of catalog.catalog()) for (const mode of ['light', 'dark']) {
 const t = rules.resolve({themeId:theme.id,mode}, 'unknown', false);
 assert.equal(t.themeId,theme.id);
 for (const key of ['background','surface','surfaceElevated','surfaceInteractive','textPrimary','textSecondary','textDisabled','border','borderStrong','accent','accentText','focus','success','warning','danger']) assert.match(t.colors[key], /^#[0-9a-f]{6}$/i);
 assert.equal(t.colors.workspacePalette.length,8);
 assert.ok(rules.contrast(t.colors.textPrimary,t.colors.surface)>=4.5);
 assert.ok(rules.contrast(t.colors.accentText,t.colors.accent)>=4.5);
}
const custom = {themeId:'glass',mode:'dark',themeOverrides:{glass:{dark:{accent:'#ffffff',backgroundOpacity:0,borderStrength:2,radiusScale:2,motionScale:1.5,sheenStrength:NaN,unknown:1},light:{accent:'#000000'}},unknown:{dark:{accent:'#ffffff'}}}};
const before=JSON.stringify(custom);
const t=rules.resolve(custom,'light',false);
assert.equal(t.colors.accent,'#ffffff');
assert.ok(rules.contrast(t.colors.accentText,t.colors.accent)>=4.5);
assert.ok(rules.contrast(t.colors.accentForeground,t.colors.surface)>=4.5);
assert.equal(t.material.backgroundOpacity,.85);
assert.equal(t.material.borderStrength,1);
assert.equal(t.material.radiusScale,1.25);
assert.equal(t.motionScale,1.5);
assert.equal(rules.resolve(custom,'light',true).motionScale,0);
assert.equal(rules.resolve(custom,'light',true).reducedMotion,true);
assert.equal(JSON.stringify(custom),before);
const n=plain(rules.normalize(custom,{}));
assert.equal(n.themeOverrides.glass.dark.sheenStrength,undefined);
assert.equal(n.themeOverrides.unknown,undefined);
assert.equal(n.themeOverrides.glass.dark.unknown,undefined);
assert.equal(rules.resolve({...custom,mode:'light'},'dark',false).colors.accent,'#000000');
assert.equal(rules.resolve({...custom,themeId:'neutral'},'dark',false).colors.accent,'#5b9cff');
assert.deepEqual(plain(rules.normalize(n,{})),n);
assert.equal(rules.normalize({wallpaper:{policy:'custom',customPath:'/missing wallpaper.png'}},{}).wallpaper.customPath,'/missing wallpaper.png');
console.log('PASS Appearance catalog, mode, custom, contrast, purity and reduced motion');

// Compatibility fixture captured from the pre-Appearance semantic token facade.
const neutralBaseline = {
  "light": {
    "background": "#f3f5f7",
    "surface": "#ffffff",
    "surfaceElevated": "#f8f9fb",
    "surfaceInteractive": "#eceff3",
    "textPrimary": "#1b1f24",
    "textSecondary": "#5e6773",
    "textDisabled": "#929aa5",
    "border": "#d7dce2",
    "borderStrong": "#b7bec8",
    "accent": "#1769e0",
    "accentText": "#ffffff",
    "focus": "#0f5fcf",
    "success": "#16825d",
    "warning": "#a76000",
    "danger": "#c43145",
    "workspacePalette": [
      "#dbeafe",
      "#dcfce7",
      "#fef3c7",
      "#f3e8ff",
      "#ffe4e6",
      "#cffafe",
      "#e0e7ff",
      "#ede0d4"
    ],
    "workspaceActivePalette": [
      "#93c5fd",
      "#86efac",
      "#fcd34d",
      "#d8b4fe",
      "#fda4af",
      "#67e8f9",
      "#a5b4fc",
      "#c4a484"
    ]
  },
  "dark": {
    "background": "#111318",
    "surface": "#181b20",
    "surfaceElevated": "#20242b",
    "surfaceInteractive": "#292e37",
    "textPrimary": "#f2f4f7",
    "textSecondary": "#a9b0ba",
    "textDisabled": "#707985",
    "border": "#343a44",
    "borderStrong": "#4a5360",
    "accent": "#5b9cff",
    "accentText": "#07111f",
    "focus": "#8bb8ff",
    "success": "#3ccb8e",
    "warning": "#e8b44f",
    "danger": "#f06a75",
    "workspacePalette": [
      "#233a5e",
      "#1f4a3b",
      "#58451d",
      "#49305f",
      "#5a2934",
      "#1f4650",
      "#303b5f",
      "#4b382b"
    ],
    "workspaceActivePalette": [
      "#5b8fce",
      "#479a72",
      "#aa7d2d",
      "#8a5fb0",
      "#ad5265",
      "#458998",
      "#6578b0",
      "#8c6b52"
    ]
  }
};
for (const mode of ['light','dark']) {
 const actual=rules.resolve({themeId:'neutral',mode},'unknown',false).colors;
 for (const key of Object.keys(neutralBaseline[mode])) assert.deepEqual(plain(actual[key]),neutralBaseline[mode][key], 'Neutral '+mode+' '+key);
}
for (const invalid of [null,[],{}, {mode:'bad',themeId:'constructor',wallpaper:{policy:'bad',customPath:3}}]) {
 const normalized=rules.normalize(invalid,{});
 assert.equal(normalized.themeId,'modern-flat');
 assert.equal(normalized.mode,'dark');
 assert.equal(normalized.wallpaper.policy,'keep');
}
const polluted=JSON.parse('{"themeOverrides":{"__proto__":{"dark":{"accent":"#ffffff"}},"glass":{"constructor":{},"dark":{"__proto__":{},"accent":"red","motionScale":"1","radiusScale":null}}}}');
assert.deepEqual(plain(rules.normalize(polluted,{}).themeOverrides),{});
for (const [key,min,max] of [['backgroundOpacity',.85,1],['borderStrength',0,1],['shadowStrength',0,1],['sheenStrength',0,1],['radiusScale',.75,1.25],['motionScale',.5,1.5]]) {
 for (const [value,expected] of [[-20,min],[20,max],[(min+max)/2,(min+max)/2]]) {
  const normalized=rules.normalize({themeOverrides:{soft:{light:{[key]:value}}}},{});
  assert.equal(normalized.themeOverrides.soft.light[key],expected);
 }
 for (const value of [Infinity,-Infinity,NaN,'1',null])
  assert.deepEqual(plain(rules.normalize({themeOverrides:{soft:{light:{[key]:value}}}},{}).themeOverrides),{});
}
console.log('PASS exact Neutral compatibility, malformed inputs, prototype keys and every numeric boundary');

assert.equal(catalog.lookup("liquid-glass").design.controlMotion.pressScale, .985);
