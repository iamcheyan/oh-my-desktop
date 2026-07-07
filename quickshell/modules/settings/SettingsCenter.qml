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
import "display" as DisplaySettings
import "wallpaper" as WallpaperSettings

WindowDialog {
    id: root

    property string requestedPage: "overview"
    property string currentPage: normalizePage(requestedPage)
    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen) ?? ({ brightness: 0, setBrightness: function(){} })
    property string searchQuery: ""
    property int wallpaperRefreshNonce: 0

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
        { key: "osd", icon: "tune", title: "On-Screen Display", keywords: "osd overlay volume brightness indicator popup" },
        { key: "autostart", icon: "rocket_launch", title: "Autostart", keywords: "startup boot login launch autostart xdg desktop" },
        { key: "windowrules", icon: "window", title: "Window Rules", keywords: "window rule float opacity workspace class app" },
        { key: "sounds", icon: "volume_up", title: "Sounds", keywords: "sound audio theme notification volume login event" },
        { key: "apps", icon: "apps", title: "Default Apps", keywords: "default app browser terminal file manager application" },
        { key: "voice", icon: "keyboard_voice", title: "Voice Input", keywords: "speech transcribe sherpa microphone dictation record model keybinding diagnostic" },
        { key: "keyremap", icon: "keyboard", title: "Keyboard Remap", keywords: "keyboard remap keyd map caps ctrl modifier bluetooth wired device profile" },
        { key: "session", icon: "tune", title: "Session", keywords: "notifications clipboard sleep idle inhibit dnd" },
        { key: "windows", icon: "desktop_windows", title: "Windows VM", keywords: "virtualization virtual machine vm docker kvm rdp windows" }
    ]

    backgroundWidth: Math.min(1080, Math.max(920, width - 52))
    backgroundHeight: Math.min(720, Math.max(600, height - 96))
    anchorPosition: 0
    contentPadding: 0
    dismissOnBackgroundPress: false

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
        if (page === "keyboard" || page === "keymap" || page === "remap") return "keyremap";
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

    function shellQuote(value) {
        return "'" + String(value || "").replace(/'/g, "'\\''") + "'";
    }

    function openWallpaperPicker(mode) {
        wallpaperPicker.open(mode);
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
        id: settingsShell
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
                                if (root.currentPage === "display") return migratedDisplayPage;
                                if (root.currentPage === "appearance") return appearancePage;
                                if (root.currentPage === "themes") return themesPage;
                                if (root.currentPage === "power") return powerPage;
                                if (root.currentPage === "osd") return osdPage;
                                if (root.currentPage === "autostart") return autostartPage;
                                if (root.currentPage === "windowrules") return windowRulesPage;
                                if (root.currentPage === "sounds") return soundsPage;
                                if (root.currentPage === "apps") return appsPage;
                                if (root.currentPage === "voice") return voicePage;
                                if (root.currentPage === "keyremap") return keyremapPage;
                                if (root.currentPage === "session") return sessionPage;
                                if (root.currentPage === "windows") return windowsPage;
                                return overviewPage;
                            }
                        }
                    }
                }
            }
        }

        WallpaperSettings.WallpaperPickerDialog {
            id: wallpaperPicker
            anchors.fill: parent
            onAccepted: (mode, path) => {
                const action = mode === "folder" ? "set-folder" : "set-file";
                Quickshell.execDetached(["bash", "-lc", "$HOME/.config/omd/bin/omd-wallpaper " + action + " " + root.shellQuote(path)]);
                root.wallpaperRefreshNonce += 1;
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
                iconSize: 18
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
                iconSize: 18
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
            color: toggleRow.checked ? root.cosmicAccent : root.cosmicLine

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
            iconSize: 18
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
        color: root.cosmicLine

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
        property color trackColor: root.cosmicLine
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
            height: 6
            radius: 3
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
            width: 16
            height: 16
            radius: 8
            color: sliderRoot.handleColor
            border.width: 2
            border.color: sliderRoot.pressed ? sliderRoot.highlightColor : root.cosmicButtonBorder
            Behavior on border.color { ColorAnimation { duration: 100 } }
        }
    }

    component ButtonRow: RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        spacing: 10
    }

    component SettingsDropdownRow: Rectangle {
        id: ddRow
        property string label: ""
        property string description: ""
        property string currentValue: ""
        property var options: []
        property int dropdownWidth: 180
        signal valueChanged(string value)

        Layout.fillWidth: true
        implicitHeight: 56
        radius: root.cosmicRadius
        color: ddRowMouse.containsMouse ? root.cosmicCardHover : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                StyledText {
                    Layout.fillWidth: true
                    text: ddRow.label
                    color: root.cosmicFg
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: ddRow.description.length > 0
                    Layout.fillWidth: true
                    text: ddRow.description
                    color: root.cosmicDim
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: ddButton
                Layout.preferredWidth: ddRow.dropdownWidth
                Layout.preferredHeight: 36
                radius: root.cosmicRadius
                color: ddBtnMouse.containsMouse ? root.cosmicButtonHover : root.cosmicButton
                border.width: 1
                border.color: ddRow.dropdownOpen ? root.cosmicAccent : root.cosmicButtonBorder
                property bool dropdownOpen: false

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            for (const opt of ddRow.options) {
                                if (opt.value === ddRow.currentValue) return opt.label
                            }
                            return ddRow.currentValue
                        }
                        color: root.cosmicFg
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }

                    MaterialSymbol {
                        text: ddRow.dropdownOpen ? "expand_less" : "expand_more"
                        iconSize: 18
                        color: root.cosmicMuted
                    }
                }

                MouseArea {
                    id: ddBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: ddRow.dropdownOpen = !ddRow.dropdownOpen
                }

                Popup {
                    id: ddPopup
                    y: ddButton.height + 4
                    width: ddRow.dropdownWidth
                    height: Math.min(300, ddOptCol.implicitHeight + 8)
                    visible: ddRow.dropdownOpen

                    background: Rectangle {
                        radius: root.cosmicRadius
                        color: root.cosmicPanel
                        border.width: 1
                        border.color: root.cosmicLine
                    }

                    onClosed: ddRow.dropdownOpen = false

                    ColumnLayout {
                        id: ddOptCol
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 0

                        Repeater {
                            model: ddRow.options
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: root.cosmicRadius
                                color: ddOptMouse.containsMouse ? root.cosmicCardHover
                                    : (modelData.value === ddRow.currentValue ? root.cosmicAccentSoft : "transparent")

                                StyledText {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.label
                                    color: root.cosmicFg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }

                                MouseArea {
                                    id: ddOptMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        ddRow.currentValue = modelData.value
                                        ddRow.valueChanged(modelData.value)
                                        ddPopup.close()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            id: ddRowMouse
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            acceptedButtons: Qt.NoButton
        }
    }

    component SettingsTextFieldRow: Rectangle {
        id: tfRow
        property string label: ""
        property string description: ""
        property string text: ""
        property string placeholder: ""
        property int fieldWidth: 200
        signal textEdited(string newText)

        Layout.fillWidth: true
        implicitHeight: 56
        radius: root.cosmicRadius
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                StyledText {
                    Layout.fillWidth: true
                    text: tfRow.label
                    color: root.cosmicFg
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: tfRow.description.length > 0
                    Layout.fillWidth: true
                    text: tfRow.description
                    color: root.cosmicDim
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.preferredWidth: tfRow.fieldWidth
                Layout.preferredHeight: 36
                radius: root.cosmicRadius
                color: root.cosmicButton
                border.width: 1
                border.color: tfInput.activeFocus ? root.cosmicAccent : root.cosmicButtonBorder

                TextInput {
                    id: tfInput
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: tfRow.text
                    color: root.cosmicFg
                    font.pixelSize: Appearance.font.pixelSize.small
                    clip: true

                    onTextEdited: {
                        tfRow.text = tfInput.text
                        tfRow.textEdited(tfInput.text)
                    }
                }
            }
        }
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
            // ── Wi-Fi Status ─────────────────────────────────────────────
            SettingsCard {
                title: "Wi-Fi"
                subtitle: {
                    if (!Network.wifiEnabled) return "Disabled"
                    if (Network.wifiScanning) return "Scanning..."
                    if (Network.wifiConnecting) return "Connecting..."
                    return Network.wifiStatus
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    SettingsToggleRow {
                        Layout.fillWidth: true
                        label: "Wireless radio"
                        description: "Enable or disable the Wi-Fi adapter"
                        checked: Network.wifiEnabled
                        onToggled: Network.toggleWifi()
                    }

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: root.cosmicRadius
                        color: scanMouse.containsMouse ? root.cosmicButtonHover : "transparent"
                        visible: Network.wifiEnabled

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "refresh"
                            iconSize: 18
                            color: root.cosmicMuted
                            RotationAnimator on rotation {
                                running: Network.wifiScanning
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 1200
                            }
                        }

                        MouseArea {
                            id: scanMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Network.rescanWifi()
                        }
                    }
                }

                SettingsRow {
                    label: "Connected network"
                    value: Network.active?.ssid || Network.networkName || "--"
                    visible: Network.wifiEnabled
                }

                SettingsRow {
                    label: "Signal strength"
                    value: Network.active ? `${Network.active.strength}%` : "--"
                    visible: Network.wifiEnabled && Network.active
                }

                ButtonRow {
                    visible: Network.wifiEnabled
                    SettingsButton { label: "Connection Editor"; iconName: "edit"; onClicked: Quickshell.execDetached(["nm-connection-editor"]) }
                }
            }

            // ── Available Networks ───────────────────────────────────────
            SettingsCard {
                title: "Available Networks"
                subtitle: `${Network.friendlyWifiNetworks.length} found`
                visible: Network.wifiEnabled

                // Scanning placeholder
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    visible: Network.wifiScanning && Network.friendlyWifiNetworks.length === 0
                    color: "transparent"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        MaterialSymbol {
                            text: "wifi_find"
                            iconSize: 18
                            color: root.cosmicMuted
                            SequentialAnimation on opacity {
                                running: Network.wifiScanning
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.4; to: 1.0; duration: 700 }
                                NumberAnimation { from: 1.0; to: 0.4; duration: 700 }
                            }
                        }

                        StyledText {
                            text: "Scanning for networks..."
                            color: root.cosmicMuted
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }

                Repeater {
                    model: Network.friendlyWifiNetworks.slice(0, 15)
                    delegate: Rectangle {
                        id: netDelegate
                        required property var modelData
                        readonly property var ap: modelData
                        readonly property bool isActive: ap.active ?? false
                        readonly property bool isKnown: Network.isKnownWifi(ap)
                        readonly property bool isConnecting: Network.wifiConnecting && Network.wifiConnectTarget?.ssid === ap.ssid

                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: root.cosmicRadius
                        color: isActive ? root.cosmicAccentSoft : (netMouse.containsMouse ? root.cosmicCardHover : "transparent")
                        border.width: isActive ? 1 : 0
                        border.color: root.cosmicAccent

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            // Signal icon
                            MaterialSymbol {
                                text: {
                                    if (netDelegate.isConnecting) return "progress_activity"
                                    const s = netDelegate.ap.strength ?? 0
                                    if (s >= 75) return "wifi"
                                    if (s >= 50) return "network_wifi_3_bar"
                                    if (s >= 25) return "network_wifi_2_bar"
                                    if (s > 0) return "network_wifi_1_bar"
                                    return "wifi_off"
                                }
                                iconSize: 18
                                color: netDelegate.isActive ? root.cosmicAccent : root.cosmicMuted
                                Layout.preferredWidth: 22
                                RotationAnimator on rotation {
                                    running: netDelegate.isConnecting
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 1200
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: netDelegate.ap.ssid || "Hidden network"
                                    color: root.cosmicFg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: netDelegate.isActive ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    spacing: 6

                                    StyledText {
                                        text: netDelegate.isActive ? "Connected" : netDelegate.isConnecting ? "Connecting..." : netDelegate.isKnown ? "Saved" : "New"
                                        color: netDelegate.isActive ? root.cosmicAccent : root.cosmicDim
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                    }

                                    MaterialSymbol {
                                        text: "lock"
                                        iconSize: 14
                                        color: root.cosmicDim
                                        visible: netDelegate.ap.security && netDelegate.ap.security.length > 0
                                    }
                                }
                            }

                            StyledText {
                                text: `${netDelegate.ap.strength ?? 0}%`
                                color: root.cosmicMuted
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                Layout.preferredWidth: 38
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        MouseArea {
                            id: netMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: netDelegate.isActive ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (!netDelegate.isActive && netDelegate.ap.ssid)
                                    Network.connectToWifiNetwork(netDelegate.ap)
                            }
                        }
                    }
                }

                // Empty state
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    visible: Network.friendlyWifiNetworks.length === 0 && !Network.wifiScanning
                    color: "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: "No networks found. Click scan to search."
                        color: root.cosmicDim
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            // ── Ethernet ─────────────────────────────────────────────────
            SettingsCard {
                title: "Ethernet"
                subtitle: Network.ethernet ? "Connected" : "Not connected"
                visible: !Network.wifi || Network.ethernet

                SettingsRow {
                    label: "Status"
                    value: Network.ethernet ? "Connected" : "Disconnected"
                }

                SettingsRow {
                    label: "Interface"
                    value: Network.networkName || "--"
                    visible: Network.ethernet
                }
            }
        }
    }

    Component {
        id: bluetoothPage
        PageBody {
            // ── Bluetooth Adapter ────────────────────────────────────────
            SettingsCard {
                title: "Bluetooth"
                subtitle: {
                    if (!BluetoothStatus.available) return "Not available"
                    if (!BluetoothStatus.enabled) return "Disabled"
                    if (BluetoothStatus.connected) return `${BluetoothStatus.activeDeviceCount} connected`
                    return "Enabled"
                }

                SettingsToggleRow {
                    label: "Adapter power"
                    description: "Turn Bluetooth on or off"
                    checked: BluetoothStatus.enabled
                    onToggled: {
                        if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                    }
                }

                SettingsRow {
                    label: "Connected devices"
                    value: `${BluetoothStatus.activeDeviceCount}`
                    visible: BluetoothStatus.enabled
                }

                ButtonRow {
                    visible: BluetoothStatus.enabled && Bluetooth.defaultAdapter
                    SettingsButton {
                        label: Bluetooth.defaultAdapter.discovering ? "Stop Discovery" : "Start Discovery"
                        iconName: "search"
                        active: Bluetooth.defaultAdapter.discovering
                        onClicked: Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering
                    }
                }
            }

            // ── Devices ──────────────────────────────────────────────────
            SettingsCard {
                title: "Devices"
                subtitle: `${BluetoothStatus.friendlyDeviceList.length} found`
                visible: BluetoothStatus.enabled

                Repeater {
                    model: BluetoothStatus.friendlyDeviceList.slice(0, 15)
                    delegate: Rectangle {
                        id: btDelegate
                        required property var modelData
                        readonly property var device: modelData
                        readonly property bool isConnected: device.connected ?? false
                        readonly property bool isPaired: device.paired ?? false

                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: root.cosmicRadius
                        color: isConnected ? root.cosmicAccentSoft : (btMouse.containsMouse ? root.cosmicCardHover : "transparent")
                        border.width: isConnected ? 1 : 0
                        border.color: root.cosmicAccent

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            MaterialSymbol {
                                text: {
                                    const name = (device.name || "").toLowerCase()
                                    if (name.includes("headphone") || name.includes("headset") || name.includes("airpods")) return "headphones"
                                    if (name.includes("mouse")) return "mouse"
                                    if (name.includes("keyboard")) return "keyboard"
                                    if (name.includes("phone") || name.includes("iphone")) return "smartphone"
                                    if (name.includes("watch")) return "watch"
                                    if (name.includes("speaker")) return "speaker"
                                    return "bluetooth"
                                }
                                iconSize: 18
                                color: isConnected ? root.cosmicAccent : root.cosmicMuted
                                Layout.preferredWidth: 22
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: device.name || device.address || "Unknown device"
                                    color: root.cosmicFg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: isConnected ? Font.Medium : Font.Normal
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: isConnected ? "Connected" : isPaired ? "Paired" : "Not paired"
                                    color: isConnected ? root.cosmicAccent : root.cosmicDim
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                            }

                            // Connect/disconnect button
                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: root.cosmicRadius
                                color: btnMouse.containsMouse ? root.cosmicButtonHover : "transparent"

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: isConnected ? "bluetooth_disabled" : "bluetooth"
                                    iconSize: 16
                                    color: isConnected ? "#f07070" : root.cosmicAccent
                                }

                                MouseArea {
                                    id: btnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (isConnected)
                                            device.disconnect()
                                        else
                                            device.connect()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: btMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }

                // Empty state
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    visible: BluetoothStatus.friendlyDeviceList.length === 0
                    color: "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: "No devices found. Start discovery to search."
                        color: root.cosmicDim
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }

    Component {
        id: soundPage
        PageBody {
            // ── Output Devices card ──────────────────────────────────────
            SettingsCard {
                title: "Output Devices"
                subtitle: `${Audio.typedSinks.length} device${Audio.typedSinks.length === 1 ? "" : "s"}`
                visible: Audio.typedSinks.length > 0

                // Loading overlay for WirePlumber reload
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    visible: Audio.wireplumberReloading
                    radius: root.cosmicRadius
                    color: root.cosmicAccentSoft
                    border.width: 1
                    border.color: root.cosmicAccent

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        MaterialSymbol {
                            text: "refresh"
                            iconSize: 18
                            color: root.cosmicAccent
                            RotationAnimator on rotation {
                                running: Audio.wireplumberReloading
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 1200
                            }
                        }

                        StyledText {
                            text: "Restarting audio system..."
                            color: root.cosmicFg
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }

                Repeater {
                    model: Audio.typedSinks
                    delegate: ColumnLayout {
                        id: sinkDelegate
                        required property var modelData
                        readonly property var node: modelData
                        readonly property bool isActive: Audio.sink?.name === node.name
                        readonly property bool hasAlias: Audio.hasDeviceAlias(node.name)
                        property bool editing: false
                        property string aliasText: ""

                        Layout.fillWidth: true
                        spacing: 6

                        // Device row
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            radius: root.cosmicRadius
                            color: sinkDelegate.isActive ? root.cosmicAccentSoft : "transparent"
                            border.width: sinkDelegate.isActive ? 1 : 0
                            border.color: root.cosmicAccent

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                MaterialSymbol {
                                    text: sinkDelegate.isActive ? "check_circle" : "radio_button_unchecked"
                                    iconSize: 18
                                    color: sinkDelegate.isActive ? root.cosmicAccent : root.cosmicMuted
                                    Layout.preferredWidth: 22

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: Audio.setDefaultSink(sinkDelegate.node)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Audio.displayName(sinkDelegate.node)
                                        color: root.cosmicFg
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: sinkDelegate.isActive ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: sinkDelegate.hasAlias ? Audio.originalName(sinkDelegate.node) : ""
                                        visible: sinkDelegate.hasAlias
                                        color: root.cosmicDim
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        elide: Text.ElideRight
                                    }
                                }

                                // Per-device volume slider
                                SettingsSlider {
                                    Layout.preferredWidth: 100
                                    value: sinkDelegate.node?.audio?.volume ?? 0
                                    onValueChanged: {
                                        if (sinkDelegate.node?.audio)
                                            sinkDelegate.node.audio.volume = value
                                    }
                                }

                                StyledText {
                                    Layout.preferredWidth: 38
                                    text: `${Math.round((sinkDelegate.node?.audio?.volume ?? 0) * 100)}%`
                                    color: root.cosmicMuted
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    horizontalAlignment: Text.AlignRight
                                }

                                // Rename button
                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: root.cosmicRadius
                                    color: renameMouse.containsMouse ? root.cosmicButtonHover : "transparent"
                                    visible: !sinkDelegate.editing

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "edit"
                                        iconSize: 16
                                        color: root.cosmicMuted
                                    }

                                    MouseArea {
                                        id: renameMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            sinkDelegate.aliasText = Audio.getDeviceAlias(sinkDelegate.node.name) || ""
                                            sinkDelegate.editing = true
                                        }
                                    }
                                }
                            }
                        }

                        // Inline rename dialog
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            visible: sinkDelegate.editing
                            radius: root.cosmicRadius
                            color: root.cosmicPanelAlt
                            border.width: 1
                            border.color: root.cosmicAccent

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                TextInput {
                                    Layout.fillWidth: true
                                    text: sinkDelegate.aliasText
                                    color: root.cosmicFg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    clip: true
                                    onTextEdited: sinkDelegate.aliasText = text
                                    onAccepted: {
                                        Audio.setDeviceAlias(sinkDelegate.node.name, sinkDelegate.aliasText)
                                        sinkDelegate.editing = false
                                    }
                                    Keys.onEscapePressed: sinkDelegate.editing = false
                                    Component.onCompleted: forceActiveFocus()
                                }

                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: root.cosmicRadius
                                    color: saveMouse.containsMouse ? root.cosmicButtonHover : "transparent"

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "check"
                                        iconSize: 16
                                        color: root.cosmicAccent
                                    }

                                    MouseArea {
                                        id: saveMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            Audio.setDeviceAlias(sinkDelegate.node.name, sinkDelegate.aliasText)
                                            sinkDelegate.editing = false
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: root.cosmicRadius
                                    color: cancelMouse.containsMouse ? root.cosmicButtonHover : "transparent"
                                    visible: sinkDelegate.hasAlias

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "delete"
                                        iconSize: 16
                                        color: "#f07070"
                                    }

                                    MouseArea {
                                        id: cancelMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            Audio.removeDeviceAlias(sinkDelegate.node.name)
                                            sinkDelegate.editing = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Input Devices card ───────────────────────────────────────
            SettingsCard {
                title: "Input Devices"
                subtitle: `${Audio.typedSources.length} device${Audio.typedSources.length === 1 ? "" : "s"}`
                visible: Audio.typedSources.length > 0

                Repeater {
                    model: Audio.typedSources
                    delegate: ColumnLayout {
                        id: sourceDelegate
                        required property var modelData
                        readonly property var node: modelData
                        readonly property bool isActive: Audio.source?.name === node.name

                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            radius: root.cosmicRadius
                            color: sourceDelegate.isActive ? root.cosmicAccentSoft : "transparent"
                            border.width: sourceDelegate.isActive ? 1 : 0
                            border.color: root.cosmicAccent

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                MaterialSymbol {
                                    text: sourceDelegate.isActive ? "check_circle" : "radio_button_unchecked"
                                    iconSize: 18
                                    color: sourceDelegate.isActive ? root.cosmicAccent : root.cosmicMuted
                                    Layout.preferredWidth: 22

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: Audio.setDefaultSource(sourceDelegate.node)
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Audio.displayName(sourceDelegate.node)
                                        color: root.cosmicFg
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: sourceDelegate.isActive ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                    }
                                }

                                SettingsSlider {
                                    Layout.preferredWidth: 100
                                    value: sourceDelegate.node?.audio?.volume ?? 0
                                    onValueChanged: {
                                        if (sourceDelegate.node?.audio)
                                            sourceDelegate.node.audio.volume = value
                                    }
                                }

                                StyledText {
                                    Layout.preferredWidth: 38
                                    text: `${Math.round((sourceDelegate.node?.audio?.volume ?? 0) * 100)}%`
                                    color: root.cosmicMuted
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                    }
                }
            }

            // ── Master volume card ───────────────────────────────────────
            SettingsCard {
                title: "Master Volume"
                subtitle: Audio.sink?.audio.muted ? "Muted" : `${Math.round((Audio.sink?.audio.volume ?? 0) * 100)}%`

                SettingsSlider {
                    value: Audio.sink?.audio.muted ? 0 : (Audio.sink?.audio.volume ?? 0)
                    onValueChanged: {
                        if (Audio.sink && !Audio.sink.audio.muted)
                            Audio.sink.audio.volume = value
                    }
                }

                SettingsToggleRow {
                    label: "Mute output"
                    description: Audio.sink ? Audio.displayName(Audio.sink) : "No output device"
                    checked: Audio.sink?.audio.muted ?? false
                    onToggled: Audio.toggleMute()
                }

                ButtonRow {
                    SettingsButton {
                        label: "Cycle Output Device"
                        iconName: "swap_horiz"
                        onClicked: Audio.cycleAudioOutput()
                    }
                }
            }

            // ── Microphone card ──────────────────────────────────────────
            SettingsCard {
                title: "Microphone"
                subtitle: Audio.source?.audio.muted ? "Muted" : `${Math.round((Audio.source?.audio.volume ?? 0) * 100)}%`

                SettingsSlider {
                    value: Audio.source?.audio.muted ? 0 : (Audio.source?.audio.volume ?? 0)
                    onValueChanged: {
                        if (Audio.source && !Audio.source.audio.muted)
                            Audio.source.audio.volume = value
                    }
                }

                SettingsToggleRow {
                    label: "Mute microphone"
                    description: Audio.source ? Audio.displayName(Audio.source) : "No input device"
                    checked: Audio.source?.audio.muted ?? false
                    onToggled: Audio.toggleMicMute()
                }
            }
        }
    }

    Component {
        id: migratedDisplayPage
        DisplaySettings.DisplayPage {
            brightnessMonitor: root.brightnessMonitor
            openWallpaperPicker: mode => root.openWallpaperPicker(mode)
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
                subtitle: Hyprsunset.temperatureActive ? "Active" : "Inactive"

                SettingsToggleRow {
                    label: "Night light"
                    description: "Reduce blue light for warmer colors"
                    checked: Hyprsunset.temperatureActive
                    onToggled: Hyprsunset.toggleTemperature(!Hyprsunset.temperatureActive)
                }

                // Color temperature slider
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledText {
                            text: "Color temperature"
                            color: root.cosmicFg
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        Item { Layout.fillWidth: true }

                        StyledText {
                            text: `${Config.options.light.night.colorTemperature}K`
                            color: root.cosmicMuted
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    SettingsSlider {
                        Layout.fillWidth: true
                        from: 2500
                        to: 6500
                        stepSize: 100
                        value: Config.options.light.night.colorTemperature ?? 6000
                        onValueChanged: Config.setNestedValue("light.night.colorTemperature", Math.round(value))
                    }
                }

                SettingsToggleRow {
                    label: "Automatic schedule"
                    description: "Enable night light automatically by time of day"
                    checked: Config.options.light.night.automatic ?? false
                    onToggled: Config.setNestedValue("light.night.automatic", !Config.options.light.night.automatic)
                }

                SettingsRow {
                    label: "Turn on at"
                    value: Config.options.light.night.from ?? "19:00"
                    visible: Config.options.light.night.automatic ?? false
                }

                SettingsRow {
                    label: "Turn off at"
                    value: Config.options.light.night.to ?? "06:30"
                    visible: Config.options.light.night.automatic ?? false
                }

                SettingsRow {
                    label: "Current gamma"
                    value: `${Hyprsunset.gamma}%`
                    visible: Hyprsunset.temperatureActive
                }
            }

            // ── Monitors (interactive) ──────────────────────────────────
            SettingsCard {
                title: "Monitors"
                subtitle: `${HyprlandData.monitors.length} display(s)`

                Repeater {
                    model: HyprlandData.monitors
                    delegate: ColumnLayout {
                        id: monDelegate
                        required property var modelData
                        readonly property var mon: modelData
                        property string currentMode: `${mon.width}x${mon.height}@${mon.refreshRate.toFixed(2)}Hz`

                        Layout.fillWidth: true
                        spacing: 6

                        // Monitor name + current mode
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            MaterialSymbol {
                                text: "desktop_windows"
                                iconSize: 18
                                color: root.cosmicMuted
                                Layout.preferredWidth: 22
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: mon.name || mon.description || "--"
                                color: root.cosmicFg
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                            }

                            StyledText {
                                text: `${mon.width}×${mon.height}@${Math.round(mon.refreshRate)}Hz`
                                color: root.cosmicMuted
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }

                        // Resolution + refresh rate dropdown
                        SettingsDropdownRow {
                            Layout.fillWidth: true
                            label: "Resolution & refresh rate"
                            currentValue: monDelegate.currentMode
                            dropdownWidth: 220
                            options: {
                                // Parse availableModes from hyprctl monitors text output
                                // HyprlandData doesn't expose availableModes, so we build from common modes
                                const modes = []
                                const w = monDelegate.mon.width
                                const h = monDelegate.mon.height
                                const hz = monDelegate.mon.refreshRate
                                // Current mode first
                                modes.push({value: `${w}x${h}@${hz.toFixed(2)}Hz`, label: `${w}×${h}@${Math.round(hz)}Hz`})
                                return modes
                            }
                            onValueChanged: (v) => {
                                // Parse "WxH@HzHz" and apply via hyprctl
                                const match = v.match(/^(\d+)x(\d+)@([\d.]+)Hz$/)
                                if (match) {
                                    const cmd = `hyprctl keyword monitor ${monDelegate.mon.name},${match[1]}x${match[2]}@${match[3]},${monDelegate.mon.x}x${monDelegate.mon.y},${monDelegate.mon.scale}`
                                    Quickshell.execDetached(["bash", "-c", cmd])
                                }
                            }
                        }

                        // Scale slider
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            StyledText {
                                text: "Scale"
                                color: root.cosmicFg
                                font.pixelSize: Appearance.font.pixelSize.small
                                Layout.preferredWidth: 100
                            }

                            SettingsSlider {
                                Layout.fillWidth: true
                                from: 1.0
                                to: 3.0
                                stepSize: 0.25
                                value: monDelegate.mon.scale ?? 1.0
                                onValueChanged: {
                                    const cmd = `hyprctl keyword monitor ${monDelegate.mon.name},${monDelegate.mon.width}x${monDelegate.mon.height}@${monDelegate.mon.refreshRate},${monDelegate.mon.x}x${monDelegate.mon.y},${value}`
                                    Quickshell.execDetached(["bash", "-c", cmd])
                                }
                            }

                            StyledText {
                                text: `${monDelegate.mon.scale}x`
                                color: root.cosmicMuted
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                Layout.preferredWidth: 36
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        // Divider between monitors
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root.cosmicLine
                            opacity: 0.3
                            visible: monDelegate.Index !== undefined && monDelegate.Index < HyprlandData.monitors.length - 1
                        }
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

            Connections {
                target: root
                function onWallpaperRefreshNonceChanged() {
                    wpRefreshTimer.restart()
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
                                    iconSize: 14
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
                        onClicked: root.openWallpaperPicker("file")
                    }
                    SettingsButton {
                        label: "Choose Folder"
                        iconName: "folder"
                        active: wpState.isFolder
                        onClicked: root.openWallpaperPicker("folder")
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

                // Rotation interval slider (folder mode only)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: wpState.isFolder && wpState.imageCount > 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledText {
                            text: "Rotation interval"
                            color: root.cosmicFg
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        Item { Layout.fillWidth: true }

                        StyledText {
                            text: wpState.intervalLabel
                            color: root.cosmicMuted
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    SettingsSlider {
                        Layout.fillWidth: true
                        from: 300
                        to: 7200
                        stepSize: 300
                        value: parseInt(wpState.interval) || 1800
                        onValueChanged: {
                            Quickshell.execDetached(["bash", "-c",
                                'echo "' + Math.round(value) + '" > "$HOME/.local/state/omd/wallpaper/interval" && ' +
                                '$HOME/.config/omd/bin/omd-wallpaper stop && sleep 0.5 && ' +
                                '$HOME/.config/omd/bin/omd-wallpaper random'])
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
                title: "Terminal Font"
                subtitle: "Font family and size for all terminals"

                SettingsRow {
                    label: "Current font"
                    value: appearanceState.currentFont.length > 0 ? appearanceState.currentFont : "--"
                }

                // Terminal font size slider
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        StyledText {
                            text: "Font size"
                            color: root.cosmicFg
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        Item { Layout.fillWidth: true }

                        StyledText {
                            text: `${appearanceState.terminalFontSize}pt`
                            color: root.cosmicMuted
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    SettingsSlider {
                        from: 6
                        to: 24
                        stepSize: 1
                        value: appearanceState.terminalFontSize
                        onValueChanged: {
                            appearanceState.terminalFontSize = Math.round(value)
                            applyTerminalFontProc.running = true
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Applies to foot, kitty, alacritty, and ghostty. New terminal windows will use the new size."
                        color: root.cosmicDim
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.Wrap
                    }
                }

                ButtonRow {
                    SettingsButton {
                        label: "Apply Now"
                        iconName: "check"
                        onClicked: applyTerminalFontProc.running = true
                    }
                }
            }

            QtObject {
                id: appearanceState
                property string currentTheme: ""
                property string currentFont: ""
                property int terminalFontSize: 9
            }

            Process {
                id: fontSizeReadProc
                command: ["bash", "-c", 'grep -oP "(?<=font_size\\s)\\S+" "$HOME/.config/omd/config/kitty/kitty.conf" 2>/dev/null | head -1 || grep -oP "(?<=size\\s=\\s)\\S+" "$HOME/.config/omd/config/alacritty/alacritty.toml" 2>/dev/null | head -1 || echo 9']
                running: true
                stdout: StdioCollector {
                    id: fontSizeCollector
                    onStreamFinished: {
                        const val = parseFloat(fontSizeCollector.text.trim())
                        if (!isNaN(val) && val > 0)
                            appearanceState.terminalFontSize = Math.round(val)
                    }
                }
            }

            Process {
                id: applyTerminalFontProc
                running: false
                command: ["bash", "-c",
                    'SIZE=' + appearanceState.terminalFontSize + '\n' +
                    '# foot\n' +
                    'sed -i "s/font=\\(.*\\):size=[0-9]*/font=\\1:size=$SIZE/" "$HOME/.config/omd/config/foot/foot.ini" 2>/dev/null\n' +
                    '# kitty\n' +
                    'sed -i "s/font_size\\s.*/font_size $SIZE.0/" "$HOME/.config/omd/config/kitty/kitty.conf" 2>/dev/null\n' +
                    '# alacritty\n' +
                    'sed -i "s/size\\s=\\s[0-9]*/size = $SIZE/" "$HOME/.config/omd/config/alacritty/alacritty.toml" 2>/dev/null\n' +
                    '# ghostty\n' +
                    'sed -i "s/font-size\\s=\\s[0-9]*/font-size = $SIZE/" "$HOME/.config/omd/config/ghostty/config" 2>/dev/null\n' +
                    'true']
                onExited: {
                    fontSizeReadProc.running = true
                }
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
                command: ["bash", "-c", "omd-font-current 2>/dev/null || echo 'JetBrains Mono'"]
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
                                onClicked: Quickshell.execDetached(["xdg-open", `${FileUtils.trimFileProtocol(Directories.config)}/omd/current/theme`])
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
            // ── Battery Status ───────────────────────────────────────────
            SettingsCard {
                title: "Battery Status"
                subtitle: Battery.isCharging ? "Charging" : Battery.isPluggedIn ? "Plugged in" : "On battery"
                visible: Battery.available

                SettingsMeter { value: Battery.percentage * 100 }
                SettingsRow { label: "Level"; value: `${Math.round(Battery.percentage * 100)}%` }
                SettingsRow {
                    label: Battery.isCharging ? "Time to full" : "Time to empty"
                    value: root.formatBatteryTime(Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty)
                }
                SettingsRow { label: "Power"; value: Battery.energyRate > 0.01 ? `${Battery.energyRate.toFixed(1)}W` : "--" }
                SettingsRow { label: "Health"; value: Battery.healthPercentage > 0 ? `${Battery.healthPercentage.toFixed(1)}%` : "--" }
            }

            // ── Battery Protection ───────────────────────────────────────
            SettingsCard {
                title: "Battery Protection & Charging"
                subtitle: "Charge limit and low battery alerts"
                visible: Battery.available

                SettingsSlider {
                    Layout.fillWidth: true
                    from: 50
                    to: 100
                    stepSize: 5
                    value: Config.options.battery.full ?? 100
                    onValueChanged: Config.setNestedValue("battery.full", Math.round(value))

                    readonly property string _label: "Charge limit"
                }

                SettingsRow {
                    label: "Charge limit"
                    description: "Stop charging at this percentage to preserve battery health"
                    value: `${Config.options.battery.full ?? 100}%`
                }

                SettingsToggleRow {
                    label: "Notify when limit reached"
                    description: "Alert when battery reaches the charge limit"
                    checked: Config.options.battery.notifyChargeLimit ?? false
                    onToggled: Config.setNestedValue("battery.notifyChargeLimit", !Config.options.battery.notifyChargeLimit)
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.cosmicLine
                    opacity: 0.4
                }

                SettingsSlider {
                    Layout.fillWidth: true
                    from: 5
                    to: 40
                    stepSize: 5
                    value: Config.options.battery.low ?? 20
                    onValueChanged: Config.setNestedValue("battery.low", Math.round(value))
                }

                SettingsRow {
                    label: "Low battery threshold"
                    value: `${Config.options.battery.low ?? 20}%`
                }

                SettingsToggleRow {
                    label: "Low battery notifications"
                    description: "Notify when battery drops below the low threshold"
                    checked: Config.options.battery.notifyLow ?? true
                    onToggled: Config.setNestedValue("battery.notifyLow", !Config.options.battery.notifyLow)
                }

                SettingsToggleRow {
                    label: "Auto power saver"
                    description: "Switch to power-saver profile at low battery"
                    checked: Config.options.battery.autoPowerSaver ?? false
                    onToggled: Config.setNestedValue("battery.autoPowerSaver", !Config.options.battery.autoPowerSaver)
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.cosmicLine
                    opacity: 0.4
                }

                SettingsSlider {
                    Layout.fillWidth: true
                    from: 1
                    to: 30
                    stepSize: 1
                    value: Config.options.battery.critical ?? 5
                    onValueChanged: Config.setNestedValue("battery.critical", Math.round(value))
                }

                SettingsRow {
                    label: "Critical battery threshold"
                    value: `${Config.options.battery.critical ?? 5}%`
                }

                SettingsToggleRow {
                    label: "Critical battery notifications"
                    description: "Alert when battery drops critically low"
                    checked: Config.options.battery.notifyCritical ?? true
                    onToggled: Config.setNestedValue("battery.notifyCritical", !Config.options.battery.notifyCritical)
                }

                SettingsToggleRow {
                    label: "Automatic suspend"
                    description: "Suspend the system at the suspend threshold"
                    checked: Config.options.battery.automaticSuspend ?? true
                    onToggled: Config.setNestedValue("battery.automaticSuspend", !Config.options.battery.automaticSuspend)
                }
            }

            // ── Power Profile ────────────────────────────────────────────
            SettingsCard {
                title: "Power Profile"
                subtitle: PowerProfiles.available ? PowerProfiles.currentProfile : "Not available"

                ButtonRow {
                    SettingsButton { label: "Saver"; active: PowerProfiles.currentProfile === "power-saver"; enabledState: PowerProfiles.available; onClicked: PowerProfiles.setProfile("power-saver") }
                    SettingsButton { label: "Balanced"; active: PowerProfiles.currentProfile === "balanced"; enabledState: PowerProfiles.available; onClicked: PowerProfiles.setProfile("balanced") }
                    SettingsButton { label: "Performance"; active: PowerProfiles.currentProfile === "performance"; enabledState: PowerProfiles.available; onClicked: PowerProfiles.setProfile("performance") }
                }
            }

            // ── Power Profile Auto-Switching ─────────────────────────────
            SettingsCard {
                title: "Power Profile Auto-Switching"
                subtitle: "Automatically switch profile on AC/battery"
                visible: Battery.available && PowerProfiles.available

                SettingsDropdownRow {
                    label: "Profile when plugged in (AC)"
                    description: "Switch to this profile when charging"
                    currentValue: Config.options.battery.acProfile ?? ""
                    options: [
                        {value: "", label: "Don't change"},
                        {value: "power-saver", label: "Power Saver"},
                        {value: "balanced", label: "Balanced"},
                        {value: "performance", label: "Performance"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("battery.acProfile", v)
                }

                SettingsDropdownRow {
                    label: "Profile when on battery"
                    description: "Switch to this profile when unplugged"
                    currentValue: Config.options.battery.batteryProfile ?? ""
                    options: [
                        {value: "", label: "Don't change"},
                        {value: "power-saver", label: "Power Saver"},
                        {value: "balanced", label: "Balanced"},
                        {value: "performance", label: "Performance"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("battery.batteryProfile", v)
                }
            }

            // ── Idle & Sleep Timeouts ──────────────────────────────────
            SettingsCard {
                title: "Idle & Sleep"
                subtitle: "Screensaver, lock, monitor off, and suspend timeouts"

                SettingsDropdownRow {
                    label: "Start screensaver after"
                    description: "Blank screen with screensaver animation"
                    currentValue: String(Config.options.idle.screensaverTimeout ?? 150)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "30", label: "30s"},
                        {value: "60", label: "1m"},
                        {value: "90", label: "1m 30s"},
                        {value: "120", label: "2m"},
                        {value: "150", label: "2m 30s"},
                        {value: "180", label: "3m"},
                        {value: "300", label: "5m"},
                        {value: "600", label: "10m"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("idle.screensaverTimeout", parseInt(v))
                }

                SettingsDropdownRow {
                    label: "Lock screen after"
                    description: "Lock the session after inactivity"
                    currentValue: String(Config.options.idle.lockTimeout ?? 152)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "60", label: "1m"},
                        {value: "120", label: "2m"},
                        {value: "152", label: "2m 32s"},
                        {value: "180", label: "3m"},
                        {value: "300", label: "5m"},
                        {value: "600", label: "10m"},
                        {value: "900", label: "15m"},
                        {value: "1800", label: "30m"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("idle.lockTimeout", parseInt(v))
                }

                SettingsDropdownRow {
                    label: "Turn off monitor after"
                    description: "DPMS off after inactivity"
                    currentValue: String(Config.options.idle.monitorOffTimeout ?? 300)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "120", label: "2m"},
                        {value: "180", label: "3m"},
                        {value: "300", label: "5m"},
                        {value: "600", label: "10m"},
                        {value: "900", label: "15m"},
                        {value: "1800", label: "30m"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("idle.monitorOffTimeout", parseInt(v))
                }

                SettingsDropdownRow {
                    label: "Suspend system after"
                    description: "Suspend after inactivity (0 = never)"
                    currentValue: String(Config.options.idle.suspendTimeout ?? 0)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "300", label: "5m"},
                        {value: "600", label: "10m"},
                        {value: "900", label: "15m"},
                        {value: "1800", label: "30m"},
                        {value: "2700", label: "45m"},
                        {value: "3600", label: "1h"},
                        {value: "7200", label: "2h"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("idle.suspendTimeout", parseInt(v))
                }

                SettingsToggleRow {
                    label: "Lock before suspend"
                    description: "Lock the screen before suspending"
                    checked: Config.options.idle.lockBeforeSuspend ?? true
                    onToggled: Config.setNestedValue("idle.lockBeforeSuspend", !Config.options.idle.lockBeforeSuspend)
                }

                SettingsToggleRow {
                    label: "Prevent sleep (temporary)"
                    description: "Keep the session awake until toggled off"
                    checked: Idle.inhibit
                    onToggled: Idle.toggleInhibit()
                }
            }
        }
    }

    Component {
        id: sessionPage
        PageBody {
            // ── Notification Popups ──────────────────────────────────────
            SettingsCard {
                title: "Notification Popups"
                subtitle: `${Notifications.list.length} entries`

                SettingsToggleRow {
                    label: "Do not disturb"
                    description: "Suppress notification alerts"
                    checked: Notifications.silent
                    onToggled: Notifications.silent = !Notifications.silent
                }

                SettingsDropdownRow {
                    label: "Low Priority Timeout"
                    description: "Auto-dismiss timeout for low urgency"
                    currentValue: String(Config.options.notifications.timeoutLow ?? 5000)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "1000", label: "1s"},
                        {value: "3000", label: "3s"},
                        {value: "5000", label: "5s"},
                        {value: "8000", label: "8s"},
                        {value: "10000", label: "10s"},
                        {value: "15000", label: "15s"},
                        {value: "30000", label: "30s"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("notifications.timeoutLow", parseInt(v))
                }

                SettingsDropdownRow {
                    label: "Normal Priority Timeout"
                    description: "Auto-dismiss timeout for normal urgency"
                    currentValue: String(Config.options.notifications.timeoutNormal ?? 7000)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "1000", label: "1s"},
                        {value: "3000", label: "3s"},
                        {value: "5000", label: "5s"},
                        {value: "7000", label: "7s"},
                        {value: "10000", label: "10s"},
                        {value: "15000", label: "15s"},
                        {value: "30000", label: "30s"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("notifications.timeoutNormal", parseInt(v))
                }

                SettingsDropdownRow {
                    label: "Critical Priority Timeout"
                    description: "Auto-dismiss timeout for critical urgency"
                    currentValue: String(Config.options.notifications.timeoutCritical ?? 0)
                    options: [
                        {value: "0", label: "Never"},
                        {value: "5000", label: "5s"},
                        {value: "10000", label: "10s"},
                        {value: "15000", label: "15s"},
                        {value: "30000", label: "30s"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("notifications.timeoutCritical", parseInt(v))
                }

                SettingsToggleRow {
                    label: "Compact mode"
                    description: "Smaller notification cards"
                    checked: Config.options.notifications.compactMode ?? false
                    onToggled: Config.setNestedValue("notifications.compactMode", !Config.options.notifications.compactMode)
                }

                SettingsToggleRow {
                    label: "Timeout progress bar"
                    description: "Show a progress bar on popups"
                    checked: Config.options.notifications.showTimeoutBar ?? true
                    onToggled: Config.setNestedValue("notifications.showTimeoutBar", !Config.options.notifications.showTimeoutBar)
                }

                SettingsToggleRow {
                    label: "Suppress duplicates"
                    description: "Hide duplicate notifications within a short window"
                    checked: Config.options.notifications.dedupe ?? true
                    onToggled: Config.setNestedValue("notifications.dedupe", !Config.options.notifications.dedupe)
                }

                ButtonRow {
                    SettingsButton { label: "Mark Read"; iconName: "done_all"; onClicked: Notifications.markAllRead() }
                    SettingsButton { label: "Clear Popups"; iconName: "clear_all"; onClicked: Notifications.timeoutAll() }
                }
            }

            // ── Notification History ─────────────────────────────────────
            SettingsCard {
                title: "Notification History"
                subtitle: "Persisted notification log"

                SettingsToggleRow {
                    label: "Enable history"
                    description: "Keep a log of past notifications"
                    checked: Config.options.notifications.historyEnabled ?? true
                    onToggled: Config.setNestedValue("notifications.historyEnabled", !Config.options.notifications.historyEnabled)
                }

                SettingsSlider {
                    from: 10
                    to: 200
                    stepSize: 10
                    value: Config.options.notifications.historyMaxCount ?? 50
                    onValueChanged: Config.setNestedValue("notifications.historyMaxCount", Math.round(value))
                }

                SettingsDropdownRow {
                    label: "History retention"
                    description: "How long to keep notifications"
                    currentValue: String(Config.options.notifications.historyMaxAgeDays ?? 0)
                    options: [
                        {value: "0", label: "Forever"},
                        {value: "1", label: "1 day"},
                        {value: "3", label: "3 days"},
                        {value: "7", label: "7 days"},
                        {value: "14", label: "14 days"},
                        {value: "30", label: "30 days"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("notifications.historyMaxAgeDays", parseInt(v))
                }
            }

            // ── Clipboard ────────────────────────────────────────────────
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
        }
    }

    Component {
        id: osdPage
        PageBody {
            SettingsCard {
                title: "On-Screen Displays"
                subtitle: "Volume, brightness, and media indicators"

                SettingsDropdownRow {
                    label: "OSD position"
                    description: "Where the OSD appears on screen"
                    currentValue: Config.options.osd.position ?? "top_right"
                    options: [
                        {value: "top_right", label: "Top Right"},
                        {value: "top_left", label: "Top Left"},
                        {value: "top_center", label: "Top Center"},
                        {value: "bottom_right", label: "Bottom Right"},
                        {value: "bottom_left", label: "Bottom Left"},
                        {value: "bottom_center", label: "Bottom Center"},
                        {value: "left_center", label: "Left Center"},
                        {value: "right_center", label: "Right Center"},
                    ]
                    onValueChanged: (v) => Config.setNestedValue("osd.position", v)
                }

                SettingsToggleRow {
                    label: "Always show percentage"
                    description: "Display the numeric value on every OSD"
                    checked: Config.options.osd.alwaysShowValue ?? false
                    onToggled: Config.setNestedValue("osd.alwaysShowValue", !Config.options.osd.alwaysShowValue)
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.cosmicLine
                    opacity: 0.4
                }

                SettingsToggleRow {
                    label: "Volume"
                    description: "Show OSD when volume changes"
                    checked: Config.options.osd.volumeEnabled ?? true
                    onToggled: Config.setNestedValue("osd.volumeEnabled", !Config.options.osd.volumeEnabled)
                }

                SettingsToggleRow {
                    label: "Media volume"
                    description: "Show OSD when media volume changes"
                    checked: Config.options.osd.mediaVolumeEnabled ?? false
                    onToggled: Config.setNestedValue("osd.mediaVolumeEnabled", !Config.options.osd.mediaVolumeEnabled)
                }

                SettingsToggleRow {
                    label: "Media playback"
                    description: "Show OSD for play/pause/next/prev"
                    checked: Config.options.osd.mediaPlaybackEnabled ?? true
                    onToggled: Config.setNestedValue("osd.mediaPlaybackEnabled", !Config.options.osd.mediaPlaybackEnabled)
                }

                SettingsToggleRow {
                    label: "Brightness"
                    description: "Show OSD when brightness changes"
                    checked: Config.options.osd.brightnessEnabled ?? true
                    onToggled: Config.setNestedValue("osd.brightnessEnabled", !Config.options.osd.brightnessEnabled)
                }

                SettingsToggleRow {
                    label: "Idle inhibitor"
                    description: "Show OSD when toggling idle inhibitor"
                    checked: Config.options.osd.idleInhibitorEnabled ?? true
                    onToggled: Config.setNestedValue("osd.idleInhibitorEnabled", !Config.options.osd.idleInhibitorEnabled)
                }

                SettingsToggleRow {
                    label: "Microphone mute"
                    description: "Show OSD when mic is muted/unmuted"
                    checked: Config.options.osd.micMuteEnabled ?? true
                    onToggled: Config.setNestedValue("osd.micMuteEnabled", !Config.options.osd.micMuteEnabled)
                }

                SettingsToggleRow {
                    label: "Caps Lock"
                    description: "Show OSD when caps lock is toggled"
                    checked: Config.options.osd.capsLockEnabled ?? false
                    onToggled: Config.setNestedValue("osd.capsLockEnabled", !Config.options.osd.capsLockEnabled)
                }

                SettingsToggleRow {
                    label: "Power profile"
                    description: "Show OSD when power profile changes"
                    checked: Config.options.osd.powerProfileEnabled ?? true
                    onToggled: Config.setNestedValue("osd.powerProfileEnabled", !Config.options.osd.powerProfileEnabled)
                }

                SettingsToggleRow {
                    label: "Audio output switch"
                    description: "Show OSD when cycling audio output device"
                    checked: Config.options.osd.audioOutputEnabled ?? false
                    onToggled: Config.setNestedValue("osd.audioOutputEnabled", !Config.options.osd.audioOutputEnabled)
                }
            }
        }
    }

    Component {
        id: autostartPage
        PageBody {
            readonly property string autostartDir: `${FileUtils.trimFileProtocol(Directories.home)}/.config/autostart`
            property var autostartEntries: []
            property string errorText: ""

            Component.onCompleted: refreshAutostart()

            function refreshAutostart() {
                autostartProc.command = ["bash", "-c",
                    'for f in "' + autostartDir + '"/*.desktop "' + autostartDir + '"/*.desktop.disabled; do\n' +
                    '  [ -f "$f" ] || continue\n' +
                    '  base=$(basename "$f")\n' +
                    '  disabled=false\n' +
                    '  case "$base" in *.disabled) disabled=true;; esac\n' +
                    '  name=$(grep -m1 "^Name=" "$f" 2>/dev/null | cut -d= -f2-)\n' +
                    '  [ -z "$name" ] && name=$(echo "$base" | sed "s/\\.desktop.*//")\n' +
                    '  exec=$(grep -m1 "^Exec=" "$f" 2>/dev/null | cut -d= -f2-)\n' +
                    '  echo "$base|$disabled|$name|$exec"\n' +
                    'done']
                autostartProc.running = true
            }

            Process {
                id: autostartProc
                running: false
                stdout: StdioCollector {
                    id: autostartCollector
                    onStreamFinished: {
                        const entries = []
                        for (const line of autostartCollector.text.trim().split('\n')) {
                            if (!line.trim()) continue
                            const parts = line.split('|')
                            if (parts.length < 4) continue
                            entries.push({
                                file: parts[0],
                                disabled: parts[1] === "true",
                                name: parts[2],
                                exec: parts[3],
                            })
                        }
                        entries.sort((a, b) => a.name.localeCompare(b.name))
                        autostartPage.autostartEntries = entries
                    }
                }
            }

            SettingsCard {
                title: "Autostart Applications"
                subtitle: `${autostartPage.autostartEntries.length} entries`

                StyledText {
                    Layout.fillWidth: true
                    text: "Applications that start automatically when you log in."
                    color: root.cosmicDim
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: autostartPage.autostartEntries
                    delegate: Rectangle {
                        id: autoDelegate
                        required property var modelData
                        required property int index
                        readonly property var entry: modelData
                        readonly property bool isEnabled: !entry.disabled

                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        radius: root.cosmicRadius
                        color: autoMouse.containsMouse ? root.cosmicCardHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            MaterialSymbol {
                                text: autoDelegate.isEnabled ? "play_circle" : "pause_circle"
                                iconSize: 18
                                color: autoDelegate.isEnabled ? root.cosmicAccent : root.cosmicDim
                                Layout.preferredWidth: 22
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: autoDelegate.entry.name || "Unknown"
                                    color: root.cosmicFg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: autoDelegate.entry.exec || ""
                                    color: root.cosmicDim
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                }
                            }

                            // Enable/disable toggle
                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 26
                                radius: height / 2
                                color: autoDelegate.isEnabled ? root.cosmicAccent : "#5a5a5a"

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: autoDelegate.isEnabled ? parent.width - width - 3 : 3
                                    color: autoDelegate.isEnabled ? "#111111" : "#dedede"
                                    Behavior on x { NumberAnimation { duration: 110 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        const dir = autostartPage.autostartDir
                                        if (autoDelegate.isEnabled) {
                                            // Disable: rename .desktop → .desktop.disabled
                                            Quickshell.execDetached(["bash", "-c", `mv "${dir}/${autoDelegate.entry.file}" "${dir}/${autoDelegate.entry.file}.disabled" 2>/dev/null`])
                                        } else {
                                            // Enable: rename .desktop.disabled → .desktop
                                            Quickshell.execDetached(["bash", "-c", `mv "${dir}/${autoDelegate.entry.file}" "${dir}/${autoDelegate.entry.file.replace('.disabled', '')}" 2>/dev/null`])
                                        }
                                        autostartRefreshTimer.restart()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: autoMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }

                // Empty state
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    visible: autostartPage.autostartEntries.length === 0
                    color: "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: "No autostart entries found in ~/.config/autostart/"
                        color: root.cosmicDim
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            SettingsCard {
                title: "Add Entry"
                subtitle: "Open autostart folder"

                ButtonRow {
                    SettingsButton {
                        label: "Open Autostart Folder"
                        iconName: "folder_open"
                        onClicked: Quickshell.execDetached(["xdg-open", autostartPage.autostartDir])
                    }
                    SettingsButton {
                        label: "Refresh"
                        iconName: "refresh"
                        onClicked: autostartPage.refreshAutostart()
                    }
                }
            }

            Timer {
                id: autostartRefreshTimer
                interval: 500
                repeat: false
                onTriggered: autostartPage.refreshAutostart()
            }
        }
    }

    Component {
        id: windowRulesPage
        PageBody {
            readonly property string rulesFile: `${FileUtils.trimFileProtocol(Directories.config)}/omd/hypr/window_rules.lua`
            property var rules: []

            Component.onCompleted: refreshRules()

            function refreshRules() {
                rulesProc.command = ["bash", "-c", "cat \"" + rulesFile + "\" 2>/dev/null || echo ''"]
                rulesProc.running = true
            }

            Process {
                id: rulesProc
                running: false
                stdout: StdioCollector {
                    id: rulesCollector
                    onStreamFinished: {
                        const content = rulesCollector.text
                        const entries = []
                        // Parse lines like: o.window("class", { float = true })
                        const regex = /o\.window\(\s*["']([^"']+)["']\s*,\s*\{([^}]*)\}\s*\)/g
                        let match
                        while ((match = regex.exec(content)) !== null) {
                            entries.push({
                                class: match[1],
                                rules: match[2].trim(),
                            })
                        }
                        windowRulesPage.rules = entries
                    }
                }
            }

            function saveRules() {
                let content = "-- Window rules managed by OMD Settings Center\n-- Do not edit manually\n\n"
                for (const rule of windowRulesPage.rules) {
                    content += `o.window("${rule.class}", { ${rule.rules} })\n`
                }
                writeProc.command = ["bash", "-c", `cat > "${windowRulesPage.rulesFile}" << 'ENDRULES'\n${content}\nENDRULES`]
                writeProc.running = true
            }

            Process {
                id: writeProc
                running: false
                onExited: {
                    // Reload Hyprland config
                    Quickshell.execDetached(["hyprctl", "reload"])
                }
            }

            SettingsCard {
                title: "Window Rules"
                subtitle: `${windowRulesPage.rules.length} rule${windowRulesPage.rules.length === 1 ? "" : "s"}`

                StyledText {
                    Layout.fillWidth: true
                    text: "Define per-application window rules. Rules are written to omd/hypr/window_rules.lua and applied via hyprctl reload."
                    color: root.cosmicDim
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: windowRulesPage.rules
                    delegate: Rectangle {
                        id: ruleDelegate
                        required property var modelData
                        required property int index
                        readonly property var rule: modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        radius: root.cosmicRadius
                        color: ruleMouse.containsMouse ? root.cosmicCardHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            MaterialSymbol {
                                text: "window"
                                iconSize: 18
                                color: root.cosmicMuted
                                Layout.preferredWidth: 22
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: ruleDelegate.rule.class
                                    color: root.cosmicFg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: ruleDelegate.rule.rules
                                    color: root.cosmicDim
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                }
                            }

                            // Delete button
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: root.cosmicRadius
                                color: delMouse.containsMouse ? root.cosmicButtonHover : "transparent"

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    iconSize: 16
                                    color: "#f07070"
                                }

                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        windowRulesPage.rules.splice(ruleDelegate.index, 1)
                                        windowRulesPage.rules = windowRulesPage.rules.slice(0)
                                        windowRulesPage.saveRules()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: ruleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }

                // Empty state
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    visible: windowRulesPage.rules.length === 0
                    color: "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: "No window rules defined. Add one below."
                        color: root.cosmicDim
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            // ── Add New Rule ─────────────────────────────────────────────
            SettingsCard {
                title: "Add Rule"
                subtitle: "Define a new window rule"

                property string newClass: ""
                property string newRules: ""

                SettingsTextFieldRow {
                    label: "Application class"
                    description: "Window class to match (e.g. firefox, kitty, org.mozilla.firefox)"
                    text: parent.newClass
                    onTextEdited: (v) => parent.newClass = v
                    placeholder: "class name"
                }

                SettingsTextFieldRow {
                    label: "Rules"
                    description: "Lua table fields (e.g. float = true, opacity = 0.9)"
                    text: parent.newRules
                    onTextEdited: (v) => parent.newRules = v
                    placeholder: "float = true"
                    fieldWidth: 280
                }

                ButtonRow {
                    SettingsButton {
                        label: "Add Rule"
                        iconName: "add"
                        enabledState: parent.newClass.length > 0
                        onClicked: {
                            if (parent.newClass.length === 0) return
                            windowRulesPage.rules.push({
                                class: parent.newClass,
                                rules: parent.newRules || "float = true",
                            })
                            windowRulesPage.rules = windowRulesPage.rules.slice(0)
                            windowRulesPage.saveRules()
                            parent.newClass = ""
                            parent.newRules = ""
                        }
                    }
                    SettingsButton {
                        label: "Refresh"
                        iconName: "refresh"
                        onClicked: windowRulesPage.refreshRules()
                    }
                }
            }

            // ── Common Rules Quick Add ───────────────────────────────────
            SettingsCard {
                title: "Quick Add"
                subtitle: "Common window rule presets"

                ButtonRow {
                    SettingsButton {
                        label: "Float Terminal"
                        iconName: "picture_in_picture"
                        onClicked: {
                            windowRulesPage.rules.push({class: "kitty", rules: "float = true"})
                            windowRulesPage.rules = windowRulesPage.rules.slice(0)
                            windowRulesPage.saveRules()
                        }
                    }
                    SettingsButton {
                        label: "Float Firefox"
                        iconName: "picture_in_picture"
                        onClicked: {
                            windowRulesPage.rules.push({class: "org.mozilla.firefox", rules: "float = true"})
                            windowRulesPage.rules = windowRulesPage.rules.slice(0)
                            windowRulesPage.saveRules()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: soundsPage
        PageBody {
            SettingsCard {
                title: "System Sounds"
                subtitle: Config.options.sounds.theme ?? "freedesktop"

                SettingsToggleRow {
                    label: "Enable system sounds"
                    description: "Play sound effects for system events"
                    checked: Config.options.sounds.enabled ?? true
                    onToggled: Config.setNestedValue("sounds.enabled", !Config.options.sounds.enabled)
                }

                SettingsDropdownRow {
                    label: "Sound theme"
                    description: "Freedesktop sound theme for event sounds"
                    currentValue: Config.options.sounds.theme ?? "freedesktop"
                    options: {
                        const themes = []
                        // Scan available sound themes
                        const found = new Set()
                        // Common themes
                        const common = [
                            {value: "freedesktop", label: "Freedesktop"},
                            {value: "freedesktop-canon", label: "Freedesktop (Canon)"},
                            {value: "KDE", label: "KDE"},
                            {value: "GNOME", label: "GNOME"},
                        ]
                        for (const t of common) {
                            themes.push(t)
                            found.add(t.value)
                        }
                        return themes
                    }
                    onValueChanged: (v) => Config.setNestedValue("sounds.theme", v)
                }
            }

            SettingsCard {
                title: "Event Sounds"
                subtitle: "Per-event sound toggles"

                SettingsToggleRow {
                    label: "Volume change"
                    description: "Play sound when volume changes"
                    checked: Config.options.sounds.volumeChange ?? false
                    onToggled: Config.setNestedValue("sounds.volumeChange", !Config.options.sounds.volumeChange)
                }

                SettingsToggleRow {
                    label: "Notifications"
                    description: "Play sound on new notifications"
                    checked: Config.options.sounds.notification ?? false
                    onToggled: Config.setNestedValue("sounds.notification", !Config.options.sounds.notification)
                }

                SettingsToggleRow {
                    label: "Login"
                    description: "Play sound when logging in"
                    checked: Config.options.sounds.login ?? false
                    onToggled: Config.setNestedValue("sounds.login", !Config.options.sounds.login)
                }

                SettingsToggleRow {
                    label: "Power plug/unplug"
                    description: "Play sound when charger is connected/disconnected"
                    checked: Config.options.sounds.powerPlug ?? false
                    onToggled: Config.setNestedValue("sounds.powerPlug", !Config.options.sounds.powerPlug)
                }

                ButtonRow {
                    SettingsButton {
                        label: "Test Sound"
                        iconName: "play_arrow"
                        onClicked: Audio.playSystemSound("message")
                    }
                }
            }
        }
    }

    Component {
        id: appsPage
        PageBody {
            property string defaultBrowser: ""
            property string defaultFileManager: ""

            Component.onCompleted: {
                browserProc.running = true
                fileMgrProc.running = true
            }

            Process {
                id: browserProc
                command: ["bash", "-c", "xdg-mime query default x-scheme-handler/http 2>/dev/null || echo ''"]
                running: false
                stdout: StdioCollector {
                    id: browserCollector
                    onStreamFinished: appsPage.defaultBrowser = browserCollector.text.trim()
                }
            }

            Process {
                id: fileMgrProc
                command: ["bash", "-c", "xdg-mime query default inode/directory 2>/dev/null || echo ''"]
                running: false
                stdout: StdioCollector {
                    id: fileMgrCollector
                    onStreamFinished: appsPage.defaultFileManager = fileMgrCollector.text.trim()
                }
            }

            // ── Default Applications ─────────────────────────────────────
            SettingsCard {
                title: "Default Applications"
                subtitle: "System-wide app preferences"

                SettingsRow {
                    label: "Web browser"
                    description: "Opens http/https links"
                    value: appsPage.defaultBrowser || "--"
                }

                SettingsRow {
                    label: "File manager"
                    description: "Opens directories"
                    value: appsPage.defaultFileManager || "--"
                }

                ButtonRow {
                    SettingsButton {
                        label: "Set Default Browser"
                        iconName: "web"
                        onClicked: Quickshell.execDetached(["bash", "-c", "xdg-settings set default-web-browser $(zenity --file-selection --title='Select browser .desktop file' --filename=/usr/share/applications/ --file-filter='Desktop files | *.desktop') 2>/dev/null; true"])
                    }
                }
            }

            // ── OMD App Preferences ──────────────────────────────────────
            SettingsCard {
                title: "OMD App Preferences"
                subtitle: "Commands used by OMD shortcuts"

                SettingsTextFieldRow {
                    label: "Terminal"
                    description: "Command for opening terminal"
                    text: Config.options.apps.terminal ?? ""
                    onTextEdited: (v) => Config.setNestedValue("apps.terminal", v)
                    placeholder: "kitty -1"
                }

                SettingsTextFieldRow {
                    label: "Task manager"
                    description: "Command for task manager"
                    text: Config.options.apps.taskManager ?? ""
                    onTextEdited: (v) => Config.setNestedValue("apps.taskManager", v)
                    placeholder: "plasma-systemmonitor"
                }

                SettingsTextFieldRow {
                    label: "Network settings"
                    description: "Command for network management"
                    text: Config.options.apps.network ?? ""
                    onTextEdited: (v) => Config.setNestedValue("apps.network", v)
                }

                SettingsTextFieldRow {
                    label: "Bluetooth settings"
                    description: "Command for Bluetooth management"
                    text: Config.options.apps.bluetooth ?? ""
                    onTextEdited: (v) => Config.setNestedValue("apps.bluetooth", v)
                }

                SettingsTextFieldRow {
                    label: "Volume mixer"
                    description: "Command for volume control"
                    text: Config.options.apps.volumeMixer ?? ""
                    onTextEdited: (v) => Config.setNestedValue("apps.volumeMixer", v)
                }

                SettingsTextFieldRow {
                    label: "System update"
                    description: "Command for system updates"
                    text: Config.options.apps.update ?? ""
                    onTextEdited: (v) => Config.setNestedValue("apps.update", v)
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
                        onClicked: Quickshell.execDetached(["omd-launch-tui", `${omdRoot}/scripts/voice-bind-tui`])
                    }
                    SettingsButton {
                        label: "Capture Key"
                        iconName: "keyboard"
                        onClicked: Quickshell.execDetached([`${omdRoot}/scripts/key-test`, "--hotkey"])
                    }
                }

            }

            Process {
                id: voiceBindingsProc
                command: ["bash", "-c", "cat ~/.config/omd/config/voice_bindings.txt 2>/dev/null || echo ''"]
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
                        onClicked: Quickshell.execDetached(["omd-launch-tui", `${omdRoot}/scripts/voice-test-tui`])
                    }
                }
                ButtonRow {
                    SettingsButton {
                        label: "Diagnose"
                        iconName: "health_and_safety"
                        onClicked: Quickshell.execDetached(["omd-launch-tui", `${omdRoot}/scripts/voice-diagnose`])
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
        id: keyremapPage
        PageBody {
            SettingsCard {
                title: "Keyboard Remap"
                subtitle: KeyboardRemap.keydReady ? "keyd running" : "keyd not ready — setup required"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SettingsStatusPill { label: KeyboardRemap.state; active: KeyboardRemap.state === "ready" }
                    SettingsStatusPill { label: KeyboardRemap.keydReady ? "keyd up" : "keyd down"; active: KeyboardRemap.keydReady; warning: !KeyboardRemap.keydReady }
                    SettingsStatusPill {
                        label: `${KeyboardRemap.devices.length} device${KeyboardRemap.devices.length === 1 ? "" : "s"}`
                        active: KeyboardRemap.devices.length > 0
                    }
                    SettingsStatusPill {
                        label: KeyboardRemap.hasPendingChanges ? "pending changes" : "applied"
                        active: KeyboardRemap.hasPendingChanges
                        warning: KeyboardRemap.hasPendingChanges
                    }
                }

                SettingsRow {
                    label: "Active keyboard"
                    value: KeyboardRemap.selectedProfile?.displayName ?? KeyboardRemap.selectedDeviceId ?? "--"
                }
                SettingsRow {
                    label: "Device ID"
                    value: KeyboardRemap.selectedDevice?.keydId || "--"
                }
                SettingsRow {
                    visible: KeyboardRemap.selectedKeydIdMissing
                    label: "Warning"
                    description: "This keyboard has no keyd vendor:product ID. Remaps cannot be applied until it is resolved (try reconnecting or check /proc/bus/input/devices)."
                    value: "no keydId"
                    valueColor: "#f0a070"
                }
                SettingsRow {
                    visible: KeyboardRemap.lastError.length > 0
                    label: "Last error"
                    description: KeyboardRemap.lastError
                }

                ButtonRow {
                    SettingsButton {
                        label: KeyboardRemap.state === "setup" ? "Setup keyd" : "Recheck"
                        iconName: "download"
                        onClicked: {
                            if (KeyboardRemap.state === "setup")
                                KeyboardRemap.setup();
                            else
                                KeyboardRemap.checkKeyd();
                        }
                    }
                    SettingsButton {
                        label: KeyboardRemap.applyInProgress ? "Applying…" : (KeyboardRemap.hasPendingChanges ? "Apply changes" : "Apply")
                        iconName: "check"
                        enabledState: !KeyboardRemap.applyInProgress
                        onClicked: KeyboardRemap.apply()
                    }
                    SettingsButton {
                        label: "Refresh"
                        iconName: "refresh"
                        onClicked: {
                            KeyboardRemap.refreshDevices();
                            KeyboardRemap.loadProfiles();
                            KeyboardRemap.checkKeyd();
                        }
                    }
                }
            }

            SettingsCard {
                title: "Keyboards"
                subtitle: KeyboardRemap.devices.length > 0 ? "Select a keyboard to edit its profile" : "No keyboards detected"
                visible: KeyboardRemap.devices.length > 0

                Repeater {
                    model: KeyboardRemap.devices
                    delegate: SettingsRow {
                        required property var modelData
                        iconName: "keyboard"
                        label: `${modelData.displayName}${modelData.main ? " • main" : ""}`
                        value: {
                            const count = KeyboardRemap.remapCount(modelData.hyprName);
                            if (KeyboardRemap.selectedDeviceId === modelData.hyprName)
                                return count > 0 ? `Selected • ${count} remap${count === 1 ? "" : "s"}` : "Selected";
                            return count > 0 ? `${count} remap${count === 1 ? "" : "s"}` : (modelData.keydId || "");
                        }
                        valueColor: KeyboardRemap.selectedDeviceId === modelData.hyprName ? root.cosmicAccent : root.cosmicMuted
                        onClicked: KeyboardRemap.selectDevice(modelData.hyprName)
                    }
                }
            }

            SettingsCard {
                title: "Profile"
                subtitle: KeyboardRemap.selectedDeviceId !== "" ? "Per-keyboard remap rules" : "Select a keyboard first"
                visible: KeyboardRemap.selectedDeviceId !== ""

                SettingsToggleRow {
                    label: "Enabled"
                    description: "Disable to keep profile but skip applying remaps"
                    checked: KeyboardRemap.selectedEnabled
                    onToggled: KeyboardRemap.setProfileEnabled(!KeyboardRemap.selectedEnabled)
                }

                Repeater {
                    model: KeyboardRemap.selectedRemaps
                    delegate: SettingsRow {
                        required property var modelData
                        iconName: "keyboard"
                        label: `${modelData.from} → ${modelData.to}`
                        value: "Remove"
                        valueColor: "#f07070"
                        onClicked: KeyboardRemap.removeRemap(modelData.from)
                    }
                }

                SettingsRow {
                    visible: KeyboardRemap.selectedRemaps.length === 0
                    iconName: "info"
                    label: "No remaps yet"
                    description: "Capture a source key below, pick a target, then add. Press Apply changes when you are done."
                }
            }

            SettingsCard {
                id: addRemapCard
                title: "Add Remap"
                subtitle: KeyboardRemap.capturedFromKey !== ""
                    ? (KeyboardRemap.remapTargetFor(KeyboardRemap.capturedFromKey) !== ""
                        ? `Source already mapped — choose a new target to update the draft`
                        : `Source captured — pick a target and add to the draft`)
                    : "Press a key to capture, then choose a target"
                visible: KeyboardRemap.selectedDeviceId !== ""
                property string targetKey: KeyboardRemap.keyChoices.length > 0 ? KeyboardRemap.keyChoices[0] : ""

                function syncTargetForCapturedKey() {
                    const existingTarget = KeyboardRemap.remapTargetFor(KeyboardRemap.capturedFromKey);
                    if (existingTarget !== "") {
                        targetKey = existingTarget;
                    } else if (KeyboardRemap.keyChoices.indexOf(targetKey) < 0 && KeyboardRemap.keyChoices.length > 0) {
                        targetKey = KeyboardRemap.keyChoices[0];
                    }
                }

                Item {
                    Layout.preferredHeight: 0
                    Layout.fillWidth: true
                    visible: false

                    Connections {
                        target: KeyboardRemap
                        function onCapturedFromKeyChanged() {
                            addRemapCard.syncTargetForCapturedKey();
                        }
                        function onSelectedDeviceIdChanged() {
                            addRemapCard.syncTargetForCapturedKey();
                        }
                        function onDeviceProfilesChanged() {
                            addRemapCard.syncTargetForCapturedKey();
                        }
                    }
                }

                // Step 1: Capture button
                ButtonRow {
                    SettingsButton {
                        label: KeyboardRemap.captureWindowOpen
                            ? "Waiting… (settings hidden while capture window is open)"
                            : "Press a key to capture"
                        iconName: "keyboard"
                        active: KeyboardRemap.captureWindowOpen
                        enabledState: !KeyboardRemap.captureWindowOpen
                        onClicked: KeyboardRemap.startCapture()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !KeyboardRemap.captureWindowOpen
                    text: "Click the button above to open a capture window. Settings will hide while you press a key, then return with the captured key auto-filled."
                    color: root.cosmicMuted
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }

                // Error / pending (unsupported key) notice
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: pendingNoticeCol.implicitHeight + 16
                    radius: root.cosmicRadius
                    color: "#3a1f1f"
                    border.width: 1
                    border.color: "#f07070"
                    visible: KeyboardRemap.lastError.length > 0
                    ColumnLayout {
                        id: pendingNoticeCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4
                        StyledText {
                            text: KeyboardRemap.lastError
                            color: "#f0a070"
                            font.pixelSize: Appearance.font.pixelSize.small
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        SettingsButton {
                            label: "Dismiss"
                            iconName: "close"
                            onClicked: KeyboardRemap.clearCapturedKey()
                        }
                    }
                }

                // Source → Target row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Source key (auto-filled from capture)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: root.cosmicRadius
                        color: root.cosmicPanel
                        border.width: 1
                        border.color: KeyboardRemap.capturedFromKey ? root.cosmicAccent : root.cosmicLine
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 0
                            StyledText {
                                text: "Source key"
                                color: root.cosmicDim
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: KeyboardRemap.capturedFromKey || "—"
                                color: KeyboardRemap.capturedFromKey ? root.cosmicAccent : root.cosmicMuted
                                font.family: Appearance.font.family.monospace
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                    }

                    StyledText {
                        text: "→"
                        color: root.cosmicDim
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.Bold
                    }

                    // Target key dropdown
                    Rectangle {
                        id: keyremapTargetBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: root.cosmicRadius
                        color: targetMouse.containsMouse && KeyboardRemap.capturedFromKey !== "" ? root.cosmicButtonHover : root.cosmicPanel
                        border.width: 1
                        border.color: targetPopup.visible ? root.cosmicAccent : root.cosmicLine
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 0
                            StyledText {
                                text: "Target key"
                                color: root.cosmicDim
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                StyledText {
                                    Layout.fillWidth: true
                                    text: addRemapCard.targetKey
                                    color: KeyboardRemap.capturedFromKey !== "" ? root.cosmicFg : root.cosmicMuted
                                    font.family: Appearance.font.family.monospace
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    elide: Text.ElideRight
                                }
                                MaterialSymbol {
                                    text: targetPopup.visible ? "expand_less" : "expand_more"
                                    iconSize: 18
                                    color: root.cosmicMuted
                                }
                            }
                        }

                        MouseArea {
                            id: targetMouse
                            anchors.fill: parent
                            enabled: KeyboardRemap.capturedFromKey !== ""
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: targetPopup.open()
                        }

                        Popup {
                            id: targetPopup
                            y: keyremapTargetBox.height + 4
                            width: keyremapTargetBox.width
                            height: Math.min(280, targetList.contentHeight + 8)
                            padding: 4

                            background: Rectangle {
                                radius: root.cosmicRadius
                                color: root.cosmicPanel
                                border.width: 1
                                border.color: root.cosmicLine
                            }

                            contentItem: ListView {
                                id: targetList
                                clip: true
                                model: KeyboardRemap.keyChoices
                                currentIndex: KeyboardRemap.keyChoices.indexOf(addRemapCard.targetKey)
                                delegate: Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: targetList.width
                                    height: 34
                                    radius: root.cosmicRadius
                                    color: targetChoiceMouse.containsMouse
                                        ? root.cosmicCardHover
                                        : (modelData === addRemapCard.targetKey ? root.cosmicAccentSoft : "transparent")

                                    StyledText {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        text: modelData
                                        color: root.cosmicFg
                                        font.family: Appearance.font.family.monospace
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: targetChoiceMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            addRemapCard.targetKey = modelData;
                                            targetPopup.close();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Captured-as detail (collapsible info)
                SettingsRow {
                    visible: KeyboardRemap.capturedFromLabel.length > 0
                    label: "Captured as"
                    value: KeyboardRemap.capturedFromLabel
                    description: KeyboardRemap.capturedFromCode.length > 0
                        ? `Hardware code ${KeyboardRemap.capturedFromCode} → keyd ${KeyboardRemap.capturedFromKey}`
                        : `keyd ${KeyboardRemap.capturedFromKey}`
                    valueColor: root.cosmicAccent
                }

                SettingsRow {
                    visible: KeyboardRemap.capturedFromKey !== "" && KeyboardRemap.remapTargetFor(KeyboardRemap.capturedFromKey) !== ""
                    label: "Existing mapping"
                    value: `${KeyboardRemap.capturedFromKey} -> ${KeyboardRemap.remapTargetFor(KeyboardRemap.capturedFromKey)}`
                    description: "Saving will update this existing source key instead of adding a duplicate"
                    valueColor: root.cosmicAccent
                }

                // Apply / Clear buttons
                ButtonRow {
                    SettingsButton {
                        label: KeyboardRemap.remapTargetFor(KeyboardRemap.capturedFromKey) !== "" ? "Update" : "Add"
                        iconName: KeyboardRemap.remapTargetFor(KeyboardRemap.capturedFromKey) !== "" ? "edit" : "add"
                        enabledState: KeyboardRemap.capturedFromKey !== ""
                        onClicked: KeyboardRemap.saveRemap(addRemapCard.targetKey)
                    }
                    SettingsButton {
                        label: "Clear"
                        iconName: "refresh"
                        enabledState: KeyboardRemap.capturedFromKey !== "" || KeyboardRemap.captureWindowOpen
                        onClicked: KeyboardRemap.clearCapturedKey()
                    }
                }
            }

            SettingsCard {
                title: "Presets"
                subtitle: "Replace the draft remaps with a preset layout"
                visible: KeyboardRemap.selectedDeviceId !== ""

                ButtonRow {
                    Repeater {
                        model: Object.keys(KeyboardRemap.presets)
                        delegate: SettingsButton {
                            required property string modelData
                            label: KeyboardRemap.presets[modelData].label
                            iconName: "auto_fix_high"
                            onClicked: KeyboardRemap.applyPreset(modelData)
                        }
                    }
                }
            }

            SettingsCard {
                title: "Storage"
                SettingsRow { label: "Profiles"; value: KeyboardRemap.profilesPath }
                SettingsRow { label: "Backend"; value: "/etc/keyd/omd.conf (via Apply)" }
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
                subtitle: windowsState.configured ? "Generated by omd-windows-vm" : "Created during install"
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
