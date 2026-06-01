const std = @import("std");
const shimizu = @import("shimizu");
const wlr_layer_shell = @import("wlr-layer-shell").wlr_layer_shell_unstable_v1;

const Pixel = [4]u8;
const TRANSPARENT = Pixel{ 0x00, 0x00, 0x00, 0x00 };
const OPAQUE_WHITE = Pixel{ 0xFF, 0xFF, 0xFF, 0xFF };
const line_thickness: u32 = 2;
const default_width: u32 = 1920;
const default_height: u32 = 1080;

const Orientation = enum {
    horizontal,
    vertical,
};

const Alignment = enum {
    left,
    right,
    center,
};

const Config = struct {
    type_arg: []const u8,
    orientation: Orientation = .horizontal,
    alignment: Alignment = .center,
};

const ColorRule = struct {
    states: []const []const u8,
    color: Pixel,
};

const StyleConfig = struct {
    default_color: Pixel = OPAQUE_WHITE,
    rules: []ColorRule = &.{},
};

const ParsedMessage = struct {
    percent: f32,
    states_buf: [16][]const u8 = undefined,
    states_len: usize = 0,

    fn states(self: *const ParsedMessage) []const []const u8 {
        return self.states_buf[0..self.states_len];
    }
};

const Globals = struct {
    wl_shm: ?shimizu.core.wl_shm = null,
    wl_compositor: ?shimizu.core.wl_compositor = null,
    layer_shell: ?wlr_layer_shell.zwlr_layer_shell_v1 = null,
};

