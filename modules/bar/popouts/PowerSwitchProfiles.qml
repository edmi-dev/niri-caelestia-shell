pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// NIRI-PORT(F17): port-only — the battery popout profile pill for power-switch profiles (any count,
// four on the laptop). Same look as the upstream PowerProfiles pill; the indicator slides by x/width
// because the buttons come from a Repeater, and the gaps shrink so four buttons fit batteryWidth.
Column {
    id: root

    spacing: Tokens.spacing.small

    Component.onCompleted: PowerSwitch.refresh() // Pick up switches made from the CLI

    StyledRect {
        id: profiles

        readonly property Item currentItem: {
            const idx = PowerSwitch.profiles.findIndex(p => p.name === PowerSwitch.current);
            return idx >= 0 && idx < repeater.count ? repeater.itemAt(idx) : null; // count: re-evaluate once delegates exist
        }

        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: row.implicitWidth + Tokens.padding.extraSmall * 2
        implicitHeight: row.implicitHeight + Tokens.padding.small

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.full

        StyledRect {
            id: indicator

            visible: profiles.currentItem !== null
            x: row.x + (profiles.currentItem?.x ?? 0)
            y: row.y
            implicitWidth: profiles.currentItem?.width ?? 0
            implicitHeight: row.implicitHeight

            color: Colours.palette.m3primary
            radius: Tokens.rounding.full

            Behavior on x {
                Anim {}
            }
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: PowerSwitch.profiles.length > 3 ? Tokens.spacing.large : Tokens.spacing.largeIncreased

            Repeater {
                id: repeater

                model: PowerSwitch.profiles

                Profile {}
            }
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter

        text: PowerSwitch.currentProfile?.label ?? ""
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.body.small
    }

    component Profile: Item {
        id: profile

        required property var modelData
        readonly property bool active: PowerSwitch.current === modelData.name

        implicitWidth: icon.implicitHeight + Tokens.padding.small
        implicitHeight: icon.implicitHeight + Tokens.padding.small

        StateLayer {
            radius: Tokens.rounding.full
            color: profile.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            disabled: PowerSwitch.busy
            onClicked: PowerSwitch.set(profile.modelData.name)
        }

        MaterialIcon {
            id: icon

            anchors.centerIn: parent

            text: profile.modelData.icon
            fontStyle: Tokens.font.icon.large
            color: profile.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
            fill: profile.active ? 1 : 0

            Behavior on fill {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }
}
