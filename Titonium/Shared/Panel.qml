pragma ComponentBehavior: Bound

import qs.Titonium.Theme

Surface {
    styleRole: "panel"
    tone: "surface"
    radius: Math.round((legacyPaint ? Metrics.radiusLarge : tokens.design.panelRadius) * tokens.material.radiusScale)
    padding: Metrics.spacingLarge
    outlined: true
}
