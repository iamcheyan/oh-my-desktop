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

        StyledPopupValueRow {
            visible: KeyboardRemap.selectedDeviceId !== ""
            icon: NerdIconMap.settings
            label: "Presets:"
            value: {
                const n = KeyboardRemap.devicePresetCount(KeyboardRemap.selectedDeviceId)
                return n > 0 ? `${n} enabled` : "None"
            }
        }

        StyledPopupValueRow {
            icon: NerdIconMap.settings
            label: "Configure:"
            value: "Right-click"
        }
    }
}
