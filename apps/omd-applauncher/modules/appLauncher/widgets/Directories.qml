pragma Singleton
import QtQuick
import Quickshell

QtObject {
    readonly property string config: (Quickshell.env("HOME") ?? "") + "/.config"
    readonly property string assetsPath: (Quickshell.env("HOME") ?? "") + "/Development/oh-my-desktop/quickshell/assets"
}
