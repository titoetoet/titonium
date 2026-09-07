.pragma library
.import "ThemeCatalog.js" as ThemeCatalog
function record(value) { return value && typeof value === 'object' && !Array.isArray(value) ? value : {}; }
function own(object, key) { return Object.prototype.hasOwnProperty.call(object, key); }
function choose(value, allowed, fallback) { return allowed.indexOf(value) >= 0 ? value : fallback; }
function clone(value) { return JSON.parse(JSON.stringify(value)); }
function normalize(appearance, defaults) {
 const source=record(appearance),base=record(defaults),ids=ThemeCatalog.allowedIds();
 const ranges={backgroundOpacity:[.85,1],borderStrength:[0,1],shadowStrength:[0,1],sheenStrength:[0,1],radiusScale:[.75,1.25],motionScale:[.5,1.5]};
 const overrides={},input=record(source.themeOverrides);
 for (const id of ids) { if (!own(input,id)) continue; const theme=record(input[id]),result={};
  for (const mode of ['light','dark']) { if (!own(theme,mode)) continue; const variant=record(theme[mode]),fields={};
   if (own(variant,'accent') && typeof variant.accent==='string' && /^#[0-9a-f]{6}$/i.test(variant.accent)) fields.accent=variant.accent.toLowerCase();
   for (const key of Object.keys(ranges)) if (own(variant,key) && typeof variant[key]==='number' && Number.isFinite(variant[key])) fields[key]=Math.max(ranges[key][0],Math.min(ranges[key][1],variant[key]));
   if (Object.keys(fields).length) result[mode]=fields;
  }
  if (Object.keys(result).length) overrides[id]=result;
 }
 const wallpaper=record(source.wallpaper),fallbackWallpaper=record(base.wallpaper);
 const defaultId=choose(base.themeId,ids,'modern-flat');
 const missingPersistedId=appearance && typeof appearance==='object' && !Array.isArray(appearance) && !own(source,'themeId') && own(base,'themeId');
 return {mode:choose(source.mode,['dark','light','system'],choose(base.mode,['dark','light','system'],'dark')),
  themeId:choose(source.themeId,ids,missingPersistedId?'neutral':defaultId),themeOverrides:overrides,
  wallpaper:{policy:choose(wallpaper.policy,['keep','theme','custom'],choose(fallbackWallpaper.policy,['keep','theme','custom'],'keep')),
   customPath:typeof wallpaper.customPath==='string'?wallpaper.customPath:(typeof fallbackWallpaper.customPath==='string'?fallbackWallpaper.customPath:'')}};
}
function luminance(hex) { const channels=[1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)/255).map(v=>v<=.04045?v/12.92:Math.pow((v+.055)/1.055,2.4)); return channels[0]*.2126+channels[1]*.7152+channels[2]*.0722; }
function contrast(a,b) { const x=luminance(a),y=luminance(b); return (Math.max(x,y)+.05)/(Math.min(x,y)+.05); }
function resolve(appearance,systemMode,reducedMotion) {
 const normalized=normalize(appearance,{}),mode=normalized.mode==='system'?(systemMode==='light'?'light':'dark'):normalized.mode;
 const descriptor=ThemeCatalog.lookup(normalized.themeId)||ThemeCatalog.lookup('modern-flat');
 const fallback=ThemeCatalog.lookup('modern-flat').variants[mode],preset=descriptor.variants[mode];
 const colors=Object.assign({},fallback.colors,preset.colors),material=Object.assign({},fallback.material,preset.material);
 const overrides=record(record(normalized.themeOverrides[normalized.themeId])[mode]);
 if (overrides.accent) { colors.accent=overrides.accent; colors.accentText=contrast('#ffffff',colors.accent)>=contrast('#000000',colors.accent)?'#ffffff':'#000000'; }
 else if (contrast(colors.accentText,colors.accent)<4.5) colors.accentText=contrast('#ffffff',colors.accent)>=contrast('#000000',colors.accent)?'#ffffff':'#000000';
 colors.accentForeground=contrast(colors.accent,colors.surface)>=4.5&&contrast(colors.accent,colors.background)>=4.5?colors.accent:colors.textPrimary;
 for (const key of Object.keys(material)) if (overrides[key]!==undefined) material[key]=overrides[key];
 if (!descriptor.legacy) {
  if (['material','modern-flat','neumorphism'].indexOf(descriptor.id)>=0) material.backgroundOpacity=1;
  if (descriptor.id==='modern-flat') { material.shadowStrength=0; material.sheenStrength=0; }
  else if (descriptor.id==='material'||descriptor.id==='neumorphism') material.sheenStrength=0;
 }
 const motionScale=reducedMotion===true?0:(overrides.motionScale===undefined?preset.motionScale:overrides.motionScale),design=clone(descriptor.design);
 return {themeId:descriptor.id,mode:mode,legacy:descriptor.legacy,colors:colors,material:material,design:design,motionScale:motionScale,reducedMotion:reducedMotion===true};
}
