.pragma library

function create() {
    const nativeById = {};

    function liveNative(id, source) {
        const native = nativeById[id];
        return native && source.indexOf(native) >= 0 ? native : null;
    }

    function targetFor(id, source, method) {
        const target = liveNative(id, source)?.wayland;
        return target && typeof target[method] === "function" ? target : null;
    }

    return Object.freeze({
        replace: function(records) {
            const oldIds = Object.keys(nativeById);
            for (let index = 0; index < oldIds.length; index++)
                delete nativeById[oldIds[index]];
            const source = Array.isArray(records) ? records : [];
            for (let index = 0; index < source.length; index++) {
                const id = typeof source[index]?.id === "string" ? source[index].id.trim() : "";
                const native = source[index]?.native;
                if (id && native)
                    nativeById[id] = native;
            }
        },

        focus: function(id, source) {
            const records = Array.isArray(source) ? source : [];
            const native = liveNative(id, records);
            const target = targetFor(id, records, "activate");
            if (!target)
                return false;
            if (native.workspace && typeof native.workspace.activate === "function")
                native.workspace.activate();
            target.activate();
            return true;
        },

        close: function(id, source) {
            const target = targetFor(id, Array.isArray(source) ? source : [], "close");
            if (!target)
                return false;
            target.close();
            return true;
        },
    });
}

const sharedRegistry = create();

function replace(records) {
    sharedRegistry.replace(records);
}

function focus(id, source) {
    return sharedRegistry.focus(id, source);
}

function close(id, source) {
    return sharedRegistry.close(id, source);
}
