pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Weather
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Shared.Surface {
    id: root
    readonly property var weather: WeatherService.snapshot
    tone: "elevated"
    radius: Metrics.radiusMedium
    clipContent: true
    Accessible.name: I18n.tr("center_notch.overview.weather.accessible")

    Component.onCompleted: WeatherService.acquire()
    Component.onDestruction: WeatherService.release()

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.surfaceElevated }
            GradientStop {
                position: 1
                color: root.weather.kind === "clear"
                    ? (Theme.light ? "#fff1c7" : "#3a3021")
                    : root.weather.kind === "rain" || root.weather.kind === "thunderstorm"
                        ? (Theme.light ? "#dce7f1" : "#26323d")
                        : root.weather.kind === "fog"
                            ? (Theme.light ? "#e9ecef" : "#30343a")
                            : (Theme.light ? "#e4efff" : "#243044")
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingLarge
        anchors.rightMargin: Metrics.spacingLarge
        spacing: Metrics.spacingLarge

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            Shared.TextLabel {
                text: Qt.formatDateTime(clock.date,
                    Preferences.use24Hour ? "HH:mm" : "h:mm AP")
                variant: "display"
                strong: true
                font.pixelSize: 30
            }
            Shared.TextLabel {
                text: clock.date.toLocaleDateString(
                    Qt.locale(I18n.locale === "vi" ? "vi_VN" : "en_US"),
                    "dddd, dd MMMM")
                variant: "caption"
                tone: "secondary"
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 280
            spacing: 1
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Metrics.spacingSmall
                Shared.TextLabel {
                    visible: root.weather.available
                    text: Math.round(root.weather.temperatureC) + "°C"
                    variant: "titleLarge"
                    strong: true
                    font.pixelSize: 25
                }
                Shared.TextLabel {
                    text: WeatherService.loading && !root.weather.available
                        ? I18n.tr("center_notch.overview.weather.loading")
                        : root.weather.available
                            ? I18n.tr("center_notch.overview.weather.kind." + root.weather.kind)
                            : I18n.tr("center_notch.overview.weather.unavailable")
                    variant: "label"
                    strong: true
                }
            }
            Shared.TextLabel {
                Layout.alignment: Qt.AlignRight
                visible: root.weather.available
                text: I18n.tr("center_notch.overview.weather.feels_like", {
                    "value": Math.round(root.weather.feelsLikeC)
                }) + "  ·  " + I18n.tr("center_notch.overview.weather.humidity", {
                    "value": Math.round(root.weather.humidity)
                })
                variant: "caption"
                tone: "secondary"
            }
            Shared.TextLabel {
                Layout.alignment: Qt.AlignRight
                visible: root.weather.available
                text: (root.weather.location || "") + "  ·  "
                    + I18n.tr("center_notch.overview.weather.wind", {
                        "value": Math.round(root.weather.windKph)
                    })
                variant: "caption"
                tone: "secondary"
                elide: Text.ElideLeft
            }
        }

        Item {
            Layout.preferredWidth: 76
            Layout.fillHeight: true
            Rectangle {
                anchors.centerIn: parent
                width: 64
                height: 64
                radius: 32
                color: root.weather.kind === "clear"
                    ? (root.weather.isDay ? "#f6c453" : "#8296bd")
                    : root.weather.kind === "thunderstorm" ? "#56667e"
                        : root.weather.kind === "rain" ? "#6d91b8" : "#9eabb9"
                opacity: 0.2
            }
            Shared.Icon {
                anchors.centerIn: parent
                name: root.weather.icon || "cloud_off"
                size: 56
                color: root.weather.kind === "clear" && root.weather.isDay
                    ? Theme.warning : Theme.textPrimary
                accessibleName: root.weather.kind
            }
        }
    }
}
