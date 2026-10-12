import QtQuick

// Second-screen view on dual-screen devices: visuals only, no controls.
// For now it's ambience (wallpaper + clock); later it shows art for
// whatever is focused on the main screen.
Item {
    Wallpaper {
        anchors.fill: parent
    }

    ClockBlock {
        anchors.centerIn: parent
        centered: true
    }
}
