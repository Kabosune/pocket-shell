import QtQuick
import Quickshell

ShellRoot {
    PanelWindow {
        screen: Device.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.bg

        // Home loads separately so a broken Home falls back to the Hello
        // screen (with its session buttons) instead of a blank screen.
        Loader {
            id: home
            anchors.fill: parent
            source: "Home.qml"
        }

        Hello {
            anchors.fill: parent
            visible: home.status !== Loader.Ready
        }
    }
}
