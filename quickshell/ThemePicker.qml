import QtQuick

// Theme picker: every theme found in the theme folders, with a small
// preview drawn from each theme's own colours, fonts and corners.
// Choosing a theme applies it right away. Themes that list
// "accentChoices" also get a "Your colour" row.
//
// Controller: left/right choose, A applies, down moves to the colour row,
// up goes back, B closes.
Item {
    id: picker

    property bool open: false
    property string row: "themes"   // "themes" | "colours"
    property int themeIndex: 0
    property int colourIndex: 0

    readonly property var themes: Theme.installed
    readonly property var colours: Theme.accentChoices || []

    function show() {
        Theme.refresh();
        row = "themes";
        themeIndex = Math.max(0, indexOfCurrent());
        const current = String(Theme.accent).toUpperCase();
        colourIndex = Math.max(0, colours.findIndex(c => String(c).toUpperCase() === current));
        open = true;
    }

    function hide() {
        open = false;
    }

    function indexOfCurrent() {
        for (let i = 0; i < themes.length; i++) {
            if (themes[i].id === Theme.currentId)
                return i;
        }
        return -1;
    }

    function apply(index) {
        const t = themes[index];
        if (t)
            Theme.useTheme(t.id);
    }

    function pickColour(index) {
        const c = colours[index];
        if (c)
            Theme.setAccent(c);
    }

    function handle(button) {
        if (row === "themes") {
            switch (button) {
            case "left":
                themeIndex = Math.max(0, themeIndex - 1);
                apply(themeIndex);
                break;
            case "right":
                themeIndex = Math.min(themes.length - 1, themeIndex + 1);
                apply(themeIndex);
                break;
            case "a":
                apply(themeIndex);
                break;
            case "down":
                if (colours.length > 0) {
                    row = "colours";
                    colourIndex = Math.max(0, Math.min(colourIndex, colours.length - 1));
                }
                break;
            case "b":
            case "home":
            case "start":
                hide();
                break;
            }
            return;
        }
        switch (button) {
        case "left":
            colourIndex = Math.max(0, colourIndex - 1);
            pickColour(colourIndex);
            break;
        case "right":
            colourIndex = Math.min(colours.length - 1, colourIndex + 1);
            pickColour(colourIndex);
            break;
        case "a":
            pickColour(colourIndex);
            break;
        case "up":
            row = "themes";
            break;
        case "b":
        case "home":
        case "start":
            hide();
            break;
        }
    }

    // Value from a theme's raw data, falling back to Dusk Tide.
    function val(data, path) {
        const keys = path.split(".");
        let v = data;
        for (let i = 0; i < keys.length && v !== undefined && v !== null; i++)
            v = v[keys[i]];
        if (v !== undefined && v !== null)
            return v;
        v = Theme.defaults;
        for (let i = 0; i < keys.length && v !== undefined && v !== null; i++)
            v = v[keys[i]];
        return v;
    }

    function c(data, path) {
        return Theme.toColor(val(data, path));
    }

    visible: open

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: picker.hide()
        }
    }

    Text {
        x: 48
        y: 58
        text: "Themes"
        color: Theme.textStrong
        font.family: Theme.displayFont
        font.weight: Font.Black
        font.pixelSize: 34
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 48
        y: 70
        text: picker.themes.length === 1 ? "1 theme installed" : `${picker.themes.length} themes installed`
        color: Theme.textMuted
        font.family: Theme.bodyFont
        font.weight: Font.Bold
        font.pixelSize: 14
    }

    ListView {
        id: list
        x: 0
        y: 112
        width: parent.width
        height: 214
        leftMargin: 48
        rightMargin: 48
        orientation: ListView.Horizontal
        spacing: 18
        model: picker.themes
        currentIndex: picker.themeIndex
        highlightFollowsCurrentItem: false
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Item {
            id: card
            required property var modelData
            required property int index

            readonly property var d: modelData.data
            readonly property bool inUse: modelData.id === Theme.currentId
            readonly property bool focused: Controller.active && picker.row === "themes" && index === picker.themeIndex
            readonly property color pAccent: picker.c(d, "colors.accent")
            readonly property real pRadius: Math.min(12, picker.val(d, "radii.card"))
            readonly property var wall: picker.val(d, "wallpaper")

            width: 220
            height: 200
            y: 6
            scale: focused ? 1.04 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }

            FocusRing {
                visible: card.focused
                radius: Theme.rCard
            }

            Surface {
                anchors.fill: parent
                color: Theme.surfaceStrong

                // Preview: the theme's background with a little card, a
                // chip and an accent button on it
                Rectangle {
                    id: preview
                    x: 10
                    y: 10
                    width: parent.width - 20
                    height: 116
                    radius: Math.max(2, card.pRadius - 2)
                    clip: true
                    color: card.wall && card.wall.type !== "scene" && card.wall.color
                        ? Theme.toColor(card.wall.color) : picker.c(card.d, "colors.bg")

                    // A hint of the scene or grid wallpaper
                    Rectangle {
                        visible: !card.wall || card.wall.type === "scene"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 44
                        color: Qt.darker(picker.c(card.d, "colors.bg"), 1.3)
                    }
                    Rectangle {
                        visible: !card.wall || card.wall.type === "scene"
                        x: 120
                        y: 50
                        width: 30
                        height: 30
                        radius: 15
                        color: card.pAccent
                    }
                    Grid {
                        visible: card.wall && card.wall.type === "grid"
                        anchors.fill: parent
                        columns: 25
                        Repeater {
                            model: card.wall && card.wall.type === "grid" ? 25 * 15 : 0
                            Rectangle {
                                width: 8
                                height: 8
                                color: "transparent"
                                border.width: 0.5
                                border.color: Theme.toColor(card.wall.line || "rgba(60, 80, 110, 0.07)")
                            }
                        }
                    }

                    Rectangle {
                        x: 12
                        y: 12
                        width: 96
                        height: 62
                        radius: card.pRadius
                        color: picker.c(card.d, "colors.surface")
                        border.width: Math.max(1, picker.val(card.d, "style.border"))
                        border.color: picker.c(card.d, "colors.surfaceBorder")

                        Text {
                            x: 10
                            y: 6
                            text: "12:34"
                            color: picker.c(card.d, "colors.textStrong")
                            font.family: picker.val(card.d, "fonts.display")
                            font.weight: Font.Black
                            font.pixelSize: 24
                        }

                        Rectangle {
                            x: 10
                            y: 40
                            width: 46
                            height: 12
                            radius: Math.min(6, picker.val(card.d, "radii.pill"))
                            color: card.pAccent
                        }
                    }

                    Rectangle {
                        x: 120
                        y: 12
                        width: 34
                        height: 34
                        radius: Math.min(17, picker.val(card.d, "radii.icon"))
                        color: picker.c(card.d, "colors.chip")
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 14
                    spacing: 2

                    Row {
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.d.name || card.modelData.id
                            color: Theme.textStrong
                            font.family: Theme.bodyFont
                            font.weight: Font.ExtraBold
                            font.pixelSize: 16
                        }

                        Rectangle {
                            visible: card.inUse
                            anchors.verticalCenter: parent.verticalCenter
                            width: inUseLabel.implicitWidth + 12
                            height: 18
                            radius: Theme.rPill
                            color: Theme.accent

                            Text {
                                id: inUseLabel
                                anchors.centerIn: parent
                                text: "In use"
                                color: Theme.accentInk
                                font.family: Theme.bodyFont
                                font.weight: Font.ExtraBold
                                font.pixelSize: 10
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: card.d.description || (card.modelData.user ? "Installed theme" : "Built-in theme")
                        color: Theme.textMuted
                        font.family: Theme.bodyFont
                        font.weight: Font.DemiBold
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        picker.row = "themes";
                        picker.themeIndex = card.index;
                        picker.apply(card.index);
                    }
                }
            }
        }
    }

    // Favourite colour
    Column {
        x: 48
        y: 352
        spacing: 12
        visible: picker.colours.length > 0

        Text {
            text: "YOUR COLOUR"
            color: Theme.textMuted
            font.family: Theme.bodyFont
            font.weight: Font.ExtraBold
            font.pixelSize: 11
            font.letterSpacing: 1.5
        }

        Flow {
            width: picker.width - 96
            spacing: 10

            Repeater {
                model: picker.colours

                Item {
                    id: swatch
                    required property string modelData
                    required property int index
                    readonly property bool chosen: String(Theme.accent).toUpperCase() === modelData.toUpperCase()
                    readonly property bool focused: Controller.active && picker.row === "colours" && index === picker.colourIndex

                    width: 40
                    height: 40

                    FocusRing {
                        visible: swatch.focused
                        radius: Theme.rKey + 2
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.rKey + 2
                        color: Theme.toColor(swatch.modelData)
                        border.width: swatch.chosen ? 3 : 1
                        border.color: swatch.chosen ? Theme.textStrong : Theme.surfaceBorder
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            picker.row = "colours";
                            picker.colourIndex = swatch.index;
                            picker.pickColour(swatch.index);
                        }
                    }
                }
            }
        }
    }

    Text {
        x: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        text: "Add themes to ~/.local/share/pocket-shell/themes"
        color: Theme.textMuted
        font.family: Theme.bodyFont
        font.weight: Font.DemiBold
        font.pixelSize: 12
    }

    HintBar {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        items: [
            { key: "A", round: true, text: "Use" },
            { key: "B", round: true, text: "Done" }
        ]
    }
}
