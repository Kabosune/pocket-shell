import QtQuick

// Everything on the main screen: wallpaper, top bar, the four pages and
// the overlays (Start menu, theme picker, Recents, toasts). Routes
// controller input.
//
// L1/R1 change page, B goes back to Home, Start opens the menu, Select
// opens Quick settings,
// Home returns to the Home page (or from an app, back to the shell), and
// holding Home opens Recents. Back works like B in the shell; in an app
// it sends that app's own "back" key (see AppBack.qml). While an app is
// in front, only Home, hold-Home and Back reach the shell; everything
// else is the app's.
Item {
    id: main

    property int page: 0
    readonly property var pageNames: ["Home", "Library", "Apps", "Glance"]
    readonly property var pageFiles: ["Home.qml", "Library.qml", "Apps.qml", "Glance.qml"]

    readonly property var directions: ["up", "down", "left", "right"]
    readonly property bool overlayOpen: themes.open || recents.open || sheet.open || quick.open

    function goToPage(i) {
        const step = i < page ? "page-prev" : "page-next";
        page = (i + pageNames.length) % pageNames.length;
        Sfx.play(step, 1);
    }

    function showSession() {
        sheet.show();
        Sfx.play("open", 1);
    }

    // kind: "" for information, "error" when something didn't work
    function toast(message, kind) {
        toaster.show(message);
        Sfx.play(kind === "error" ? "error" : "notice", 2);
    }

    // The default sound for a button press. Whatever the press does can
    // ask for a more specific sound, which wins (see Sfx.qml).
    function buttonSound(button) {
        if (directions.indexOf(button) >= 0)
            return "move";
        if (overlayOpen)
            return button === "a" ? "select" : ["b", "home", "start", "recents", "select"].indexOf(button) >= 0 ? "back" : "";
        switch (button) {
        case "a":
            return "select";
        case "b":
            return page !== 0 ? "back" : "";
        case "home":
            return page !== 0 ? "page" : "";
        case "start":
        case "recents":
            return "open";
        }
        return "";
    }

    function pageItem(i) {
        const loader = pages.itemAt(i);
        return loader && loader.status === Loader.Ready ? loader.item : null;
    }

    function handle(button) {
        if (!Wm.inShell) {
            if (button === "back") {
                AppBack.press();
            } else if (button === "home") {
                Wm.goHome();
                Sfx.play("back", 1);
            } else if (button === "recents") {
                Wm.goHome();
                recents.show();
                Sfx.play("open", 1);
            }
            return;
        }
        if (button === "back")
            button = "b";
        const sound = buttonSound(button);
        if (sound)
            Sfx.play(sound, 0);
        if (quick.open) {
            quick.handle(button);
            return;
        }
        if (themes.open) {
            themes.handle(button);
            return;
        }
        if (recents.open) {
            recents.handle(button);
            return;
        }
        if (sheet.open) {
            sheet.handle(button);
            return;
        }
        switch (button) {
        case "l1":
            goToPage(page - 1);
            return;
        case "r1":
            goToPage(page + 1);
            return;
        case "recents":
            recents.show();
            return;
        case "select":
            quick.show();
            return;
        case "start":
            sheet.show();
            return;
        case "home":
            if (page !== 0) {
                page = 0;
                return;
            }
            break;
        }
        const current = pageItem(page);
        if (current && current.handle(button))
            return;
        if (button === "b" && page !== 0)
            page = 0;
    }

    Connections {
        target: Controller
        function onPressed(button, repeat) {
            main.handle(button);
        }
    }

    Wallpaper {
        anchors.fill: parent
    }

    Repeater {
        id: pages
        model: main.pageFiles

        Loader {
            id: pageLoader
            required property string modelData
            required property int index

            width: main.width
            height: main.height
            source: modelData
            // Hidden behind full-screen overlays so their hints don't clash
            opacity: index === main.page && !themes.open && !recents.open ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 140 } }

            Binding {
                when: pageLoader.status === Loader.Ready
                target: pageLoader.item
                property: "shell"
                value: main
            }
            Binding {
                when: pageLoader.status === Loader.Ready
                target: pageLoader.item
                property: "current"
                value: pageLoader.index === main.page
            }

            Text {
                anchors.centerIn: parent
                visible: pageLoader.status === Loader.Error
                text: `The ${main.pageNames[pageLoader.index]} page couldn't load.`
                color: Theme.textMuted
                font.family: Theme.bodyFont
                font.pixelSize: 16
            }
        }
    }

    TopBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        page: main.page
        pages: main.pageNames
        onStatusTapped: quick.show()
        onPageTapped: index => {
            if (index !== main.page)
                main.goToPage(index);
        }
    }

    SessionSheet {
        id: sheet
        anchors.fill: parent
        onThemesRequested: themes.show()
    }

    ThemePicker {
        id: themes
        anchors.fill: parent
    }

    Recents {
        id: recents
        anchors.fill: parent
    }

    QuickPanel {
        id: quick
        anchors.fill: parent
    }

    Toast {
        id: toaster
        anchors.fill: parent
    }

    Scanlines {
        anchors.fill: parent
        visible: Theme.scanlines
        shade: Theme.scanline
    }

    // Start-up chime, once the sounds have had a moment to load.
    Timer {
        interval: 700
        running: true
        onTriggered: Sfx.play("boot", 3)
    }

    // Any touch switches back to touch mode, which hides the focus rings.
    // A PointHandler only watches, so taps still reach the controls below.
    Item {
        anchors.fill: parent
        z: 1000

        PointHandler {
            onActiveChanged: {
                if (active)
                    Controller.active = false;
            }
        }
    }
}
