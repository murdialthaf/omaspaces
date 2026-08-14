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
  moduleName: "lobo.omaspaces"

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
  readonly property int workspaceCount: Util.clamp(Math.round(Number(root.setting("workspaceCount", 5))), 1, 10)
  readonly property int maxWorkspaceId: Math.max(root.workspaceCount, Util.clamp(Math.round(Number(root.setting("maxWorkspaceId", 10))), 1, 10))
  readonly property bool hideEmpty: root.boolSetting("hideEmpty", false)
  readonly property int iconLimit: Util.clamp(Math.round(Number(root.setting("iconLimit", 4))), 1, 8)
  readonly property string accentSource: root.setting("accentSource", "Accent")
  readonly property bool compact: root.boolSetting("compact", false)
  readonly property bool showTooltip: root.boolSetting("showTooltip", true)
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

  function isOccupied(workspace) {
    return workspace !== null && workspace.toplevels && workspace.toplevels.values.length > 0
  }

  // Base workspaces always appear; anything above that only appears once
  // Hyprland reports it (i.e. it has, or has had, a window), and drops back
  // out once empty if hideEmpty is on.
  function visibleWorkspaceIds() {
    var ids = []
    for (var n = 1; n <= root.workspaceCount; n++) ids.push(n)

    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= root.maxWorkspaceId && ids.indexOf(id) === -1) ids.push(id)
    }
    ids.sort(function (a, b) { return a - b })

    if (!root.hideEmpty) return ids

    var focusedId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    return ids.filter(function (id) {
      if (id <= root.workspaceCount || id === focusedId) return true
      return root.isOccupied(root.workspaceById(id))
    })
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
  // without forking IconRules.js. Kept as two arrays deliberately: entries
  // is the plain-object form that's serialized to disk and driven by the
  // editor UI below; customIconRules is compiled from it (regex objects
  // aren't JSON-serializable, so the two can't be the same array). Scanning
  // it fresh on every icon lookup costs nothing at this size — it's a
  // handful of user-curated rules, not the built-in list.
  property var iconOverrideEntries: []
  property var customIconRules: []

  function parseIconOverrideEntries(raw) {
    var text = String(raw || "").trim()
    if (text === "") return []
    var parsed
    try {
      parsed = JSON.parse(text)
    } catch (e) {
      console.warn("lobo.omaspaces: iconOverridesPath is not valid JSON: " + e)
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
        console.warn("lobo.omaspaces: skipping invalid icon override pattern " + JSON.stringify(entries[i].match))
      }
    }
    return out
  }

  function applyIconOverrideEntries(entries) {
    root.iconOverrideEntries = entries
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

  readonly property string iconOverridesDir: {
    var p = root.iconOverridesEffectivePath
    var slash = p.lastIndexOf("/")
    return slash > 0 ? p.substring(0, slash) : p
  }

  // The rules editor writes here. mkdir -p first since the target directory
  // (a user-typed path, or a first run before ~/.config/omarchy exists) may
  // not exist yet — FileView.setText() doesn't create parent directories.
  Process {
    id: iconOverridesMkdir
    onExited: iconOverridesFile.setText(JSON.stringify(root.iconOverrideEntries, null, 2) + "\n")
  }

  function saveIconOverrideEntries(entries) {
    root.applyIconOverrideEntries(entries)
    iconOverridesMkdir.command = ["mkdir", "-p", root.iconOverridesDir]
    iconOverridesMkdir.running = true
  }

  function addIconOverride(pattern, icon) {
    var p = String(pattern || "").trim()
    var i = String(icon || "").trim()
    if (p === "" || i === "") return false
    try {
      new RegExp(p, "i")
    } catch (e) {
      return false
    }
    root.saveIconOverrideEntries(root.iconOverrideEntries.concat([{ match: p, icon: i }]))
    return true
  }

  function removeIconOverride(index) {
    var next = root.iconOverrideEntries.slice()
    if (index < 0 || index >= next.length) return
    next.splice(index, 1)
    root.saveIconOverrideEntries(next)
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

  // Distinct window classes currently open, across every workspace — feeds
  // the rules-editor picker so adding a rule doesn't require knowing (or
  // looking up) an app's exact Hyprland window class by hand.
  function openAppOptions() {
    var seen = {}
    var out = []
    var tops = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var i = 0; i < tops.length; i++) {
      var cls = root.toplevelClass(tops[i])
      if (!cls || seen[cls]) continue
      seen[cls] = true
      out.push(cls)
    }
    out.sort()
    return out
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

  function windowTitles(workspace) {
    if (!workspace) return ""
    var tops = workspace.toplevels ? workspace.toplevels.values : []
    var titles = []
    for (var i = 0; i < tops.length; i++) {
      var t = root.toplevelTitle(tops[i])
      if (t) titles.push(t)
    }
    return titles.join("\n")
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

  function tooltipFor(workspace) {
    if (!root.showTooltip) return ""
    var titles = root.windowTitles(workspace)
    var hint = "Right-click: icon rules"
    return titles ? titles + "\n" + hint : hint
  }

  // -------------------------------------------------------- icon rules editor
  property bool rulesEditorOpen: false
  property string rulesEditorPrefill: ""

  function openRulesEditor(workspace) {
    var tops = workspace && workspace.toplevels ? workspace.toplevels.values : []
    var cls = tops.length > 0 ? root.toplevelClass(tops[0]) : ""
    root.rulesEditorPrefill = cls
    // onOpenChanged only fires on the open/close transition, so re-opening
    // via a different pill while the popup is already up needs a direct
    // set here too, or the pattern field would keep showing the first
    // pill's prefill.
    if (root.rulesEditorOpen) patternField.text = cls
    root.rulesEditorOpen = true
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
    columns: root.vertical ? 1 : Math.max(1, root.visibleWorkspaceIds().length)
    columnSpacing: root.vertical ? 0 : root.pillGap
    rowSpacing: root.vertical ? root.pillGap : 0

    Repeater {
      model: root.visibleWorkspaceIds()

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
          tooltipText: root.tooltipFor(pill.workspace)
          onPressed: function (button) {
            if (button === Qt.LeftButton) root.focusWorkspace(pill.modelData)
            else if (button === Qt.RightButton) root.openRulesEditor(pill.workspace)
          }
          onWheelMoved: function (delta) { root.switchWorkspace(delta > 0 ? 1 : -1) }
        }

        HoverHandler {
          onHoveredChanged: pill.hot = hovered
        }
      }
    }
  }

  // Right-click any pill to open this: an editor for the icon-overrides
  // file (see iconOverridesEffectivePath above) so adding or fixing an
  // icon doesn't require hand-editing JSON. The app picker below is
  // sourced live from currently open windows purely as a convenience for
  // filling in the pattern field — the field itself stays a free-text
  // regex input, so a picked value can still be broadened (e.g. trimmed
  // down to `firefox` to match every Firefox variant) before saving.
  PopupCard {
    id: rulesPopup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.rulesEditorOpen
    contentWidth: fittedContentWidth(Style.space(320))
    contentHeight: fittedContentHeight(rulesColumn.implicitHeight, Style.space(420))

    function close() { root.rulesEditorOpen = false }

    onOpenChanged: if (open) {
      patternField.text = root.rulesEditorPrefill
      iconField.text = ""
      appPicker.value = ""
    }

    Column {
      id: rulesColumn
      anchors.fill: parent
      spacing: Style.spacing.lg

      Text {
        text: "ICON RULES"
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        width: parent.width
        text: "Pick an open app (or type your own pattern below), paste an icon, and add it. Saved to " + root.iconOverridesEffectivePath + " and applied immediately."
        color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.4)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Dropdown {
        id: appPicker
        width: parent.width
        showLabel: false
        options: root.rulesEditorOpen ? root.openAppOptions() : []
        onChanged: function (v) { patternField.text = v }
      }

      TextField {
        id: patternField
        width: parent.width
        placeholderText: "app pattern (regex), e.g. firefox|zen"
      }

      Row {
        width: parent.width
        spacing: Style.spacing.controlGap

        TextField {
          id: iconField
          width: parent.width - addButton.width - parent.spacing
          placeholderText: "icon glyph"
        }

        Button {
          id: addButton
          text: "Add"
          bordered: true
          foreground: root.bar ? root.bar.barForeground : Color.foreground
          onClicked: {
            if (root.addIconOverride(patternField.text, iconField.text)) {
              patternField.text = ""
              iconField.text = ""
              appPicker.value = ""
            }
          }
        }
      }

      PanelSeparator {
        foreground: root.bar ? root.bar.barForeground : Color.foreground
      }

      Text {
        visible: root.iconOverrideEntries.length === 0
        text: "No custom rules yet."
        color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.4)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
      }

      Column {
        width: parent.width
        spacing: Style.spacing.xs

        Repeater {
          model: root.iconOverrideEntries

          Row {
            required property var modelData
            required property int index
            width: rulesColumn.width
            spacing: Style.spacing.controlGap

            Text {
              width: parent.width - removeButton.width - parent.spacing
              text: modelData.icon + "  " + modelData.match
              color: root.bar ? root.bar.barForeground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            Button {
              id: removeButton
              text: "✕"
              foreground: root.bar ? root.bar.barForeground : Color.foreground
              onClicked: root.removeIconOverride(index)
            }
          }
        }
      }
    }
  }
}
