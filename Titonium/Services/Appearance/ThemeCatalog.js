.pragma library
.import "LegacyThemeCatalog.js" as LegacyThemeCatalog

const publicIds = ['glassmorphism', 'material', 'liquid-glass', 'modern-flat', 'neumorphism'];
const legacyIds = ['neutral', 'glass', 'soft', 'graphite'];

function clone(value) { return JSON.parse(JSON.stringify(value)); }
function own(object, key) { return Object.prototype.hasOwnProperty.call(object, key); }
function controlMotion(durationMs, curve) {
    return {durationMs:durationMs, curve:curve, pressScale:1};
}
function design(renderer, panelRadius, controlRadius, fieldTreatment, depthTreatment,
                durationMs, curve, requiredBackdrop) {
    return {renderer:renderer, panelRadius:panelRadius, controlRadius:controlRadius,
        fieldTreatment:fieldTreatment, depthTreatment:depthTreatment,
        controlMotion:controlMotion(durationMs, curve), requiredBackdrop:requiredBackdrop};
}
function legacyById() {
    const result = {};
    for (const descriptor of LegacyThemeCatalog.catalog()) result[descriptor.id] = descriptor;
    return result;
}
function publicCatalog() {
    const legacy = legacyById();
    const sources = {'glassmorphism':'glass', material:'neutral', 'liquid-glass':'glass',
        'modern-flat':'neutral', neumorphism:'soft'};
    const designs = {
        'glassmorphism':design('glassmorphism',16,10,'frosted','soft-shadow',140,'standard','blur'),
        // A negative control radius requests a capsule from the paint geometry boundary.
        material:design('material',20,-1,'tonal','elevation',160,'emphasized','none'),
        'liquid-glass':design('liquid-glass',24,-1,'glass-well','optical-edge',220,'spring-damped','refraction'),
        'modern-flat':design('modern-flat',8,4,'outlined','none',90,'standard','none'),
        neumorphism:design('neumorphism',18,10,'inset','dual-shadow',140,'standard','none')
    };
    designs["liquid-glass"].controlMotion.pressScale = .985;
    return publicIds.map(function(id) {
        const source = legacy[sources[id]];
        const variants = clone(source.variants);
        if (id === 'material') for (const mode of ['light','dark']) variants[mode].material =
            {backgroundOpacity:1,borderStrength:.65,shadowStrength:.38,sheenStrength:0,radiusScale:1};
        else if (id === 'liquid-glass') for (const mode of ['light','dark']) variants[mode].material =
            {backgroundOpacity:.88,borderStrength:.8,shadowStrength:.3,sheenStrength:1,radiusScale:1.2};
        else if (id === 'modern-flat') for (const mode of ['light','dark']) variants[mode].material =
            {backgroundOpacity:1,borderStrength:1,shadowStrength:0,sheenStrength:0,radiusScale:.85};
        else if (id === 'neumorphism') for (const mode of ['light','dark']) variants[mode].material =
            {backgroundOpacity:1,borderStrength:0,shadowStrength:.7,sheenStrength:0,radiusScale:1};
        return {id:id,nameKey:'settings.appearance.theme.'+id,legacy:false,design:designs[id],
            variants:variants,wallpapers:{light:'',dark:''}};
    });
}
function legacyDesign(id) {
    const designs = {
        neutral:design('legacy',8,4,'outlined','none',90,'standard','none'),
        glass:design('legacy',16,10,'frosted','soft-shadow',140,'standard','blur'),
        soft:design('legacy',18,10,'tonal','soft-shadow',140,'standard','none'),
        graphite:design('legacy',8,4,'outlined','soft-shadow',90,'standard','none')
    };
    return designs[id];
}
function catalog() { return publicCatalog(); }
function allowedIds() { return publicIds.concat(legacyIds); }
function lookup(id) {
    if (typeof id !== 'string' || allowedIds().indexOf(id) < 0) return null;
    const publicEntries = publicCatalog();
    for (const descriptor of publicEntries) if (descriptor.id === id) return descriptor;
    const legacy = legacyById();
    if (!own(legacy, id)) return null;
    const descriptor = clone(legacy[id]);
    descriptor.legacy = true;
    descriptor.design = legacyDesign(id);
    return descriptor;
}
