import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    StyledPopupContent {
        StyledPopupValueRow {
            icon: NerdIconMap.keyboard
            label: "Keyboard:"
            value: KeyboardRemap.selectedDevice
                ? (KeyboardRemap.selectedProfile?.displayName ?? KeyboardRemap.selectedDeviceId)
                : "None detected"
        }

        StyledPopupValueRow {
            icon: KeyboardRemap.keydReady ? NerdIconMap.check : NerdIconMap.warning
            label: "keyd:"
            value: KeyboardRemap.keydReady ? "Running" : "Not ready"
        }

        StyledPopupValueRow {
            visible: KeyboardRemap.selectedDeviceId !== "" && !KeyboardRemap.selectedEnabled
            icon: NerdIconMap.block
            label: "Profile:"
            value: "Disabled"
        }

        Repeater {
            model: KeyboardRemap.selectedRemaps
            delegate: StyledPopupValueRow {
                required property int index
                required property var modelData
                icon: NerdIconMap.keyboard
                label: index === 0 ? "Remap:" : ""
                value: `${modelData.from} → ${modelData.to}`
            }
        }

        StyledPopupValueRow {
            visible: KeyboardRemap.selectedDeviceId !== "" && KeyboardRemap.selectedRemaps.length === 0
            icon: NerdIconMap.info
            label: "Remaps:"
            value: "None"
        }

        StyledPopupValueRow {
            icon: NerdIconMap.settings
            label: "Configure:"
            value: "Right-click"
        }
    }
}