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
            icon: NerdIconMap.volumeHigh
            label: "Volume"
            value: ServiceManager.audio?.sink?.audio?.muted
                ? "Muted"
                : Math.round((ServiceManager.audio?.sink?.audio?.volume ?? 0) * 100) + "%"
        }
        StyledPopupValueRow {
            icon: NerdIconMap.volumeHeadphone
            label: "Output device"
            value: {
                const name = ServiceManager.audio?.friendlyDeviceName?.(ServiceManager.audio?.sink) ?? ""
                if (name.length > 0) return name;
                return ServiceManager.audio?.sink?.description ?? ServiceManager.audio?.sink?.name ?? "-";
            }
        }
        StyledPopupValueRow {
            icon: NerdIconMap.mic
            label: "Input device"
            value: {
                const name = ServiceManager.audio?.friendlyDeviceName?.(ServiceManager.audio?.source)
                    ?? ServiceManager.audio?.source?.description
                    ?? ServiceManager.audio?.source?.name
                    ?? "-";
                const muted = ServiceManager.audio?.source?.audio?.muted ?? false;
                return name + (muted ? " (muted)" : "");
            }
        }
    }
}
