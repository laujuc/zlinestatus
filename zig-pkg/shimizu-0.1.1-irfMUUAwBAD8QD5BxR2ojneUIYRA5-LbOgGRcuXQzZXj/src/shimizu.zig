pub const wire = @import("wire");
pub const core = @import("core");
pub const compat = @import("./libwayland-compat.zig");
pub const posix = @import("./posix.zig");
pub const scanner = @import("scanner");

pub const Word = wire.Word;
pub const Header = wire.Header;
pub const Uint = wire.Uint;
pub const Int = wire.Int;
pub const Fixed = wire.Fixed;
pub const String = wire.String;
pub const Object = wire.Object;
pub const NewId = wire.NewId;
pub const Array = wire.Array;
pub const Fd = wire.Fd;
pub const Connection = wire.Connection;

/// No message can be larger than this, since the size of a message is stored in 16 bits.
pub const MAX_MESSAGE_WORDSIZE = MAX_MESSAGE_SIZE / @sizeOf(u32);

/// No message can be larger than this, since the size of a message is stored in 16 bits.
pub const MAX_MESSAGE_SIZE = std.math.maxInt(u16);

pub fn globalMatchesInterface(global: std.meta.TagPayload(core.wl_registry.Event, .global), I: type) bool {
    return std.mem.eql(u8, global.interface, I.NAME) and global.version >= I.VERSION;
}

/// A location the Wayland connection might be at, according the environment
/// variables described in the Wayland protocol.
///
/// - https://wayland-book.com/protocol-design/wire-protocol.html#transports
pub const ConnectionLocation = union(enum) {
    /// The Wayland connection is on an already open file descriptor, likely opened
    /// by the parent process.
    fd: std.posix.fd_t,
    /// According to the set environment variables, the Wayland connection should
    /// be at this path.
    ///
    /// Of course, the connection won't be at that path if the user doesn't have a
    /// Wayland compositor, so there is no guarantee that it is _definitely_ at this
    /// path.
    path: []const u8,

    pub fn deinit(this: @This(), gpa: std.mem.Allocator) void {
        switch (this) {
            .fd => {},
            .path => |path| gpa.free(path),
        }
    }
};

/// Checks WAYLAND_SOCKET, WAYLAND_DISPLAY, and XDG_RUNTIME_DIR to find the path
/// or file descriptor that we should use to open a connection to the Wayland
/// compositor.
///
/// If you want to use a FixedBufferAllocator, 2 * std.fs.max_path_bytes should be a safe amount.
/// The function possibly allocates two paths (one for WAYLAND_DISPLAY and another for XDG_RUNTIME_DIR).
/// I double that number just in case.
///
/// https://wayland-book.com/protocol-design/wire-protocol.html#transports
pub fn findConnectionLocation(gpa: std.mem.Allocator) error{ OutOfMemory, Overflow, InvalidCharacter, XDGRuntimeDirEnvironmentVariableNotFound }!ConnectionLocation {
    if (std.process.parseEnvVarInt("WAYLAND_SOCKET", std.posix.fd_t, 10)) |file_descriptor| {
        return ConnectionLocation{ .fd = file_descriptor };
    } else |err| switch (err) {
        error.EnvironmentVariableNotFound => {},
        else => |e| return e,
    }

    const display_name = std.process.getEnvVarOwned(gpa, "WAYLAND_DISPLAY") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => try gpa.dupe(u8, "wayland-0"),
        error.InvalidWtf8 => @panic("Linux does not use WTF-8, Windows does not use Wayland"),
        error.OutOfMemory => return error.Overflow,
    };
    if (std.fs.path.isAbsolute(display_name)) {
        return ConnectionLocation{ .path = display_name };
    }
    defer gpa.free(display_name);

    const xdg_runtime_dir_path = std.process.getEnvVarOwned(gpa, "XDG_RUNTIME_DIR") catch |err| switch (err) {
        error.InvalidWtf8 => @panic("Linux does not use WTF-8, Windows does not use Wayland"),
        // XDG_RUNTIME_DIR doesn't have a default value, so we give up if we can't find it.
        error.EnvironmentVariableNotFound => return error.XDGRuntimeDirEnvironmentVariableNotFound,
        error.OutOfMemory => return error.Overflow,
    };
    defer gpa.free(xdg_runtime_dir_path);

    const path = try std.fs.path.join(gpa, &.{
        xdg_runtime_dir_path,
        display_name,
    });

    return ConnectionLocation{ .path = path };
}

comptime {
    if (builtin.is_test) {
        _ = wire;
        _ = @import("./test.zig");
    }
}

const log = std.log.scoped(.shimizu);

const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
