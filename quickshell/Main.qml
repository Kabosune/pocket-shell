import QtQuick

// Everything on the main screen: wallpaper, top bar, the four pages and
// the overlays (session sheet, Recents, toasts). Routes controller input.
//
// L1/R1 change page, B goes back to Home, Start opens the session sheet,
// Home returns to the Home page (or from an app, back to the shell), and
// holding Home opens Recents. While an app is in front, only Home and
// hold-Home reach the shell; everything else is the app's.
Item {
    id: main

    property int page: 0
    readonly property var pageNames: ["Home", "Library", "Apps", "Glance"]
    readonly property var pageFiles: ["Home.qml", "Library.qml", "Apps.qml", "Glance.qml"]

    function goToPage(i) {
        page = (i + pageNames.length) % pageNames.length;
    }

    function showSession() {
        sheet.show();
    }

    function toast(message) {
        toaster.show(message);
    }

    function pageItem(i) {
        const loader = pages.itemAt(i);
        return loader && loader.status === Loader.Ready ? loader.item : null;
    }

    function handle(button) {
        if (!Wm.inShell) {
            if (button === "home") {
                Wm.goHome();
            } else if (button === "recents") {
                Wm.goHome();
                recents.show();
            }
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
            opacity: index === main.page ? 1 : 0
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
        onPageTapped: index => main.page = index
    }

    SessionSheet {
        id: sheet
        anchors.fill: parent
    }

    Recents {
        id: recents
        anchors.fill: parent
    }

    Toast {
        id: toaster
        anchors.fill: parent
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
