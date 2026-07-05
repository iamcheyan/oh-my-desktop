pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item { // Window
    id: root
    property var toplevel
    property var windowData
    property var monitorData
    property var scale
    property real scaleX: scale * widthRatio
    property real scaleY: scale * heightRatio
    property bool restrictToWorkspace: true
    property real widthRatio: {
        const widgetWidth = widgetMonitor.transform & 1 ? widgetMonitor.height : widgetMonitor.width;
        const monitorWidth = monitorData.transform & 1 ? monitorData.height : monitorData.width;
        return (widgetWidth * monitorData.scale) / (monitorWidth * widgetMonitor.scale);
    }
    property real heightRatio: {
        const widgetHeight = widgetMonitor.transform & 1 ? widgetMonitor.width : widgetMonitor.height;
        const monitorHeight = monitorData.transform & 1 ? monitorData.width : monitorData.height;
        return (widgetHeight * monitorData.scale) / (monitorHeight * widgetMonitor.scale);
    }
    property real initX: {
        return xOffset + localX;
    }

    property real initY: {
        return yOffset + localY;
    }
    property real xOffset: 0
    property real yOffset: 0
    property real workspaceWidth: 1
    property real workspaceHeight: 1
    property var widgetMonitor
    property int widgetMonitorId: widgetMonitor.id

    // Monitor logical dimensions (accounting for transforms)
    property real monitorLogicalWidth: {
        if (!monitorData) return 1920;
        const w = monitorData.transform & 1 ? monitorData.height : monitorData.width;
        return w / (monitorData.scale ?? 1);
    }
    property real monitorLogicalHeight: {
        if (!monitorData) return 1080;
        const h = monitorData.transform & 1 ? monitorData.width : monitorData.height;
        return h / (monitorData.scale ?? 1);
    }

    // Raw coordinate relative to the monitor the window claims to be on.
    // These may be stale after a cross-monitor move — Hyprland does not
    // re-tile windows on inactive workspaces.
    property real rawRelX: (windowData?.at[0] ?? 0) - (monitorData?.x ?? 0) - (monitorData?.reserved[0] ?? 0)
    property real rawRelY: (windowData?.at[1] ?? 0) - (monitorData?.y ?? 0) - (monitorData?.reserved[1] ?? 0)
    property real rawW: windowData?.size[0] ?? 800
    property real rawH: windowData?.size[1] ?? 600

    // After scaling and clamping, would this window be too small to see?
    // This happens when stale coordinates place the window near/past the
    // monitor edge, so clamping squishes it to just a few pixels.
    property bool isRenderDegenerate: {
        const clampedX = Math.max(0, Math.min(rawRelX * root.scaleX, Math.max(0, workspaceWidth - 1)));
        const visibleW = Math.min(rawW * root.scaleX, Math.max(1, workspaceWidth - clampedX));
        const clampedY = Math.max(0, Math.min(rawRelY * root.scaleY, Math.max(0, workspaceHeight - 1)));
        const visibleH = Math.min(rawH * root.scaleY, Math.max(1, workspaceHeight - clampedY));
        // If either dimension is less than 10 % of the workspace box, the
        // window is effectively invisible — treat it as degenerate.
        return visibleW < workspaceWidth * 0.10 || visibleH < workspaceHeight * 0.10;
    }

    // When degenerate, center the window inside its workspace box at a
    // reasonable size; otherwise use the real Hyprland coordinates.
    property real effectiveW: isRenderDegenerate ? Math.min(rawW, monitorLogicalWidth) : rawW
    property real effectiveH: isRenderDegenerate ? Math.min(rawH, monitorLogicalHeight) : rawH
    property real effectiveRelX: isRenderDegenerate ? (monitorLogicalWidth - effectiveW) / 2 : rawRelX
    property real effectiveRelY: isRenderDegenerate ? (monitorLogicalHeight - effectiveH) / 2 : rawRelY

    property real rawLocalX: effectiveRelX * root.scaleX
    property real rawLocalY: effectiveRelY * root.scaleY
    property real rawWindowWidth: Math.max(1, effectiveW * root.scaleX)
    property real rawWindowHeight: Math.max(1, effectiveH * root.scaleY)
    property real localX: Math.max(0, Math.min(rawLocalX, Math.max(0, workspaceWidth - 1)))
    property real localY: Math.max(0, Math.min(rawLocalY, Math.max(0, workspaceHeight - 1)))
    property var targetWindowWidth: Math.max(1, Math.min(rawWindowWidth, Math.max(1, workspaceWidth - localX)))
    property var targetWindowHeight: Math.max(1, Math.min(rawWindowHeight, Math.max(1, workspaceHeight - localY)))
    property bool hovered: false
    property bool pressed: false

    property bool centerIcons: Config.options.overview.centerIcons
    property real iconGapRatio: 0.06
    property real iconToWindowRatio: centerIcons ? 0.35 : 0.15
    property real xwaylandIndicatorToIconRatio: 0.35
    property real iconToWindowRatioCompact: 0.6
    property string iconPath: AppSearch.iconSource(AppSearch.guessIcon(windowData?.class))
    property bool compactMode: Appearance.font.pixelSize.smaller * 4 > targetWindowHeight || Appearance.font.pixelSize.smaller * 4 > targetWindowWidth

    property bool indicateXWayland: windowData?.xwayland ?? false

    x: xOffset + localX
    y: yOffset + localY
    width: targetWindowWidth
    height: targetWindowHeight
    opacity: 1

    property real topLeftRadius
    property real topRightRadius
    property real bottomLeftRadius
    property real bottomRightRadius

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomRightRadius: root.bottomRightRadius
            bottomLeftRadius: root.bottomLeftRadius
        }
    }

    Behavior on x {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on y {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on width {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on height {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }

    ScreencopyView {
        id: windowPreview
        anchors.fill: parent
        captureSource: GlobalStates.overviewOpen ? root.toplevel : null
        live: true

        // Color overlay for interactions
        Rectangle {
            anchors.fill: parent
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomRightRadius: root.bottomRightRadius
            bottomLeftRadius: root.bottomLeftRadius
            color: pressed ? ColorUtils.transparentize(Appearance.colors.colLayer2Active, 0.5) : 
                hovered ? ColorUtils.transparentize(Appearance.colors.colLayer2Hover, 0.7) : 
                ColorUtils.transparentize(Appearance.colors.colLayer2)
        }

        StyledImage {
            id: windowIcon
            property real baseSize: Math.min(root.targetWindowWidth, root.targetWindowHeight)
            anchors {
                top: root.centerIcons ? undefined : parent.top
                left: root.centerIcons ? undefined : parent.left
                centerIn: root.centerIcons ? parent : undefined
                margins: baseSize * root.iconGapRatio
            }
            property var iconSize: {
                // console.log("-=-=-", root.toplevel.title, "-=-=-")
                // console.log("Target window size:", targetWindowWidth, targetWindowHeight)
                // console.log("Icon ratio:", root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio)
                // console.log("Scale:", root.monitorData.scale)
                // console.log("Final:", Math.min(targetWindowWidth, targetWindowHeight) * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio) / root.monitorData.scale)
                return baseSize * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio);
            }
            mipmap: true
            Layout.alignment: Qt.AlignHCenter
            source: root.iconPath
            width: iconSize
            height: iconSize

            Behavior on width {
                animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
            }
            Behavior on height {
                animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
            }
        }

        Rectangle {
            visible: root.iconPath === "" || windowIcon.status === Image.Error
            anchors {
                top: root.centerIcons ? undefined : parent.top
                left: root.centerIcons ? undefined : parent.left
                centerIn: root.centerIcons ? parent : undefined
                margins: Math.min(root.targetWindowWidth, root.targetWindowHeight) * root.iconGapRatio
            }
            width: windowIcon.width
            height: windowIcon.height
            radius: Math.max(4, width * 0.18)
            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.25)

            StyledText {
                anchors.centerIn: parent
                text: (windowData?.class || windowData?.title || "?").charAt(0).toUpperCase()
                font.pixelSize: Math.max(10, parent.height * 0.45)
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnPrimary
            }
        }
    }

    // Border around the entire workspace thumbnail (sibling of ScreencopyView)
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomRightRadius: root.bottomRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        border.color: ColorUtils.transparentize(Appearance.m3colors.m3outlineVariant, 1)
        border.width: 2
    }
}
