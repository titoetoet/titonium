.pragma library

var sizes = Object.freeze({
    micro: 11,
    caption: 12,
    bodySmall: 13,
    body: 14,
    bodyLarge: 15,
    label: 14,
    titleSmall: 16,
    title: 17,
    titleLarge: 20,
    display: 28,
    mono: 14
});

function sizeFor(variant) {
    return sizes[variant] || sizes.body;
}
