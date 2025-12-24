const std = @import("std");

pub fn main() !void {
    // Parse args: -type <type> <value>
    const args = std.os.argv;
    if (args.len < 4 or !std.mem.eql(u8, std.mem.span(args[1]), "-type")) {
        std.debug.print("Usage: zsendvalue -type <type> <value>\n", .{});
        return error.InvalidArgs;
    }
    const type_arg = std.mem.span(args[2]);
    const value_str = std.mem.span(args[3]);
    const value = try std.fmt.parseFloat(f32, value_str);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Get socket path
    const xdg_runtime_dir = std.os.getenv("XDG_RUNTIME_DIR") orelse return error.NoXdgRuntimeDir;
    const socket_path = try std.fmt.allocPrint(allocator, "{s}/zlinestatus-{s}.sock", .{ xdg_runtime_dir, type_arg });

    // Connect to socket
    const socket = try std.os.socket(std.os.AF.UNIX, std.os.SOCK_STREAM, 0);
    defer std.os.close(socket);

    var addr = std.os.sockaddr_un{
        .path = undefined,
    };
    std.mem.copyForwards(u8, &addr.path, socket_path);
    try std.os.connect(socket, @ptrCast(*const std.os.sockaddr, &addr), @sizeOf(std.os.sockaddr_un));

    // Send value
    const msg = try std.fmt.allocPrint(allocator, "{d}\n", .{value});
    _ = try std.os.send(socket, msg, 0);
}