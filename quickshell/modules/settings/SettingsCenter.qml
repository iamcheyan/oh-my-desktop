import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

WindowDialog {
    id: root

    property string requestedPage: "overview"
    property string currentPage: normalizePage(requestedPage)
    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen) ?? ({ brightness: 0, setBrightness: function(){} })
    property string searchQuery: ""

    readonly property color cosmicBg: "#181818"
    readonly property color cosmicPanel: "#242424"
    readonly property color cosmicPanelAlt: "#2d2d2d"
    readonly property color cosmicPanelHover: "#343434"
    readonly property color cosmicCard: "#303030"
    readonly property color cosmicCardHover: "#393939"
    readonly property color cosmicButton: "#242424"
    readonly property color cosmicButtonHover: "#3d3d3d"
    readonly property color cosmicButtonActive: "#234249"
    readonly property color cosmicButtonBorder: "#4a4a4a"
    readonly property color cosmicFg: "#f4f4f4"
    readonly property color cosmicMuted: "#b8b8b8"
    readonly property color cosmicDim: "#878787"
    readonly property color cosmicLine: "#454545"
    readonly property color cosmicAccent: TuiStyle.accent
    readonly property color cosmicAccentSoft: OmarchyTheme.accentSoft
    readonly property int cosmicRadius: 8
    readonly property int cosmicRoundRadius: 12
    readonly property int shellInset: 10
    readonly property int pageInset: 24

    readonly property var pages: [
        { key: "overview", icon: "settings", title: "Overview", keywords: "system summary home" },
        { key: "network", icon: "wifi", title: "Network & Wireless", keywords: "wifi wireless lan internet ssid" },
        { key: "bluetooth", icon: "bluetooth", title: "Bluetooth", keywords: "bt adapter devices pair" },
        { key: "sound", icon: "volume_up", title: "Sound", keywords: "audio volume mute speaker microphone input output" },
        { key: "display", icon: "desktop_windows", title: "Displays", keywords: "screen brightness night light monitor resolution refresh scale" },
        { key: "appearance", icon: "palette", title: "Appearance", keywords: "theme wallpaper font color look style" },
        { key: "themes", icon: "format_paint", title: "Themes", keywords: "theme preview color wallpaper omarchy appearance" },
        { key: "power", icon: "battery_charging_full", title: "Power & Battery", keywords: "energy charging profile battery" },
        { key: "voice", icon: "keyboard_voice", title: "Voice Input", keywords: "speech transcribe sherpa microphone dictation record model keybinding diagnostic" },
        { key: "session", icon: "tune", title: "Session", keywords: "notifications clipboard sleep idle inhibit dnd" },
        { key: "windows", icon: "desktop_windows", title: "Windows VM", keywords: "virtualization virtual machine vm docker kvm rdp windows" }
    ]

    backgroundWidth: Math.min(1080, Math.max(920, width - 52))
    backgroundHeight: Math.min(720, Math.max(600, height - 96))
    anchorPosition: 0
    contentPadding: 0
    dismissOnBackgroundPress: false
    focus: true

    function normalizePage(page) {
        if (page === "wifi") return "network";
        if (page === "nightlight") return "display";
        if (page === "audio") return "sound";
        if (page === "battery") return "power";
        if (page === "settings") return "overview";
        if (page === "control") return "overview";
        if (page === "theme") return "appearance";
        if (page === "themes") return "themes";
        if (page === "font") return "appearance";
        if (page === "wallpaper") return "appearance";
        if (page === "virtualization") return "windows";
        if (page === "vm") return "windows";
        if (page === "windows-vm") return "windows";
        if (page === "notifications") return "session";
        if (page === "clipboard") return "session";
        if (page === "voice") return "voice";
        if (page === "idle") return "session";
        return page && page.length > 0 ? page : "overview";
    }

    function pageTitle(page) {
        const match = pages.find(item => item.key === page);
        return match ? match.title : "Overview";
    }

    function formatBatteryTime(seconds) {
        if (!Battery.available || seconds <= 0)
            return "--";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
    }

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    function parseKeyValue(text) {
        const result = {};
        const lines = String(text || "").split("\n");
        for (const line of lines) {
            const idx = line.indexOf("=");
            if (idx > 0)
                result[line.slice(0, idx)] = line.slice(idx + 1);
        }
        return result;
    }

    function fileUrl(path) {
        if (!path || path.length === 0) return "";
        return path.startsWith("file://") ? path : `file://${path}`;
    }

    readonly property var filteredPages: pages.filter(p => pageMatchesSearch(p))

    function pageMatchesSearch(pageEntry) {
        const q = root.searchQuery.trim().toLowerCase();
        if (q.length === 0) return true;
        if (pageEntry.title.toLowerCase().includes(q)) return true;
        if (pageEntry.keywords.toLowerCase().includes(q)) return true;
        if (pageEntry.key.toLowerCase().includes(q)) return true;
        return false;
    }

    onRequestedPageChanged: currentPage = normalizePage(requestedPage)
    onVisibleChanged: {
        if (visible) {
            currentPage = normalizePage(requestedPage);
            root.forceActiveFocus();
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
            root.dismiss();
            event.accepted = true;
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: TuiStyle.bg
        radius: TuiStyle.shellRadius
        border.width: TuiStyle.borderWidth
        border.color: TuiStyle.shellBorder
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.shellInset
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 274
                Layout.fillHeight: true
                radius: TuiStyle.shellRadius - root.shellInset
                color: root.cosmicPanel

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: parent.radius
                    color: parent.color
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 20
                        color: root.cosmicPanelAlt

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            MaterialSymbol {
                                text: "search"
                                iconSize: 18
                                color: root.cosmicAccent
                            }

                            TextField {
                                id: searchField
                                Layout.fillWidth: true
                                placeholderText: "Search settings"
                                placeholderTextColor: root.cosmicDim
                                color: root.cosmicFg
                                font.pixelSize: Appearance.font.pixelSize.small
                                background: Item {}
                                cursorVisible: focus
                                selectByMouse: true
                                onTextChanged: root.searchQuery = text
                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Escape) {
                                        if (text.length > 0) {
                                            text = "";
                                            event.accepted = true;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.preferredHeight: 4 }

                    StyledFlickable {
                        id: navScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: navColumn.implicitHeight + 8

                        ColumnLayout {
                            id: navColumn
                            width: navScroll.width
                            spacing: 4

                            Repeater {
                                model: root.filteredPages
                                delegate: SettingsNavItem {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    iconName: modelData.icon
                                    label: modelData.title
                                    selected: root.currentPage === modelData.key
                                    onClicked: root.currentPage = modelData.key
                                }
                            }

                            Item {
                                Layout.fillHeight: true
                                visible: root.filteredPages.length === 0
                                Layout.preferredHeight: 80
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: root.filteredPages.length === 0
                                text: "No matching settings"
                                color: root.cosmicDim
                                font.pixelSize: Appearance.font.pixelSize.small
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    SettingsButton {
                        Layout.fillWidth: true
                        label: "Reload Shell"
                        iconName: "refresh"
                        onClicked: Quickshell.reload(true)
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: root.cosmicLine
                opacity: 0.55
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: TuiStyle.shellRadius - root.shellInset
                color: root.cosmicBg
                clip: true

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: parent.radius
                    color: parent.color
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        id: titleBar
                        Layout.fillWidth: true
                        Layout.preferredHeight: 66
                        color: "transparent"

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            property real pressX: 0
                            property real pressY: 0
                            property real startOffsetX: 0
                            property real startOffsetY: 0
                            onPressed: (mouse) => {
                                pressX = mouse.x;
                                pressY = mouse.y;
                                startOffsetX = root.dragOffsetX;
                                startOffsetY = root.dragOffsetY;
                                root.dragging = true;
                            }
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    root.dragOffsetX += mouse.x - pressX;
                                    root.dragOffsetY += mouse.y - pressY;
                                }
                            }
                            onReleased: root.dragging = false
                            onCanceled: root.dragging = false
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 28
                            anchors.rightMargin: 18
                            spacing: 12

                            StyledText {
                                Layout.fillWidth: true
                                text: root.pageTitle(root.currentPage)
                                color: root.cosmicFg
                                font.pixelSize: Appearance.font.pixelSize.huge
                                font.weight: Font.DemiBold
                            }

                            SettingsIconButton {
                                iconName: "close"
                                onClicked: root.dismiss()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.cosmicLine
                        opacity: 0.55
                    }

                    StyledFlickable {
                        id: pageScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: pageLoader.item ? pageLoader.item.implicitHeight + root.pageInset * 2 : 0

                        Loader {
                            id: pageLoader
                            x: root.pageInset
                            y: root.pageInset
                            width: Math.max(0, pageScroll.width - root.pageInset * 2)
                            sourceComponent: {
                                if (root.currentPage === "network") return networkPage;
                                if (root.currentPage === "bluetooth") return bluetoothPage;
                                if (root.currentPage === "sound") return soundPage;
                                if (root.currentPage === "display") return displayPage;
                                if (root.currentPage === "appearance") return appearancePage;
                                if (root.currentPage === "themes") return themesPage;
                                if (root.currentPage === "power") return powerPage;
                                if (root.currentPage === "voice") return voicePage;
                                if (root.currentPage === "session") return sessionPage;
                                if (root.currentPage === "windows") return windowsPage;
                                return overviewPage;
                            }
                        }
                    }
                }
            }
        }
    }

    component PageBody: ColumnLayout {
        id: pageBodyRoot
        width: parent ? parent.width : 760
        spacing: 18
    }

    component SettingsNavItem: Rectangle {
        id: nav
        property string iconName: ""
        property string label: ""
        property bool selected: false
        signal clicked()

        Layout.preferredHeight: 38
        radius: root.cosmicRoundRadius
        color: selected ? root.cosmicAccentSoft : navMouse.containsMouse ? root.cosmicPanelAlt : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 12

            MaterialSymbol {
                text: nav.iconName
                iconSize: 18
                color: nav.selected ? root.cosmicAccent : root.cosmicMuted
            }

            StyledText {
                Layout.fillWidth: true
                text: nav.label
                color: nav.selected ? root.cosmicAccent : root.cosmicMuted
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: nav.selected ? Font.Medium : Font.Normal
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.clicked()
        }
    }

    component SettingsCard: Rectangle {
        id: card
        property string title: ""
        property string subtitle: ""
        default property alias content: contentColumn.children

        Layout.fillWidth: true
        implicitHeight: cardColumn.implicitHeight + 32
        radius: root.cosmicRoundRadius
        color: root.cosmicCard

        ColumnLayout {
            id: cardColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                visible: card.title.length > 0 || card.subtitle.length > 0
                spacing: 10

                StyledText {
                    Layout.fillWidth: true
                    text: card.title
                    color: root.cosmicFg
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: card.subtitle.length > 0
                    text: card.subtitle
                    color: root.cosmicMuted
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                id: contentColumn
                Layout.fillWidth: true
                spacing: 4
            }
        }
    }

    component SettingsRow: Rectangle {
        id: row
        property string iconName: ""
        property string label: ""
        property string description: ""
        property string value: ""
        property color valueColor: root.cosmicMuted
        property bool showChevron: false
        property int rightInset: 12
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 56
        radius: root.cosmicRadius
        color: rowMouse.containsMouse ? root.cosmicCardHover : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: row.rightInset
            spacing: 14

            MaterialSymbol {
                visible: row.iconName.length > 0
                Layout.preferredWidth: visible ? 22 : 0
                Layout.fillHeight: true
                text: row.iconName
                iconSize: 19
                color: root.cosmicMuted
            }

            ColumnLayout {
                id: rowText
                Layout.fillWidth: true
                spacing: 3

                StyledText {
                    Layout.fillWidth: true
                    text: row.label
                    color: root.cosmicFg
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: row.description.length > 0
                    Layout.fillWidth: true
                    text: row.description
                    color: root.cosmicDim
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }

            StyledText {
                id: valueText
                visible: row.value.length > 0
                Layout.preferredWidth: visible ? Math.min(180, implicitWidth) : 0
                Layout.fillHeight: true
                text: row.value
                color: row.valueColor
                font.pixelSize: Appearance.font.pixelSize.small
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            MaterialSymbol {
                visible: row.showChevron
                Layout.preferredWidth: visible ? 20 : 0
                Layout.fillHeight: true
                text: "chevron_right"
                iconSize: 20
                color: root.cosmicMuted
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.showChevron ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: row.clicked()
        }
    }

    component SettingsToggleRow: SettingsRow {
        id: toggleRow
        property bool checked: false
        signal toggled()

        value: ""
        rightInset: 70
        onClicked: toggled()

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: 26
            radius: height / 2
            color: toggleRow.checked ? root.cosmicAccent : "#5a5a5a"

            Rectangle {
                width: 20
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                x: toggleRow.checked ? parent.width - width - 3 : 3
                color: toggleRow.checked ? "#111111" : "#dedede"
                Behavior on x { NumberAnimation { duration: 110 } }
            }
        }
    }

    component SettingsButton: Rectangle {
        id: button
        property string label: ""
        property string iconName: ""
        property bool active: false
        property bool enabledState: true
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        Layout.minimumHeight: 42
        radius: root.cosmicRadius
        color: active ? root.cosmicButtonActive : buttonMouse.containsMouse ? root.cosmicButtonHover : root.cosmicButton
        border.width: 1
        border.color: active ? root.cosmicAccent : root.cosmicButtonBorder
        opacity: enabledState ? 1 : 0.45

        RowLayout {
            anchors.centerIn: parent
            spacing: 8

            MaterialSymbol {
                visible: button.iconName.length > 0
                text: button.iconName
                iconSize: 18
                color: button.active ? root.cosmicAccent : root.cosmicFg
            }

            StyledText {
                text: button.label
                color: button.active ? root.cosmicAccent : root.cosmicFg
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: button.enabledState
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component SettingsIconButton: Rectangle {
        id: iconButton
        property string iconName: ""
        signal clicked()

        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: root.cosmicRadius
        color: iconMouse.containsMouse ? root.cosmicPanelAlt : "transparent"

        MaterialSymbol {
            anchors.centerIn: parent
            text: iconButton.iconName
            iconSize: 17
            color: root.cosmicAccent
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconButton.clicked()
        }
    }

    component SettingsMeter: Rectangle {
        id: meter
        property real value: 0

        Layout.fillWidth: true
        Layout.preferredHeight: 8
        radius: height / 2
        color: "#202020"

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(parent.height, parent.width * root.clamp(meter.value, 0, 100) / 100)
            radius: height / 2
            color: root.cosmicAccent
        }
    }

    component SettingsStatusPill: Rectangle {
        id: pill
        property string label: ""
        property bool active: false
        property bool warning: false

        Layout.preferredHeight: 28
        Layout.preferredWidth: pillText.implicitWidth + 24
        radius: height / 2
        color: active ? root.cosmicAccentSoft : warning ? "#3a3020" : root.cosmicButton
        border.width: 1
        border.color: active ? root.cosmicAccent : warning ? "#8f805d" : root.cosmicButtonBorder

        StyledText {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.active ? root.cosmicAccent : root.cosmicMuted
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Medium
        }
    }

    component SettingsSlider: Slider {
        id: sliderRoot
        property color trackColor: "#202020"
        property color highlightColor: root.cosmicAccent
        property color handleColor: root.cosmicFg

        Layout.fillWidth: true
        Layout.preferredHeight: 28
        from: 0
        to: 1
        leftPadding: 0
        rightPadding: 0

        background: Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            width: sliderRoot.width
            implicitHeight: 8
            radius: height / 2
            color: sliderRoot.trackColor

            Rectangle {
                width: sliderRoot.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: sliderRoot.highlightColor
            }
        }

        handle: Rectangle {
            x: sliderRoot.visualPosition * (sliderRoot.width - width)
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 18
            implicitHeight: 18
            radius: height / 2
            color: sliderRoot.handleColor
            border.width: 2
            border.color: sliderRoot.pressed ? sliderRoot.highlightColor : "#555"
            Behavior on border.color { ColorAnimation { duration: 100 } }
        }
    }

    component ButtonRow: RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        spacing: 10
    }

    Component {
        id: overviewPage
        PageBody {
            SettingsCard {
                title: "System"
                subtitle: "Current session"
                SettingsRow { iconName: "battery_charging_full"; label: "Battery"; value: Battery.available ? `${Math.round(Battery.percentage * 100)}%` : "--" }
                SettingsRow { iconName: "speed"; label: "Power profile"; value: PowerProfiles.currentProfile }
                SettingsRow { iconName: "wifi"; label: "Network"; value: Network.networkName || Network.wifiStatus }
                SettingsRow { iconName: "volume_up"; label: "Audio"; value: `${Math.round((Audio.sink?.audio.volume ?? 0) * 100)}%` }
                SettingsRow { iconName: "memory"; label: "Memory"; value: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%` }
                SettingsRow { iconName: "developer_board"; label: "CPU"; value: `${Math.round(ResourceUsage.cpuUsage)}%` }
            }

            SettingsCard {
                title: "Quick Links"
                subtitle: "Open a category"
                ButtonRow {
                    SettingsButton { label: "Network"; iconName: "wifi"; onClicked: root.currentPage = "network" }
                    SettingsButton { label: "Display"; iconName: "desktop_windows"; onClicked: root.currentPage = "display" }
                    SettingsButton { label: "Themes"; iconName: "format_paint"; onClicked: root.currentPage = "themes" }
                }
            }
        }
    }

    Component {
        id: networkPage
        PageBody {
            SettingsCard {
                title: "Wi-Fi"
                subtitle: Network.wifiScanning ? "Scanning" : Network.wifiStatus
                SettingsToggleRow {
                    label: "Wireless radio"
                    description: "Enable or disable the Wi-Fi adapter"
                    checked: Network.wifiEnabled
                    onToggled: Network.toggleWifi()
                }
                SettingsRow { label: "SSID"; value: Network.active?.ssid || Network.networkName || "--" }
                SettingsRow { label: "Signal"; value: Network.active ? `${Network.active.strength}%` : "--" }
                ButtonRow {
                    SettingsButton { label: "Scan"; iconName: "refresh"; onClicked: Network.rescanWifi() }
                    SettingsButton { label: "Connection Editor"; iconName: "edit"; onClicked: Quickshell.execDetached(["nm-connection-editor"]) }
                }
            }

            SettingsCard {
                title: "Visible Networks"
                subtitle: `${Network.friendlyWifiNetworks.length} found`
                Repeater {
                    model: Network.friendlyWifiNetworks.slice(0, 8)
                    delegate: SettingsRow {
                        required property var modelData
                        iconName: modelData.active ? "wifi" : "network_wifi"
                        label: modelData.ssid || "--"
                        description: Network.isKnownWifi(modelData) ? "Known network" : "New network"
                        value: modelData.active ? "Connected" : `${modelData.strength}%`
                        valueColor: modelData.active ? root.cosmicAccent : root.cosmicMuted
                        showChevron: !modelData.active
                        onClicked: {
                            if (!modelData.active && modelData.ssid)
                                Network.connectToWifiNetwork(modelData);
                        }
                    }
                }
            }
        }
    }

    Component {
        id: bluetoothPage
        PageBody {
            SettingsCard {
                title: "Bluetooth"
                subtitle: BluetoothStatus.enabled ? "Enabled" : "Disabled"
                SettingsToggleRow {
                    label: "Adapter power"
                    description: "Turn Bluetooth discovery and device connections on or off"
                    checked: BluetoothStatus.enabled
                    onToggled: {
                        if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                    }
                }
                SettingsRow { label: "Connected devices"; value: `${BluetoothStatus.activeDeviceCount}` }
                SettingsRow { label: "Current device"; value: BluetoothStatus.firstActiveDevice?.name || "--" }
            }

            SettingsCard {
                title: "Devices"
                subtitle: `${BluetoothStatus.friendlyDeviceList.length} entries`
                Repeater {
                    model: BluetoothStatus.friendlyDeviceList.slice(0, 8)
                    delegate: SettingsRow {
                        required property var modelData
                        iconName: "bluetooth"
                        label: modelData.name || modelData.address || "--"
                        value: modelData.connected ? "Connected" : modelData.paired ? "Paired" : "New"
                        valueColor: modelData.connected ? root.cosmicAccent : root.cosmicMuted
                        showChevron: modelData.paired
                        onClicked: {
                            if (modelData.connected)
                                modelData.disconnect();
                            else
                                modelData.connect();
                        }
                    }
                }
            }
        }
    }

    Component {
        id: soundPage
        PageBody {
            SettingsCard {
                title: "Output"
                subtitle: Audio.sink?.audio.muted ? "Muted" : `${Math.round((Audio.sink?.audio.volume ?? 0) * 100)}%`
                SettingsSlider {
                    value: Audio.sink?.audio.muted ? 0 : (Audio.sink?.audio.volume ?? 0)
                    onValueChanged: {
                        if (Audio.sink && !Audio.sink.audio.muted)
                            Audio.sink.audio.volume = value;
                    }
                }
                SettingsToggleRow {
                    label: "Mute output"
                    description: Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : "No output device"
                    checked: Audio.sink?.audio.muted ?? false
                    onToggled: Audio.toggleMute()
                }
            }

            SettingsCard {
                title: "Input"
                subtitle: Audio.source?.audio.muted ? "Muted" : `${Math.round((Audio.source?.audio.volume ?? 0) * 100)}%`
                SettingsSlider {
                    value: Audio.source?.audio.muted ? 0 : (Audio.source?.audio.volume ?? 0)
                    onValueChanged: {
                        if (Audio.source && !Audio.source.audio.muted)
                            Audio.source.audio.volume = value;
                    }
                }
                SettingsToggleRow {
                    label: "Mute microphone"
                    description: Audio.source ? Audio.friendlyDeviceName(Audio.source) : "No input device"
                    checked: Audio.source?.audio.muted ?? false
                    onToggled: Audio.toggleMicMute()
                }
            }
        }
    }

    Component {
        id: displayPage
        PageBody {
            SettingsCard {
                title: "Display"
                subtitle: `${Math.round(root.brightnessMonitor.brightness * 100)}% brightness`
                SettingsMeter { value: root.brightnessMonitor.brightness * 100 }
                ButtonRow {
                    SettingsButton { label: "Dim"; iconName: "remove"; onClicked: root.brightnessMonitor.setBrightness(root.clamp(root.brightnessMonitor.brightness - 0.05, 0, 1)) }
                    SettingsButton { label: "Brighten"; iconName: "add"; onClicked: root.brightnessMonitor.setBrightness(root.clamp(root.brightnessMonitor.brightness + 0.05, 0, 1)) }
                }
            }

            SettingsCard {
                title: "Night Light"
                subtitle: Hyprsunset.temperatureActive ? "Enabled" : "Disabled"
                SettingsToggleRow {
                    label: "Night light"
                    description: `${Math.round(Config.options.light.night.colorTemperature)}K`
                    checked: Hyprsunset.temperatureActive
                    onToggled: Hyprsunset.toggleTemperature(!Hyprsunset.temperatureActive)
                }
            }

            SettingsCard {
                title: "Monitors"
                subtitle: `${HyprlandData.monitors.length} display(s)`
                Repeater {
                    model: HyprlandData.monitors
                    delegate: SettingsRow {
                        required property var modelData
                        iconName: "desktop_windows"
                        label: modelData.name || modelData.description || "--"
                        value: `${modelData.width}×${modelData.height}@${Math.round(modelData.refreshRate)}Hz · ${modelData.scale}x`
                    }
                }
            }
        }
    }

    Component {
        id: appearancePage
        PageBody {
            QtObject {
                id: wpState
                property string mode: "file"
                property string source: ""
                property string current: ""
                property string interval: "1800"
                property int imageCount: 0

                readonly property bool isFolder: mode === "folder"
                readonly property string intervalLabel: {
                    const sec = parseInt(interval) || 1800
                    if (sec >= 3600) return `${Math.round(sec / 3600)}h`
                    if (sec >= 60) return `${Math.round(sec / 60)}m`
                    return `${sec}s`
                }

                function refresh() {
                    wallpaperStatusProc.running = true
                }
            }

            SettingsCard {
                title: "Wallpaper"
                subtitle: wpState.isFolder ? "Folder rotation" : "Single image"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 210
                        Layout.preferredHeight: 118
                        radius: root.cosmicRadius
                        color: root.cosmicButton
                        clip: true

                        Image {
                            id: wallpaperPreview
                            anchors.fill: parent
                            source: root.fileUrl(wpState.current)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: source.toString().length > 0 && wpState.current.length > 0
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: root.cosmicButton
                            visible: !wallpaperPreview.visible

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: wpState.isFolder ? "folder" : "image"
                                iconSize: 36
                                color: root.cosmicDim
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            width: modeBadge.implicitWidth + 16
                            height: 22
                            radius: 11
                            color: wpState.isFolder ? root.cosmicAccentSoft : "#3a3a3a"
                            border.width: 1
                            border.color: wpState.isFolder ? root.cosmicAccent : "#555"

                            Row {
                                id: modeBadge
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    text: wpState.isFolder ? "folder" : "image"
                                    iconSize: 13
                                    color: wpState.isFolder ? root.cosmicAccent : root.cosmicMuted
                                }

                                StyledText {
                                    text: wpState.isFolder ? "Folder" : "Image"
                                    color: wpState.isFolder ? root.cosmicAccent : root.cosmicMuted
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            text: wpState.source.length > 0 ? FileUtils.fileNameForPath(wpState.source) : "No wallpaper set"
                            color: root.cosmicFg
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: wpState.source.length > 0
                            text: wpState.source
                            color: root.cosmicDim
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: wpState.isFolder && wpState.imageCount > 0
                            text: `${wpState.imageCount} images · rotates every ${wpState.intervalLabel}`
                            color: root.cosmicMuted
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }

                ButtonRow {
                    SettingsButton {
                        label: "Choose Image"
                        iconName: "image"
                        active: !wpState.isFolder
                        onClicked: Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-wallpaper pick-file && sleep 1 && $HOME/.config/omd/bin/omd-wallpaper status > /dev/null"])
                    }
                    SettingsButton {
                        label: "Choose Folder"
                        iconName: "folder"
                        active: wpState.isFolder
                        onClicked: Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-wallpaper pick-folder && sleep 1 && $HOME/.config/omd/bin/omd-wallpaper status > /dev/null"])
                    }
                }

                ButtonRow {
                    visible: wpState.isFolder
                    SettingsButton {
                        label: "Next Image"
                        iconName: "skip_next"
                        onClicked: {
                            Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-wallpaper random"])
                            wpRefreshTimer.restart()
                        }
                    }
                    SettingsButton {
                        label: "Stop Rotation"
                        iconName: "stop"
                        onClicked: {
                            Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-wallpaper stop"])
                            wpRefreshTimer.restart()
                        }
                    }
                }
            }

            Timer {
                id: wpRefreshTimer
                interval: 1500
                repeat: false
                onTriggered: wpState.refresh()
            }

            Timer {
                interval: 5000
                repeat: true
                running: true
                onTriggered: wpState.refresh()
            }

            Process {
                id: wallpaperStatusProc
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-wallpaper status 2>/dev/null || true"]
                running: true
                stdout: StdioCollector {
                    id: wallpaperStatusCollector
                    onStreamFinished: {
                        const data = root.parseKeyValue(wallpaperStatusCollector.text)
                        wpState.mode = data.mode || "file"
                        wpState.source = data.source || ""
                        wpState.current = data.current || ""
                        wpState.interval = data.interval || "1800"
                        if (wpState.isFolder && wpState.source.length > 0) {
                            wallpaperCountProc.running = true
                        } else {
                            wpState.imageCount = 0
                        }
                    }
                }
            }

            Process {
                id: wallpaperCountProc
                command: ["bash", "-c", `find -L '${wpState.source}' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \\) 2>/dev/null | wc -l`]
                stdout: StdioCollector {
                    id: wallpaperCountCollector
                    onStreamFinished: {
                        wpState.imageCount = parseInt(wallpaperCountCollector.text.trim()) || 0
                    }
                }
            }

            SettingsCard {
                title: "Font"
                subtitle: "Monospace family"
                SettingsRow {
                    label: "Current font"
                    value: appearanceState.currentFont.length > 0 ? appearanceState.currentFont : "--"
                }
            }

            QtObject {
                id: appearanceState
                property string currentTheme: ""
                property string currentFont: ""
            }

            Process {
                id: themeCurrentProc
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-theme current"]
                running: true
                stdout: StdioCollector {
                    id: themeCurrentCollector
                    onStreamFinished: {
                        const data = root.parseKeyValue(themeCurrentCollector.text);
                        appearanceState.currentTheme = data.name || "Unknown";
                    }
                }
            }

            Process {
                id: fontCurrentProc
                command: ["bash", "-c", "omarchy-font-current 2>/dev/null || echo 'JetBrains Mono'"]
                running: true
                stdout: StdioCollector {
                    id: fontCurrentCollector
                    onStreamFinished: {
                        appearanceState.currentFont = fontCurrentCollector.text.trim();
                    }
                }
            }
        }
    }

    Component {
        id: themesPage
        PageBody {
            QtObject {
                id: themeState
                property var themes: []
                property string currentSlug: ""
                property string currentName: "Loading..."
                property string currentAccent: root.cosmicAccent
                property string currentBackground: root.cosmicButton
                property string currentForeground: root.cosmicFg
                property string applyingSlug: ""

                function refresh() {
                    themeListProc.running = true;
                    themeCurrentProc2.running = true;
                }

                function apply(slug) {
                    if (!slug || slug.length === 0 || applyingSlug.length > 0)
                        return;
                    applyingSlug = slug;
                    themeApplyProc.command = ["bash", "-c", `$HOME/.config/omd/bin/omd-settings-theme apply '${slug.replace(/'/g, "'\\''")}'`];
                    themeApplyProc.running = true;
                }
            }

            SettingsCard {
                title: "Current Theme"
                subtitle: themeState.currentName

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    Rectangle {
                        Layout.preferredWidth: 260
                        Layout.preferredHeight: 132
                        radius: root.cosmicRadius
                        color: themeState.currentBackground || root.cosmicButton
                        border.width: 1
                        border.color: themeState.currentAccent || root.cosmicButtonBorder
                        clip: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 6
                            color: themeState.currentAccent || root.cosmicAccent
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 22
                            anchors.rightMargin: 16
                            anchors.topMargin: 16
                            anchors.bottomMargin: 16
                            spacing: 12

                            StyledText {
                                Layout.fillWidth: true
                                text: themeState.currentName
                                color: themeState.currentForeground || root.cosmicFg
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: [themeState.currentAccent || root.cosmicAccent, themeState.currentForeground || root.cosmicFg, themeState.currentBackground || "#000000"]
                                    delegate: Rectangle {
                                        required property string modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 24
                                        radius: 12
                                        color: modelData
                                        border.width: 1
                                        border.color: root.cosmicButtonBorder
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignBottom
                                text: themeState.currentSlug
                                color: themeState.currentForeground || root.cosmicDim
                                opacity: 0.72
                                font.pixelSize: Appearance.font.pixelSize.small
                                elide: Text.ElideRight
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ButtonRow {
                            SettingsButton {
                                label: "Refresh"
                                iconName: "refresh"
                                onClicked: themeState.refresh()
                            }
                            SettingsButton {
                                label: "Open Theme Folder"
                                iconName: "folder"
                                onClicked: Quickshell.execDetached(["xdg-open", `${FileUtils.trimFileProtocol(Directories.config)}/omarchy/current/theme`])
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "Theme previews are generated from colors.toml, so themes do not need screenshots."
                            color: root.cosmicDim
                            wrapMode: Text.WordWrap
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
            }

            SettingsCard {
                title: "Available Themes"
                subtitle: `${themeState.themes.length} entries`

                Flow {
                    id: themeFlow
                    Layout.fillWidth: true
                    spacing: 12

                    Repeater {
                        model: themeState.themes
                        delegate: Rectangle {
                            required property var modelData

                            width: Math.max(220, Math.floor((themeFlow.width - themeFlow.spacing) / 2))
                            height: 134
                            radius: root.cosmicRoundRadius
                            color: modelData.background || root.cosmicButton
                            border.width: modelData.current ? 2 : 1
                            border.color: modelData.current ? root.cosmicAccent : root.cosmicButtonBorder
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                color: themeMouse.containsMouse ? root.cosmicCardHover : "transparent"
                                opacity: themeMouse.containsMouse ? 0.18 : 0
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 5
                                color: modelData.accent || root.cosmicAccent
                            }

                            ColumnLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 18
                                anchors.rightMargin: 14
                                anchors.topMargin: 14
                                anchors.bottomMargin: 12
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: modelData.foreground || root.cosmicFg
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    SettingsStatusPill {
                                        visible: modelData.current || themeState.applyingSlug === modelData.slug
                                        label: themeState.applyingSlug === modelData.slug ? "Applying" : "Current"
                                        active: true
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.slug
                                    color: modelData.foreground || root.cosmicDim
                                    opacity: 0.62
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                }

                                Item {
                                    Layout.fillHeight: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: [modelData.accent || root.cosmicAccent, modelData.foreground || root.cosmicFg, modelData.background || "#000000"]
                                        delegate: Rectangle {
                                            required property string modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 20
                                            radius: 10
                                            color: modelData
                                            border.width: 1
                                            border.color: root.cosmicButtonBorder
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: themeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: themeState.apply(modelData.slug)
                            }
                        }
                    }
                }
            }

            Process {
                id: themeListProc
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-theme list"]
                running: true
                stdout: StdioCollector {
                    id: themeListCollector2
                    onStreamFinished: {
                        const entries = [];
                        for (const line of themeListCollector2.text.trim().split("\n")) {
                            if (line.length === 0) continue;
                            const parts = line.split("\t");
                            entries.push({
                                slug: parts[0] || "",
                                name: parts[1] || parts[0] || "",
                                preview: parts[2] || "",
                                current: (parts[3] || "") === "current",
                                accent: parts[4] || "",
                                background: parts[5] || "",
                                foreground: parts[6] || ""
                            });
                        }
                        themeState.themes = entries;
                    }
                }
            }

            Process {
                id: themeCurrentProc2
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-theme current"]
                running: true
                stdout: StdioCollector {
                    id: themeCurrentCollector2
                    onStreamFinished: {
                        const data = root.parseKeyValue(themeCurrentCollector2.text);
                        themeState.currentSlug = data.slug || "";
                        themeState.currentName = data.name || "Unknown";
                        themeState.currentAccent = data.accent || root.cosmicAccent;
                        themeState.currentBackground = data.background || root.cosmicButton;
                        themeState.currentForeground = data.foreground || root.cosmicFg;
                    }
                }
            }

            Process {
                id: themeApplyProc
                running: false
                onExited: (exitCode, exitStatus) => {
                    OmarchyTheme.reload();
                    themeState.applyingSlug = "";
                    themeState.refresh();
                }
            }
        }
    }

    Component {
        id: powerPage
        PageBody {
            SettingsCard {
                title: "Battery"
                subtitle: Battery.isCharging ? "Charging" : Battery.isPluggedIn ? "Plugged in" : "Battery"
                SettingsMeter { value: Battery.available ? Battery.percentage * 100 : 0 }
                SettingsRow { label: "Level"; value: Battery.available ? `${Math.round(Battery.percentage * 100)}%` : "--" }
                SettingsRow { label: Battery.isCharging ? "Time to full" : "Time to empty"; value: root.formatBatteryTime(Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty) }
                SettingsRow { label: "Power"; value: Battery.energyRate > 0.01 ? `${Battery.energyRate.toFixed(1)}W` : "--" }
                SettingsRow { label: "Health"; value: Battery.healthPercentage > 0 ? `${Battery.healthPercentage.toFixed(1)}%` : "--" }
            }

            SettingsCard {
                title: "Power Profile"
                subtitle: PowerProfiles.currentProfile
                ButtonRow {
                    SettingsButton { label: "Saver"; active: PowerProfiles.currentProfile === "power-saver"; onClicked: PowerProfiles.setProfile("power-saver") }
                    SettingsButton { label: "Balanced"; active: PowerProfiles.currentProfile === "balanced"; onClicked: PowerProfiles.setProfile("balanced") }
                    SettingsButton { label: "Performance"; active: PowerProfiles.currentProfile === "performance"; onClicked: PowerProfiles.setProfile("performance") }
                }
            }
        }
    }

    Component {
        id: sessionPage
        PageBody {
            SettingsCard {
                title: "Notifications"
                subtitle: `${Notifications.list.length} entries`
                SettingsToggleRow {
                    label: "Do not disturb"
                    description: "Suppress notification alerts"
                    checked: Notifications.silent
                    onToggled: Notifications.silent = !Notifications.silent
                }
                ButtonRow {
                    SettingsButton { label: "Mark Read"; iconName: "done_all"; onClicked: Notifications.markAllRead() }
                    SettingsButton { label: "Clear Timeouts"; iconName: "clear_all"; onClicked: Notifications.timeoutAll() }
                }
            }

            SettingsCard {
                title: "Clipboard"
                subtitle: `${Cliphist.entries.length} entries`
                SettingsRow {
                    label: "Latest item"
                    description: Cliphist.entries.length > 0 ? StringUtils.cleanCliphistEntry(Cliphist.entries[0]).slice(0, 120) : "--"
                }
                ButtonRow {
                    SettingsButton { label: "Open Picker"; iconName: "content_paste"; onClicked: Quickshell.execDetached(["qs", "-p", `${FileUtils.trimFileProtocol(Directories.config)}/omd/apps/omd-clipboard`, "ipc", "call", "clipboard", "toggle"]) }
                    SettingsButton { label: "Refresh"; iconName: "refresh"; onClicked: Cliphist.refresh() }
                }
            }

            SettingsCard {
                title: "Session Behavior"
                subtitle: "Idle and sleep"
                SettingsToggleRow {
                    label: "Prevent sleep"
                    description: "Keep the current session awake"
                    checked: Idle.inhibit
                    onToggled: Idle.toggleInhibit()
                }
            }
        }
    }

    Component {
        id: voicePage
        PageBody {
            readonly property string omdRoot: `${FileUtils.trimFileProtocol(Directories.config)}/omd`
            property var voicePageBindings: []

            SettingsCard {
                title: "Voice Engine"
                subtitle: VoiceInput.state === "setup" ? "Needs setup" : VoiceInput.daemonRunning ? "Daemon running" : "Daemon idle"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SettingsStatusPill { label: VoiceInput.state === "idle" ? "ready" : VoiceInput.state; active: VoiceInput.state === "idle" }
                    SettingsStatusPill { label: VoiceInput.modelSizeMB > 0 ? `${VoiceInput.modelSizeMB} MB model` : "no model"; active: VoiceInput.modelSizeMB > 0; warning: VoiceInput.modelSizeMB === 0 }
                    SettingsStatusPill { label: VoiceInput.daemonRunning ? "daemon up" : "daemon down"; active: VoiceInput.daemonRunning }
                }

                SettingsRow {
                    label: "Engine state"
                    value: VoiceInput.state
                }
                SettingsRow {
                    label: "Last result"
                    description: VoiceInput.lastTranscription.length > 0 ? VoiceInput.lastTranscription.slice(0, 100) : "--"
                }
                SettingsRow {
                    visible: VoiceInput.lastError.length > 0
                    label: "Last error"
                    description: VoiceInput.lastError
                }

                ButtonRow {
                    SettingsButton {
                        label: VoiceInput.state === "recording" ? "Stop" : VoiceInput.state === "transcribing" ? "Transcribing…" : "Record"
                        iconName: "keyboard_voice"
                        enabledState: VoiceInput.state === "idle" || VoiceInput.state === "recording"
                        active: VoiceInput.state === "recording"
                        onClicked: VoiceInput.toggle()
                    }
                    SettingsButton {
                        label: VoiceInput.state === "setup" ? "Setup" : "Recheck"
                        iconName: "download"
                        onClicked: {
                            if (VoiceInput.state === "setup")
                                VoiceInput.setup()
                            else
                                VoiceInput.checkState()
                        }
                    }
                }
            }

            SettingsCard {
                title: "Keybindings"
                subtitle: voicePageBindings.length > 0 ? `${voicePageBindings.length} active` : "No bindings"

                Repeater {
                    model: voicePageBindings
                    delegate: SettingsRow {
                        required property var modelData
                        iconName: "keyboard"
                        label: modelData
                    }
                }

                ButtonRow {
                    SettingsButton {
                        label: "Configure"
                        iconName: "settings"
                        onClicked: Quickshell.execDetached(["omarchy-launch-tui", `${omdRoot}/scripts/voice-bind-tui`])
                    }
                    SettingsButton {
                        label: "Capture Key"
                        iconName: "keyboard"
                        onClicked: Quickshell.execDetached([`${omdRoot}/scripts/key-test`])
                    }
                }

            }

            Process {
                id: voiceBindingsProc
                command: ["bash", "-c", "cat ~/.config/omarchy/voice_bindings.txt 2>/dev/null || echo ''"]
                running: true
                stdout: StdioCollector {
                    id: voiceBindingsCollector
                    onStreamFinished: {
                        const text = voiceBindingsCollector.text.trim()
                        voicePageBindings = text.length > 0
                            ? text.split("\n").filter(l => l.length > 0 && !l.startsWith("#"))
                            : []
                    }
                }
            }

            SettingsCard {
                title: "Test & Diagnostics"
                subtitle: "Verify recording and troubleshoot"

                ButtonRow {
                    SettingsButton {
                        label: "Quick Test"
                        iconName: "mic"
                        enabledState: VoiceInput.state === "idle"
                        onClicked: VoiceInput.testRecording()
                    }
                    SettingsButton {
                        label: "TUI Test"
                        iconName: "terminal"
                        onClicked: Quickshell.execDetached(["omarchy-launch-tui", `${omdRoot}/scripts/voice-test-tui`])
                    }
                }
                ButtonRow {
                    SettingsButton {
                        label: "Diagnose"
                        iconName: "health_and_safety"
                        onClicked: Quickshell.execDetached(["omarchy-launch-tui", `${omdRoot}/scripts/voice-diagnose`])
                    }
                    SettingsButton {
                        label: "Clear History"
                        iconName: "clear_all"
                        onClicked: VoiceInput.clearHistory()
                    }
                }
            }

            SettingsCard {
                title: "History"
                subtitle: `${VoiceInput.history.length} entries`
                visible: VoiceInput.history.length > 0

                Repeater {
                    model: VoiceInput.history.slice(0, 8)
                    delegate: SettingsRow {
                        required property var modelData
                        iconName: "history"
                        label: modelData.text ? modelData.text.slice(0, 80) : "--"
                        value: modelData.time || ""
                    }
                }
            }

            SettingsCard {
                title: "Paths & Cache"
                subtitle: "Runtime directories"
                SettingsRow { label: "Cache dir"; value: VoiceInput.cacheDir }
                SettingsRow { label: "Model dir"; value: VoiceInput.modelDir }
                SettingsRow { label: "Venv dir"; value: VoiceInput.venvDir }
                SettingsRow { label: "Socket"; value: "/tmp/omd-voice.sock" }
            }
        }
    }

    Component {
        id: windowsPage
        PageBody {
            QtObject {
                id: windowsState
                property bool configured: false
                property bool kvm: false
                property bool dockerCli: false
                property bool dockerRunning: false
                property bool compose: false
                property string container: "missing"
                property string web: "http://127.0.0.1:8006"
                property string composeFile: `${FileUtils.trimFileProtocol(Directories.home)}/.config/windows/docker-compose.yml`
                property string storageDir: `${FileUtils.trimFileProtocol(Directories.home)}/.windows`
                property string sharedDir: `${FileUtils.trimFileProtocol(Directories.home)}/Windows`
                property string ram: ""
                property string cpu: ""
                property string disk: ""
                property string user: ""
                property string pendingDanger: ""

                readonly property bool running: container === "running"
                readonly property string displayStatus: !configured ? "Not installed" : running ? "Running" : container === "missing" ? "Configured" : container

                function refresh() {
                    windowsStatusProc.running = true;
                }

                function run(action) {
                    windowsActionProc.command = ["bash", "-c", `$HOME/.config/omd/bin/omd-settings-windows-vm ${action}`];
                    windowsActionProc.running = true;
                }

                function launch(keepAlive) {
                    Quickshell.execDetached(["bash", "-c", `$HOME/.config/omd/bin/omd-settings-windows-vm ${keepAlive ? "launch-keepalive" : "launch"}`]);
                }
            }

            SettingsCard {
                title: "Windows VM"
                subtitle: windowsState.displayStatus

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SettingsStatusPill { label: windowsState.configured ? "configured" : "not installed"; active: windowsState.configured }
                    SettingsStatusPill { label: windowsState.kvm ? "KVM ready" : "KVM missing"; active: windowsState.kvm; warning: !windowsState.kvm }
                    SettingsStatusPill { label: windowsState.dockerRunning ? "Docker running" : windowsState.dockerCli ? "Docker stopped" : "Docker missing"; active: windowsState.dockerRunning; warning: !windowsState.dockerRunning }
                    SettingsStatusPill { label: windowsState.compose ? "Compose ready" : "Compose missing"; active: windowsState.compose; warning: !windowsState.compose }
                }

                SettingsRow {
                    label: "Container"
                    description: "Docker container: omarchy-windows"
                    value: windowsState.container
                    valueColor: windowsState.running ? root.cosmicAccent : root.cosmicMuted
                }
                SettingsRow {
                    label: "Web console"
                    description: "Browser console for installation and emergency access"
                    value: windowsState.web
                    showChevron: true
                    onClicked: windowsState.run("web")
                }
            }

            SettingsCard {
                title: "Actions"
                subtitle: "Large downloads and destructive operations are confirmed"

                ButtonRow {
                    SettingsButton {
                        label: windowsState.configured ? "Reinstall" : "Install"
                        iconName: "download"
                        active: windowsState.pendingDanger === "install"
                        onClicked: {
                            if (windowsState.pendingDanger === "install") {
                                windowsState.pendingDanger = "";
                                Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm install"]);
                            } else {
                                windowsState.pendingDanger = "install";
                            }
                        }
                    }
                    SettingsButton {
                        label: "Connect"
                        iconName: "login"
                        enabledState: windowsState.configured
                        onClicked: windowsState.launch(false)
                    }
                    SettingsButton {
                        label: "Keep Alive"
                        iconName: "keep"
                        enabledState: windowsState.configured
                        onClicked: windowsState.launch(true)
                    }
                }

                ButtonRow {
                    SettingsButton {
                        label: "Stop"
                        iconName: "stop"
                        enabledState: windowsState.configured && windowsState.container !== "missing"
                        onClicked: windowsState.run("stop")
                    }
                    SettingsButton {
                        label: "Open Console"
                        iconName: "open_in_browser"
                        enabledState: windowsState.configured
                        onClicked: windowsState.run("web")
                    }
                    SettingsButton {
                        label: windowsState.pendingDanger === "remove" ? "Confirm Delete" : "Remove"
                        iconName: "delete"
                        active: windowsState.pendingDanger === "remove"
                        enabledState: windowsState.configured
                        onClicked: {
                            if (windowsState.pendingDanger === "remove") {
                                windowsState.pendingDanger = "";
                                Quickshell.execDetached(["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm remove"]);
                            } else {
                                windowsState.pendingDanger = "remove";
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: windowsState.pendingDanger.length > 0
                    text: windowsState.pendingDanger === "remove"
                        ? "Remove opens a terminal confirmation and deletes the VM data if confirmed there."
                        : "Install opens an interactive terminal, downloads Windows, and allocates disk space."
                    color: root.cosmicMuted
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }

            SettingsCard {
                title: "Configuration"
                subtitle: windowsState.configured ? "Generated by omarchy-windows-vm" : "Created during install"
                SettingsRow { label: "Compose file"; value: windowsState.composeFile }
                SettingsRow { label: "Storage"; value: windowsState.storageDir }
                SettingsRow { label: "Shared folder"; value: windowsState.sharedDir }
                SettingsRow { label: "RAM"; value: windowsState.ram.length > 0 ? windowsState.ram : "--" }
                SettingsRow { label: "CPU cores"; value: windowsState.cpu.length > 0 ? windowsState.cpu : "--" }
                SettingsRow { label: "Disk"; value: windowsState.disk.length > 0 ? windowsState.disk : "--" }
                SettingsRow { label: "Windows user"; value: windowsState.user.length > 0 ? windowsState.user : "--" }
            }

            Timer {
                interval: 8000
                repeat: true
                running: true
                onTriggered: windowsState.refresh()
            }

            Process {
                id: windowsStatusProc
                command: ["bash", "-c", "$HOME/.config/omd/bin/omd-settings-windows-vm status"]
                running: true
                stdout: StdioCollector {
                    id: windowsStatusCollector
                    onStreamFinished: {
                        const data = root.parseKeyValue(windowsStatusCollector.text);
                        windowsState.configured = data.configured === "true";
                        windowsState.kvm = data.kvm === "true";
                        windowsState.dockerCli = data.dockerCli === "true";
                        windowsState.dockerRunning = data.dockerRunning === "true";
                        windowsState.compose = data.compose === "true";
                        windowsState.container = data.container || "missing";
                        windowsState.web = data.web || "http://127.0.0.1:8006";
                        windowsState.composeFile = data.composeFile || windowsState.composeFile;
                        windowsState.storageDir = data.storageDir || windowsState.storageDir;
                        windowsState.sharedDir = data.sharedDir || windowsState.sharedDir;
                        windowsState.ram = data.ram || "";
                        windowsState.cpu = data.cpu || "";
                        windowsState.disk = data.disk || "";
                        windowsState.user = data.user || "";
                    }
                }
            }

            Process {
                id: windowsActionProc
                running: false
                onExited: (exitCode, exitStatus) => windowsState.refresh()
            }
        }
    }
}
