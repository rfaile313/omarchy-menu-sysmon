import QtQuick
import Quickshell.Io
import qs.Ui

// Bar widget: runs bin/menu-sysmon on an interval and renders its JSON.
// The host injects `bar`, `moduleName` and `settings` after load.
WidgetButton {
  id: root

  property var settings: ({})
  property string outputText: ""
  property string outputTooltip: ""
  property bool outputActive: false

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  readonly property string scriptPath:
    Qt.resolvedUrl("bin/menu-sysmon").toString().replace(/^file:\/\//, "")

  function update(raw) {
    var text = String(raw || "").trim()
    if (text === "") return
    try {
      var data = JSON.parse(text)
      outputText = data.text || text
      outputTooltip = data.tooltip || ""
      outputActive = data.class === "warning" || data.class === "critical"
    } catch (e) {
      outputText = text
      outputTooltip = ""
      outputActive = false
    }
  }

  text: outputText
  tooltipText: outputTooltip
  active: outputActive
  horizontalMargin: Number(setting("horizontalMargin", 4))
  verticalPadding: Number(setting("verticalPadding", 6))
  fontSize: Number(setting("fontSize", 12))

  onPressed: function(button) {
    var command = ""
    if (button === Qt.RightButton) command = String(setting("onRightClick", ""))
    else if (button === Qt.MiddleButton) command = String(setting("onMiddleClick", ""))
    else command = String(setting("onClick", "omarchy-launch-or-focus-tui btop"))
    if (command && root.bar) root.bar.run(command)
  }

  Process {
    id: proc
    command: ["bash", "-lc",
      "'" + root.scriptPath + "' " + String(root.setting("fields", "cpu,ram,disk,net,fan"))
        + " " + String(root.setting("warnThreshold", 75))]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.update(text)
    }
  }

  Timer {
    interval: Math.max(1, Number(root.setting("interval", 3))) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!proc.running) proc.running = true
  }
}
