pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Core.Runtime
import "AppearanceRules.js" as AppearanceRules
import "ThemeCatalog.js" as ThemeCatalog

QtObject {
    id: root
    readonly property var platformStyleHints: Qt.styleHints
    readonly property string systemMode: root.platformStyleHints.colorScheme === Qt.Light ? "light"
        : root.platformStyleHints.colorScheme === Qt.Dark ? "dark" : "unknown"
    readonly property var catalog: ThemeCatalog.catalog()
    function themeDescriptor(themeId) { return ThemeCatalog.lookup(themeId) }
    property var trialCandidate: null
    property int trialGeneration: -1
    readonly property var tokens: resolveCandidate(trialCandidate || {
        appearance: Preferences.effectiveState.appearance,
        reducedMotion: Preferences.effectiveState.accessibility?.reducedMotion === true
    })
    function resolveCandidate(candidate) {
        return AppearanceRules.resolve(candidate?.appearance || {}, systemMode,
            candidate?.reducedMotion === true)
    }
    function setTrial(candidate, generation) {
        if (generation < trialGeneration) return false
        trialGeneration = generation
        trialCandidate = JSON.parse(JSON.stringify(candidate))
        return true
    }
    function clearTrial(generation) {
        if (generation !== trialGeneration) return false
        trialCandidate = null
        return true
    }
}
