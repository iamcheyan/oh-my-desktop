pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.bar
import QtQuick
import QtQuick.Layouts

Item {
    implicitWidth: Math.min(280, contentLayout.implicitWidth + 16)
    implicitHeight: contentLayout.implicitHeight + 16

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2

        StyledPopupValueRow {
            icon: NerdIconMap.batteryFull
            label: "Battery"
            value: ServiceManager.power?.battery?.available ?? false
                ? Math.round((ServiceManager.power?.battery?.percentage ?? 0) * 100) + "%"
                : "N/A"
        }
        StyledPopupValueRow {
            icon: NerdIconMap.bolt
            label: "Charging"
            value: ServiceManager.power?.battery?.isPluggedIn ?? false
                ? "Yes"
                : "No"
            visible: ServiceManager.power?.battery?.available ?? false
        }
        StyledPopupValueRow {
            icon: NerdIconMap.speed
            label: "Power profile"
            value: {
                const p = ServiceManager.power?.powerProfiles?.currentProfile;
                if (!p || p === "unavailable") return "-";
                if (p === "power-saver") return "Power saver";
                if (p === "balanced") return "Balanced";
                if (p === "performance") return "Performance";
                return p;
            }
        }
        StyledPopupValueRow {
            icon: NerdIconMap.keyboard
            label: "Layout"
            value: {
                const xkb = ServiceManager.hyprlandXkb;
                if (!xkb?.active) return "-";
                return (xkb.layout ?? "") + (xkb.variant?.length > 0 ? " (" + xkb.variant + ")" : "");
            }
        }
    }
}
