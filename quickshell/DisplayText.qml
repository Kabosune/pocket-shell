import QtQuick

// Text in the theme's display font (clocks, titles, big numbers).
//
// Pixel fonts only look right when each font pixel lands on whole screen
// pixels. For themes that set "fonts.displayGrid" this snaps the size to a
// multiple of that grid, never fakes bold or letter-spacing, and uses hinted
// native rendering instead of smoothed distance-field text.
Text {
    property real size: 24
    property int weight: Font.Black
    property real spacing: 0

    font.family: Theme.displayFont
    font.pixelSize: Theme.displaySize(size)
    font.weight: Theme.pixelDisplay ? Font.Normal : weight
    font.letterSpacing: Theme.pixelDisplay ? 0 : spacing
    font.hintingPreference: Theme.pixelDisplay ? Font.PreferFullHinting : Font.PreferDefaultHinting
    renderType: Theme.pixelDisplay ? Text.NativeRendering : Text.QtRendering
    font.capitalization: Theme.lowercase ? Font.AllLowercase : Font.MixedCase
}
