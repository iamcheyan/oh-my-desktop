pragma Singleton
import QtQuick

QtObject {
    id: root
    property QtObject font: QtObject {
        property QtObject pixelSize: QtObject {
            property int smallest: 8
            property int smaller: 10
            property int small: 12
            property int normal: 14
            property int large: 18
        }
        property QtObject family: QtObject {
            property string main: "MesloLGS Nerd Font"
        }
    }
}
