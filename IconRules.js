.pragma library

// Class/title -> glyph resolution for open windows, split into two tiers:
//
//   titleRules  Small and checked on every lookup. These exist only for
//               apps that share one window class across many different
//               sites/services (mainly browser tabs), so the class alone
//               can't tell them apart.
//   classRules  Everything else, matched by window class. The caller is
//               expected to cache these by class, since a class is stable
//               for the lifetime of a window while its title is not.
//
// Keeping title-matching to a short, separate list (instead of interleaving
// title checks into one long ordered rule set) is what makes class-level
// caching safe: a cached class lookup never needs to be invalidated by a
// title change, because nothing later in the class list depends on title.

var DEFAULT_ICON = "󰀻"

var titleRules = [
  { match: /youtube/i, icon: "󰗃" },
  { match: /chatgpt/i, icon: "󰭹" },
  { match: /claude/i, icon: "󰭹" },
  { match: /gemini/i, icon: "󰭹" },
  { match: /github/i, icon: "󰊤" },
  { match: /drive\.google/i, icon: "󰊶" },
  { match: /mail\.google/i, icon: "󰊫" },
  { match: /music\.youtube/i, icon: "󰗃" },
  { match: /chess\.com/i, icon: "󰡘" },
  { match: /makerworld/i, icon: "󰹛" },
  { match: /devhints/i, icon: "󰘦" },
  { match: /opencode/i, icon: "󰆍" }
]

