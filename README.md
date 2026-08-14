# Omaspaces

Hyprland workspace indicators for the Omarchy bar, with per-app window icons
and a full set of layout and styling options.

![preview](preview.png)

## Requirements

- Omarchy (Quattro) running on Hyprland
- A Nerd Font installed and set as the bar font, so app glyphs render

## Installation

```sh
omarchy plugin add https://github.com/DanielLob-o/Omaspaces.git --enable
omarchy bar put lobo.omaspaces --section center
```

## Configuration

Open the widget's settings from the bar's widget settings panel to adjust:

| Setting | Description |
|---|---|
| Show app icons | Render a glyph per open window inside its workspace pill |
| Show workspace numbers | Show the workspace number |
| Base workspace count | Workspaces always shown, even empty |
| Highest workspace shown | Ceiling for extra workspaces that appear once occupied |
| Hide empty extra workspaces | Drop (rather than dim) empty workspaces above the base count |
| Max icons per workspace | Caps icons per pill before collapsing into a `+N` |
| Active color | `Accent`, `Urgent`, or `Foreground` palette role, shown as a soft background fill on the focused (or urgent) workspace |
| Compact spacing | Tighter padding/gaps between pills |
| Show window titles on hover | Tooltip listing the pill's open window titles |
| Custom icon rules file | Path to a JSON file of your own icon overrides (see below) |

### Built-in icon rules

App-to-icon rules live in `IconRules.js`, split into a small `titleRules`
list (for apps that need a window title to disambiguate, like browser tabs)
and a larger `classRules` list (matched and cached by window class). Add or
reorder entries there and save; the shell hot-reloads plugin QML on change.

### Your own icon overrides

Rather than editing `IconRules.js`, point the "Custom icon rules file"
setting at a JSON file of your own, for example
`~/.config/omarchy/omaspaces-icons.json`:

```json
[
  { "match": "claude-code|claude", "icon": "" },
  { "match": "my-internal-app", "icon": "󰀻" }
]
```

Each entry's `match` is a case-insensitive regular expression tested against
both the window class and title; the first match wins. Overrides are checked
before the built-in rules, so they can also be used to replace a built-in
icon you don't like. The file is watched and reloads automatically on save —
no restart needed.

## Removal

```sh
omarchy plugin remove lobo.omaspaces
```

## License

MIT. See [LICENSE](LICENSE).
