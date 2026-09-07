.pragma library
function tidy(value) {
    return String(value || '').replace(/\s+/g, ' ').trim();
}
function unquote(value) {
    return tidy(value).replace(/^(?:"(.*)"|“(.*)”|'(.*)')$/, function(_, a, b, c) {
        return a !== undefined ? a : b !== undefined ? b : c;
    }).trim();
}
function clean(value) {
    return tidy(String(value || '').replace(/\([^()]*\)|\[[^\[\]]*\]|\{[^{}]*\}|【[^【】]*】/g, function(tag) {
        const content = tag.slice(1, -1).trim();
        return /^(?:official|mv|m\/v|lyrics?|audio|video|vietsub|pinyin|karaoke|prod|ft|feat|remix|cover|live|4k|hd|hq|speed\s*up|slowed|visuali[sz]er)\b/i.test(content) ? '' : tag;
    }).replace(/#\S+/g, ''));
}
function formatSongDisplay(rawTitle, channelName) {
    const text = clean(rawTitle);
    if (!text) return '';
    const artist = unquote(tidy(channelName).replace(/(?:\s*-\s*)?\b(?:official|topic|vevo|channel)\b/gi, ' '));
    // Require a whole matching segment, not a substring of another artist/title.
    const parts = text.split(/\s+[-–—|:~•]\s+|_+/).map(unquote).filter(function(p) { return p.length > 0; });
    if (artist && parts.length >= 2) {
        const match = parts.findIndex(function(p) { return p.toLowerCase() === artist.toLowerCase(); });
        if (match >= 0) {
            parts.splice(match, 1);
            return parts.join(' - ') + ' - ' + artist;
        }
    }
    // Ambiguous multi-part titles stay intact; channel metadata is not always an artist.
    if (parts.length >= 2) return unquote(text);
    const title = unquote(text);
    return artist ? title + ' - ' + artist : title;
}
