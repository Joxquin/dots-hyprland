import qs.modules.common
import QtQuick

/**
 * Recreation of GTK revealer. Expects one single child.
 */
Item {
    id: root
    property bool reveal
    property bool vertical: false
    clip: true

    implicitWidth: vertical ? childrenRect.width : (reveal ? childrenRect.width : 0)
    implicitHeight: vertical ? (reveal ? childrenRect.height : 0) : childrenRect.height
    visible: reveal || (implicitWidth > 0 && !vertical) || (implicitHeight > 0 && vertical)

    Behavior on implicitWidth {
        enabled: !vertical
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on implicitHeight {
        enabled: vertical
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
}
