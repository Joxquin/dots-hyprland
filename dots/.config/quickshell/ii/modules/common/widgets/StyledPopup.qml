import qs
import qs.modules.common
import QtQuick

// A bar popup is a declaration plus a hover state machine; it owns no surface.
// Its content is declared here, unparented and windowless, and BarPopupOverlay
// parents it into the one card it hosts on one static layer surface per screen
// when this popup claims GlobalStates.activeBarPopup.
QtObject {
    id: root
    property Item hoverTarget
    default property Item contentItem
    property real contentPadding: Appearance.spacing.space100
    property bool pinnedOpen: false
    property bool contentDrivesSize: false
    readonly property bool targetHovered: hoverTarget?.containsMouse ?? false
    property bool popupHovered: false
    property bool hoverHeld: false
    readonly property bool popupVisible: pinnedOpen || hoverHeld

    property var surfaceWindow: null

    signal dismissRequested()
    signal aboutToRelease()

    property var extraGrabWindows: []

    onPopupVisibleChanged: {
        if (popupVisible) claimSlot();
    }
    Component.onCompleted: if (popupVisible) claimSlot()

    Component.onDestruction: {
        if (GlobalStates.activeBarPopup === root) GlobalStates.activeBarPopup = null;
    }

    function updateHoverHold() {
        if (targetHovered || popupHovered) {
            hoverCloseTimer.stop();
            hoverHeld = true;
        } else if (hoverHeld) {
            hoverCloseTimer.restart();
        }
    }

    property Timer hoverCloseTimer: Timer {
        interval: 180
        onTriggered: root.hoverHeld = false
    }

    function claimSlot() {
        const occupant = GlobalStates.activeBarPopup;
        if (occupant && occupant !== root && occupant.pinnedOpen && !root.pinnedOpen) return;
        GlobalStates.activeBarPopup = root;
    }

    onTargetHoveredChanged: {
        if (targetHovered) claimSlot();
        updateHoverHold();
    }
    onPopupHoveredChanged: updateHoverHold()

    property Connections slotWatcher: Connections {
        target: GlobalStates
        function onActiveBarPopupChanged() {
            if (GlobalStates.activeBarPopup !== root && root.hoverHeld
                    && !root.targetHovered && !root.popupHovered) {
                root.hoverCloseTimer.stop();
                root.hoverHeld = false;
            }
        }
    }

    readonly property bool barVertical: Config.options.bar.vertical
    readonly property string barEdge: {
        if (!barVertical) return Config.options.bar.bottom ? "bottom" : "top"
        return Config.options.bar.bottom ? "right" : "left"
    }
    readonly property real barThickness: barVertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
}
