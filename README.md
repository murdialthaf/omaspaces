# Dynamic Omaspaces

Hyprland workspace pills for the [Omarchy](https://omarchy.org/) bar that come and go with your windows. A workspace gets a pill only while it has windows or is focused, and each pill shows a Nerd Font icon for every app open on it.

Based on [Omaspaces](https://github.com/DanielLob-o/Omaspaces) by Daniel Lobo.

## How it differs from Omaspaces

- **Dynamic.** No fixed set of empty pills. You see pills only for workspaces that are in use or focused on the focused monitor, so the bar grows and shrinks with what's open.
- **Bigger icon list.** Built-in icons for a wider range of desktop apps, Steam games, Wine programs, and Omarchy web apps (WhatsApp, YouTube, Gmail, Drive, Maps, Reddit and more), which otherwise all show the Chrome icon.
- **Simpler.** There's no hover tooltip and no right-click editor. You add custom icons through a JSON file (see below).

## What you see

- **Pills:** one per workspace in use, with its number and an icon for each open app. Past the limit, the rest fold into `+N`.
- **Active state:** the focused (or urgent) workspace gets a soft background in your accent color.
- **Click** a pill to switch to that workspace, or **scroll** over the widget to step through workspaces.

## Requirements

- Omarchy running on Hyprland
- A Nerd Font as the bar font, so the app icons render (Omarchy's default JetBrainsMono Nerd Font works)

## Installation

```sh
omarchy plugin add https://github.com/murdialthaf/omaspaces.git --enable
omarchy bar put murdi.omaspaces --section center
```

If Omarchy's built-in workspaces widget or the original Omaspaces is also on your bar, turn it off so you don't get two rows of workspaces:

```sh
omarchy plugin disable omarchy.workspaces
omarchy plugin disable lobo.omaspaces
```

## Configuration

Set options with `omarchy bar set murdi.omaspaces <key> <value>`, or edit the widget's entry in `~/.config/omarchy/shell.json` (it reloads on save). Pass `--json` for booleans and numbers. Without it the value is saved as a string, and the string `"false"` counts as true:

```sh
omarchy bar set murdi.omaspaces compact true --json
omarchy bar set murdi.omaspaces iconLimit 3 --json
```

| Setting | Key | Default | Description |
|---|---|---|---|
| Show app icons | `showIcons` | `true` | Draw an icon for each open window inside its pill |
| Show workspace numbers | `showNumbers` | `true` | Show the workspace number. If icons are also off, numbers show anyway |
| Max icons per workspace | `iconLimit` | `4` | Icons per pill (1–8) before the rest fold into `+N` |
| Active color | `accentSource` | `Accent` | `Accent`, `Urgent` or `Foreground`: the theme color used for the focused workspace |
| Compact spacing | `compact` | `false` | Tighter padding and gaps between pills |
| Custom icon rules file | `iconOverridesPath` | `~/.config/omarchy/omaspaces-icons.json` | JSON file of your own icon rules (see below) |

## Adding your own icons

Create the file at `iconOverridesPath`:

```json
[
  { "match": "dbeaver", "icon": "󰆼" },
  { "match": "my-internal-app", "icon": "󰀻" }
]
```

- `match` is a case-insensitive regular expression, tested against both the window class and the window title.
- Your rules are checked before the built-in ones, so they can also replace a built-in icon. The first match wins.
- The widget watches the file and applies changes as soon as you save, with no restart.

To find an app's window class, open the app and run:

```sh
hyprctl clients | grep -A2 'class:'
```

You can copy icons from the [Nerd Fonts cheat sheet](https://www.nerdfonts.com/cheat-sheet).

### Built-in rules

The built-in list is in `IconRules.js` and has two parts:

- `titleRules` match the window title. They're for apps that share one window class across many sites, such as browser tabs.
- `classRules` match the window class and are cached per class.

Omarchy web apps launched with `omarchy-launch-webapp` get a class like `chrome-web.whatsapp.com__-Default`, so their rules come before the browser rules.

## Removal

```sh
omarchy plugin remove murdi.omaspaces
```

## License

MIT. See [LICENSE](LICENSE). Original work © Daniel Lobo.
