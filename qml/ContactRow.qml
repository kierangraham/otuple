import QtQuick
import QtQuick.Layouts
import qs.Ui as Ui
import qs.Commons

Ui.BorderSurface {
    id: root
    required property var contact
    property bool busy: false
    signal callRequested(string uid)
    signal favoriteRequested(string uid, bool favorite)
    implicitHeight: Style.space(50)
    height: implicitHeight
    radius: Style.cornerRadius
    color: hover.hovered ? Style.hoverFillFor(Color.popups.text, Color.accent) : "transparent"
    borderSpec: hover.hovered ? Border.controlSpec("hover-cursor", Color.popups.text, Color.accent) : Border.none()
    HoverHandler {
        id: hover
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.spacing.lg
        anchors.rightMargin: Style.spacing.sm
        spacing: Style.spacing.rowGap
        Text {
            text: root.contact.status === "online" ? "󰄬" : root.contact.status === "busy" ? "󰏤" : "󰝦"
            color: root.contact.status === "online" ? Color.accent : root.contact.status === "busy" ? Color.urgent : Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.icon
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.xs
            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: root.contact.name
                elide: Text.ElideRight
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
            }
            Text {
                text: root.contact.status === "online" ? "Available" : root.contact.status === "busy" ? "In a call" : "Offline"
                color: Qt.darker(Color.popups.text, 1.5)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
        }
        Ui.PanelActionButton {
            iconText: root.contact.favorite ? "󰓎" : "󰓏"
            tooltipText: root.contact.favorite ? "Remove from favorites" : "Add to favorites"
            foreground: root.contact.favorite ? Color.accent : Color.popups.text
            enabled: !root.busy
            focusable: true
            onClicked: root.favoriteRequested(root.contact.id, !root.contact.favorite)
        }
        Ui.PanelActionButton {
            iconText: "\uf095"
            tooltipText: "Call " + root.contact.name
            foreground: Color.popups.text
            enabled: !root.busy && root.contact.status === "online"
            focusable: true
            onClicked: root.callRequested(root.contact.id)
        }
    }
}
