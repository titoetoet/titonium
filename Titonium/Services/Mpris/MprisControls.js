.pragma library

function seekPosition(identity, token, current, fraction) {
    if (!current || !identity || current.identity !== identity
            || current.trackToken !== token || current.canSeek !== true
            || !Number.isFinite(current.length) || current.length <= 0
            || !Number.isFinite(fraction)) return null;
    return Math.max(0, Math.min(1, fraction)) * current.length;
}

// Qt can expose the MPRIS object-path variant through its QVariant string form.
// Normalize at the native boundary before comparing with busctl's plain path.
function trackId(value) {
    var text = String(value || "");
    var wrapped = /^QVariant\(QDBusObjectPath, QDBusObjectPath\("([^"\\]+)"\)\)$/.exec(text);
    if (wrapped) text = wrapped[1];
    return /^\/(?:[A-Za-z0-9_]+(?:\/[A-Za-z0-9_]+)*)?$/.test(text) ? text : "";
}

function sourceDetails(identity, url) {
    var name = String(identity || "").trim();
    var host = /^https?:\/\/([^\/:?#]+)(?:[\/:?#]|$)/i.exec(String(url || ""));
    var youtube = host && /^(?:[a-z0-9-]+\.)*youtube\.com$|^youtu\.be$/i.test(host[1]);
    return { label: youtube ? "YouTube" + (name ? " · " + name : "") : name,
        icon: youtube ? "smart_display" : (/chrom|firefox|brave|browser/i.test(name) ? "language" : "music_note") };
}
