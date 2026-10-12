import QtQuick
import Quickshell

// Stacked clock (hours over accent minutes) with the day pill and date.
Column {
    id: block

    property bool tall: false
    property bool centered: false

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    component Digits: DisplayText {
        property bool tall: false
        weight: Font.Black
        size: tall ? 196 : 168
        spacing: tall ? -6 : -5
        lineHeightMode: Text.ProportionalHeight
        lineHeight: 0.84
    }

    Digits {
        tall: block.tall
        anchors.horizontalCenter: block.centered ? parent.horizontalCenter : undefined
        text: Qt.formatTime(clock.date, "HH")
        color: Theme.textStrong
    }

    Digits {
        tall: block.tall
        anchors.horizontalCenter: block.centered ? parent.horizontalCenter : undefined
        text: Qt.formatTime(clock.date, "mm")
        color: Theme.accent
    }

    Item { width: 1; height: 18 }

    Row {
        anchors.horizontalCenter: block.centered ? parent.horizontalCenter : undefined
        spacing: 10

        Surface {
            anchors.verticalCenter: parent.verticalCenter
            width: dayText.implicitWidth + 24
            height: dayText.implicitHeight + 10
            radius: Theme.rPill

            Text {
                id: dayText
                anchors.centerIn: parent
                text: Qt.formatDate(clock.date, "ddd").toUpperCase()
                color: Theme.text
                font.family: Theme.bodyFont
                font.weight: Font.ExtraBold
                font.pixelSize: 12
                font.letterSpacing: 1.5
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDate(clock.date, "MMMM d")
            color: Theme.textStrong
            font.family: Theme.bodyFont
            font.weight: Font.ExtraBold
            font.pixelSize: 20
        }
    }
}
