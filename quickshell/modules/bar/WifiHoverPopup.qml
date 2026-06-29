import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    StyledPopupContent {
        // 1. Connection state
        StyledPopupValueRow {
            icon: Network.nerdIcon
            label: Translation.tr("Internet:")
            value: {
                if (Network.ethernet) return Translation.tr("Connected (Ethernet)");
                if (Network.wifiStatus === "connected") return Translation.tr("Connected (Wi-Fi)");
                if (Network.wifiStatus === "connecting") return Translation.tr("Connecting...");
                if (Network.wifiStatus === "disconnected") return Translation.tr("Disconnected");
                if (Network.wifiStatus === "disabled") return Translation.tr("Disabled");
                return Network.wifiStatus;
            }
        }

        // 2. Active SSID
        StyledPopupValueRow {
            visible: Network.wifiStatus === "connected" && Network.networkName !== ""
            icon: NerdIconMap.wifi
            label: Translation.tr("SSID:")
            value: Network.networkName
        }

        // 3. Signal strength
        StyledPopupValueRow {
            visible: Network.wifiStatus === "connected" && !Network.ethernet
            icon: NerdIconMap.wifi
            label: Translation.tr("Signal Strength:")
            value: `${Network.networkStrength}%`
        }
    }
}
