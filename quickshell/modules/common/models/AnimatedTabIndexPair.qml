import QtQuick

// idx1 is the "leading" indicator position, idx2 is the "following" one
// The former animates faster than the latter, see the NumberAnimations below
QtObject {
    id: root
    required property int index

    property real idx1: index
    property real idx2: index
    property int idx1Duration: 0
    property int idx2Duration: 0

    Behavior on idx1 {
        NumberAnimation {
            duration: 0
        }
    }
    Behavior on idx2 {
        NumberAnimation {
            duration: 0
        }
    }
}
