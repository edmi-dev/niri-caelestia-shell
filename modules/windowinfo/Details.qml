import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

ColumnLayout {
    id: root

    // NIRI-PORT(U49): niri window object {id, title, app_id, pid, workspace_id, is_floating, layout}
    required property var client
    readonly property var workspace: Compositor.workspaceById(client?.workspace_id ?? -1)

    anchors.fill: parent
    spacing: Tokens.spacing.small

    Label {
        Layout.topMargin: Tokens.padding.extraLargeIncreased

        text: root.client?.title ?? Tr.tr("No active client")
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere

        font: Tokens.font.body.builders.large.weight(Font.Medium).build()
    }

    Label {
        text: root.client?.app_id ?? Tr.tr("No active client")
        color: Colours.palette.m3tertiary

        font: Tokens.font.body.large
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.leftMargin: Tokens.padding.extraLargeIncreased
        Layout.rightMargin: Tokens.padding.extraLargeIncreased
        Layout.topMargin: Tokens.spacing.medium
        Layout.bottomMargin: Tokens.spacing.largeIncreased

        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "location_on"
        text: {
            const addr = root.client?.id; // NIRI-PORT(U49): niri window id
            if (addr !== undefined)
                return Tr.trCtx("Address: %1", "window address").arg(addr);
            return Tr.trCtx("Address: unknown", "window address");
        }
        color: Colours.palette.m3primary
    }

    Detail {
        icon: "location_searching"
        // TRANSLATORS: %1/%2 = x and y position in pixels
        text: Tr.tr("Position: %1, %2").arg(root.client?.layout?.tile_pos_in_workspace_view?.[0] ?? -1).arg(root.client?.layout?.tile_pos_in_workspace_view?.[1] ?? -1) // NIRI-PORT(U49): floating windows only
    }

    Detail {
        icon: "resize"
        // TRANSLATORS: %1/%2 = width and height in pixels; the x is a multiplication sign
        text: Tr.tr("Size: %1 x %2").arg(root.client?.layout?.window_size[0] ?? -1).arg(root.client?.layout?.window_size[1] ?? -1)
        color: Colours.palette.m3tertiary
    }

    Detail {
        icon: "workspaces"
        // TRANSLATORS: %1 = workspace name, %2 = workspace id
        text: Tr.tr("Workspace: %1 (%2)").arg(root.workspace?.name ?? root.workspace?.idx ?? -1).arg(root.workspace?.id ?? -1)
        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "desktop_windows"
        text: {
            // NIRI-PORT(U49): niri output of the window's workspace; niri outputs have no numeric id, show the model
            const mon = Compositor.outputs[root.workspace?.output ?? ""];
            if (mon)
                // TRANSLATORS: %1 = monitor name, %2 = monitor id, %3/%4 = x/y position in pixels
                return Tr.tr("Monitor: %1 (%2) at %3, %4").arg(mon.name).arg(mon.model).arg(mon.logical?.x ?? -1).arg(mon.logical?.y ?? -1);
            return Tr.tr("Monitor: unknown");
        }
    }

    // NIRI-PORT(U49): niri does not report initial title/class, Xwayland or pinned state; those rows are hidden
    Detail {
        visible: false
        icon: "page_header"
        text: {
            const title = root.client?.lastIpcObject?.initialTitle;
            if (title)
                return Tr.tr("Initial title: %1").arg(title);
            return Tr.tr("Initial title: unknown");
        }
        color: Colours.palette.m3tertiary
    }

    Detail {
        visible: false
        icon: "category"
        text: {
            const cls = root.client?.lastIpcObject?.initialClass;
            if (cls)
                return Tr.tr("Initial class: %1").arg(cls);
            return Tr.tr("Initial class: unknown");
        }
    }

    Detail {
        icon: "account_tree"
        // TRANSLATORS: %1 = process id
        text: Tr.tr("Process id: %1").arg(String(root.client?.pid ?? -1))
        color: Colours.palette.m3primary
    }

    Detail {
        icon: "picture_in_picture_center"
        text: root.client?.is_floating ? Tr.tr("Floating: yes") : Tr.tr("Floating: no")
        color: Colours.palette.m3secondary
    }

    Detail {
        visible: false
        icon: "gradient"
        text: root.client?.lastIpcObject?.xwayland ? Tr.tr("Xwayland: yes") : Tr.tr("Xwayland: no")
    }

    Detail {
        visible: false
        icon: "keep"
        text: root.client?.lastIpcObject?.pinned ? Tr.tr("Pinned: yes") : Tr.tr("Pinned: no")
        color: Colours.palette.m3secondary
    }

    Detail {
        icon: "fullscreen"
        text: {
            // NIRI-PORT(U49): window size heuristic (Q3 = a); maximised is not distinguishable on niri
            if (root.client)
                return Compositor.isWindowFullscreen(root.client.id) ? Tr.tr("Fullscreen state: on") : Tr.tr("Fullscreen state: off");
            return Tr.tr("Fullscreen state: unknown");
        }
        color: Colours.palette.m3tertiary
    }

    Item {
        Layout.fillHeight: true
    }

    component Detail: RowLayout {
        id: detail

        required property string icon
        required property string text
        property alias color: icon.color

        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.fillWidth: true

        spacing: Tokens.spacing.medium

        MaterialIcon {
            id: icon

            Layout.alignment: Qt.AlignVCenter
            text: detail.icon
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: detail.text
            elide: Text.ElideRight
            font: Tokens.font.body.medium
        }
    }

    component Label: StyledText {
        Layout.leftMargin: Tokens.padding.large
        Layout.rightMargin: Tokens.padding.large
        Layout.fillWidth: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        animate: true
    }
}
