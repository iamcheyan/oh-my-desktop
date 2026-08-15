/// Visual overlay wrapper for the Hyprsunset singleton.
/// Loaded by ModuleLoader.overlays in the bar process; calls
/// Hyprsunset.load() at startup to ensure the night-light
/// service is running and schedule-enabled.
pragma ComponentBehavior: Bound
import QtQuick
import qs.services

Item {
    id: root

    Component.onCompleted: {
        Hyprsunset.load()
    }
}
