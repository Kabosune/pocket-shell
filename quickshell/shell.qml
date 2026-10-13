//@ pragma IconTheme breeze
import QtQuick
import Quickshell
import Quickshell.Wayland

// One window per screen the device profile lists (see Device.qml).
// The main screen gets the shell (Main.qml); a second screen gets the
// display-only Showcase. Windows sit on the bottom layer, so apps and
// games open on top of the shell.
ShellRoot {
    Variants {
        model: Device.shellScreens

        delegate: Component {
            PanelWindow {
                id: window

                required property var modelData
                readonly property bool isMain: Device.roleOf(modelData) !== "second"

                screen: modelData
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.namespace: "pocket-shell"
                color: Theme.bg

                // Content loads separately so a broken page falls back to the
                // Hello screen (with its session buttons) instead of a blank screen.
                Loader {
                    id: content
                    anchors.fill: parent
                    source: window.isMain ? "Main.qml" : "Showcase.qml"
                }

                Hello {
                    anchors.fill: parent
                    visible: window.isMain && content.status !== Loader.Ready
                }
            }
        }
    }

    // Volume pop-up, above apps and games. Loaded separately so a problem
    // with it can't take the rest of the shell down.
    LazyLoader {
        active: true
        source: "OsdWindow.qml"
    }
}
