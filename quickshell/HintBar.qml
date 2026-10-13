import QtQuick

// Controller hints: which button does what on this screen.
Row {
    id: hints

    property var items: [
        { key: "A", round: true, text: "Open" },
        { key: "B", round: true, text: "Back" },
        { key: "SELECT", round: false, text: "Panel" },
        { key: "HOLD HOME", round: false, text: "Recents" }
    ]

    spacing: 14

    Repeater {
        model: hints.items

        Row {
            id: hint
            required property var modelData
            spacing: 6

            KeyCap {
                anchors.verticalCenter: parent.verticalCenter
                label: hint.modelData.key
                round: hint.modelData.round
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.label(hint.modelData.text)
                color: Theme.textHint
                font.family: Theme.bodyFont
                font.weight: Font.Bold
                font.pixelSize: 12
            }
        }
    }
}