const AppState = struct {
    surface_configured: bool = false,
    width: u32 = default_width,
    height: u32 = line_thickness,
    closed: bool = false,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const config = parseArgs(args) catch {
        std.debug.print(
            "Usage: zlinestatus -type <type> [-orientation horizontal|vertical] [-alignment left|right|center]\n",
            .{},
        );
        return error.InvalidArgs;
    };

    const xdg_runtime_dir = std.posix.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;
    const socket_path = try std.fmt.allocPrint(allocator, "{s}/zlinestatus-{s}.sock", .{ xdg_runtime_dir, config.type_arg });
    defer allocator.free(socket_path);
    const style = try loadStyleConfig(allocator, config.type_arg);
    defer freeStyleConfig(allocator, style);

    std.posix.unlink(socket_path) catch {};
    const socket = try std.posix.socket(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    defer std.posix.close(socket);

    var socket_addr = std.mem.zeroes(std.posix.sockaddr.un);
    socket_addr.family = std.posix.AF.UNIX;
    if (socket_path.len >= socket_addr.path.len) return error.NameTooLong;
    @memcpy(socket_addr.path[0..socket_path.len], socket_path);
    try std.posix.bind(socket, @ptrCast(&socket_addr), @sizeOf(std.posix.sockaddr.un));
    try std.posix.listen(socket, 4);

    var connection = try shimizu.posix.Connection.open(allocator, .{});
    defer {
        _ = connection.flushSendBuffers() catch {};
        connection.close();
    }

    const display = connection.getDisplay();
    const registry = try display.get_registry(&connection.connection);
    const registry_done_callback = try display.sync(&connection.connection);

    var globals = Globals{};
    try connection.connection.setEventListener(registry, *Globals, onRegistryEvent, &globals);

    var registration_done = false;
    try connection.connection.setEventListener(
        registry_done_callback,
        *bool,
        onWlCallbackSetTrue,
        &registration_done,
    );

    while (!registration_done) try connection.recv();

    const wl_compositor = globals.wl_compositor orelse return error.WlCompositorNotFound;
    const wl_shm = globals.wl_shm orelse return error.WlShmNotFound;
    const layer_shell = globals.layer_shell orelse return error.LayerShellNotFound;

    const wl_surface = try wl_compositor.create_surface(&connection.connection);
    const layer_surface = try layer_shell.get_layer_surface(
        &connection.connection,
        @enumFromInt(@intFromEnum(wl_surface)),
        null,
        .top,
        "zlinestatus",
    );

    switch (config.orientation) {
        .horizontal => {
            try layer_surface.set_size(&connection.connection, 0, line_thickness);
            try layer_surface.set_anchor(&connection.connection, .{
                .top = true,
                .bottom = false,
                .left = true,
                .right = true,
            });
        },
        .vertical => {
            try layer_surface.set_size(&connection.connection, line_thickness, 0);
            try layer_surface.set_anchor(&connection.connection, .{
                .top = true,
                .bottom = true,
                .left = config.alignment == .left,
                .right = config.alignment == .right,
            });
        },
    }
    try layer_surface.set_keyboard_interactivity(&connection.connection, .none);
    try layer_surface.set_exclusive_zone(&connection.connection, 0);

    var state = AppState{};
    try connection.connection.setEventListener(layer_surface, *AppState, onLayerSurfaceEvent, &state);

    try wl_surface.commit(&connection.connection);
    _ = try connection.flushSendBuffers();
    while (!state.surface_configured and !state.closed) try connection.recv();
    if (state.closed) return error.SurfaceClosed;

    const width = if (state.width == 0)
        (if (config.orientation == .vertical) line_thickness else default_width)
    else
        state.width;
    const height = if (state.height == 0)
        (if (config.orientation == .vertical) default_height else line_thickness)
    else
        state.height;
    const framebuffer_byte_size: usize =
        @as(usize, width) * @as(usize, height) * @sizeOf(Pixel);

    const fd = try std.posix.memfd_create("zlinestatus", 0);
    defer std.posix.close(fd);
    try std.posix.ftruncate(fd, @intCast(framebuffer_byte_size));

    const memory = try std.posix.mmap(
        null,
        framebuffer_byte_size,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .SHARED },
        fd,
        0,
    );
    defer std.posix.munmap(memory);

    const pixels: []Pixel = std.mem.bytesAsSlice(Pixel, memory);
    const wl_shm_pool = try wl_shm.create_pool(
        &connection.connection,
        @enumFromInt(fd),
        @intCast(framebuffer_byte_size),
    );
    defer wl_shm_pool.destroy(&connection.connection) catch {};

    const wl_buffer = try wl_shm_pool.create_buffer(
        &connection.connection,
        0,
        @intCast(width),
        @intCast(height),
        @intCast(width * @sizeOf(Pixel)),
        .argb8888,
    );
    defer wl_buffer.destroy(&connection.connection) catch {};

    drawPercent(pixels, width, height, 0.0, config.orientation, config.alignment, style.default_color);
    try wl_surface.attach(&connection.connection, wl_buffer, 0, 0);
    try wl_surface.damage(&connection.connection, 0, 0, @intCast(width), @intCast(height));
    try wl_surface.commit(&connection.connection);
    _ = try connection.flushSendBuffers();

    while (true) {
        var client_addr: std.posix.sockaddr.un = undefined;
        var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr.un);
        const client = std.posix.accept(socket, @ptrCast(&client_addr), &addr_len, 0) catch continue;
        defer std.posix.close(client);

        var buf: [64]u8 = undefined;
        const len = std.posix.recv(client, &buf, 0) catch continue;
        if (len == 0) continue;

        const raw = std.mem.trim(u8, buf[0..len], &std.ascii.whitespace);
        const parsed = parseIncomingMessage(raw) catch continue;
        const color = pickColorForStates(style, parsed.states());

        drawPercent(
            pixels,
            width,
            height,
            parsed.percent,
            config.orientation,
            config.alignment,
            color,
        );
        try wl_surface.attach(&connection.connection, wl_buffer, 0, 0);
        try wl_surface.damage(&connection.connection, 0, 0, @intCast(width), @intCast(height));
        try wl_surface.commit(&connection.connection);
        _ = try connection.flushSendBuffers();
    }
}

