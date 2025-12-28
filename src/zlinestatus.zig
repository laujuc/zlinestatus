const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.wl;
const xdg = wayland.xdg;
const Buffer = wayland.shm.Buffer;

const App = struct {
    shm: ?wl.Shm = null,
    compositor: ?wl.Compositor = null,
    wm_base: ?xdg.WmBase = null,
    running: bool = true,
    width: u31 = 4,
    height: u31 = 300,
    value: f32 = 0.0,
    client: *wayland.Client,
};

const SurfaceCtx = struct {
    app: *App,
    wl_surface: wl.Surface,
    xdg_surface: xdg.Surface,
    xdg_toplevel: xdg.Toplevel,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 3 or !std.mem.eql(u8, args[1], "-type")) {
        std.debug.print("Usage: zlinestatus -type <type>\n", .{});
        return error.InvalidArgs;
    }
    const type_arg = args[2];

    const xdg_runtime_dir = std.posix.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;
    const socket_path = try std.fmt.allocPrint(allocator, "{s}/zlinestatus-{s}.sock", .{ xdg_runtime_dir, type_arg });

    std.posix.unlink(socket_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };

    const socket = try std.posix.socket(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    defer std.posix.close(socket);

    var addr: std.posix.sockaddr.un = .{
        .family = std.posix.AF.UNIX,
        .path = undefined,
    };
    if (socket_path.len >= addr.path.len) return error.SocketPathTooLong;
    @memset(addr.path[0..], 0);
    @memcpy(addr.path[0..socket_path.len], socket_path);
    try std.posix.bind(socket, @ptrCast(&addr), @sizeOf(std.posix.sockaddr.un));
    try std.posix.listen(socket, 8);

    const client = try wayland.Client.connect(allocator);
    defer client.deinit();

    const registry = client.request(client.wl_display, .get_registry, .{});
    var app = App{
        .client = client,
        .shm = null,
        .compositor = null,
        .wm_base = null,
    };
    client.set_listener(registry, *App, registryListener, &app);
    try client.roundtrip();

    const compositor = app.compositor orelse return error.NoWlCompositor;
    const wm_base = app.wm_base orelse return error.NoXdgWmBase;

    var surface_ctx = try createSurface(client, &app, compositor, wm_base);
    defer destroySurface(client, &surface_ctx);

    client.set_listener(surface_ctx.xdg_surface, *SurfaceCtx, xdgSurfaceListener, &surface_ctx);
    client.set_listener(surface_ctx.xdg_toplevel, *SurfaceCtx, xdgToplevelListener, &surface_ctx);

    client.request(surface_ctx.wl_surface, .commit, {});
    flushEvents(client) catch {};

    var poll_fds = [1]std.posix.pollfd{.{ .fd = socket, .events = std.posix.POLL.IN, .revents = 0 }};
    while (app.running) {
    flushEvents(client) catch {};

        poll_fds[0].revents = 0;
        const ready = std.posix.poll(&poll_fds, 200) catch continue;
        if (ready > 0 and (poll_fds[0].revents & std.posix.POLL.IN) != 0) {
            handleSocket(socket, &app, &surface_ctx);
        }
    }
}

fn handleSocket(socket: std.posix.socket_t, app: *App, surface_ctx: *SurfaceCtx) void {
    while (true) {
        var client_addr: std.posix.sockaddr.un = undefined;
        var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr.un);
        const client_fd = std.posix.accept(socket, @ptrCast(&client_addr), &addr_len, std.posix.SOCK.NONBLOCK) catch return;
        defer std.posix.close(client_fd);

        var buf: [64]u8 = undefined;
        const len = std.posix.recv(client_fd, &buf, std.posix.MSG.DONTWAIT) catch continue;
        if (len == 0) continue;

        const trimmed = std.mem.trim(u8, buf[0..len], &std.ascii.whitespace);
        const parsed = std.fmt.parseFloat(f32, trimmed) catch continue;
        app.value = std.math.clamp(parsed, 0.0, 1.0);
        drawAndCommit(app, surface_ctx) catch {};
    }
}

