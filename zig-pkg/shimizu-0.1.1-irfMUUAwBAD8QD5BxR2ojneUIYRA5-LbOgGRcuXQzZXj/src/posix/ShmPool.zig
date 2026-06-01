wl_shm_pool: shimizu.core.wl_shm_pool,
memory_fd: std.posix.fd_t,
memory_len: u31,

pub fn init(connection: *shimizu.Connection, wl_shm: shimizu.core.wl_shm, initial_size: u31) !@This() {
    const timestamp = std.time.nanoTimestamp();

    var memory_fd_name_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const memory_fd_name = try std.fmt.bufPrint(&memory_fd_name_buffer, "{s}-{x}", .{
        @typeName(@This()),
        std.mem.asBytes(&timestamp),
    });

    const fd = try std.posix.memfd_create(memory_fd_name, 0);
    errdefer std.posix.close(fd);

    try std.posix.ftruncate(fd, initial_size);

    const wl_shm_pool = try wl_shm.create_pool(
        connection,
        @enumFromInt(fd),
        initial_size,
    );

    return .{
        .wl_shm_pool = wl_shm_pool,
        .memory_fd = fd,
        .memory_len = initial_size,
    };
}

pub fn deinit(this: *@This(), connection: *shimizu.Connection) void {
    this.wl_shm_pool.destroy(connection) catch |err| {
        log.warn("{s}: Failed to destroy wl_shm_pool: {}", .{ @typeName(@This()), err });
    };

    std.posix.close(this.memory_fd);

    this.* = undefined;
}

pub const Error = shimizu.wire.Connection.Error || std.posix.MMapError || std.posix.TruncateError;

pub fn resize(this: *@This(), connection: *shimizu.Connection, new_len: u31) Error!void {
    std.debug.assert(new_len > this.memory_len);

    try std.posix.ftruncate(this.memory_fd, new_len);
    this.memory_len = new_len;

    try this.wl_shm_pool.resize(connection, @intCast(this.memory_len));
}

pub fn createBuffer(this: *@This(), connection: *shimizu.Connection, offset: u31, width: u31, height: u31, stride: u31, format: shimizu.core.wl_shm.Format) Error!shimizu.core.wl_buffer {
    std.debug.assert(offset + stride * height <= this.memory_len);

    const buffer = try this.wl_shm_pool.create_buffer(
        connection,
        offset,
        width,
        height,
        stride,
        format,
    );

    return buffer;
}

pub fn mapAll(this: *@This()) ![]align(std.heap.page_size_min) u8 {
    return try std.posix.mmap(null, this.memory_len, std.posix.PROT.READ | std.posix.PROT.WRITE, .{ .TYPE = .SHARED }, this.memory_fd, 0);
}

pub fn map(this: *@This(), offset: u31, len: u31) ![]align(std.heap.page_size_min) u8 {
    return try std.posix.mmap(null, len, std.posix.PROT.READ | std.posix.PROT.WRITE, .{ .TYPE = .SHARED }, this.memory_fd, offset);
}

pub fn unmap(this: *@This(), mapped_buffer: []align(std.heap.page_size_min) u8) void {
    _ = this;
    std.posix.munmap(mapped_buffer);
}

const log = std.log.scoped(.shimizu);

const builtin = @import("builtin");
const mem = std.mem;
const math = std.math;
const SmpAllocator = @This();
const std = @import("std");
const shimizu = @import("../shimizu.zig");
