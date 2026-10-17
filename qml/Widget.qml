pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui as Ui

Ui.Panel {
    id: app
    moduleName: "kierangraham.otuple"
    manageIpc: false
    readonly property var service: bar?.shell?.serviceFor("kierangraham.otuple") ?? pendingService
    QtObject {
        id: pendingService
        property bool demo: false
        property bool busy: true
        property bool loaded: false
        property bool modern: false
        property bool failed: false
        property string message: ""
        property string version: ""
        property string callLink: ""
        property string loginLink: ""
        property var contacts: []
        property var preferences: ({})
        function send(action, value) {
        }
        function restart() {
        }
    }
    property bool favoritesOnly: false
    property string page: "people"
    readonly property var filteredContacts: (service ? service.contacts : []).filter(c => (!favoritesOnly || c.favorite) && (c.name + " " + c.email).toLowerCase().includes(search.text.toLowerCase())).sort((a, b) => Number(b.favorite) - Number(a.favorite) || ({
                online: 0,
                busy: 1,
                offline: 2
            }[a.status] ?? 3) - ({
                online: 0,
                busy: 1,
                offline: 2
            }[b.status] ?? 3) || a.name.localeCompare(b.name))
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    visible: true

    function send(action, value) {
        if (service)
            service.send(action, value);
    }
    onOpenedChanged: if (opened)
        app.send("refresh")

    Connections {
        target: app.service
        ignoreUnknownSignals: true
        function onResultReceived(action) {
            if (action === "login")
                app.page = "account";
            if (action === "auth")
                authCode.text = "";
        }
    }
    Ui.BarIconButton {
        id: button
        anchors.fill: parent
        bar: app.bar
        tooltipText: "Tuple"
        iconComponent: TupleMark {
            foreground: button.foreground
        }
        onPressed: app.toggle()
    }
    Ui.KeyboardPanel {
        id: panel
        anchorItem: button
        owner: app
        bar: app.bar
        open: app.opened
        focusTarget: app.page === "people" ? search : focusScope
        contentWidth: panel.fittedContentWidth(Style.space(380))
        contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(680))
        Item {
            id: focusScope
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: {
                if (signOutDialog.opened)
                    signOutDialog.opened = false;
                else
                    app.close();
            }
            Keys.onPressed: event => {
                if (signOutDialog.handleKey(event))
                    event.accepted = true;
            }
            Shortcut {
                sequence: "Ctrl+R"
                enabled: app.opened
                onActivated: app.send("refresh")
            }
            Shortcut {
                sequence: "Ctrl+F"
                enabled: app.opened
                onActivated: {
                    app.page = "people";
                    search.forceActiveFocus();
                }
            }
            Shortcut {
                sequence: "Ctrl+,"
                enabled: app.opened
                onActivated: app.page = app.page === "settings" ? "people" : "settings"
            }
            ColumnLayout {
                id: content
                anchors.fill: parent
                spacing: Style.spacing.panelGap
                Ui.PanelHero {
                    Layout.fillWidth: true
                    title: app.page === "settings" ? "Tuple preferences" : app.page === "account" ? "Tuple account" : "Tuple"
                    meta: app.service.demo ? "Preview" : app.service.busy ? "Working…" : app.service.loaded ? app.service.contacts.filter(c => c.status === "online").length + " available" : "Connecting…"
                    iconComponent: TupleMark {
                        foreground: Color.popups.text
                    }
                    trailingControl: Row {
                        spacing: Style.spacing.xs
                        Ui.PanelActionButton {
                            iconText: "󰑐"
                            tooltipText: "Refresh · Ctrl+R"
                            focusable: true
                            foreground: Color.popups.text
                            onClicked: app.send("refresh")
                        }
                        Ui.PanelActionButton {
                            iconText: "󰒓"
                            tooltipText: "Preferences"
                            focusable: true
                            foreground: Color.popups.text
                            onClicked: app.page = app.page === "settings" ? "people" : "settings"
                        }
                    }
                }
                RowLayout {
                    visible: app.page === "people"
                    spacing: Style.spacing.md
                    MenuButton {
                        text: "People"
                        primary: !app.favoritesOnly
                        Layout.fillWidth: true
                        onClicked: app.favoritesOnly = false
                    }
                    MenuButton {
                        text: "Favorites"
                        primary: app.favoritesOnly
                        Layout.fillWidth: true
                        onClicked: app.favoritesOnly = true
                    }
                }
                Ui.TextField {
                    id: search
                    visible: app.page === "people"
                    Layout.fillWidth: true
                    implicitHeight: Style.space(34)
                    placeholderText: "Search people"

                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    selectByMouse: true

                    onAccepted: {
                        const contact = app.filteredContacts.find(c => c.status === "online");
                        if (contact)
                            app.send("call", contact.id);
                    }
                }
                RowLayout {
                    visible: app.page === "people"
                    Text {
                        text: app.favoritesOnly ? "FAVORITES" : "CONTACTS"
                        color: Qt.darker(Color.popups.text, 1.4)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        text: app.filteredContacts.filter(c => c.status === "online").length + " available"
                        color: Qt.darker(Color.popups.text, 1.4)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
                ListView {
                    visible: app.page === "people"
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(Style.space(250), Math.max(Style.space(100), contentHeight))
                    model: app.filteredContacts
                    clip: true
                    spacing: 2
                    Controls.ScrollBar.vertical: Controls.ScrollBar {}
                    delegate: ContactRow {
                        required property var modelData
                        width: ListView.view.width
                        contact: modelData
                        busy: app.service.busy
                        onCallRequested: uid => app.send("call", uid)
                        onFavoriteRequested: (uid, favorite) => app.send(favorite ? "favorite" : "unfavorite", uid)
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: app.filteredContacts.length === 0
                        text: !app.service.loaded ? "Connecting to Tuple…" : search.text ? "No matching people" : app.favoritesOnly ? "Star a contact to add a favorite" : "No contacts yet"
                        color: Qt.darker(Color.popups.text, 1.4)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                    }
                }
                ColumnLayout {
                    visible: app.page === "people"
                    Layout.fillWidth: true
                    spacing: Style.spacing.lg
                    RowLayout {
                        Ui.TextField {
                            id: linkInput
                            Layout.fillWidth: true
                            implicitHeight: Style.space(32)
                            placeholderText: "Paste a Tuple call link"

                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            selectByMouse: true

                            onAccepted: app.send("join", text.trim())
                        }
                        MenuButton {
                            text: "Join"
                            enabled: !app.service.busy && linkInput.text.trim().length > 0
                            onClicked: app.send("join", linkInput.text.trim())
                        }
                    }
                    MenuButton {
                        text: "Start a call with my link"
                        visible: !app.service.modern
                        Layout.fillWidth: true
                        enabled: !app.service.busy
                        onClicked: app.send("new")
                    }
                    MenuButton {
                        text: "Copy call link"
                        visible: app.service && app.service.callLink.length > 0
                        Layout.fillWidth: true
                        onClicked: {
                            Quickshell.clipboardText = app.service.callLink;
                            app.service.message = "Call link copied";
                            app.service.failed = false;
                        }
                    }
                }
                ColumnLayout {
                    visible: app.page === "settings"
                    Layout.fillWidth: true
                    spacing: Style.spacing.panelGap
                    Text {
                        text: "Preferences"
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.title
                        font.weight: Font.DemiBold
                    }
                    Ui.Toggle {
                        Layout.fillWidth: true
                        label: "Start calls muted"
                        checked: app.service.preferences["start-calls-muted"] === "1"
                        enabled: !app.service.busy
                        titleSize: Style.font.body
                        onClicked: app.send("start-muted", checked ? "0" : "1")
                    }
                    Ui.Toggle {
                        Layout.fillWidth: true
                        label: "Screen annotation overlay"
                        checked: app.service.preferences.overlay === "1"
                        enabled: !app.service.busy
                        titleSize: Style.font.body
                        onClicked: app.send("overlay", checked ? "0" : "1")
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Audio and shared-screen windows are managed by Tuple."
                        color: Qt.darker(Color.popups.text, 1.4)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: app.service.version
                        color: Qt.darker(Color.popups.text, 1.4)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }
                    MenuButton {
                        text: "Account & sign-in"
                        Layout.fillWidth: true
                        onClicked: app.page = "account"
                    }
                    RowLayout {
                        MenuButton {
                            text: "Go online"
                            enabled: !app.service.busy
                            Layout.fillWidth: true
                            onClicked: app.send("on")
                        }
                        MenuButton {
                            text: "Go offline"
                            enabled: !app.service.busy
                            Layout.fillWidth: true
                            onClicked: app.send("off")
                        }
                    }
                    MenuButton {
                        text: "Reconnect"
                        Layout.fillWidth: true
                        onClicked: app.service.restart()
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Use Go offline to stop receiving calls. The bar button remains available."
                        color: Qt.darker(Color.popups.text, 1.4)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }
                }
                ColumnLayout {
                    visible: app.page === "account"
                    Layout.fillWidth: true
                    spacing: Style.spacing.xl
                    Text {
                        text: "Tuple account"
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.title
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Sign in on Tuple’s website, then paste the authorization code here."
                        color: Qt.darker(Color.popups.text, 1.4)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        wrapMode: Text.WordWrap
                    }
                    MenuButton {
                        text: "Get sign-in link"
                        Layout.fillWidth: true
                        enabled: !app.service.busy
                        onClicked: app.send("login")
                    }
                    MenuButton {
                        text: "Open sign-in in browser"
                        visible: app.service.loginLink.length > 0
                        Layout.fillWidth: true
                        onClicked: Qt.openUrlExternally(app.service.loginLink)
                    }
                    Ui.TextField {
                        id: authCode
                        Layout.fillWidth: true
                        placeholderText: "Authorization code"
                        echoMode: TextInput.Password
                    }
                    MenuButton {
                        text: "Finish signing in"
                        primary: true
                        Layout.fillWidth: true
                        enabled: !app.service.busy && authCode.text.trim().length > 0
                        onClicked: app.send("auth", authCode.text.trim())
                    }
                    MenuButton {
                        text: "Sign out"
                        destructive: true
                        Layout.fillWidth: true
                        enabled: !app.service.busy
                        onClicked: signOutDialog.opened = true
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Util.alpha(Color.popups.text, 0.12)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "CALL CONTROLS"
                        color: Qt.darker(Color.popups.text, 1.4)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        text: app.service.busy ? "Working…" : ""
                        color: Color.accent
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.spacing.md
                    MenuButton {
                        text: "Mute"
                        enabled: !app.service.busy
                        Layout.fillWidth: true
                        onClicked: app.send("mute")
                    }
                    MenuButton {
                        text: "Unmute"
                        enabled: !app.service.busy
                        Layout.fillWidth: true
                        onClicked: app.send("unmute")
                    }
                    MenuButton {
                        text: "Share"
                        enabled: !app.service.busy
                        Layout.fillWidth: true
                        onClicked: app.send("share")
                    }
                    MenuButton {
                        text: "Stop share"
                        enabled: !app.service.busy
                        Layout.fillWidth: true
                        onClicked: app.send("unshare")
                    }
                    MenuButton {
                        text: "Leave"
                        destructive: true
                        enabled: !app.service.busy
                        Layout.fillWidth: true
                        onClicked: app.send("end")
                    }
                }
                Text {
                    visible: app.service.message.length > 0
                    Layout.fillWidth: true
                    text: app.service.message
                    textFormat: Text.PlainText
                    color: app.service.failed ? Color.urgent : Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.WordWrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
                RowLayout {
                    MenuButton {
                        text: app.page === "people" ? "Account" : "← People"
                        implicitHeight: Style.space(25)
                        onClicked: app.page = app.page === "people" ? "account" : "people"
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "Esc to close"
                        color: Qt.darker(Color.popups.text, 1.6)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }
            Ui.ConfirmDialog {
                id: signOutDialog
                anchors.fill: parent
                message: "Sign out of Tuple?"
                confirmText: "Sign out"
                onConfirmed: {
                    opened = false;
                    app.send("logout");
                }
                onCanceled: opened = false
            }
        }
    }
}