fn drawAndCommit(app: *App, surface_ctx: *SurfaceCtx) !void {
    const client = app.client;
    const shm = app.shm orelse return error.NoWlShm;
    const buf = try Buffer.get(client, shm, app.width, app.height);
    drawLine(buf.mem(), app.width, app.height, app.value);
    client.request(surface_ctx.wl_surface, .attach, .{ .buffer = buf.wl_buffer, .x = 0, .y = 0 });
    client.request(surface_ctx.wl_surface, .damage, .{
        .x = 0,
        .y = 0,
        .width = std.math.maxInt(i32),
        .height = std.math.maxInt(i32),
    });
    client.request(surface_ctx.wl_surface, .commit, {});
    flushEvents(client) catch {};
}

fn drawLine(buf: []align(4) u8, width: u32, height: u32, value: f32) void {
    const data_u32: []u32 = std.mem.bytesAsSlice(u32, buf);
    const line_height = @min(height, @as(u32, @intFromFloat(@ceil(value * @as(f32, @floatFromInt(height))))));
    const start_row: u32 = if (line_height > 0) height - line_height else height;
    for (data_u32) |*px| px.* = 0x00000000;
    for (@as(usize, start_row)..@as(usize, height)) |y| {
        const base = y * @as(usize, @intCast(width));
        for (0..width) |x| {
            data_u32[base + @as(usize, x)] = 0xFFFFFFFF;
        }
    }
}

fn createSurface(client: *wayland.Client, app: *App, compositor: wl.Compositor, wm_base: xdg.WmBase) !SurfaceCtx {
    const wl_surface = client.request(compositor, .create_surface, .{});
    const xdg_surface = client.request(wm_base, .get_xdg_surface, .{ .surface = wl_surface });
    const xdg_toplevel = client.request(xdg_surface, .get_toplevel, .{});
    client.request(xdg_toplevel, .set_title, .{ .title = "zlinestatus" });
    client.request(xdg_toplevel, .set_min_size, .{ .width = @intCast(app.width), .height = @intCast(app.height) });
    return .{
        .app = app,
        .wl_surface = wl_surface,
        .xdg_surface = xdg_surface,
        .xdg_toplevel = xdg_toplevel,
    };
}

fn destroySurface(client: *wayland.Client, surf: *SurfaceCtx) void {
    client.request(surf.xdg_toplevel, .destroy, {});
    client.request(surf.xdg_surface, .destroy, {});
    client.request(surf.wl_surface, .destroy, {});
}

fn flushEvents(client: *wayland.Client) !void {
    client.connection.send();
    client.connection.recv();
    try client.connection.loop.run(.no_wait);
}

fn registryListener(client: *wayland.Client, registry: wl.Registry, event: wl.Registry.Event, ctx: *App) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                ctx.compositor = client.bind(registry, global.name, wl.Compositor, 1);
            } else if (std.mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                ctx.shm = client.bind(registry, global.name, wl.Shm, 1);
            } else if (std.mem.orderZ(u8, global.interface, xdg.WmBase.interface.name) == .eq) {
                ctx.wm_base = client.bind(registry, global.name, xdg.WmBase, 1);
            }
        },
        .global_remove => {},
    }
}

fn xdgSurfaceListener(client: *wayland.Client, xdg_surface: xdg.Surface, event: xdg.Surface.Event, surf: *SurfaceCtx) void {
    switch (event) {
        .configure => |configure| {
            client.request(xdg_surface, .ack_configure, .{ .serial = configure.serial });
            drawAndCommit(surf.app, surf) catch {};
        },
    }
}

fn xdgToplevelListener(_: *wayland.Client, _: xdg.Toplevel, event: xdg.Toplevel.Event, surf: *SurfaceCtx) void {
    switch (event) {
        .configure => |configure| {
            if (configure.width > 0) surf.app.width = @intCast(configure.width);
            if (configure.height > 0) surf.app.height = @intCast(configure.height);
        },
        .close => surf.app.running = false,
        else => {},
    }
}

test "drawLine fills bottom rows" {
    var buf: [16 * 4]u8 align(4) = undefined; // width 4, height 4
    drawLine(buf[0..], 4, 4, 0.5);
    const data = std.mem.bytesAsSlice(u32, buf[0..]);
    try std.testing.expectEqual(@as(u32, 0xFFFFFFFF), data[2 * 4]);
    try std.testing.expectEqual(@as(u32, 0x00000000), data[0]);
}
