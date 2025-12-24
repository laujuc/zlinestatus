const std = @import("std");
const shimizu = @import("shimizu");
const z2d = @import("z2d");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Get XDG_RUNTIME_DIR
    const xdg_runtime_dir = std.os.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;
    const socket_path = try std.fs.path.join(allocator, &[_][]const u8{ xdg_runtime_dir, "line_program.sock" });

    // Create Unix socket
    const socket = try std.os.socket(std.os.AF.UNIX, std.os.SOCK_STREAM, 0);
    defer std.os.close(socket);

    var addr = std.os.sockaddr_un{
        .path = undefined,
    };
    std.mem.copyForwards(u8, &addr.path, socket_path);
    try std.os.bind(socket, @ptrCast(*const std.os.sockaddr, &addr), @sizeOf(std.os.sockaddr_un));
    try std.os.listen(socket, 1);

    // Wayland setup with Shimizu
    const display = try shimizu.wl_display.connect(null);
    defer shimizu.wl_display.disconnect(display);

    const registry = try shimizu.wl_registry.getRegistry(display);
    defer shimizu.wl_registry.destroy(registry);

    // Assume we get compositor and shm from registry
    // This is simplified; in real code, bind globals
    var compositor: ?*shimizu.wl_compositor = null;
    var shm: ?*shimizu.wl_shm = null;
    // ... event handling to bind

    // For simplicity, assume we have them
    // Get output size - need to bind wl_output and get geometry
    // Assume screen_height = 1080; // placeholder
    const screen_height: u32 = 1080; // TODO: get from Wayland
    const width: u32 = 4;
    const height: u32 = screen_height;

    // Create surface
    const surface = try shimizu.wl_compositor.createSurface(compositor.?);
    defer shimizu.wl_surface.destroy(surface);

    // Create shm pool and buffer
    const size = width * height * 4; // RGBA
    const fd = try std.os.memfd_create("buffer", 0);
    try std.os.ftruncate(fd, size);
    const pool = try shimizu.wl_shm.createPool(shm.?, fd, size);
    defer shimizu.wl_shm_pool.destroy(pool);
    const buffer = try shimizu.wl_shm_pool.createBuffer(pool, 0, width, height, width * 4, shimizu.wl_shm.Format.argb8888);
    defer shimizu.wl_buffer.destroy(buffer);

    // Map the buffer
    const data = try std.os.mmap(null, size, std.os.PROT_READ | std.os.PROT_WRITE, std.os.MAP_SHARED, fd, 0);
    defer std.os.munmap(data);

    // z2d setup
    var surface_z2d = try z2d.Surface.init(.image_surface_rgba, allocator, width, height);
    defer surface_z2d.deinit();

    var path = z2d.Path.init(allocator);
    defer path.deinit();

    // Initial draw
    var value: f32 = 0.5; // initial
    try drawLine(&surface_z2d, &path, value, height);

    // Copy to buffer
    const pixels = surface_z2d.image_surface.getPixelsAs([]u32);
    @memcpy(@ptrCast([*]u8, data), @ptrCast([*]const u8, pixels.ptr), size);

    // Attach and commit
    try shimizu.wl_surface.attach(surface, buffer, 0, 0);
    try shimizu.wl_surface.commit(surface);

    // Event loop
    while (true) {
        // Dispatch Wayland events
        try shimizu.wl_display.dispatch(display);

        // Check socket
        var client_addr: std.os.sockaddr_un = undefined;
        var addr_len: std.os.socklen_t = @sizeOf(std.os.sockaddr_un);
        const client = std.os.accept(socket, @ptrCast(*std.os.sockaddr, &client_addr), &addr_len) catch continue;
        defer std.os.close(client);

        // Read float
        var buf: [64]u8 = undefined;
        const len = try std.os.recv(client, &buf, 0);
        if (len > 0) {
            const str = buf[0..len];
            value = try std.fmt.parseFloat(f32, std.mem.trim(u8, str, &std.ascii.whitespace));
            value = std.math.clamp(value, 0.0, 1.0);
        }

        // Update drawing
        try drawLine(&surface_z2d, &path, value, height);
        @memcpy(@ptrCast([*]u8, data), @ptrCast([*]const u8, pixels.ptr), size);

        // Commit
        try shimizu.wl_surface.attach(surface, buffer, 0, 0);
        try shimizu.wl_surface.commit(surface);
    }
}

fn drawLine(surface: *z2d.Surface, path: *z2d.Path, value: f32, max_height: u32) !void {
    const draw_height = @floatToInt(u32, @intToFloat(f32, max_height) * value);
    path.clear();
    try path.addRectangle(0, max_height - draw_height, 4, draw_height);
    surface.clear(0x00000000); // transparent
    surface.fill(path, 0xFFFFFFFF); // white
}