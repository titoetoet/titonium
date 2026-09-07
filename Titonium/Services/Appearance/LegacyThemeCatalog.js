.pragma library

// Original Titonium semantic palettes and primitive material presets.
function catalog() {
    return [
    {
        "id": "neutral",
        "nameKey": "settings.appearance.theme.neutral",
        "variants": {
            "light": {
                "colors": {
                    "background": "#f3f5f7",
                    "surface": "#ffffff",
                    "surfaceElevated": "#f8f9fb",
                    "surfaceInteractive": "#eceff3",
                    "textPrimary": "#1b1f24",
                    "textSecondary": "#5e6773",
                    "textDisabled": "#929aa5",
                    "border": "#d7dce2",
                    "borderStrong": "#b7bec8",
                    "accent": "#1769e0",
                    "accentText": "#ffffff",
                    "focus": "#0f5fcf",
                    "success": "#16825d",
                    "warning": "#a76000",
                    "danger": "#c43145",
                    "workspacePalette": [
                        "#dbeafe",
                        "#dcfce7",
                        "#fef3c7",
                        "#f3e8ff",
                        "#ffe4e6",
                        "#cffafe",
                        "#e0e7ff",
                        "#ede0d4"
                    ],
                    "workspaceActivePalette": [
                        "#93c5fd",
                        "#86efac",
                        "#fcd34d",
                        "#d8b4fe",
                        "#fda4af",
                        "#67e8f9",
                        "#a5b4fc",
                        "#c4a484"
                    ]
                },
                "material": {
                    "backgroundOpacity": 1,
                    "borderStrength": 1,
                    "shadowStrength": 0,
                    "sheenStrength": 0,
                    "radiusScale": 1
                },
                "motionScale": 1
            },
            "dark": {
                "colors": {
                    "background": "#111318",
                    "surface": "#181b20",
                    "surfaceElevated": "#20242b",
                    "surfaceInteractive": "#292e37",
                    "textPrimary": "#f2f4f7",
                    "textSecondary": "#a9b0ba",
                    "textDisabled": "#707985",
                    "border": "#343a44",
                    "borderStrong": "#4a5360",
                    "accent": "#5b9cff",
                    "accentText": "#07111f",
                    "focus": "#8bb8ff",
                    "success": "#3ccb8e",
                    "warning": "#e8b44f",
                    "danger": "#f06a75",
                    "workspacePalette": [
                        "#233a5e",
                        "#1f4a3b",
                        "#58451d",
                        "#49305f",
                        "#5a2934",
                        "#1f4650",
                        "#303b5f",
                        "#4b382b"
                    ],
                    "workspaceActivePalette": [
                        "#5b8fce",
                        "#479a72",
                        "#aa7d2d",
                        "#8a5fb0",
                        "#ad5265",
                        "#458998",
                        "#6578b0",
                        "#8c6b52"
                    ]
                },
                "material": {
                    "backgroundOpacity": 1,
                    "borderStrength": 1,
                    "shadowStrength": 0,
                    "sheenStrength": 0,
                    "radiusScale": 1
                },
                "motionScale": 1
            }
        },
        "wallpapers": {
            "light": "",
            "dark": ""
        }
    },
    {
        "id": "glass",
        "nameKey": "settings.appearance.theme.glass",
        "variants": {
            "light": {
                "colors": {
                    "background": "#e7edf5",
                    "surface": "#f5f9ff",
                    "surfaceElevated": "#ffffff",
                    "surfaceInteractive": "#e2ecfa",
                    "textPrimary": "#1b1f24",
                    "textSecondary": "#5e6773",
                    "textDisabled": "#929aa5",
                    "border": "#d7dce2",
                    "borderStrong": "#b7bec8",
                    "accent": "#225fbe",
                    "accentText": "#ffffff",
                    "focus": "#0f5fcf",
                    "success": "#16825d",
                    "warning": "#a76000",
                    "danger": "#c43145",
                    "workspacePalette": [
                        "#dbeafe",
                        "#dcfce7",
                        "#fef3c7",
                        "#f3e8ff",
                        "#ffe4e6",
                        "#cffafe",
                        "#e0e7ff",
                        "#ede0d4"
                    ],
                    "workspaceActivePalette": [
                        "#93c5fd",
                        "#86efac",
                        "#fcd34d",
                        "#d8b4fe",
                        "#fda4af",
                        "#67e8f9",
                        "#a5b4fc",
                        "#c4a484"
                    ]
                },
                "material": {
                    "backgroundOpacity": 0.91,
                    "borderStrength": 1,
                    "shadowStrength": 0.65,
                    "sheenStrength": 0.8,
                    "radiusScale": 1
                },
                "motionScale": 1
            },
            "dark": {
                "colors": {
                    "background": "#0f1723",
                    "surface": "#172335",
                    "surfaceElevated": "#203149",
                    "surfaceInteractive": "#2a3d57",
                    "textPrimary": "#f2f4f7",
                    "textSecondary": "#a9b0ba",
                    "textDisabled": "#707985",
                    "border": "#343a44",
                    "borderStrong": "#4a5360",
                    "accent": "#8bb8ff",
                    "accentText": "#07111f",
                    "focus": "#8bb8ff",
                    "success": "#3ccb8e",
                    "warning": "#e8b44f",
                    "danger": "#f06a75",
                    "workspacePalette": [
                        "#233a5e",
                        "#1f4a3b",
                        "#58451d",
                        "#49305f",
                        "#5a2934",
                        "#1f4650",
                        "#303b5f",
                        "#4b382b"
                    ],
                    "workspaceActivePalette": [
                        "#5b8fce",
                        "#479a72",
                        "#aa7d2d",
                        "#8a5fb0",
                        "#ad5265",
                        "#458998",
                        "#6578b0",
                        "#8c6b52"
                    ]
                },
                "material": {
                    "backgroundOpacity": 0.91,
                    "borderStrength": 1,
                    "shadowStrength": 0.65,
                    "sheenStrength": 0.8,
                    "radiusScale": 1
                },
                "motionScale": 1
            }
        },
        "wallpapers": {
            "light": "Titonium/Theme/assets/wallpapers/glass-light.png",
            "dark": "Titonium/Theme/assets/wallpapers/glass-dark.png"
        }
    },
    {
        "id": "soft",
        "nameKey": "settings.appearance.theme.soft",
        "variants": {
            "light": {
                "colors": {
                    "background": "#f5f0ed",
                    "surface": "#fff9f5",
                    "surfaceElevated": "#faf0e9",
                    "surfaceInteractive": "#efe3dc",
                    "textPrimary": "#1b1f24",
                    "textSecondary": "#5e6773",
                    "textDisabled": "#929aa5",
                    "border": "#d7dce2",
                    "borderStrong": "#b7bec8",
                    "accent": "#8054a4",
                    "accentText": "#ffffff",
                    "focus": "#0f5fcf",
                    "success": "#16825d",
                    "warning": "#a76000",
                    "danger": "#c43145",
                    "workspacePalette": [
                        "#dbeafe",
                        "#dcfce7",
                        "#fef3c7",
                        "#f3e8ff",
                        "#ffe4e6",
                        "#cffafe",
                        "#e0e7ff",
                        "#ede0d4"
                    ],
                    "workspaceActivePalette": [
                        "#93c5fd",
                        "#86efac",
                        "#fcd34d",
                        "#d8b4fe",
                        "#fda4af",
                        "#67e8f9",
                        "#a5b4fc",
                        "#c4a484"
                    ]
                },
                "material": {
                    "backgroundOpacity": 1,
                    "borderStrength": 0.35,
                    "shadowStrength": 0.25,
                    "sheenStrength": 0.15,
                    "radiusScale": 1.2
                },
                "motionScale": 1
            },
            "dark": {
                "colors": {
                    "background": "#201c24",
                    "surface": "#292330",
                    "surfaceElevated": "#342c3d",
                    "surfaceInteractive": "#40364a",
                    "textPrimary": "#f2f4f7",
                    "textSecondary": "#a9b0ba",
                    "textDisabled": "#707985",
                    "border": "#343a44",
                    "borderStrong": "#4a5360",
                    "accent": "#d0a8ed",
                    "accentText": "#07111f",
                    "focus": "#8bb8ff",
                    "success": "#3ccb8e",
                    "warning": "#e8b44f",
                    "danger": "#f06a75",
                    "workspacePalette": [
                        "#233a5e",
                        "#1f4a3b",
                        "#58451d",
                        "#49305f",
                        "#5a2934",
                        "#1f4650",
                        "#303b5f",
                        "#4b382b"
                    ],
                    "workspaceActivePalette": [
                        "#5b8fce",
                        "#479a72",
                        "#aa7d2d",
                        "#8a5fb0",
                        "#ad5265",
                        "#458998",
                        "#6578b0",
                        "#8c6b52"
                    ]
                },
                "material": {
                    "backgroundOpacity": 1,
                    "borderStrength": 0.35,
                    "shadowStrength": 0.25,
                    "sheenStrength": 0.15,
                    "radiusScale": 1.2
                },
                "motionScale": 1
            }
        },
        "wallpapers": {
            "light": "Titonium/Theme/assets/wallpapers/soft-light.png",
            "dark": "Titonium/Theme/assets/wallpapers/soft-dark.png"
        }
    },
    {
        "id": "graphite",
        "nameKey": "settings.appearance.theme.graphite",
        "variants": {
            "light": {
                "colors": {
                    "background": "#e9e9e9",
                    "surface": "#f8f8f8",
                    "surfaceElevated": "#ffffff",
                    "surfaceInteractive": "#e2e2e2",
                    "textPrimary": "#1b1f24",
                    "textSecondary": "#5e6773",
                    "textDisabled": "#929aa5",
                    "border": "#d7dce2",
                    "borderStrong": "#b7bec8",
                    "accent": "#465868",
                    "accentText": "#ffffff",
                    "focus": "#0f5fcf",
                    "success": "#16825d",
                    "warning": "#a76000",
                    "danger": "#c43145",
                    "workspacePalette": [
                        "#dbeafe",
                        "#dcfce7",
                        "#fef3c7",
                        "#f3e8ff",
                        "#ffe4e6",
                        "#cffafe",
                        "#e0e7ff",
                        "#ede0d4"
                    ],
                    "workspaceActivePalette": [
                        "#93c5fd",
                        "#86efac",
                        "#fcd34d",
                        "#d8b4fe",
                        "#fda4af",
                        "#67e8f9",
                        "#a5b4fc",
                        "#c4a484"
                    ]
                },
                "material": {
                    "backgroundOpacity": 1,
                    "borderStrength": 0.7,
                    "shadowStrength": 0.35,
                    "sheenStrength": 0.1,
                    "radiusScale": 0.85
                },
                "motionScale": 1
            },
            "dark": {
                "colors": {
                    "background": "#111111",
                    "surface": "#1d1d1d",
                    "surfaceElevated": "#292929",
                    "surfaceInteractive": "#353535",
                    "textPrimary": "#f2f4f7",
                    "textSecondary": "#a9b0ba",
                    "textDisabled": "#707985",
                    "border": "#343a44",
                    "borderStrong": "#4a5360",
                    "accent": "#b6c9d9",
                    "accentText": "#07111f",
                    "focus": "#8bb8ff",
                    "success": "#3ccb8e",
                    "warning": "#e8b44f",
                    "danger": "#f06a75",
                    "workspacePalette": [
                        "#233a5e",
                        "#1f4a3b",
                        "#58451d",
                        "#49305f",
                        "#5a2934",
                        "#1f4650",
                        "#303b5f",
                        "#4b382b"
                    ],
                    "workspaceActivePalette": [
                        "#5b8fce",
                        "#479a72",
                        "#aa7d2d",
                        "#8a5fb0",
                        "#ad5265",
                        "#458998",
                        "#6578b0",
                        "#8c6b52"
                    ]
                },
                "material": {
                    "backgroundOpacity": 1,
                    "borderStrength": 0.7,
                    "shadowStrength": 0.35,
                    "sheenStrength": 0.1,
                    "radiusScale": 0.85
                },
                "motionScale": 1
            }
        },
        "wallpapers": {
            "light": "Titonium/Theme/assets/wallpapers/graphite-light.png",
            "dark": "Titonium/Theme/assets/wallpapers/graphite-dark.png"
        }
    }
];
}
