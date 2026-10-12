pragma Singleton
import QtQuick
import Quickshell

// Design tokens from the Pocket Shell Concept canvas (Dusk Tide preset).
// All sizes are logical px: the RP5 in landscape at scale 2 is 960x540,
// the same size as the landscape mockups, so values carry over 1:1.
Singleton {
    // "sharp" is the default look; "soft" is the rounded preset.
    property string preset: "sharp"
    readonly property bool soft: preset === "soft"

    // Accent (later: picked from the wallpaper)
    property color accent: "#F4B78E"
    readonly property color accentInk: "#2B1A10"
    readonly property color accentGlow: Qt.rgba(accent.r, accent.g, accent.b, 0.5)

    // Surfaces
    readonly property color bg: "#1A2838"
    readonly property color surface: Qt.rgba(14 / 255, 36 / 255, 40 / 255, 0.72)
    readonly property color surfaceBorder: Qt.rgba(207 / 255, 230 / 255, 225 / 255, 0.12)
    readonly property color chip: "#1F4447"
    readonly property color chipFocused: "#2C5A5B"
    readonly property color focusGap: "#0B2222"
    readonly property color keyBorder: Qt.rgba(207 / 255, 230 / 255, 225 / 255, 0.35)

    // Text
    readonly property color textStrong: "#EAF3F1"
    readonly property color text: "#DDEBE8"
    readonly property color textMuted: "#A9C4C0"
    readonly property color textHint: "#C3D8D4"
    readonly property color iconOnChip: "#CFE6E1"

    // Corner radii
    readonly property real rCard: soft ? 28 : 6
    readonly property real rArt: soft ? 22 : 4
    readonly property real rPill: soft ? 999 : 4
    readonly property real rBtn: soft ? 18 : 4
    readonly property real rIcon: soft ? 22 : 6
    readonly property real rDock: soft ? 30 : 8
    readonly property real rKey: soft ? 6 : 2

    // Focus ring: sharp = dark gap + accent ring; soft = single accent ring
    readonly property real focusGapWidth: soft ? 0 : 2
    readonly property real focusRingWidth: soft ? 2.5 : 2

    // Type
    readonly property string displayFont: soft ? "Nunito" : "Archivo"
    readonly property string bodyFont: "Manrope"

    // Spacing
    readonly property real touchMin: 44
    readonly property real edge: 48
}
