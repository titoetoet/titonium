#!/usr/bin/env node
// Catches public/legacy catalog leakage and loss of structural style distinctions.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const appearanceDir = path.join(root, 'Titonium/Services/Appearance');
const load = (name, dependencies = {}) => {
    const context = vm.createContext(dependencies);
    vm.runInContext(fs.readFileSync(path.join(appearanceDir, name), 'utf8')
        .replace(/^\.(pragma|import).*$/mg, ''), context);
    return context;
};

const legacy = load('LegacyThemeCatalog.js');
const catalog = load('ThemeCatalog.js', {LegacyThemeCatalog: legacy});
const rules = load('AppearanceRules.js', {ThemeCatalog: catalog});
const plain = value => JSON.parse(JSON.stringify(value));

assert.deepEqual(Array.from(catalog.catalog(), item => item.id), [
    'glassmorphism', 'material', 'liquid-glass', 'modern-flat', 'neumorphism'
]);
assert.deepEqual(Array.from(catalog.allowedIds()), [
    'glassmorphism', 'material', 'liquid-glass', 'modern-flat', 'neumorphism',
    'neutral', 'glass', 'soft', 'graphite'
]);
for (const id of catalog.allowedIds()) {
    const descriptor = catalog.lookup(id);
    assert.equal(descriptor.id, id);
    assert.equal(descriptor.legacy, ['neutral', 'glass', 'soft', 'graphite'].includes(id));
    assert.ok(descriptor.design);
    assert.ok(descriptor.variants.light && descriptor.variants.dark);
    assert.ok(descriptor.wallpapers);
}
for (const unsafe of ['constructor', '__proto__', 'prototype', '', null, 12])
    assert.equal(catalog.lookup(unsafe), null);

const expectedDesign = {
    glassmorphism: ['glassmorphism', 16, 10, 'frosted', 'soft-shadow', 'standard', 140, 'blur'],
    material: ['material', 20, -1, 'tonal', 'elevation', 'emphasized', 160, 'none'],
    'liquid-glass': ['liquid-glass', 24, -1, 'glass-well', 'optical-edge', 'spring-damped', 220, 'refraction'],
    'modern-flat': ['modern-flat', 8, 4, 'outlined', 'none', 'standard', 90, 'none'],
    neumorphism: ['neumorphism', 18, 10, 'inset', 'dual-shadow', 'standard', 140, 'none'],
};
for (const [id, values] of Object.entries(expectedDesign)) {
    for (const mode of ['light', 'dark']) {
        const resolved = rules.resolve({themeId: id, mode}, 'unknown', false);
        assert.equal(resolved.themeId, id);
        assert.equal(resolved.mode, mode);
        assert.equal(resolved.legacy, false);
        assert.deepEqual(plain([
            resolved.design.renderer, resolved.design.panelRadius,
            resolved.design.controlRadius, resolved.design.fieldTreatment,
            resolved.design.depthTreatment, resolved.design.controlMotion.curve,
            resolved.design.controlMotion.durationMs, resolved.design.requiredBackdrop,
        ]), values);
        assert.equal(resolved.design.controlMotion.pressScale, id === "liquid-glass" ? .985 : 1);
    }
}

assert.equal(rules.resolve({themeId: 'constructor'}, 'light', false).themeId, 'modern-flat');
assert.equal(rules.resolve({themeId: 'liquid-glass'}, 'dark', false).design.requiredBackdrop,
    'refraction');
const flat = rules.resolve({themeId: 'modern-flat', mode: 'dark', themeOverrides: {
    'modern-flat': {dark: {backgroundOpacity: .85, shadowStrength: 1, sheenStrength: 1}}
}}, 'light', false);
assert.equal(flat.material.backgroundOpacity, 1);
assert.equal(flat.material.shadowStrength, 0);
assert.equal(flat.material.sheenStrength, 0);
const normalizedFlat = rules.normalize({themeId: 'modern-flat', themeOverrides: {
    'modern-flat': {dark: {backgroundOpacity: .85, shadowStrength: 1, sheenStrength: 1}}
}}, {});
assert.equal(normalizedFlat.themeOverrides['modern-flat'].dark.shadowStrength, 1,
    'locked overrides remain persisted for undo and later compatibility');
for (const id of ['material', 'modern-flat', 'neumorphism'])
    assert.equal(rules.resolve({themeId: id, themeOverrides: {[id]: {dark: {
        backgroundOpacity: .85
    }}}}, 'dark', false).material.backgroundOpacity, 1);
assert.equal(rules.resolve({themeId: 'glassmorphism', themeOverrides: {glassmorphism: {dark: {
    backgroundOpacity: 0
}}}}, 'dark', false).material.backgroundOpacity, .85);
const reduced = rules.resolve({themeId: 'liquid-glass'}, 'dark', true);
assert.equal(reduced.motionScale, 0);
assert.equal(reduced.design.controlMotion.durationMs, 220,
    'resolved design retains base control duration for the paint motion boundary');
for (const source of legacy.catalog()) {
    const descriptor = catalog.lookup(source.id);
    assert.deepEqual(plain(descriptor.variants), plain(source.variants),
        source.id + ' keeps the frozen palette and primitive material values');
    assert.deepEqual(plain(descriptor.wallpapers), plain(source.wallpapers),
        source.id + ' keeps both frozen wallpaper paths');
}

console.log('PASS five public styles, private legacy lookup and structural design contracts');
