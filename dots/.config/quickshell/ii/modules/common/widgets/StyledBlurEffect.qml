import QtQuick
import QtQuick.Effects

MultiEffect {
    id: root
    source: wallpaper
    anchors.fill: source
    saturation: 0.2
    blurEnabled: false
    blurMax: 100
    blur: 1
}