fn loadStyleConfig(allocator: std.mem.Allocator, type_arg: []const u8) !StyleConfig {
    var style = StyleConfig{};

    const config_home = std.posix.getenv("XDG_CONFIG_HOME") orelse blk: {
        const home = std.posix.getenv("HOME") orelse return style;
        break :blk try std.fmt.allocPrint(allocator, "{s}/.config", .{home});
    };
    defer if (std.posix.getenv("XDG_CONFIG_HOME") == null) allocator.free(config_home);

    const path = try std.fmt.allocPrint(allocator, "{s}/zlinestatus/{s}.conf", .{ config_home, type_arg });
    defer allocator.free(path);

    const file = std.fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return style,
        else => return err,
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 64 * 1024);
    defer allocator.free(content);

    var rules: std.ArrayList(ColorRule) = .empty;
    errdefer {
        for (rules.items) |rule| {
            for (rule.states) |state| allocator.free(state);
            allocator.free(rule.states);
        }
        rules.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line_with_nl| {
        const line = std.mem.trim(u8, line_with_nl, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        const eq_index = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eq_index], " \t");
        const value = std.mem.trim(u8, line[eq_index + 1 ..], " \t");
        if (key.len == 0 or value.len == 0) continue;

        const color = parseHexColor(value) catch continue;
        if (std.mem.eql(u8, key, "default") or std.mem.eql(u8, key, "default_color")) {
            style.default_color = color;
            continue;
        }

        var states_list: std.ArrayList([]const u8) = .empty;
        errdefer {
            for (states_list.items) |state| allocator.free(state);
            states_list.deinit(allocator);
        }

        var state_it = std.mem.tokenizeAny(u8, key, "+, ");
        while (state_it.next()) |state| {
            if (state.len == 0) continue;
            const dup = try allocator.dupe(u8, state);
            try states_list.append(allocator, dup);
        }
        if (states_list.items.len == 0) continue;

        try rules.append(allocator, .{
            .states = try states_list.toOwnedSlice(allocator),
            .color = color,
        });
    }

    style.rules = try rules.toOwnedSlice(allocator);
    return style;
}

fn freeStyleConfig(allocator: std.mem.Allocator, style: StyleConfig) void {
    if (style.rules.len == 0) return;
    for (style.rules) |rule| {
        for (rule.states) |state| allocator.free(state);
        allocator.free(rule.states);
    }
    allocator.free(style.rules);
}

fn parseArgs(args: []const []const u8) !Config {
    var cfg = Config{ .type_arg = "" };
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-type")) {
            i += 1;
            if (i >= args.len) return error.InvalidArgs;
            cfg.type_arg = args[i];
        } else if (std.mem.eql(u8, arg, "-orientation")) {
            i += 1;
            if (i >= args.len) return error.InvalidArgs;
            cfg.orientation = parseOrientation(args[i]) orelse return error.InvalidArgs;
        } else if (std.mem.eql(u8, arg, "-alignment") or std.mem.eql(u8, arg, "-align")) {
            i += 1;
            if (i >= args.len) return error.InvalidArgs;
            cfg.alignment = parseAlignment(args[i]) orelse return error.InvalidArgs;
        } else {
            return error.InvalidArgs;
        }
    }
    if (cfg.type_arg.len == 0) return error.InvalidArgs;
    return cfg;
}

fn parseOrientation(raw: []const u8) ?Orientation {
    if (std.mem.eql(u8, raw, "horizontal")) return .horizontal;
    if (std.mem.eql(u8, raw, "vertical")) return .vertical;
    return null;
}

fn parseAlignment(raw: []const u8) ?Alignment {
    if (std.mem.eql(u8, raw, "left")) return .left;
    if (std.mem.eql(u8, raw, "right")) return .right;
    if (std.mem.eql(u8, raw, "center")) return .center;
    return null;
}

fn parseIncomingMessage(raw: []const u8) !ParsedMessage {
    const ws_index = std.mem.indexOfAny(u8, raw, " \t") orelse raw.len;
    const percent_raw = raw[0..ws_index];
    var percent = try std.fmt.parseFloat(f32, percent_raw);
    if (percent <= 1.0) percent *= 100.0;
    percent = std.math.clamp(percent, 0.0, 100.0);

    var parsed = ParsedMessage{ .percent = percent };
    if (ws_index < raw.len) {
        const remainder = std.mem.trim(u8, raw[ws_index..], " \t");
        var it = std.mem.tokenizeAny(u8, remainder, ",+ \t");
        while (it.next()) |state| {
            if (state.len == 0) continue;
            if (parsed.states_len >= parsed.states_buf.len) break;
            parsed.states_buf[parsed.states_len] = state;
            parsed.states_len += 1;
        }
    }

    return parsed;
}

