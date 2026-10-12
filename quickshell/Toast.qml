import QtQuick

// Short message at the bottom of the screen that fades away.
Item {
    id: toast

    function show(message) {
        label.text = message;
        bubble.opacity = 1;
        hideTimer.restart();
    }

    Surface {
        id: bubble
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 120
        width: label.implicitWidth + 36
        height: label.implicitHeight + 20
        radius: Theme.rPill
        color: Theme.surfaceStrong
        opacity: 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 180 } }

        Text {
            id: label
            anchors.centerIn: parent
            color: Theme.textStrong
            font.family: Theme.bodyFont
            font.weight: Font.Bold
            font.pixelSize: 14
        }
    }

    Timer {
        id: hideTimer
        interval: 2500
        onTriggered: bubble.opacity = 0
    }
}
