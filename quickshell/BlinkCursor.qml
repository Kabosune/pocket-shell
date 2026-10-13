import QtQuick

// Terminal-style cursor blink for a value source: `BlinkCursor on opacity {}`.
// Stops (fully shown) while an app covers the shell.
SequentialAnimation {
    loops: Animation.Infinite
    running: Wm.inShell

    NumberAnimation { to: 1; duration: 0 }
    PauseAnimation { duration: 530 }
    NumberAnimation { to: 0; duration: 0 }
    PauseAnimation { duration: 530 }
}