fn pickColorForStates(style: StyleConfig, active_states: []const []const u8) Pixel {
    var best = style.default_color;
    var best_specificity: usize = 0;

    for (style.rules) |rule| {
        if (rule.states.len == 0) continue;
        var matches = true;
        for (rule.states) |required| {
            var found = false;
            for (active_states) |active| {
                if (std.ascii.eqlIgnoreCase(required, active)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                matches = false;
                break;
            }
        }
        if (matches and rule.states.len >= best_specificity) {
            best = rule.color;
            best_specificity = rule.states.len;
        }
    }
    return best;
}

fn parseHexColor(raw: []const u8) !Pixel {
    if (raw.len != 7 and raw.len != 9) return error.InvalidColor;
    if (raw[0] != '#') return error.InvalidColor;

    const r = try std.fmt.parseInt(u8, raw[1..3], 16);
    const g = try std.fmt.parseInt(u8, raw[3..5], 16);
    const b = try std.fmt.parseInt(u8, raw[5..7], 16);
    const a: u8 = if (raw.len == 9) try std.fmt.parseInt(u8, raw[7..9], 16) else 0xFF;
    return .{ r, g, b, a };
}

fn drawPercent(
    pixels: []Pixel,
    width: u32,
    height: u32,
    percent: f32,
    orientation: Orientation,
    alignment: Alignment,
    color: Pixel,
) void {
    @memset(pixels, TRANSPARENT);
    switch (orientation) {
        .horizontal => {
            const fill_width = @as(u32, @intFromFloat(@as(f32, @floatFromInt(width)) * (percent / 100.0)));
            const start_x: u32 = switch (alignment) {
                .left => 0,
                .right => width - fill_width,
                .center => (width - fill_width) / 2,
            };
            for (0..height) |y| {
                const row_start: usize = @as(usize, y) * @as(usize, width);
                for (0..fill_width) |x| {
                    pixels[row_start + @as(usize, start_x + x)] = color;
                }
            }
        },
        .vertical => {
            const fill_height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(height)) * (percent / 100.0)));
            for (0..fill_height) |y| {
                const row_start: usize = @as(usize, y) * @as(usize, width);
                for (0..width) |x| {
                    pixels[row_start + @as(usize, x)] = color;
                }
            }
        }
    }
}

fn onRegistryEvent(
    globals: *Globals,
    connection: *shimizu.Connection,
    registry: shimizu.core.wl_registry,
    event: shimizu.core.wl_registry.Event,
) !void {
    switch (event) {
        .global => |global| {
            if (shimizu.globalMatchesInterface(global, shimizu.core.wl_compositor)) {
                const obj = try registry.bind(
                    connection,
                    global.name,
                    shimizu.core.wl_compositor.NAME,
                    shimizu.core.wl_compositor.VERSION,
                );
                globals.wl_compositor = @enumFromInt(@intFromEnum(obj));
            } else if (shimizu.globalMatchesInterface(global, shimizu.core.wl_shm)) {
                const obj = try registry.bind(
                    connection,
                    global.name,
                    shimizu.core.wl_shm.NAME,
                    shimizu.core.wl_shm.VERSION,
                );
                globals.wl_shm = @enumFromInt(@intFromEnum(obj));
            } else if (shimizu.globalMatchesInterface(global, wlr_layer_shell.zwlr_layer_shell_v1)) {
                const obj = try registry.bind(
                    connection,
                    global.name,
                    wlr_layer_shell.zwlr_layer_shell_v1.NAME,
                    wlr_layer_shell.zwlr_layer_shell_v1.VERSION,
                );
                globals.layer_shell = @enumFromInt(@intFromEnum(obj));
            }
        },
        else => {},
    }
}

fn onLayerSurfaceEvent(
    state: *AppState,
    connection: *shimizu.Connection,
    layer_surface: wlr_layer_shell.zwlr_layer_surface_v1,
    event: wlr_layer_shell.zwlr_layer_surface_v1.Event,
) !void {
    switch (event) {
        .configure => |configure| {
            try layer_surface.ack_configure(connection, configure.serial);
            if (configure.width > 0) state.width = @intCast(configure.width);
            if (configure.height > 0) state.height = @intCast(configure.height);
            state.surface_configured = true;
        },
        .closed => state.closed = true,
    }
}

fn onWlCallbackSetTrue(
    done: *bool,
    _: *shimizu.Connection,
    _: shimizu.core.wl_callback,
    _: shimizu.core.wl_callback.Event,
) !void {
    done.* = true;
}
