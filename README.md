# zlinestatus

A Zig program that draws a vertical line on the screen (4 pixels wide, screen height tall) using the Shimizu library for Wayland and z2d for 2D graphics. The line's height is updated based on a value (0.0 to 1.0) received via a Unix socket in `XDG_RUNTIME_DIR`.

## Building

1. Ensure Zig is installed.
2. Clone the repository.
3. Run `zig build` to build both executables.

## Usage

### zlinestatus
Run the main program with a type to distinguish instances:

```
zig build run-zlinestatus -- -type mytype
```

This creates a socket at `$XDG_RUNTIME_DIR/zlinestatus-mytype.sock` and draws the line.

### zsendvalue
Send a value to update the line:

```
zig build run-zsendvalue -- -type mytype 0.75
```

This sends `0.75` to the socket, updating the line to 75% of screen height.

## Dependencies
- Shimizu (Wayland protocol)
- z2d (2D graphics)

Update hashes in `build.zig.zon` after fetching.

## Notes
- Wayland setup is simplified; enhance for production (e.g., proper event handling, output size detection).
- Assumes ARGB8888 buffer format.