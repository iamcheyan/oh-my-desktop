import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Image {
    asynchronous: true
    retainWhileLoading: true
    visible: opacity > 0
    opacity: (status === Image.Ready) ? 1 : 0
    Behavior on opacity {
        // The animation system defaults to duration 0 in performance mode,
        // which makes asynchronously-loaded icons "snap" in after their
        // parent (e.g. a ScreencopyView snapshot) is already shown. Use a
        // small fixed fade so the icon appears to land on the preview
        // instead of popping in.
        NumberAnimation {
            duration: Appearance?.animation?.elementMoveEnter?.duration > 0
                ? Appearance.animation.elementMoveEnter.duration
                : 120
            easing.type: Easing.OutCubic
        }
    }

    property list<string> fallbacks: []
    property int currentFallbackIndex: 0

    onStatusChanged: {
        if (status === Image.Error && currentFallbackIndex < fallbacks.length) {
            source = fallbacks[currentFallbackIndex];
            currentFallbackIndex += 1;
        }
    }

    sourceSize: {
        const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
        return Qt.size(width * dpr, height * dpr);
    }
}
