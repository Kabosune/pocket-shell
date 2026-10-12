import QtQuick
import QtQuick.Effects

// Blurred, faded box art behind a page: the single-screen version of the
// dual-screen showcase. Loaded separately so a missing effects module only
// loses the blur, not the page.
Item {
    id: backdrop

    property string source: ""

    Image {
        id: art
        anchors.fill: parent
        source: backdrop.source
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 480
        sourceSize.height: 270
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: art
        visible: art.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        opacity: 0.35
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