var classRules = [
  // Web apps (omarchy-launch-webapp gives each one a chrome-<host>-Default
  // class). Must come before Browsers, whose /chrome/ would swallow them.
  { match: /^chrome-web\.whatsapp\.com/i, icon: "󰖣" },
  { match: /^chrome-www\.youtube\.com/i, icon: "󰗃" },
  { match: /^chrome-mail\.google\.com/i, icon: "󰊫" },
  { match: /^chrome-drive\.google\.com/i, icon: "󰊶" },
  { match: /^chrome-maps\.google\.com/i, icon: "󰗵" },
  { match: /^chrome-www\.reddit\.com/i, icon: "󰑍" },
  { match: /^chrome-www\.chess\.com/i, icon: "󰡘" },
  { match: /^chrome-chatgpt\.com/i, icon: "󰭹" },
  { match: /^chrome-plugins\.omarchy\.org/i, icon: "󰐱" },
  { match: /^chrome-.*-Default$/i, icon: "󰖟" },

  // Terminals
  { match: /^foot$/i, icon: "󰆍" },
  { match: /^TUI\.(tile|float)$/i, icon: "󰆍" },

  // Browsers
  { match: /firefox|librewolf|floorp|waterfox|zen-browser|^zen$/i, icon: "󰈹" },
  { match: /microsoft-edge/i, icon: "󰇩" },
  { match: /brave/i, icon: "" },
  { match: /tor-browser|tor browser/i, icon: "󰗹" },
  { match: /chromium|thorium|google-chrome|chrome/i, icon: "󰊯" },

  // Editors / IDEs
  { match: /code-url-handler|code-oss|codium|^code$|visual-studio-code|com\.microsoft\.VSCode/i, icon: "󰨞" },
  { match: /^t3code$/i, icon: "󰅴" },
  { match: /^opencode-desktop$/i, icon: "󰆍" },
  { match: /^dyad$/i, icon: "󰚩" },
  { match: /dev\.zed\.zed/i, icon: "󱓞" },
  { match: /^n?vim$|neovim/i, icon: "" },

  // Chat / comms
  { match: /discord|webcord|vesktop/i, icon: "󰙯" },
  { match: /^slack$/i, icon: "󰒱" },
  { match: /signal/i, icon: "󰍡" },
  { match: /telegram/i, icon: "󰒊" },
  { match: /whatsapp|zapzap/i, icon: "󰖣" },

  // Media
  { match: /^spotify$/i, icon: "󰓇" },
  { match: /rhythmbox/i, icon: "󰝚" },
  { match: /^obs$|com\.obsproject\.studio/i, icon: "󰐍" },
  { match: /qv4l2|qvidcap/i, icon: "󰖠" },

  // Games
  { match: /^steam$/i, icon: "󰓓" },
  { match: /^steam_app_1815780$/i, icon: "󰞬" },
  { match: /^steam_app_/i, icon: "󰊗" },
  { match: /retroarch/i, icon: "󰊗" },
  { match: /moonlight/i, icon: "󰖔" },
  { match: /\.exe$|^wine/i, icon: "󰡶" },

  // Dev / ops tooling
  { match: /virt-manager|virtualbox/i, icon: "󰍺" },
  { match: /remmina/i, icon: "󰢹" },
  { match: /pavucontrol/i, icon: "󰓃" },
  { match: /gparted|gnome-disks|org\.gnome\.DiskUtility/i, icon: "󰋊" },
  { match: /lstopo/i, icon: "󰘚" },
  { match: /avahi|bssh|bvnc/i, icon: "󰌗" },
  { match: /limine-snapper/i, icon: "󰁯" },
  { match: /fcitx/i, icon: "󰌌" },
  { match: /system-config-printer/i, icon: "󰐪" },
  { match: /^voxtype/i, icon: "󰍬" },
  { match: /^uuctl$/i, icon: "󰙪" },

  // Software stores
  { match: /cosmic-store|com\.system76\.CosmicStore|org\.gnome\.Software/i, icon: "󰓜" },

  // Design / creative (Storyteller *Craft AppImages)
  { match: /designcraft/i, icon: "󰏘" },
  { match: /effectcraft/i, icon: "󰁨" },
  { match: /filmcraft/i, icon: "󰿎" },
  { match: /lightcraft/i, icon: "󰛨" },
  { match: /pdfcraft/i, icon: "󰈦" },
  { match: /photocraft/i, icon: "󱇣" },
  { match: /vectorcraft/i, icon: "󰫨" },
  { match: /^aether$|li\.oever\.aether/i, icon: "󰏘" },

  // Omarchy apps
  { match: /^omacalc$/i, icon: "󰃬" },
  { match: /^omacut$/i, icon: "󰆐" },
  { match: /^omawrite$/i, icon: "󰏫" },
  { match: /tensaku/i, icon: "󰷈" },

  // Office / docs
  { match: /libreoffice-writer/i, icon: "󰈙" },
  { match: /libreoffice-calc/i, icon: "󰧷" },
  { match: /libreoffice/i, icon: "󰈙" },
  { match: /evince/i, icon: "󰈦" },

  // Flatpak / System apps
  { match: /com\.bambulab\.BambuStudio|bambu-studio/i, icon: "󰹛" },
  { match: /com\.github\.IsmaelMartinez\.teams_for_linux|teams-for-linux/i, icon: "󰊻" },
  { match: /com\.github\.vikdevelop\.photopea_app/i, icon: "󰏘" },
  { match: /com\.spotify\.Client/i, icon: "󰓇" },
  { match: /com\.wps\.Office/i, icon: "󰈚" },
  { match: /eu\.nokun\.MirrorHall/i, icon: "󰋩" },
  { match: /io\.appflowy\.AppFlowy/i, icon: "󰠮" },
  { match: /io\.github\.flattool\.Ignition/i, icon: "󰍛" },
  { match: /io\.gitlab\.adhami3310\.Impression/i, icon: "󰈟" },
  { match: /org\.gnome\.Calculator/i, icon: "󰃬" },
  { match: /org\.gnome\.Calendar/i, icon: "󰃭" },
  { match: /org\.gnome\.Weather/i, icon: "󰖕" },
  { match: /org\.gnome\.clocks/i, icon: "󰅐" },
  { match: /org\.gnome\.Nautilus/i, icon: "󰝰" },
  { match: /org\.onlyoffice\.desktopeditors/i, icon: "󰈚" },
  { match: /org\.qbittorrent\.qBittorrent|qbittorrent/i, icon: "󰍇" },
  { match: /org\.remmina\.Remmina/i, icon: "󰢹" },
  { match: /org\.torproject\.torbrowser-launcher/i, icon: "󰗹" },
  { match: /tv\.plex\.PlexDesktop|plex/i, icon: "󰚺" },

  // Additional native apps
  { match: /obsidian/i, icon: "󰎚" },
  { match: /sublime_text/i, icon: "󰘐" },
  { match: /org\.inkscape\.Inkscape/i, icon: "󰏘" },
  { match: /com\.mitchellh\.ghostty/i, icon: "󰆍" },
  { match: /localsend/i, icon: "󰒊" },
  { match: /org\.quickshell/i, icon: "󰙀" },
  { match: /^mpv$/i, icon: "󱉺" },
  { match: /^imv/i, icon: "󰋩" },
  { match: /btop/i, icon: "󰨇" },
  { match: /cliamp/i, icon: "󰝚" },
  { match: /org\.omarchy\.agent/i, icon: "󰚩" },
  { match: /org\.omarchy\.terminal/i, icon: "󰆍" }
]

function iconForTitle(title) {
  if (!title) return ""
  for (var i = 0; i < titleRules.length; i++) {
    if (titleRules[i].match.test(title)) return titleRules[i].icon
  }
  return ""
}

function iconForClass(cls) {
  if (!cls) return ""
  for (var i = 0; i < classRules.length; i++) {
    if (classRules[i].match.test(cls)) return classRules[i].icon
  }
  return ""
}
