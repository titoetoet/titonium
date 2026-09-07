pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Appearance

QtObject {
    id: root

    readonly property var tokens: AppearanceService.tokens
    readonly property var design: AppearanceService.tokens.design || ({})
    readonly property bool legacy: AppearanceService.tokens.legacy !== false
    // Paint coefficients for the layout-owned continuous silhouette.
    readonly property var chassis: {
        const id = root.design.renderer;
        const m = root.material;
        if (root.legacy) return {gradient:m.sheenStrength > 0 || m.shadowStrength > 0,
            diagonal:false,top:.10*m.sheenStrength,bottom:.10*m.shadowStrength,
            shoulder:.35,foot:.35,edge:m.borderStrength*Math.max(m.sheenStrength,m.shadowStrength)};
        if (id === "modern-flat") return {gradient:false,diagonal:false,top:0,bottom:0,shoulder:.35,foot:1,edge:m.borderStrength};
        if (id === "neumorphism") return {gradient:true,diagonal:true,top:.24*m.shadowStrength,bottom:.32*m.shadowStrength,shoulder:.045,foot:.955,edge:0};
        if (id === "material") return {gradient:true,diagonal:false,top:.025,bottom:.09*m.shadowStrength,shoulder:.15,foot:.94,edge:.4*m.borderStrength};
        if (id === "liquid-glass") return {gradient:true,diagonal:true,top:.26*m.sheenStrength,bottom:.24*m.shadowStrength,shoulder:.035,foot:.95,edge:.65*m.borderStrength};
        return {gradient:true,diagonal:false,top:.14*m.sheenStrength,bottom:.07*m.shadowStrength,shoulder:.28,foot:.94,edge:.45*m.borderStrength};
    }
    readonly property var material: AppearanceService.tokens.material
    readonly property string themeId: AppearanceService.tokens.themeId
    readonly property color centerSurface: root.themeId === "neutral" ? (root.light ? "#ffffff" : "#000000") : root.surface
    readonly property color connectedSurface: root.themeId === "neutral" ? (root.light ? "#ffffff" : "#0d0e12") : root.surface
    readonly property bool light: AppearanceService.tokens.mode === "light"
    readonly property color background: AppearanceService.tokens.colors.background
    readonly property color surface: AppearanceService.tokens.colors.surface
    readonly property color surfaceElevated: AppearanceService.tokens.colors.surfaceElevated
    readonly property color surfaceInteractive: AppearanceService.tokens.colors.surfaceInteractive
    readonly property color textPrimary: AppearanceService.tokens.colors.textPrimary
    readonly property color textSecondary: AppearanceService.tokens.colors.textSecondary
    readonly property color textDisabled: AppearanceService.tokens.colors.textDisabled
    readonly property color border: AppearanceService.tokens.colors.border
    readonly property color borderStrong: AppearanceService.tokens.colors.borderStrong
    readonly property color accent: AppearanceService.tokens.colors.accent
    readonly property color accentForeground: AppearanceService.tokens.colors.accentForeground
    readonly property color accentText: AppearanceService.tokens.colors.accentText
    readonly property color focus: AppearanceService.tokens.colors.focus
    readonly property color success: AppearanceService.tokens.colors.success
    readonly property color warning: AppearanceService.tokens.colors.warning
    readonly property color danger: AppearanceService.tokens.colors.danger
    readonly property var workspacePalette: AppearanceService.tokens.colors.workspacePalette
    readonly property var workspaceActivePalette: AppearanceService.tokens.colors.workspaceActivePalette
}
