import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// NIRI-PORT(F16): port-only control — a StyledSwitch-looking switch with three positions.
// Clicking a third of the track selects that position; clicking the current one advances to the next.
StyledRect {
    id: root

    property int position
    property list<string> icons // Optional icon in the thumb per position
    property int cLayer: 1
    readonly property bool checked: position > 0
    readonly property alias pressed: mouse.pressed
    readonly property alias hovered: mouse.containsMouse

    signal moved(position: int)

    radius: Tokens.rounding.full
    color: checked ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainerHighest, cLayer)

    implicitWidth: implicitHeight * 2.4
    implicitHeight: Tokens.font.body.medium.pointSize + Tokens.padding.small * 2

    StyledRect {
        id: thumb

        readonly property real nonAnimWidth: root.pressed ? implicitHeight * 1.2 : implicitHeight
        readonly property real inset: Tokens.padding.extraSmall / 2

        radius: Tokens.rounding.full
        color: root.checked ? Colours.palette.m3onPrimary : Colours.layer(Colours.palette.m3outline, root.cLayer + 1)

        x: inset + (root.implicitWidth - nonAnimWidth - inset * 2) * root.position / 2
        implicitWidth: nonAnimWidth
        implicitHeight: root.implicitHeight - Tokens.padding.extraSmall
        anchors.verticalCenter: parent.verticalCenter

        StyledRect {
            anchors.fill: parent
            radius: parent.radius

            color: root.checked ? Colours.palette.m3primary : Colours.palette.m3onSurface
            opacity: root.pressed ? 0.1 : root.hovered ? 0.08 : 0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: root.icons[root.position] ?? ""
            color: root.checked ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest
            fill: 1
        }

        Behavior on x {
            Anim {
                type: Anim.FastSpatial
            }
        }

        Behavior on implicitWidth {
            Anim {
                type: Anim.FastSpatial
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: event => {
            const pos = Math.max(0, Math.min(2, Math.floor(event.x / width * 3)));
            root.moved(pos === root.position ? (pos + 1) % 3 : pos);
        }
    }
}
