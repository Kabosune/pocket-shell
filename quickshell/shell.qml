import QtQuick
import Quickshell

ShellRoot {
    PanelWindow {
        screen: Device.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.bg

        Hello {
            anchors.fill: parent
        }
    }
}
