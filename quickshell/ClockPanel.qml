import QtQuick
import Quickshell

// Clock card for the "panels" Home layout: the time on one line and a
// strip of this week's days with today highlighted.
Surface {
    id: panel

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property var week: {
        const now = clock.date;
        const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - now.getDay());
        const letters = ["S", "M", "T", "W", "T", "F", "S"];
        const out = [];
        for (let i = 0; i < 7; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push({ letter: letters[i], day: d.getDate(), today: i === now.getDay() });
        }
        return out;
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 20
        anchors.bottomMargin: 20

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: "CLOCK"
            color: Theme.textHint
            font.family: Theme.bodyFont
            font.weight: Font.Black
            font.pixelSize: 12
            font.letterSpacing: 1.5
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: Qt.formatDate(clock.date, "dddd, MMMM d")
            color: Theme.textMuted
            font.family: Theme.bodyFont
            font.weight: Font.ExtraBold
            font.pixelSize: 13
        }

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -10

            DisplayText {
                text: Qt.formatTime(clock.date, "HH")
                color: Theme.textStrong
                weight: Font.Bold
                size: 112
            }
            DisplayText {
                text: ":"
                color: Theme.accent
                weight: Font.Bold
                size: 112
            }
            DisplayText {
                text: Qt.formatTime(clock.date, "mm")
                color: Theme.textStrong
                weight: Font.Bold
                size: 112
            }
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 6

            Repeater {
                model: panel.week

                Rectangle {
                    id: day
                    required property var modelData
                    width: (parent.width - 6 * 6) / 7
                    height: 44
                    radius: Theme.rKey
                    color: modelData.today ? Theme.accent : Theme.chip
                    border.width: modelData.today ? 2 : 0
                    border.color: Theme.accentDeep

                    Column {
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: day.modelData.letter
                            color: day.modelData.today ? Theme.accentInk : Theme.textHint
                            font.family: Theme.bodyFont
                            font.weight: Font.Black
                            font.pixelSize: 11
                        }
                        DisplayText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: day.modelData.day
                            color: day.modelData.today ? Theme.accentInk : Theme.textMuted
                            weight: Font.Bold
                            size: 15
                        }
                    }
                }
            }
        }
    }
}
