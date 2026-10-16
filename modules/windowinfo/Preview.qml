pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    // NIRI-PORT(U49): niri window object; live capture is off until Q9 (Compositor.supports.toplevelCapture)
    required property var client

    Layout.preferredWidth: preview.implicitWidth + Tokens.padding.extraLargeIncreased
    Layout.fillHeight: true

    StyledClippingRect {
        id: preview

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: label.top
        anchors.topMargin: Tokens.padding.large
        anchors.bottomMargin: Tokens.spacing.medium

        implicitWidth: view.implicitWidth

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.medium

        Loader {
            asynchronous: true
            anchors.centerIn: parent
            active: !root.client

            sourceComponent: ColumnLayout {
                spacing: 0

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "web_asset_off"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(3).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Tr.tr("No active client")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.builders.large.size(28).weight(Font.Medium).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Tr.tr("Try switching to a window")
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.large
                }
            }
        }

        ScreencopyView {
            id: view

            anchors.centerIn: parent

            captureSource: null
            live: true

            constraintSize.width: root.client ? parent.height * Math.min(root.screen.width / root.screen.height, root.client?.layout.window_size[0] / root.client?.layout.window_size[1]) : parent.height
            constraintSize.height: parent.height
        }
    }

    StyledText {
        id: label

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.large

        animate: true
        text: {
            const client = root.client;
            if (!client)
                return Tr.tr("No active client");

            const output = Compositor.workspaceById(client.workspace_id)?.output ?? "?";
            const pos = client.layout?.tile_pos_in_workspace_view ?? [-1, -1]; // NIRI-PORT(U49): floating windows only
            // TRANSLATORS: %1 = window title, %2 = monitor name, %3/%4 = x/y position in pixels
            return Tr.tr("%1 on monitor %2 at %3, %4").arg(client.title).arg(output).arg(pos[0]).arg(pos[1]);
        }
    }
}
