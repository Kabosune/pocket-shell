import QtQuick
import Quickshell
import Quickshell.Wayland

// A small window above everything (apps and games included) for the
// volume level. It takes no input and is only mapped while showing.
PanelWindow {
    id: osdWindow

    screen: Device.screen
    visible: content.status === Loader.Ready && content.item.showing && !Store.quickPanelOpen
    anchors.top: true
    margins.top: 24
    implicitWidth: 320
    implicitHeight: 56
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pocket-shell-osd"
    color: "transparent"
    mask: Region {}

    Loader {
        id: content
        anchors.fill: parent
        source: "VolumeOsd.qml"
    }
}
