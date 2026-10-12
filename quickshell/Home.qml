import QtQuick

// Home page, landscape layout from the concept canvas (Main.dc.html).
// Positions are the mockup's px values; the RP5 screen is 960x540 logical.
Item {
    id: home

    Wallpaper {
        anchors.fill: parent
    }

    TopBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        page: 0
    }

    ClockBlock {
        x: 48
        y: 70
    }

    Loader {
        x: home.width - 40 - width
        y: 74
        width: 400
        height: 156
        source: "NowPlaying.qml"
    }

    QuickToggles {
        x: home.width - 40 - width
        y: 246
        width: 400
    }

    Dock {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        onActivated: appId => {
            if (appId === "settings")
                sheet.open = true;
        }
    }

    HintBar {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
    }

    SessionSheet {
        id: sheet
        anchors.fill: parent
    }
}
