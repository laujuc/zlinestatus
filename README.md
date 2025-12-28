# zlinestatus

A Zig Wayland program that renders a vertical bar using the [way-z](https://github.com/psnszsn/way-z) client library. The bar's height (0.0 to 1.0) is updated based on a value received via a Unix socket in `XDG_RUNTIME_DIR`.

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

This creates a socket at `$XDG_RUNTIME_DIR/zlinestatus-mytype.sock` and opens a small Wayland window that shows the bar.

### zsendvalue
Send a value to update the bar:

```
zig build run-zsendvalue -- -type mytype 0.75
```

This sends `0.75` to the socket, updating the bar to 75% of its height.

## Notes
- Requires a Wayland session.
