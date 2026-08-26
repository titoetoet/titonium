.pragma library

var groups = [
    [
        {
            "id": "about",
            "labelKey": "arch_menu.item.about",
            "icon": "info",
            "requiresConfirmation": false
        }
    ],
    [
        {
            "id": "settings",
            "labelKey": "arch_menu.item.settings",
            "icon": "settings",
            "requiresConfirmation": false
        }
    ],
    [
        {
            "id": "lock",
            "labelKey": "arch_menu.item.lock",
            "icon": "lock",
            "requiresConfirmation": true
        },
        {
            "id": "sleep",
            "labelKey": "arch_menu.item.sleep",
            "icon": "bedtime",
            "requiresConfirmation": true
        },
        {
            "id": "hibernate",
            "labelKey": "arch_menu.item.hibernate",
            "icon": "ac_unit",
            "requiresConfirmation": true
        }
    ],
    [
        {
            "id": "restart",
            "labelKey": "arch_menu.item.restart",
            "icon": "restart_alt",
            "requiresConfirmation": true
        },
        {
            "id": "shutdown",
            "labelKey": "arch_menu.item.shutdown",
            "icon": "power_settings_new",
            "requiresConfirmation": true
        }
    ],
    [
        {
            "id": "logout",
            "labelKey": "arch_menu.item.logout",
            "icon": "logout",
            "requiresConfirmation": true
        }
    ]
];

var sessionActionIds = ["lock", "sleep", "hibernate", "restart", "shutdown", "logout"];

function isSessionAction(actionId) {
    return sessionActionIds.indexOf(actionId) >= 0;
}

function routeFor(item) {
    if (!item || typeof item.id !== "string")
        return "unknown";
    if (item.requiresConfirmation === true)
        return "confirm";
    if (item.id === "settings" || item.id === "about")
        return item.id;
    return "unknown";
}
