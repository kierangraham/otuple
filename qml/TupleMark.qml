import QtQuick
import qs.Commons

Item {
    id: root
    property color foreground: Color.foreground
    implicitWidth: Style.font.display
    implicitHeight: implicitWidth
    Rectangle {
        x: parent.width * 0.08
        y: parent.height * 0.12
        width: parent.width * 0.58
        height: parent.height * 0.58
        color: "transparent"
        radius: Style.cornerRadius > 0 ? parent.width * 0.08 : 0
        border.color: root.foreground
        border.width: Math.max(1, parent.width * 0.07)
    }
    Rectangle {
        x: parent.width * 0.34
        y: parent.height * 0.34
        width: parent.width * 0.58
        height: parent.height * 0.58
        color: "transparent"
        radius: Style.cornerRadius > 0 ? parent.width * 0.08 : 0
        border.color: root.foreground
        border.width: Math.max(1, parent.width * 0.07)
    }
}
