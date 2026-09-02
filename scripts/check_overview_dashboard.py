#!/usr/bin/env python3

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OVERVIEW = ROOT / "Titonium/Bar/notch/OverviewPage.qml"
WEATHER_SERVICE = ROOT / "Titonium/Services/Weather/WeatherService.qml"
WEATHER_QMLDIR = ROOT / "Titonium/Services/Weather/qmldir"
MPRIS = ROOT / "Titonium/Services/Mpris/MprisService.qml"
CHECK = ROOT / "scripts/check.sh"


def main() -> int:
    errors: list[str] = []
    required_files = (
        OVERVIEW,
        ROOT / "Titonium/Bar/notch/OverviewWeatherHero.qml",
        ROOT / "Titonium/Bar/notch/OverviewFocusCard.qml",
        ROOT / "Titonium/Bar/notch/OverviewMediaCard.qml",
        WEATHER_SERVICE,
        ROOT / "Titonium/Services/Weather/WeatherRules.js",
        WEATHER_QMLDIR,
    )
    for path in required_files:
        if not path.is_file():
            errors.append(f"missing dashboard file: {path.relative_to(ROOT)}")

    if OVERVIEW.is_file():
        source = OVERVIEW.read_text(encoding="utf-8")
        for fragment in (
            "OverviewWeatherHero {", "OverviewFocusCard {", "OverviewMediaCard {",
        ):
            if fragment not in source:
                errors.append(f"Overview dashboard missing contract: {fragment}")
        for forbidden in ("Process {", "FileView {", "Timer {"):
            if forbidden in source:
                errors.append(f"Overview owns service behavior: {forbidden}")

    if WEATHER_SERVICE.is_file():
        source = WEATHER_SERVICE.read_text(encoding="utf-8")
        for fragment in (
            "pragma Singleton", "WeatherRules.parse", "readonly property var snapshot:",
            "function acquire(): void", "function release(): void", "function refresh(): bool",
            'command: ["curl"', "property Timer refreshTimer: Timer {",
        ):
            if fragment not in source:
                errors.append(f"WeatherService missing contract: {fragment}")
        for forbidden in ("import qs.Titonium.Bar", "import qs.Titonium.Overlays"):
            if forbidden in source:
                errors.append(f"Weather service imports a view: {forbidden}")

    if WEATHER_QMLDIR.is_file() and "singleton WeatherService 1.0 WeatherService.qml" not in WEATHER_QMLDIR.read_text(encoding="utf-8"):
        errors.append("Weather qmldir missing singleton registration")

    if MPRIS.is_file():
        source = MPRIS.read_text(encoding="utf-8")
        for fragment in (
            "trackArtUrl:", "canTogglePlaying:", "canGoPrevious:", "canGoNext:",
            "function togglePlaying(): bool", "function previous(): bool", "function next(): bool",
        ):
            if fragment not in source:
                errors.append(f"Mpris dashboard projection missing: {fragment}")

    focus_card = ROOT / "Titonium/Bar/notch/OverviewFocusCard.qml"
    if focus_card.is_file():
        source = focus_card.read_text(encoding="utf-8")
        for fragment in (
            "property bool editing:", "QtControls.TextField {",
            "CenterFocusStore.saveToday(focusInput.text)",
            "center_notch.overview.focus.save", "center_notch.overview.focus.cancel",
        ):
            if fragment not in source:
                errors.append(f"Overview Focus inline editor missing: {fragment}")

    media_card = ROOT / "Titonium/Bar/notch/OverviewMediaCard.qml"
    if media_card.is_file():
        source = media_card.read_text(encoding="utf-8")
        for fragment in (
            "Layout.preferredWidth: 92", "Layout.preferredHeight: 92",
            "root.hasPlayer && root.player.playbackState === \"playing\"",
            "center_notch.overview.media.playing", "center_notch.overview.media.paused",
        ):
            if fragment not in source:
                errors.append(f"Overview Media layout missing: {fragment}")

    required_keys = {
        "center_notch.overview.weather.unavailable", "center_notch.overview.weather.loading",
        "center_notch.overview.weather.feels_like", "center_notch.overview.weather.humidity",
        "center_notch.overview.weather.wind", "center_notch.overview.focus.title",
        "center_notch.overview.focus.edit", "center_notch.overview.focus.save",
        "center_notch.overview.focus.cancel", "center_notch.overview.focus.placeholder",
        "center_notch.overview.media.title", "center_notch.overview.media.empty",
        "center_notch.overview.media.playing", "center_notch.overview.media.paused",
        "center_notch.overview.media.toggle", "center_notch.overview.media.previous",
        "center_notch.overview.media.next", "center_notch.overview.activities.title",
        "center_notch.overview.activities.count", "center_notch.overview.activities.empty",
    }
    for locale in ("en", "vi"):
        strings = json.loads((ROOT / f"config/i18n/{locale}.json").read_text(encoding="utf-8"))["strings"]
        for key in sorted(required_keys - strings.keys()):
            errors.append(f"{locale} catalog missing dashboard key: {key}")

    if CHECK.is_file():
        source = CHECK.read_text(encoding="utf-8")
        for fragment in (
            'node "$project_root/scripts/check_weather_rules.js"',
            'python3 "$project_root/scripts/check_overview_dashboard.py"',
        ):
            if fragment not in source:
                errors.append(f"check.sh missing dashboard gate: {fragment}")

    if errors:
        print("FAIL Today Overview dashboard contract")
        print("\n".join(errors))
        return 1
    print("PASS Today Overview weather, focus and media boundaries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
