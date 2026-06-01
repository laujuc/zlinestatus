//! Designed for use by a single surface.
//!
//! Requires a stable memory address.

wl_shm: shimizu.core.wl_shm,

/// ShmSwapChain will recreate the shared memory pool any time it needs to grow
/// the maximum size of the frames.
shm_pool: ?shimizu.posix.ShmPool = null,

max_buffer_size: u31 = 0,

/// Stores the next index (not the next offset) where a new frame should be
/// allocated from, if there aren't any free framebuffers.
///
/// Should be reset to zero every time the `ShmPool` is recreated.
next_frame_index: u31 = 0,

buffer_mappings: BufferMappings = .empty,
buffer_indices: std.AutoArrayHashMapUnmanaged(shimizu.core.wl_buffer, BufferIndex) = .empty,
free_buffers: std.ArrayListUnmanaged(BufferIndex) = .empty,

pub const BufferIndex = enum(u31) { _ };

pub fn deinit(this: *@This(), connection: *shimizu.Connection, gpa: std.mem.Allocator) void {
    for (this.buffer_indices.keys()) |wl_buffer| {
        wl_buffer.destroy(connection) catch {};
    }
    this.buffer_indices.deinit(gpa);

    for (this.buffer_mappings.keys()) |mapping| {
        if (this.shm_pool) |*pool| pool.unmap(mapping);
    }
    this.buffer_mappings.deinit(gpa);

    this.free_buffers.deinit(gpa);

    if (this.shm_pool) |*pool| {
        pool.deinit(connection);
        this.shm_pool = null;
    }

    this.* = undefined;
}

pub fn mapBuffer(this: *@This(), connection: *shimizu.Connection, gpa: std.mem.Allocator, num_bytes: u31) ![]align(std.heap.page_size_min) u8 {
    if (num_bytes > this.max_buffer_size) {
        log.debug("{s}: growing max_buffer_size of shared memory pool; destroying previous shared memory pool", .{@typeName(@This())});

        for (this.buffer_mappings.keys()) |mapping| {
            if (this.shm_pool) |*pool| pool.unmap(mapping);
        }
        for (this.buffer_indices.keys()) |wl_buffer| {
            wl_buffer.destroy(connection) catch {};
        }
        this.buffer_mappings.clearRetainingCapacity();
        this.buffer_indices.clearRetainingCapacity();
        this.free_buffers.clearRetainingCapacity();
        if (this.shm_pool) |*pool| {
            pool.deinit(connection);
            this.shm_pool = null;
        }

        this.next_frame_index = 0;
        this.max_buffer_size = try std.math.ceilPowerOfTwo(u31, num_bytes);

        this.shm_pool = try shimizu.posix.ShmPool.init(connection, this.wl_shm, this.max_buffer_size);
    }

    const shm_pool: *shimizu.posix.ShmPool = &this.shm_pool.?;

    try this.buffer_mappings.ensureTotalCapacity(gpa, this.next_frame_index + 1);
    try this.buffer_indices.ensureTotalCapacity(gpa, this.next_frame_index + 1);
    try this.free_buffers.ensureTotalCapacity(gpa, this.next_frame_index + 1);
    const buffer_index: BufferIndex = this.free_buffers.pop() orelse grow_shm_pool: {
        const new_index = this.next_frame_index;

        const required_pool_size = new_index * this.max_buffer_size + this.max_buffer_size;

        if (shm_pool.memory_len < required_pool_size) {
            try shm_pool.resize(connection, required_pool_size);
        }

        this.next_frame_index += 1;
        break :grow_shm_pool @enumFromInt(new_index);
    };

    const buffer_offset = @intFromEnum(buffer_index) * this.max_buffer_size;
    const buffer_bytes = try shm_pool.map(buffer_offset, num_bytes);

    this.buffer_mappings.putAssumeCapacity(buffer_bytes, buffer_index);

    return buffer_bytes;
}

/// Call to unmap a buffer without creating a `wl_buffer` from it.
///
/// Prefer `sendBuffer` if you want to create a buffer from it.
pub fn unmapBuffer(this: *@This(), bytes: []align(std.heap.page_size_min) u8) void {
    const buffer_index = this.buffer_mappings.fetchSwapRemove(bytes) orelse std.debug.panic("{s}: Unknown buffer passed to swapchain: {*} {d} bytes", .{ @typeName(@This()), bytes.ptr, bytes.len });
    this.free_buffers.appendAssumeCapacity(buffer_index.value);

    const shm_pool: *shimizu.posix.ShmPool = &this.shm_pool.?;
    shm_pool.unmap(bytes);
}

pub fn sendBuffer(this: *@This(), connection: *shimizu.Connection, bytes: []align(std.heap.page_size_min) u8, width: u31, height: u31, stride: u31, format: shimizu.core.wl_shm.Format) !shimizu.core.wl_buffer {
    const buffer_index = this.buffer_mappings.fetchSwapRemove(bytes) orelse std.debug.panic("{s}: Unknown buffer passed to swapchain: {*} {d} bytes", .{ @typeName(@This()), bytes.ptr, bytes.len });

    const shm_pool: *shimizu.posix.ShmPool = &this.shm_pool.?;
    shm_pool.unmap(bytes);

    const buffer_offset = @intFromEnum(buffer_index.value) * this.max_buffer_size;
    const wl_buffer = try shm_pool.createBuffer(connection, buffer_offset, width, height, stride, format);

    try connection.setEventListener(wl_buffer, *@This(), onWlBufferEvent, this);

    this.buffer_indices.putAssumeCapacityNoClobber(wl_buffer, buffer_index.value);
    return wl_buffer;
}

fn onWlBufferEvent(this: *@This(), connection: *shimizu.Connection, wl_buffer: shimizu.core.wl_buffer, event: shimizu.core.wl_buffer.Event) !void {
    switch (event) {
        .release => {
            wl_buffer.destroy(connection) catch {};
            if (this.buffer_indices.fetchSwapRemove(wl_buffer)) |buffer_index| {
                this.free_buffers.appendAssumeCapacity(buffer_index.value);
            }
        },
    }
}

const BufferMappings = std.ArrayHashMapUnmanaged([]align(std.heap.page_size_min) u8, BufferIndex, BufferMappingContext, false);

const BufferMappingContext = struct {
    pub fn hash(this: @This(), mapping: []align(std.heap.page_size_min) u8) u32 {
        _ = this;
        var hasher = std.hash.Wyhash.init(0);

        const ptr_int = @intFromPtr(mapping.ptr);
        hasher.update(std.mem.asBytes(&ptr_int));
        hasher.update(std.mem.asBytes(&mapping.len));

        return @as(u32, @truncate(hasher.final()));
    }

    pub fn eql(this: @This(), mapping_a: []align(std.heap.page_size_min) u8, mapping_b: []align(std.heap.page_size_min) u8, b_index: usize) bool {
        _ = this;
        _ = b_index;
        return mapping_a.ptr == mapping_b.ptr and mapping_a.len == mapping_b.len;
    }
};

const log = std.log.scoped(.shimizu);

const shimizu = @import("../shimizu.zig");
const std = @import("std");
