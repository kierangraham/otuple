import QtQuick
import Quickshell.Io

Item {
    id: service
    property var shell: null
    property bool demo: false
    property bool busy: false
    property bool loaded: false
    property bool modern: false
    property bool failed: false
    property string message: ""
    property string version: "Tuple"
    property string callLink: ""
    property string loginLink: ""
    property var contacts: []
    property var preferences: ({})
    signal resultReceived(string action)

    function send(action, value) {
        if (!bridge.running) {
            service.message = "Tuple connection stopped. Use Reconnect in preferences.";
            service.failed = true;
            return;
        }
        if (service.busy && action !== "refresh")
            return;
        service.message = "";
        service.failed = false;
        if (action !== "refresh")
            service.busy = true;
        bridge.write(JSON.stringify({
            action: action,
            value: value || ""
        }) + "\n");
    }
    function restart() {
        service.contacts = [];
        service.loaded = false;
        service.busy = false;
        service.message = "";
        service.failed = false;
        service.callLink = "";
        service.loginLink = "";
        bridge.exec(["python", decodeURIComponent(Qt.resolvedUrl("../backend.py").toString().replace(/^file:\/\//, ""))].concat(service.demo ? ["--demo"] : []));
    }
    function setDemo(value) {
        if (service.demo === value)
            return;
        service.demo = value;
        service.restart();
    }
    function receive(data) {
        if (data.type === "snapshot") {
            service.contacts = data.contacts;
            service.preferences = data.settings || {};
            service.modern = data.modern;
            service.version = data.version;
            service.loaded = true;
        } else if (data.type === "busy") {
            service.busy = data.value;
        } else if (data.type === "error" || data.type === "notice") {
            service.message = data.message;
            service.failed = data.type === "error";
        } else if (data.type === "result") {
            const text = typeof data.output === "string" ? data.output : JSON.stringify(data.output);
            const match = text.match(/https:\/\/[^\s"<>]+/);
            if (data.action === "new" && match)
                service.callLink = match[0];
            if (data.action === "login" && match)
                service.loginLink = match[0];
            service.message = service.demo ? "Preview only · no Tuple commands run" : data.action === "call" ? "Call requested" : data.action === "new" ? "Personal call started" : data.action === "auth" ? "Signed in" : "Done";
            service.failed = false;
            service.resultReceived(data.action);
        }
    }
    IpcHandler {
        target: "otuple"
        function ping(): string {
            return "otuple";
        }
        function setDemo(value: bool): void {
            service.setDemo(value);
        }
        function reconnect(): void {
            service.restart();
        }
        function status(): string {
            return JSON.stringify({
                loaded: service.loaded,
                busy: service.busy,
                demo: service.demo,
                contacts: service.contacts.length,
                failed: service.failed,
                version: service.version
            });
        }
    }
    Process {
        id: bridge
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    service.receive(JSON.parse(data));
                } catch (error) {
                    service.message = "Could not read Tuple response: " + error;
                    service.failed = true;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    service.message = text.trim().slice(-400);
                    service.failed = true;
                }
            }
        }
        onRunningChanged: if (!running)
            service.busy = false
    }
    Component.onCompleted: service.restart()
}
