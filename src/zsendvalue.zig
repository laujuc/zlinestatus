const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse args: -type <type> <percentage> [states...]
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 4 or !std.mem.eql(u8, args[1], "-type")) {
        std.debug.print("Usage: zsendvalue -type <type> <percentage> [states...]\n", .{});
        return error.InvalidArgs;
    }
    const type_arg = args[2];
    const percentage_str = args[3];
    const percentage = try std.fmt.parseFloat(f32, percentage_str);

    // Get socket path
    const xdg_runtime_dir = std.posix.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;
    const socket_path = try std.fmt.allocPrint(allocator, "{s}/zlinestatus-{s}.sock", .{ xdg_runtime_dir, type_arg });

    // Connect to socket
    const socket = try std.posix.socket(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    defer std.posix.close(socket);

    var addr = std.mem.zeroes(std.posix.sockaddr.un);
    addr.family = std.posix.AF.UNIX;
    if (socket_path.len >= addr.path.len) return error.NameTooLong;
    @memcpy(addr.path[0..socket_path.len], socket_path);
    try std.posix.connect(socket, @ptrCast(&addr), @sizeOf(std.posix.sockaddr.un));

    // Send percentage and optional states.
    var states_buf: std.ArrayList(u8) = .empty;
    defer states_buf.deinit(allocator);
    for (args[4..], 0..) |state, idx| {
        if (idx != 0) try states_buf.append(allocator, ',');
        try states_buf.appendSlice(allocator, state);
    }

    const msg = if (states_buf.items.len == 0)
        try std.fmt.allocPrint(allocator, "{d}\n", .{percentage})
    else
        try std.fmt.allocPrint(allocator, "{d} {s}\n", .{ percentage, states_buf.items });
    defer allocator.free(msg);
    _ = try std.posix.send(socket, msg, 0);
}