# zlinestatus

A Zig Wayland client that draws a thin status line and updates its length/color from values received over a Unix socket in `XDG_RUNTIME_DIR`.

## Building

1. Install Zig 0.15.2 with `zvm install 0.15.2`. The vendored `shimizu` dependency does not support Zig 0.16 yet.
2. Clone the repository.
3. Run `just build` to build both executables. The recipes use `zvm run 0.15.2` by default.

If you manage the correct Zig version outside zvm, override the command:

```sh
ZIG=zig just build
```

If you use `just`, the repository also includes:

- `just build` — builds locally into `zig-out/bin`
- `just test`
- `just install /your/prefix` — builds and installs into the specified prefix
- `PREFIX=/your/prefix just install` — equivalent environment-variable form

The install recipe places:

- `zlinestatus` and `zsendvalue` in `<prefix>/bin`
- helper scripts in `<prefix>/share/zlinestatus/scripts`
- an s6 service template in `<prefix>/share/zlinestatus/s6/zlinestatus`
- systemd user units in `<prefix>/lib/systemd/user`

## Usage

### zlinestatus
Run the main program with a type to distinguish instances. You can optionally set orientation, position, and fill alignment:

```
zig build run-zlinestatus -- -type mytype -orientation horizontal -position bottom -alignment right
```

This creates a socket at `$XDG_RUNTIME_DIR/zlinestatus-mytype.sock` and draws the line.

### zsendvalue
Send a percentage (and optional state tags) to update the line:

```
zig build run-zsendvalue -- -type mytype 75 discharging low
```

This sends `75` and the states `discharging,low` to the socket.  
The receiver accepts both `0.0..1.0` and `0..100` values for percentage.

## Per-type color configuration

Color rules are loaded from:

- `$XDG_CONFIG_HOME/zlinestatus/<type>.conf`
- or `~/.config/zlinestatus/<type>.conf` if `XDG_CONFIG_HOME` is not set.

Format: one `key=value` per line.

- `default` or `default_color` sets fallback color
- any other key is a state or state-combination (`+`, `,` or spaces separate states)
- value is `#RRGGBB` or `#RRGGBBAA`

Example `~/.config/zlinestatus/battery.conf`:

```
default=#FFFFFF
discharging=#D08770
charging=#A3BE8C
ac=#88C0D0
critical=#BF616A
low=#EBCB8B
medium=#EBCB8B
almost-full=#A3BE8C
full=#8FBCBB
charging+ac=#5E81AC
discharging+critical=#BF616A
```

Rule matching uses active states from the socket message; the most specific matching rule wins.

## Automatic status instances

One systemd template starts the renderer and a matching built-in provider. Enable as many instances as needed; no per-status unit files are required:

| Instance | Provider |
| --- | --- |
| `zlinestatus@battery.service` | Reads `/sys/class/power_supply/BAT*/capacity` and `status` |
| `zlinestatus@wifi.service` | Polls `/proc/net/wireless` |
| `zlinestatus@brightness.service` | Polls `/sys/class/backlight` |
| `zlinestatus@volume.service` | Listens to PulseAudio/PipeWire events through `pactl` |
| Any other instance | Starts only the renderer; use `zsendvalue` from your own producer |

After `just install`, reload user-unit definitions and enable the instances you need:

```sh
systemctl --user daemon-reload
systemctl --user enable --now zlinestatus@battery.service zlinestatus@wifi.service
```

The user systemd manager must know the Wayland session environment. Most desktop environments arrange this automatically. For compositors that do not, run this once from compositor startup before enabling the service:

```bash
systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR PULSE_SERVER
```

### Change the polling interval

The template sets `WAIT=5` (seconds) for polling providers. Override it for one instance with a systemd drop-in:

```sh
systemctl --user edit zlinestatus@battery.service
```

Add:

```ini
[Service]
Environment=WAIT=15
```

Then apply it:

```sh
systemctl --user daemon-reload
systemctl --user restart zlinestatus@battery.service
```

### Run the battery helper manually

The helper is available at `scripts/battery`. Its optional first argument sets the status type, and `ZSENDVALUE` can override the sender binary:

```bash
scripts/battery battery
WAIT=15 ZSENDVALUE=./zig-out/bin/zsendvalue scripts/battery battery
```

`WAIT` must be a positive number of seconds.

## s6 user services

The installed `s6/zlinestatus` directory is a complete service source: it
starts the renderer and the provider selected by `env/TYPE`. Copy it into
your writable service-source directory, then edit the environment files:

```sh
PREFIX=/usr/local
SOURCE="$PREFIX/share/zlinestatus/s6/zlinestatus"
SERVICE="$HOME/.local/share/s6/service/zlinestatus-battery"

mkdir -p "$SERVICE"
cp -a "$SOURCE"/. "$SERVICE"/
printf 'battery\n' > "$SERVICE/env/TYPE"
printf '5\n' > "$SERVICE/env/WAIT"
```

To activate it with an already-running user `s6-svscan`, link the service
source into the scan directory and request a scan:

```sh
SCANDIR="$HOME/.local/share/s6/scandir"
ln -s "$SERVICE" "$SCANDIR/zlinestatus-battery"
s6-svscanctl -a "$SCANDIR"
s6-svc -wu -u "$SCANDIR/zlinestatus-battery"
```

Set `env/TYPE` to `wifi`, `brightness`, or `volume` for the built-in
providers. Any other type starts only the renderer, so external producers can
send values with `zsendvalue`. `env/ZLINESTATUS`, `env/ZSENDVALUE`, and
`env/WAIT` override the installed commands and polling interval. Logs are
written with `s6-log` to `${XDG_RUNTIME_DIR}/zlinestatus/<type>`. The renderer
does not implement s6 readiness notification, so `s6-svstat -o up,ready`
reports `true false` when it is running.

## Additional status scripts (execline)

These scripts send values/states to `zsendvalue`:

- `scripts/wifi` — polls WLAN signal quality from `/proc/net/wireless`
- `scripts/brightness` — polls display brightness from `/sys/class/backlight/*`
- `scripts/volume` — listens for PulseAudio/PipeWire volume changes via `pactl subscribe`

Usage:

```bash
scripts/wifi [interval_seconds] [type] [zsendvalue_command]
scripts/brightness [interval_seconds] [type] [zsendvalue_command]
scripts/volume [type] [zsendvalue_command]
```

Examples:

```bash
scripts/wifi 5 wifi ./zig-out/bin/zsendvalue
scripts/brightness 2 brightness ./zig-out/bin/zsendvalue
scripts/volume volume ./zig-out/bin/zsendvalue
```

## Dependencies
- `shimizu` (Wayland protocol bindings)
- Compositor support for `wlr-layer-shell-unstable-v1` (for example niri, sway, Hyprland)

## Notes
- `zlinestatus` and `zsendvalue` communicate over Unix domain sockets:
  `$XDG_RUNTIME_DIR/zlinestatus-<type>.sock`.
- If no config file/rule matches, the line defaults to white.
- The surface role is layer-shell (top layer), not an `xdg_toplevel` window.
- Orientation values: `horizontal`, `vertical`.
- Position values depend on orientation: `horizontal` allows `top` or `bottom`, `vertical` allows `left` or `right`.
- Alignment values: `left`, `right`, `center` and control horizontal fill placement inside the line.
