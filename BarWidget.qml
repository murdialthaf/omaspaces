import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "IconRules.js" as IconRules

BarWidget {
  id: root
  moduleName: "murdi.omaspaces"

  // Settings written via `omarchy bar set` without `--json` land in
  // shell.json as plain strings (e.g. "false"), and QML's own string->bool
  // coercion treats any non-empty string as true — so a bare `setting()`
  // read would silently flip a boolean on. Style.qml's own boolToken()
  // has the same guard for the same reason; mirrored here for settings we
  // read ourselves.
  function boolSetting(key, fallback) {
    var value = root.setting(key, fallback)
    if (typeof value === "boolean") return value
    var s = String(value).trim().toLowerCase()
    if (s === "true" || s === "1" || s === "yes" || s === "on") return true
    if (s === "false" || s === "0" || s === "no" || s === "off") return false
    return fallback
  }

  // -------------------------------------------------------------- settings
  readonly property bool showIcons: root.boolSetting("showIcons", true)
  readonly property bool showNumbers: root.boolSetting("showNumbers", true)
  readonly property int iconLimit: Util.clamp(Math.round(Number(root.setting("iconLimit", 4))), 1, 8)
  readonly property string accentSource: root.setting("accentSource", "Accent")
  readonly property bool compact: root.boolSetting("compact", false)
  readonly property string iconOverridesPath: String(root.setting("iconOverridesPath", "~/.config/omarchy/omaspaces-icons.json"))

  readonly property color fgColor: root.bar ? root.bar.barForeground : Color.foreground
  readonly property color accentColor: {
    if (root.accentSource === "Urgent") return Color.urgent
    if (root.accentSource === "Foreground") return root.fgColor
    return Color.accent
  }

  // Hyprland only pushes toplevel changes through IPC events; workspace
  // membership (which pill a window's icon belongs to) is stale until we
  // explicitly ask for a refresh in response to one.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindow" || event.name === "windowtitlev2" || event.name === "activewindow")
        Hyprland.refreshToplevels()
    }
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  // Only workspaces in use (or focused) on the focused monitor get a pill,
  // so the row grows and shrinks with what's open instead of reserving
  // slots for empty workspaces.
  function workspaceIds() {
    var monitor = Hyprland.focusedMonitor
    var values = Hyprland.workspaces.values
    var ids = []

    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]
      if (workspace.id <= 0) continue
      if (monitor && workspace.monitor !== monitor) continue
      if (workspace.focused || workspace.toplevels.values.length > 0) {
        ids.push(workspace.id)
      }
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function isOccupied(workspace) {
    return workspace !== null && workspace.toplevels && workspace.toplevels.values.length > 0
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function switchWorkspace(delta) {
    if (!root.bar) return
    var target = (delta > 0 ? "e+" : "e") + Math.abs(delta)
    root.bar.run("hyprctl dispatch " + Util.shellQuote('hl.dsp.focus({ workspace = "' + target + '" })'))
  }

  readonly property string home: Quickshell.env("HOME") || ""

  function expandPath(path) {
    var value = String(path || "").trim()
    if (value === "") return ""
    if (value === "~") return root.home
    if (value.indexOf("~/") === 0) return root.home + value.substring(1)
    if (value.indexOf("$HOME/") === 0) return root.home + value.substring(5)
    if (value.charAt(0) !== "/") return root.home + "/" + value
    return value
  }

  // User-supplied overrides, checked ahead of every built-in rule so someone
  // can pin an icon for an app the built-in list gets wrong (or misses)
  // without forking IconRules.js. Scanning it fresh on every icon lookup
  // costs nothing at this size — it's a handful of user-curated rules, not
  // the built-in list.
  property var customIconRules: []

  function parseIconOverrideEntries(raw) {
    var text = String(raw || "").trim()
    if (text === "") return []
    var parsed
    try {
      parsed = JSON.parse(text)
    } catch (e) {
      console.warn("murdi.omaspaces: iconOverridesPath is not valid JSON: " + e)
      return []
    }
    if (!Array.isArray(parsed)) return []

    var out = []
    for (var i = 0; i < parsed.length; i++) {
      var entry = parsed[i]
      if (!entry || typeof entry !== "object") continue
      var pattern = entry.match || entry.pattern
      var icon = entry.icon
      if (!pattern || !icon) continue
      out.push({ match: String(pattern), icon: String(icon) })
    }
    return out
  }

  function compileIconOverrideEntries(entries) {
    var out = []
    for (var i = 0; i < entries.length; i++) {
      try {
        out.push({ re: new RegExp(entries[i].match, "i"), icon: entries[i].icon })
      } catch (e) {
        console.warn("murdi.omaspaces: skipping invalid icon override pattern " + JSON.stringify(entries[i].match))
      }
    }
    return out
  }

  function applyIconOverrideEntries(entries) {
    root.customIconRules = root.compileIconOverrideEntries(entries)
    root.iconCache = {}
  }

  function reloadIconOverrides() {
    root.applyIconOverrideEntries(root.parseIconOverrideEntries(iconOverridesFile.text()))
  }

  // FileView needs a concrete path even when the setting is unset; pointing
  // it at a path that's never expected to exist keeps that case a plain,
  // silent onLoadFailed instead of relying on unspecified empty-path behavior.
  readonly property string iconOverridesEffectivePath: {
    var p = root.expandPath(root.iconOverridesPath)
    return p !== "" ? p : (root.home + "/.cache/omarchy/omaspaces-no-icon-overrides.json")
  }

  FileView {
    id: iconOverridesFile
    path: root.iconOverridesEffectivePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.reloadIconOverrides()
    onFileChanged: reload()
    onLoadFailed: root.applyIconOverrideEntries([])
  }

  function customIconFor(cls, title) {
    var rules = root.customIconRules
    for (var i = 0; i < rules.length; i++) {
      if (rules[i].re.test(title) || rules[i].re.test(cls)) return rules[i].icon
    }
    return ""
  }

  function toplevelClass(toplevel) {
    var ipc = toplevel ? toplevel.lastIpcObject : null
    if (ipc && ipc.class) return ipc.class
    if (toplevel && toplevel.appId) return toplevel.appId
    return ""
  }

  function toplevelTitle(toplevel) {
    if (toplevel && toplevel.title) return toplevel.title
    var ipc = toplevel ? toplevel.lastIpcObject : null
    return (ipc && ipc.title) || ""
  }

  // Cached by class only (not title): most rules key off the window class,
  // which is stable for a window's lifetime, while title changes constantly
  // for things like browser tabs. Caching the combined class+title pair
  // would mean the cache almost never hits for exactly the apps that most
  // need it. The few rules that legitimately depend on title stay outside
  // the cache in IconRules.iconForTitle, checked fresh every time.
  property var iconCache: ({})

  function iconForToplevel(toplevel) {
    var cls = root.toplevelClass(toplevel).toLowerCase()
    var title = root.toplevelTitle(toplevel).toLowerCase()

    var custom = root.customIconFor(cls, title)
    if (custom) return custom

    var byTitle = IconRules.iconForTitle(title)
    if (byTitle) return byTitle

    var cached = root.iconCache[cls]
    if (cached !== undefined) return cached

    var icon = IconRules.iconForClass(cls) || IconRules.DEFAULT_ICON
    root.iconCache[cls] = icon
    return icon
  }

  function windowGlyphs(workspace) {
    if (!workspace || !root.showIcons) return ""
    var tops = workspace.toplevels ? workspace.toplevels.values : []
    if (tops.length === 0) return ""

    var shown = Math.min(tops.length, root.iconLimit)
    var glyphs = []
    for (var i = 0; i < shown; i++) glyphs.push(root.iconForToplevel(tops[i]))

    var extra = tops.length - shown
    return extra > 0 ? glyphs.join(" ") + " +" + extra : glyphs.join(" ")
  }

  // Active state is communicated purely through the pill's background — the
  // number itself never changes shape, so a workspace with no matching icon
  // rule (or icons disabled entirely) never renders as a blank,
  // unclickable-looking gap either.
  function labelFor(id, workspace) {
    var parts = []
    if (root.showNumbers || !root.showIcons)
      parts.push(id === 10 ? "0" : String(id))
    if (root.showIcons) {
      var glyphs = root.windowGlyphs(workspace)
      if (glyphs) parts.push(glyphs)
    }
    return parts.join(" ")
  }

  readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
  readonly property int pillGap: root.compact ? Style.space(2) : Style.space(4)
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(6)

  implicitWidth: root.vertical ? root.barSize : grid.implicitWidth + trailingGap
  implicitHeight: root.vertical ? grid.implicitHeight : root.barSize

  GridLayout {
    id: grid
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: root.vertical ? undefined : parent.bottom
    anchors.right: root.vertical ? parent.right : undefined
    columns: root.vertical ? 1 : Math.max(1, root.workspaceIds().length)
    columnSpacing: root.vertical ? 0 : root.pillGap
    rowSpacing: root.vertical ? root.pillGap : 0

    Repeater {
      model: root.workspaceIds()

      Rectangle {
        id: pill
        required property int modelData

        readonly property var workspace: root.workspaceById(pill.modelData)
        readonly property bool occupied: root.isOccupied(pill.workspace)
        readonly property bool focused: root.focusedId === pill.modelData
        readonly property bool urgent: pill.workspace !== null && pill.workspace.urgent === true
        readonly property color stateColor: pill.urgent ? Color.urgent : root.accentColor
        property bool hot: false

        Layout.alignment: Qt.AlignVCenter
        Layout.fillHeight: !root.vertical
        Layout.fillWidth: root.vertical
        implicitWidth: root.vertical ? (root.barSize - Style.space(4)) : btn.implicitWidth
        implicitHeight: root.vertical ? btn.implicitHeight : root.barSize - Style.space(4)

        // Always rounded, independent of the theme's window corner-radius
        // setting: a workspace pill is chrome, not a window, so it shouldn't
        // go razor-square just because the active Hyprland theme is sharp.
        radius: root.compact ? Style.space(6) : Style.space(8)
        color: {
          if (pill.focused || pill.urgent) return Util.alpha(pill.stateColor, 0.22)
          return pill.hot ? Util.alpha(root.fgColor, 0.08) : "transparent"
        }

        Behavior on color { ColorAnimation { duration: 120 } }

        WidgetButton {
          id: btn
          anchors.fill: parent
          bar: root.bar
          text: root.labelFor(pill.modelData, pill.workspace)
          fontSize: root.vertical ? Style.font.icon : Style.font.body
          horizontalMargin: root.compact ? 5 : 8
          active: pill.focused || pill.urgent
          activeColor: pill.urgent ? Color.background : root.accentColor
          dimmed: !pill.occupied && !pill.focused
          onPressed: function (button) {
            if (button === Qt.LeftButton) root.focusWorkspace(pill.modelData)
          }
          onWheelMoved: function (delta) { root.switchWorkspace(delta > 0 ? 1 : -1) }
        }

        HoverHandler {
          onHoveredChanged: pill.hot = hovered
        }
      }
    }
  }
}
