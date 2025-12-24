const std = @import("std");
const shimizu = @import("shimizu");
const z2d = @import("z2d");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse args: -type <type>
    const args = std.process.argsAlloc(allocator) catch return error.OutOfMemory;
    defer std.process.argsFree(allocator, args);
    if (args.len < 3 or !std.mem.eql(u8, args[1], "-type")) {
        std.debug.print("Usage: zlinestatus -type <type>\n", .{});
        return error.InvalidArgs;
    }
    const type_arg = args[2];

    // Get XDG_RUNTIME_DIR
    const xdg_runtime_dir = std.posix.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;
    const socket_path = try std.fmt.allocPrint(allocator, "{s}/zlinestatus-{s}.sock", .{ xdg_runtime_dir, type_arg });

    // Create Unix socket
    const socket = try std.posix.socket(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    defer std.posix.close(socket);

    var addr = std.posix.sockaddr.un{
        .family = std.posix.AF.UNIX,
        .path = undefined,
    };
    @memcpy(addr.path[0..socket_path.len], socket_path);
    try std.posix.bind(socket, @ptrCast(&addr), @sizeOf(std.posix.sockaddr.un));
    try std.posix.listen(socket, 1);

    // Wayland setup with Shimizu (simplified; in real code, handle events properly)
    const display = try shimizu.wl_display.connect(null);
    defer shimizu.wl_display.disconnect(display);

    // Assume compositor and shm are bound (simplified)
    var compositor: ?*shimizu.wl_compositor = null;
    var shm: ?*shimizu.wl_shm = null;
    // TODO: Bind globals from registry

    // Placeholder screen height; in real code, get from wl_output
    const screen_height: u32 = 1080;
    const width: u32 = 4;
    const height: u32 = screen_height;

    // Create surface
    const surface = try shimizu.wl_compositor.createSurface(compositor.?);
    defer shimizu.wl_surface.destroy(surface);

    // Create shm pool and buffer
    const size = width * height * 4;
    const fd = try std.posix.memfd_create("buffer", 0);
    try std.posix.ftruncate(fd, size);
    const pool = try shimizu.wl_shm.createPool(shm.?, fd, size);
    defer shimizu.wl_shm_pool.destroy(pool);
    const buffer = try shimizu.wl_shm_pool.createBuffer(pool, 0, width, height, width * 4, shimizu.wl_shm.Format.argb8888);
    defer shimizu.wl_buffer.destroy(buffer);

    // Map the buffer
    const data = try std.posix.mmap(null, size, std.posix.PROT.READ | std.posix.PROT.WRITE, .{ .TYPE = .SHARED }, fd, 0);
    defer std.posix.munmap(data);

    // z2d setup
    var surface_z2d = try z2d.Surface.init(.image_surface_rgba, allocator, width, height);
    defer surface_z2d.deinit();

    var path = z2d.Path.init(allocator);
    defer path.deinit();

    // Initial draw
    var value: f32 = 0.0;
    try drawLine(&surface_z2d, &path, value, height);

    // Copy to buffer
    const pixels = surface_z2d.image_surface.getPixelsAs([]u32);
    const data_slice: []u8 = @as([*]u8, @ptrCast(data))[0..size];
    const pixels_bytes: []const u8 = @as([*]const u8, @ptrCast(pixels.ptr))[0..size];
    @memcpy(data_slice, pixels_bytes);

    // Attach and commit
    try shimizu.wl_surface.attach(surface, buffer, 0, 0);
    try shimizu.wl_surface.commit(surface);

    // Event loop (simplified; integrate with Wayland dispatch)
    while (true) {
        // Dispatch Wayland (placeholder)
        // try shimizu.wl_display.dispatch(display);

        // Check socket
        var client_addr: std.posix.sockaddr.un = undefined;
        var addr_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr.un);
        const client = std.posix.accept(socket, @ptrCast(&client_addr), &addr_len, 0) catch continue;
        defer std.posix.close(client);

        // Read float
        var buf: [64]u8 = undefined;
        const len = try std.posix.recv(client, &buf, 0);
        if (len > 0) {
            const str = std.mem.trim(u8, buf[0..len], &std.ascii.whitespace);
            value = std.fmt.parseFloat(f32, str) catch 0.0;
            value = std.math.clamp(value, 0.0, 1.0);
        }

        // Update drawing
        try drawLine(&surface_z2d, &path, value, height);
        const data_slice2: []u8 = @as([*]u8, @ptrCast(data))[0..size];
        const pixels_bytes2: []const u8 = @as([*]const u8, @ptrCast(pixels.ptr))[0..size];
        @memcpy(data_slice2, pixels_bytes2);

        // Commit
        try shimizu.wl_surface.attach(surface, buffer, 0, 0);
        try shimizu.wl_surface.commit(surface);
    }
}

fn drawLine(surface: *z2d.Surface, path: *z2d.Path, value: f32, max_height: u32) !void {
    const draw_height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(max_height)) * value));
    path.clear();
    try path.addRectangle(0, max_height - draw_height, 4, draw_height);
    surface.clear(0x00000000); // transparent
    surface.fill(path, 0xFFFFFFFF); // white
}