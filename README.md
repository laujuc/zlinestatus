# zlinestatus

A Zig Wayland client that draws a thin status line and updates its length/color from values received over a Unix socket in `XDG_RUNTIME_DIR`.

## Building

1. Ensure Zig is installed.
2. Clone the repository.
3. Run `zig build` to build both executables.

If you use `just`, the repository also includes:

- `just build`
- `just test`
- `just install /your/prefix`

The install recipe places:

- `zlinestatus` and `zsendvalue` in `<prefix>/bin`
- helper scripts in `<prefix>/share/zlinestatus/scripts`
- the example s6 battery `run` script in `<prefix>/share/zlinestatus/scripts/s6/battery/run`
- a default `cfg/WAIT` in `<prefix>/share/zlinestatus/cfg/WAIT` if it does not already exist

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

## Battery polling script (execline)

An execline script is available at:

- `scripts/battery`

It polls the first battery exposed under `/sys/class/power_supply/BAT*` and sends:

- percentage (from that battery's `capacity`)
- state tags such as `discharging`, `charging`, `full`, `battery`, `ac`

Usage:

```bash
scripts/battery
```

Examples:

```bash
scripts/battery
```

`cfg/WAIT` controls the poll interval and should contain one integer number of seconds.

## s6 service example

A ready-to-use `run` script is included:

- `scripts/s6/battery/run`

From `scripts/s6/battery`, make it executable and run under `s6-supervise`/`s6-svscan` as usual.

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
