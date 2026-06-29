import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 480
    backgroundWidth: 360
    anchorPosition: 1

    onVisibleChanged: {
        if (visible) {
            root.forceActiveFocus();
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 16
        spacing: 16

        // Battery icon and percentage
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            NerdIcon {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    const pct = Battery.percentage;
                    if (Battery.isCharging) {
                        if (pct > 0.9) return NerdIconMap.batteryChargingFull;
                        if (pct > 0.8) return NerdIconMap.batteryCharging90;
                        if (pct > 0.7) return NerdIconMap.batteryCharging80;
                        if (pct > 0.6) return NerdIconMap.batteryCharging70;
                        if (pct > 0.5) return NerdIconMap.batteryCharging60;
                        if (pct > 0.4) return NerdIconMap.batteryCharging50;
                        if (pct > 0.3) return NerdIconMap.batteryCharging40;
                        if (pct > 0.2) return NerdIconMap.batteryCharging30;
                        if (pct > 0.1) return NerdIconMap.batteryCharging20;
                        return NerdIconMap.batteryCharging10;
                    } else {
                        if (pct > 0.9) return NerdIconMap.batteryFull;
                        if (pct > 0.6) return NerdIconMap.battery60;
                        if (pct > 0.4) return NerdIconMap.battery40;
                        if (pct > 0.2) return NerdIconMap.battery20;
                        return NerdIconMap.battery10;
                    }
                }
                iconSize: 48
                color: (Battery.isLow && !Battery.isCharging) ? TuiStyle.danger : TuiStyle.fg
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: `${Math.round(Battery.percentage * 100)}%`
                font.pixelSize: Appearance.font.pixelSize.larger * 1.5
                font.weight: Font.DemiBold
                color: TuiStyle.fg
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: Battery.available
                text: Battery.isCharging ? Translation.tr("Charging") : (Battery.isPluggedIn ? Translation.tr("Plugged in") : Translation.tr("On battery"))
                font.pixelSize: Appearance.font.pixelSize.small
                color: TuiStyle.dim
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: TuiStyle.line
        }

        // Battery details
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            // Time info
            RowLayout {
                Layout.fillWidth: true
                visible: {
                    let timeValue = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
                    let power = Battery.energyRate;
                    return Battery.available && !(Battery.chargeState == 4 || timeValue <= 0 || power <= 0.01);
                }

                NerdIcon {
                    text: NerdIconMap.schedule
                    iconSize: Appearance.font.pixelSize.larger
                    color: TuiStyle.dim
                }

                StyledText {
                    text: Battery.isCharging ? Translation.tr("Time to full:") : Translation.tr("Time to empty:")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: TuiStyle.dim
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: {
                        function formatTime(seconds) {
                            var h = Math.floor(seconds / 3600);
                            var m = Math.floor((seconds % 3600) / 60);
                            if (h > 0)
                                return `${h}h ${m}m`;
                            else
                                return `${m}m`;
                        }
                        if (Battery.isCharging)
                            return formatTime(Battery.timeToFull);
                        else
                            return formatTime(Battery.timeToEmpty);
                    }
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: TuiStyle.fg
                }
            }

            // Power consumption
            RowLayout {
                Layout.fillWidth: true
                visible: Battery.available && Battery.chargeState != 4 && Battery.energyRate > 0.01

                NerdIcon {
                    text: NerdIconMap.flashOn
                    iconSize: Appearance.font.pixelSize.larger
                    color: TuiStyle.dim
                }

                StyledText {
                    text: Translation.tr("Power:")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: TuiStyle.dim
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: `${Battery.energyRate.toFixed(1)}W`
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: TuiStyle.fg
                }
            }

            // Health
            RowLayout {
                Layout.fillWidth: true
                visible: Battery.available && Battery.health > 0

                NerdIcon {
                    text: NerdIconMap.favorite
                    iconSize: Appearance.font.pixelSize.larger
                    color: TuiStyle.dim
                }

                StyledText {
                    text: Translation.tr("Health:")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: TuiStyle.dim
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: `${Battery.health.toFixed(1)}%`
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: TuiStyle.fg
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: TuiStyle.line
        }
    }
}
