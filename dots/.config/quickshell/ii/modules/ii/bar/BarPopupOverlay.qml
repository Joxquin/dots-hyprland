pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets

// One always-mapped layer surface per screen, hosting the single card every bar
// popup morphs. The surface itself never moves, resizes or unmaps.
Scope {
    id: overlayScope

    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.options.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }

        PanelWindow {
            id: overlayWindow
            required property ShellScreen modelData

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "quickshell:barPopup"
            WlrLayershell.layer: WlrLayer.Overlay

            mask: Region {
                item: card
            }

            property var current: null
            property var outgoing: null
            property bool exiting: false
            property var exitSpot: null
            readonly property bool morphing: xAnim.running || yAnim.running
                || widthAnim.running || heightAnim.running

            readonly property var requested: {
                const popup = GlobalStates.activeBarPopup;
                if (!popup || !popup.popupVisible) return null;
                if (popup.hoverTarget?.QsWindow?.window?.screen !== overlayWindow.modelData) return null;
                return popup;
            }

            onRequestedChanged: {
                if (requested) takeOver(requested);
                else beginExit();
            }

            function takeOver(popup) {
                exitShrinkTimer.stop();
                exitFadeTimer.stop();
                overlayWindow.exiting = false;
                card.opacity = 1;
                if (overlayWindow.current?.contentItem)
                    overlayWindow.current.contentItem.enabled = true;

                if (overlayWindow.current === popup) {
                    retargetTimer.restart();
                    return;
                }

                if (overlayWindow.outgoing && overlayWindow.outgoing !== popup)
                    overlayWindow.release(overlayWindow.outgoing);
                overlayWindow.outgoing = null;

                const previous = overlayWindow.current;
                if (previous) previous.popupHovered = false;
                overlayWindow.current = popup;

                if (previous && previous !== popup && previous.contentItem) {
                    overlayWindow.outgoing = previous;
                    previous.contentItem.enabled = false;
                    contentExit.target = previous.contentItem;
                    contentExit.restart();
                }

                const arriving = popup.contentItem;
                if (arriving) {
                    arriving.parent = contentHost;
                    arriving.anchors.centerIn = contentHost;
                    arriving.enabled = true;
                    arriving.opacity = 0;
                    contentEnter.stop();
                    contentEnter.item = arriving;
                    contentEnter.restart();
                }
                popup.surfaceWindow = overlayWindow;
                popup.popupHovered = cardHover.hovered;

                if (card.width <= 0 || card.height <= 0) overlayWindow.park();
                retargetTimer.restart();
            }

            function retarget() {
                const popup = overlayWindow.current;
                const content = popup?.contentItem;
                const target = popup?.hoverTarget;
                if (!content || !target?.QsWindow?.window) return;

                const margin = Appearance.sizes.elevationMargin;
                const cardWidth = content.implicitWidth + popup.contentPadding * 2;
                const cardHeight = content.implicitHeight + popup.contentPadding * 2;

                const targetWindow = target.QsWindow.window;
                const barWinHeight = targetWindow.height > 0 ? targetWindow.height : (Appearance.sizes.barHeight + Appearance.rounding.screenRounding);
                const barWinWidth = targetWindow.width > 0 ? targetWindow.width : (Appearance.sizes.verticalBarWidth + Appearance.rounding.screenRounding);
                const barGap = 12;

                let cardX;
                let cardY;
                if (popup.barVertical) {
                    const base = target.QsWindow.mapFromItem(target, 0, (target.height - cardHeight) / 2).y;
                    cardY = Math.max(margin, Math.min(base, overlayWindow.height - cardHeight - margin - 15));
                    cardX = popup.barEdge === "right"
                        ? overlayWindow.width - barWinWidth - cardWidth - barGap
                        : barWinWidth + barGap;
                } else {
                    const base = target.QsWindow.mapFromItem(target, (target.width - cardWidth) / 2, 0).x;
                    cardX = Math.max(margin, Math.min(base, overlayWindow.width - cardWidth - margin - 10));
                    cardY = popup.barEdge === "bottom"
                        ? overlayWindow.height - barWinHeight - cardHeight - barGap
                        : barWinHeight + barGap;
                }

                card.width = cardWidth;
                card.height = cardHeight;
                card.x = cardX;
                card.y = cardY;
                overlayWindow.exitSpot = overlayWindow.anchorSpot();
            }

            function anchorSpot() {
                const popup = overlayWindow.current ?? overlayWindow.outgoing;
                const target = popup?.hoverTarget;
                if (!target?.QsWindow?.window) return overlayWindow.exitSpot;

                const targetWindow = target.QsWindow.window;
                const barWinHeight = targetWindow.height > 0 ? targetWindow.height : (Appearance.sizes.barHeight + Appearance.rounding.screenRounding);
                const barWinWidth = targetWindow.width > 0 ? targetWindow.width : (Appearance.sizes.verticalBarWidth + Appearance.rounding.screenRounding);
                const barGap = 12;

                const margin = Appearance.sizes.elevationMargin;
                const floor = margin * 2;
                const centre = target.QsWindow.mapFromItem(target, target.width / 2, target.height / 2);
                if (popup.barVertical) {
                    return {
                        x: popup.barEdge === "right"
                            ? overlayWindow.width - barWinWidth - floor - barGap
                            : barWinWidth + barGap,
                        y: centre.y - floor / 2,
                        width: floor,
                        height: floor
                    };
                }
                return {
                    x: centre.x - floor / 2,
                    y: popup.barEdge === "bottom"
                        ? overlayWindow.height - barWinHeight - floor - barGap
                        : barWinHeight + barGap,
                    width: floor,
                    height: floor
                };
            }

            function park() {
                const spot = overlayWindow.anchorSpot();
                if (!spot) return;
                card.animate = false;
                card.opacity = 0;
                card.x = spot.x;
                card.y = spot.y;
                card.width = spot.width;
                card.height = spot.height;
                card.animate = true;
                card.opacity = 1;
                overlayWindow.exitSpot = spot;
            }

            function beginExit() {
                if (overlayWindow.exiting) return;
                if (!overlayWindow.current && !overlayWindow.outgoing
                        && card.width <= 0 && card.height <= 0) return;
                if (card.width <= 0 && card.height <= 0) {
                    overlayWindow.finishExit();
                    return;
                }
                const spot = overlayWindow.anchorSpot();
                if (!spot) {
                    overlayWindow.finishExit();
                    return;
                }
                overlayWindow.exiting = true;
                if (overlayWindow.current?.contentItem)
                    overlayWindow.current.contentItem.enabled = false;
                card.x = spot.x;
                card.y = spot.y;
                card.width = spot.width;
                card.height = spot.height;
                exitShrinkTimer.restart();
            }

            function finishExit() {
                exitShrinkTimer.stop();
                exitFadeTimer.stop();
                contentEnter.stop();
                contentExit.stop();

                const leaving = overlayWindow.current;
                overlayWindow.release(overlayWindow.outgoing);
                overlayWindow.release(leaving);
                overlayWindow.outgoing = null;
                overlayWindow.current = null;
                overlayWindow.exiting = false;

                card.animate = false;
                card.opacity = 0;
                card.width = 0;
                card.height = 0;
                card.animate = true;

                if (leaving && GlobalStates.activeBarPopup === leaving)
                    GlobalStates.activeBarPopup = null;
            }

            function release(popup) {
                if (!popup) return;
                popup.aboutToRelease();
                const content = popup.contentItem;
                if (content) {
                    content.anchors.centerIn = null;
                    content.parent = null;
                    content.opacity = 1;
                    content.enabled = true;
                }
                popup.popupHovered = false;
                if (popup.surfaceWindow === overlayWindow) popup.surfaceWindow = null;
            }

            function updateHover() {
                if (overlayWindow.current) overlayWindow.current.popupHovered = cardHover.hovered;
            }

            Timer {
                id: retargetTimer
                interval: 0
                onTriggered: overlayWindow.retarget()
            }

            Timer {
                id: exitShrinkTimer
                interval: Appearance.animation.elementMoveExit.duration
                onTriggered: {
                    card.opacity = 0;
                    exitFadeTimer.restart();
                }
            }

            Timer {
                id: exitFadeTimer
                interval: Appearance.animation.elementMoveFast.duration
                onTriggered: overlayWindow.finishExit()
            }

            HyprlandFocusGrab {
                id: cardGrab
                active: !!overlayWindow.current?.pinnedOpen
                    && !overlayWindow.exiting
                    && !overlayWindow.morphing
                    && card.width > Appearance.sizes.elevationMargin * 2
                windows: [
                    overlayWindow,
                    overlayWindow.current?.hoverTarget?.QsWindow?.window,
                    ...(overlayWindow.current?.extraGrabWindows ?? [])
                ].filter(window => window)
                onCleared: overlayWindow.current?.dismissRequested()
            }

            Connections {
                target: overlayWindow.current?.contentItem ?? null
                ignoreUnknownSignals: true
                function onImplicitWidthChanged() { overlayWindow.retargetNow() }
                function onImplicitHeightChanged() { overlayWindow.retargetNow() }
            }

            function retargetNow() {
                if (overlayWindow.current?.contentDrivesSize) overlayWindow.retarget();
                else retargetTimer.restart();
            }

            readonly property string barEdge: {
                if (!Config.options.bar.vertical)
                    return Config.options.bar.bottom ? "bottom" : "top";
                return Config.options.bar.bottom ? "right" : "left";
            }
            onBarEdgeChanged: overlayWindow.finishExit()

            SequentialAnimation {
                id: contentEnter
                property Item item: null
                PauseAnimation {
                    duration: Appearance.animation.elementMove.duration
                        - Appearance.animation.elementMoveEnter.duration
                }
                NumberAnimation {
                    target: contentEnter.item
                    property: "opacity"
                    to: 1
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                }
            }

            NumberAnimation {
                id: contentExit
                property: "opacity"
                to: 0
                duration: Appearance.animation.elementMoveExit.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
                onFinished: {
                    const leaving = overlayWindow.outgoing;
                    if (leaving && leaving.contentItem === contentExit.target) {
                        overlayWindow.release(leaving);
                        overlayWindow.outgoing = null;
                    }
                }
            }

            StyledRectangularShadow {
                target: card
                visible: card.visible
                opacity: card.opacity
                cached: !overlayWindow.morphing
            }

            Rectangle {
                id: card
                property bool animate: true
                readonly property int motionDuration: overlayWindow.exiting
                    ? Appearance.animation.elementMoveExit.duration
                    : Appearance.animation.elementMove.duration
                readonly property var motionCurve: overlayWindow.exiting
                    ? Appearance.animationCurves.emphasizedAccel
                    : Appearance.animationCurves.expressiveDefaultSpatial

                width: 0
                height: 0
                opacity: 0
                visible: width > 0 && height > 0

                color: Appearance.colors.colLayer1Base
                radius: Appearance.rounding.normal + 4
                border.width: Appearance.borderWidth.standard
                border.color: Appearance.colors.colLayer0Border

                Behavior on x {
                    enabled: card.animate && !(overlayWindow.current?.contentDrivesSize ?? false)
                    NumberAnimation {
                        id: xAnim
                        duration: card.motionDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: card.motionCurve
                    }
                }
                Behavior on y {
                    enabled: card.animate && !(overlayWindow.current?.contentDrivesSize ?? false)
                    NumberAnimation {
                        id: yAnim
                        duration: card.motionDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: card.motionCurve
                    }
                }
                Behavior on width {
                    enabled: card.animate && !(overlayWindow.current?.contentDrivesSize ?? false)
                    NumberAnimation {
                        id: widthAnim
                        duration: card.motionDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: card.motionCurve
                    }
                }
                Behavior on height {
                    enabled: card.animate && !(overlayWindow.current?.contentDrivesSize ?? false)
                    NumberAnimation {
                        id: heightAnim
                        duration: card.motionDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: card.motionCurve
                    }
                }
                Behavior on opacity {
                    enabled: card.animate
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                HoverHandler {
                    id: cardHover
                    onHoveredChanged: overlayWindow.updateHover()
                }

                Item {
                    id: contentHost
                    anchors.fill: parent
                    anchors.margins: overlayWindow.current?.contentPadding ?? 0
                    clip: true
                }
            }
        }
    }
}
