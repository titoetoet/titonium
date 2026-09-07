// Transient pointer feedback must not hide persistent selection or attention.
function feedback(enabled, hovered, pressed, selected, warning, focused) {
    return {
        hover: enabled && hovered && !pressed ? 1 : 0,
        press: enabled && pressed ? 1 : 0,
        active: enabled && selected,
        warning: enabled && warning,
        focus: enabled && focused,
    };
}
