import QtQuick

// A 0..1 slider for touch and controller. Drag or tap the track; the
// owner moves it with the D-pad by changing `value` itself.
Item {
    id: slider

    property real value: 0
    property bool focused: false
    property bool enabled: true
    signal moved(real value)

    implicitHeight: 36

    function setFromX(x) {
        const v = Math.max(0, Math.min(1, (x - knob.width / 2) / (width - knob.width)));
        moved(v);
    }

    opacity: enabled ? 1 : 0.45

    FocusRing {
        visible: slider.focused
        radius: track.radius
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.bevel ? 16 : 10
        radius: Theme.bevel ? Theme.rKey : height / 2
        color: Theme.chip
        border.width: Theme.bevel ? Theme.borderWidth : 0
        border.color: Theme.surfaceBorder

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: parent.border.width
            width: Math.max(0, knob.x + knob.width / 2 - parent.border.width)
            radius: Math.max(0, parent.radius - parent.border.width)
            color: Theme.accent
        }
    }

    Rectangle {
        id: knob
        anchors.verticalCenter: parent.verticalCenter
        x: slider.value * (slider.width - width)
        width: Theme.bevel ? 20 : 22
        height: Theme.bevel ? 28 : 22
        radius: Theme.bevel ? Theme.rKey : width / 2
        color: Theme.bevel ? Theme.surface : Theme.textStrong
        border.width: Theme.bevel ? 2 : 0
        border.color: Theme.accentDeep

        Behavior on x {
            enabled: !drag.pressed
            NumberAnimation { duration: 80 }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.topMargin: -8
        anchors.bottomMargin: -8
        enabled: slider.enabled
        preventStealing: true
        onPressed: mouse => slider.setFromX(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                slider.setFromX(mouse.x);
        }
    }
}
