import QtQuick
import Quickshell

// One window per screen the device profile lists (see Device.qml).
// The main screen gets Home; a second screen gets the display-only Showcase.
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
                color: Theme.bg

                // Content loads separately so a broken page falls back to the
                // Hello screen (with its session buttons) instead of a blank screen.
                Loader {
                    id: content
                    anchors.fill: parent
                    source: window.isMain ? "Home.qml" : "Showcase.qml"
                }

                Hello {
                    anchors.fill: parent
                    visible: window.isMain && content.status !== Loader.Ready
                }
            }
        }
    }
}
