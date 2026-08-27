.pragma library

function create() {
    const nativeByAppId = {};

    function liveFor(appKey, source) {
        const stored = nativeByAppId[appKey] || [];
        const live = [];
        for (let index = 0; index < stored.length; index++) {
            if (source.indexOf(stored[index]) >= 0)
                live.push(stored[index]);
        }
        return live;
    }

    function targetFor(toplevel, method) {
        const target = toplevel?.wayland;
        return target && typeof target[method] === "function" ? target : null;
    }

    return {
        replace: function(records) {
            const keys = Object.keys(nativeByAppId);
            for (let index = 0; index < keys.length; index++)
                delete nativeByAppId[keys[index]];
            const source = records && typeof records === "object" ? records : {};
            const recordKeys = Object.keys(source);
            for (let index = 0; index < recordKeys.length; index++)
                nativeByAppId[recordKeys[index]] = (source[recordKeys[index]] || []).slice();
        },

        activate: function(appKey, source, previousIndex) {
            const live = liveFor(appKey, source || []);
            if (live.length === 0)
                return { available: false, success: false, selectedIndex: -1 };
            let selectedIndex = Number.isInteger(previousIndex) && previousIndex >= 0
                && previousIndex < live.length ? (previousIndex + 1) % live.length : 0;
            if (!Number.isInteger(previousIndex)) {
                for (let index = 0; index < live.length; index++) {
                    if (live[index]?.activated === true) {
                        selectedIndex = index;
                        break;
                    }
                }
            }
            const target = targetFor(live[selectedIndex], "activate");
            if (!target)
                return { available: true, success: false, selectedIndex: selectedIndex };
            target.activate();
            return { available: true, success: true, selectedIndex: selectedIndex };
        },

        closeActive: function(appKey, source) {
            const live = liveFor(appKey, source || []);
            if (live.length === 0)
                return { available: false, success: false };
            let active = live[0];
            for (let index = 0; index < live.length; index++) {
                if (live[index]?.activated === true) {
                    active = live[index];
                    break;
                }
            }
            const target = targetFor(active, "close");
            if (!target)
                return { available: true, success: false };
            target.close();
            return { available: true, success: true };
        },
    };
}
