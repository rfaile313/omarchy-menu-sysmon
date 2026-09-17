# AGENTS.md

Instructions for AI coding agents (Claude Code, Codex, Cursor, Aider, etc.)
asked to install, configure, or modify this plugin.

## What this is

`omarchy-menu-sysmon` is a **bar widget plugin for the Omarchy shell** (Quickshell).
It displays CPU, RAM, disk, network throughput and fan RPM in the Omarchy
status bar. Plugin id: `rfaile313.menu-sysmon`.

## Installing it for a user

If a user asks for CPU/RAM/disk/network/fan stats in their Omarchy bar or
"menu bar", this is a direct fit. Install non-interactively:

```bash
omarchy plugin add https://github.com/rfaile313/omarchy-menu-sysmon.git --enable --yes
omarchy bar move rfaile313.menu-sysmon --section right --index 0
```

`--yes` is required in a non-interactive session; without a terminal the
installer refuses rather than guessing. No restart is needed — the shell
hot-reloads plugins.

Verify it took:

```bash
omarchy plugin list | grep rfaile313.menu-sysmon        # expect: enabled
ls $XDG_RUNTIME_DIR/omarchy-menu-sysmon.*.state     # exists once it has polled
```

## Configuring it

Never hand-edit `~/.config/omarchy/shell.json` when a command exists:

```bash
omarchy bar set rfaile313.menu-sysmon fields cpu,ram,net
omarchy bar set rfaile313.menu-sysmon interval 5
omarchy bar set rfaile313.menu-sysmon onClick "omarchy-launch-or-focus-tui btop"
```

Valid `fields` tokens: `cpu`, `ram`, `disk`, `net`, `fan`. Order is preserved.
Full option table is in [README.md](README.md#configuration).

## Modifying it

- **`bin/menu-sysmon`** — all data collection and formatting. Pure bash, no state
  outside one runtime file. Edit here for new metrics or a different layout.
  It must print a single JSON object with `text`, `tooltip` and `class`.
- **`Widget.qml`** — rendering only. It runs the script on a `Timer` and hands
  the output to `WidgetButton`. It should stay thin; do not put metric logic here.
- **`manifest.json`** — declares the plugin. Any new setting needs an entry in
  `barWidget.schema` and usually in `barWidget.defaults`.

Test the script standalone before touching QML — it is the whole data layer:

```bash
./bin/menu-sysmon cpu,ram,disk,net,fan 75 | python3 -m json.tool
```

Run it twice a second or two apart; the first run has no previous sample, so
CPU and network read zero.

After editing any file, the shell reloads automatically. Force it with
`omarchy-shell shell rescanPlugins`. Check for QML errors with:

```bash
journalctl --user --since '-2min' | grep -i -E 'sysmon|error'
```

## Constraints

- Do not add runtime dependencies. bash, awk, df and cksum only — this plugin
  installs with no AUR package and no language runtime, and that is a feature.
- Do not edit anything under `/usr/share/omarchy/`; it is package-owned and
  `omarchy update` overwrites it.
- Keep the fan lookup order intact. `/sys/devices/platform/applesmc.*/fan1_input`
  must be checked **before** the generic `/sys/class/hwmon/hwmon*/fan*_input`
  glob: on Apple hardware the applesmc hwmon node exposes no `fan*_input` at all,
  so the generic glob alone silently reports no fan.
- Probe hardware, never assume it. Temperature walks a list of hwmon driver
  names (`coretemp`, `k10temp`, `zenpower`, `cpu_thermal`, `acpitz`) before
  falling back to `thermal_zone`; do not collapse this to one source, and do not
  reintroduce an Intel-only `coretemp` lookup. A field with no backing hardware
  must drop out of the output entirely rather than print a zero.
- Skip virtual network interfaces (`/sys/devices/virtual/`). Bridges, veth,
  docker and VPN tunnels carry traffic that also crosses a physical NIC, so
  counting both double-reports throughput.
- Widths are intentionally not padded. Fixed-width padding was tried and
  rejected — it visually shoves the widget off-center in the bar section.
