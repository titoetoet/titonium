.pragma library

// Value-only paint decisions. Neither layout nor input ownership belongs here.
function paint(tokens, role, interaction) {
    const t = tokens || {}, c = t.colors || {}, m = t.material || {};
    const d = t.design || {}, s = interaction || {};
    const enabled = s.enabled !== false;
    const pressed = enabled && s.pressed === true;
    const hovered = enabled && s.hovered === true;
    const selected = s.selected === true;
    const renderer = d.renderer || 'modern-flat';
    const flat = renderer === 'modern-flat';
    const neumo = renderer === 'neumorphism';
    const material = renderer === 'material';
    const glass = renderer === 'glassmorphism' || renderer === 'liquid-glass';
    const field = role === 'field' || role === 'slider-track' || role === 'toggle-track';
    const surface = role === 'surface' || role === 'panel';
    const quiet = s.quiet === true;
    const primary = s.primary === true;
    const engaged = hovered || pressed || selected;
    let fill = surface ? c.surface : field ? c.surfaceInteractive : c.surfaceElevated;
    if (neumo) fill = c.surface;
    if (primary) fill = c.accent;
    else if (quiet && !engaged) fill = 'transparent';
    else if (engaged && !neumo) fill = c.surfaceInteractive;
    const foreground = primary ? c.accentText : !enabled ? c.textDisabled
        : s.danger === true ? c.danger : c.textPrimary;
    const shadow = flat || (quiet && !engaged) || field ? 0 : (m.shadowStrength || 0);
    return {renderer:renderer, fill:fill || '#20242b', foreground:foreground || '#f2f4f7',
        outline:c.border || '#4a5360', focus:c.focus || '#8bb8ff',
        accent:c.accent || '#5b9cff', light:t.mode === 'light',
        depthTreatment:flat ? 'none' : d.depthTreatment || 'none',
        inset:neumo && (field || pressed || selected),
        shadowStrength:shadow, depthStrength:m.shadowStrength || 0, sheenStrength:flat || (quiet && !engaged) ? 0 : m.sheenStrength || 0,
        borderStrength:quiet ? 0 : (m.borderStrength === undefined ? 1 : m.borderStrength),
        opacity:glass ? Math.max(.85, Math.min(1, m.backgroundOpacity || 1)) : 1,
        stateLayerOpacity:!enabled ? 0 : pressed ? (material ? .16 : .12) : hovered ? .08 : selected ? .10 : 0,
        indicator:selected && !primary, enabled:enabled, pressed:pressed, hovered:hovered,
        focused:enabled && s.focused === true, primary:primary, quiet:quiet,
        field:field, surface:surface};
}
function controlMotion(tokens) {
    const t = tokens || {}, d = (t.design || {}).controlMotion || {};
    const reduced = t.reducedMotion === true;
    return {durationMs:reduced ? 0 : Math.round((d.durationMs || 100) * (t.motionScale || 1)),
        curve:d.curve || 'standard', pressScale:reduced ? 1 : d.pressScale || 1};
}
