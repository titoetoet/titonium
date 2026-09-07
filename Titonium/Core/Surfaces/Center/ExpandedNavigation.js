.pragma library
function tab(value) {
    return ['dashboard', 'tasks', 'monitoring', 'wallpapers'].indexOf(value) >= 0 ? value : 'dashboard';
}
function route(context, lastTab) {
    if (!context) return { tab: tab(lastTab), reveal: '' };
    var source = context.source;
    if (source === 'focus' || source === 'task' || source === 'job' || source === 'timer')
        return { tab: 'tasks', reveal: source === 'focus' ? 'focus' : 'task' };
    if (source === 'monitoring') return { tab: 'monitoring', reveal: 'metrics' };
    if (source === 'wallpaper' || source === 'wallpapers') return { tab: 'wallpapers', reveal: '' };
    return { tab: 'dashboard', reveal: source === 'media' ? 'music' : 'context' };
}
