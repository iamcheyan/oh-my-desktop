import QtCore
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property bool show: false
    property string mode: "file"
    property string currentPath: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    property string selectedPath: ""
    property bool selectedIsDir: false
    property int selectedIndex: -1
    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property bool dragging: false

    signal accepted(string mode, string path)
    signal dismissed()

    function open(nextMode) {
        mode = nextMode || "file";
        selectedPath = "";
        selectedIsDir = false;
        selectedIndex = -1;
        dragOffsetX = 0;
        dragOffsetY = 0;
        show = true;
        Qt.callLater(() => keyScope.forceActiveFocus());
    }

    function close() {
        show = false;
        dismissed();
    }

    function selectPath(path, isDir, index) {
        selectedPath = path;
        selectedIsDir = isDir;
        selectedIndex = index;
    }

    function activatePath(path, isDir, index) {
        if (isDir) {
            currentPath = path;
            selectedPath = "";
            selectedIsDir = false;
            selectedIndex = -1;
            return;
        }
        if (mode === "file") {
            accepted(mode, path);
            close();
        }
    }

    function chooseCurrentFolder() {
        accepted("folder", currentPath);
        close();
    }

    function goUp() {
        if (!currentPath || currentPath === "/")
            return;
        const trimmed = currentPath.replace(/\/+$/, "");
        const idx = trimmed.lastIndexOf("/");
        currentPath = idx <= 0 ? "/" : trimmed.slice(0, idx);
        selectedPath = "";
        selectedIsDir = false;
        selectedIndex = -1;
    }

    function fileUrl(path) {
        if (!path || path.length === 0)
            return "";
        return "file://" + path.split("/").map(s => encodeURIComponent(s)).join("/");
    }

    function isImageFile(fileName) {
        const lower = String(fileName || "").toLowerCase();
        return lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".png")
            || lower.endsWith(".webp") || lower.endsWith(".bmp") || lower.endsWith(".gif")
            || lower.endsWith(".jxl") || lower.endsWith(".avif") || lower.endsWith(".heif")
            || lower.endsWith(".exr");
    }

    anchors.fill: parent
    visible: show
    z: 200
    opacity: show ? 1 : 0

    Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.48)
    }

    FocusScope {
        id: keyScope
        x: parent.width / 2 - width / 2 + root.dragOffsetX
        y: parent.height / 2 - height / 2 + root.dragOffsetY
        width: Math.min(860, parent.width - 48)
        height: Math.min(580, parent.height - 48)
        focus: root.show

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backspace || (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Left)) {
                root.goUp();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.mode === "folder") {
                    if (root.selectedIsDir && root.selectedPath.length > 0)
                        root.currentPath = root.selectedPath;
                    else
                        root.chooseCurrentFolder();
                } else if (!root.selectedIsDir && root.selectedPath.length > 0) {
                    root.accepted(root.mode, root.selectedPath);
                    root.close();
                }
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: TuiStyle.shellRadius
            color: "#181818"
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.shellBorder
            clip: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: "#202020"

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property real pressX: 0
                        property real pressY: 0
                        property real startX: 0
                        property real startY: 0

                        onPressed: mouse => {
                            pressX = mouse.x;
                            pressY = mouse.y;
                            startX = root.dragOffsetX;
                            startY = root.dragOffsetY;
                            root.dragging = true;
                            keyScope.forceActiveFocus();
                        }

                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            const nextX = startX + mouse.x - pressX;
                            const nextY = startY + mouse.y - pressY;
                            const maxX = Math.max(0, root.width / 2 - keyScope.width / 2 - 16);
                            const maxY = Math.max(0, root.height / 2 - keyScope.height / 2 - 16);
                            root.dragOffsetX = Math.max(-maxX, Math.min(maxX, nextX));
                            root.dragOffsetY = Math.max(-maxY, Math.min(maxY, nextY));
                        }

                        onReleased: root.dragging = false
                        onCanceled: root.dragging = false
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 14
                        spacing: 12

                        MaterialSymbol {
                            text: root.mode === "folder" ? "folder_open" : "wallpaper"
                            iconSize: 22
                            color: TuiStyle.accent
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: root.mode === "folder" ? "Select Wallpaper Folder" : "Select Wallpaper"
                                color: "#f4f4f4"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.currentPath
                                color: "#9f9f9f"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                elide: Text.ElideMiddle
                            }
                        }

                        IconButton {
                            iconName: "arrow_upward"
                            onClicked: root.goUp()
                        }

                        IconButton {
                            iconName: "close"
                            onClicked: root.close()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#383838"
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Rectangle {
                        Layout.preferredWidth: 188
                        Layout.fillHeight: true
                        color: "#222222"

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            QuickPlace { label: "Home"; iconName: "home"; path: StandardPaths.writableLocation(StandardPaths.HomeLocation) }
                            QuickPlace { label: "Pictures"; iconName: "image"; path: StandardPaths.writableLocation(StandardPaths.PicturesLocation) }
                            QuickPlace { label: "Downloads"; iconName: "download"; path: StandardPaths.writableLocation(StandardPaths.DownloadLocation) }
                            QuickPlace { label: "Desktop"; iconName: "desktop_windows"; path: StandardPaths.writableLocation(StandardPaths.DesktopLocation) }

                            Item { Layout.fillHeight: true }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.mode === "folder" ? "Choose a folder, or press Use This Folder." : "Open a folder, then choose an image."
                                color: "#8f8f8f"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        color: "#383838"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        GridView {
                            id: fileGrid
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: folderModel
                            cellWidth: 128
                            cellHeight: 144
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: StyledScrollBar {}

                            delegate: FileTile {
                                required property string fileName
                                required property string filePath
                                required property bool fileIsDir
                                required property int index

                                width: fileGrid.cellWidth - 10
                                height: fileGrid.cellHeight - 10
                                name: fileName
                                path: filePath
                                isDir: fileIsDir
                                selected: root.selectedIndex === index
                                imageFile: root.isImageFile(fileName)

                                onClicked: {
                                    root.selectPath(filePath, fileIsDir, index);
                                    if (fileIsDir || root.mode === "file")
                                        root.activatePath(filePath, fileIsDir, index);
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 62
                            color: "#202020"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 10

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.mode === "folder"
                                        ? `Folder: ${root.currentPath}`
                                        : (root.selectedPath.length > 0 ? root.selectedPath : "No image selected")
                                    color: root.selectedPath.length > 0 || root.mode === "folder" ? "#d8d8d8" : "#8f8f8f"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    elide: Text.ElideMiddle
                                }

                                ActionButton {
                                    label: "Cancel"
                                    onClicked: root.close()
                                }

                                ActionButton {
                                    label: root.mode === "folder" ? "Use This Folder" : "Select Image"
                                    active: true
                                    enabledState: root.mode === "folder" || (root.selectedPath.length > 0 && !root.selectedIsDir)
                                    onClicked: {
                                        if (root.mode === "folder") {
                                            root.chooseCurrentFolder();
                                        } else if (root.selectedPath.length > 0 && !root.selectedIsDir) {
                                            root.accepted(root.mode, root.selectedPath);
                                            root.close();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    FolderListModel {
        id: folderModel
        folder: root.fileUrl(root.currentPath)
        showDirs: true
        showFiles: true
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: false
        caseSensitive: false
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp", "*.gif", "*.jxl", "*.avif", "*.heif", "*.exr"]
    }

    component QuickPlace: Rectangle {
        id: place
        property string label: ""
        property string iconName: ""
        property string path: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: 8
        color: root.currentPath === path ? OmarchyTheme.accentSoft : placeMouse.containsMouse ? "#303030" : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            MaterialSymbol {
                text: place.iconName
                iconSize: 18
                color: root.currentPath === place.path ? TuiStyle.accent : "#b8b8b8"
            }

            StyledText {
                Layout.fillWidth: true
                text: place.label
                color: root.currentPath === place.path ? TuiStyle.accent : "#d8d8d8"
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: placeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.currentPath = place.path;
                root.selectedPath = "";
                root.selectedIsDir = false;
                root.selectedIndex = -1;
            }
        }
    }

    component IconButton: Rectangle {
        id: button
        property string iconName: ""
        signal clicked()

        Layout.preferredWidth: 36
        Layout.preferredHeight: 36
        radius: 8
        color: buttonMouse.containsMouse ? "#343434" : "transparent"

        MaterialSymbol {
            anchors.centerIn: parent
            text: button.iconName
            iconSize: 20
            color: "#f4f4f4"
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component ActionButton: Rectangle {
        id: button
        property string label: ""
        property bool active: false
        property bool enabledState: true
        signal clicked()

        Layout.preferredWidth: Math.max(112, buttonText.implicitWidth + 28)
        Layout.preferredHeight: 38
        radius: 8
        color: active ? OmarchyTheme.accentSoft : buttonMouse.containsMouse ? "#343434" : "#2a2a2a"
        border.width: 1
        border.color: active ? TuiStyle.accent : "#4a4a4a"
        opacity: enabledState ? 1 : 0.45

        StyledText {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            color: active ? TuiStyle.accent : "#f4f4f4"
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
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

    component FileTile: Rectangle {
        id: tile
        property string name: ""
        property string path: ""
        property bool isDir: false
        property bool selected: false
        property bool imageFile: false
        signal clicked()

        radius: 10
        color: selected ? OmarchyTheme.accentSoft : tileMouse.containsMouse ? "#2a2a2a" : "transparent"
        border.width: selected ? 1 : 0
        border.color: TuiStyle.accent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 88
                radius: 8
                clip: true
                color: "#303030"

                Image {
                    anchors.fill: parent
                    source: !tile.isDir && tile.imageFile ? root.fileUrl(tile.path) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: tile.isDir || !tile.imageFile
                    text: tile.isDir ? "folder" : "draft"
                    iconSize: 34
                    color: tile.isDir ? TuiStyle.accent : "#b8b8b8"
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: tile.name
                color: "#e8e8e8"
                font.pixelSize: Appearance.font.pixelSize.smaller
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }
}
