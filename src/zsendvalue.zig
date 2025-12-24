const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse args: -type <type> <value>
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 4 or !std.mem.eql(u8, args[1], "-type")) {
        std.debug.print("Usage: zsendvalue -type <type> <value>\n", .{});
        return error.InvalidArgs;
    }
    const type_arg = args[2];
    const value_str = args[3];
    const value = try std.fmt.parseFloat(f32, value_str);

    // Get socket path
    const xdg_runtime_dir = std.posix.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;
    const socket_path = try std.fmt.allocPrint(allocator, "{s}/zlinestatus-{s}.sock", .{ xdg_runtime_dir, type_arg });

    // Connect to socket
    const socket = try std.posix.socket(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    defer std.posix.close(socket);

    var addr = std.posix.sockaddr.un{
        .family = std.posix.AF.UNIX,
        .path = undefined,
    };
    @memcpy(addr.path[0..socket_path.len], socket_path);
    try std.posix.connect(socket, @ptrCast(&addr), @sizeOf(std.posix.sockaddr.un));

    // Send value
    const msg = try std.fmt.allocPrint(allocator, "{d}\n", .{value});
    _ = try std.posix.send(socket, msg, 0);
}