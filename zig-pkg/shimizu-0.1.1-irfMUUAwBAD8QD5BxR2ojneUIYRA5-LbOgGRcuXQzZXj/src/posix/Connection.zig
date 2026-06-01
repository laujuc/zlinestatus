gpa: std.mem.Allocator,
socket: std.posix.fd_t,

/// The next object id that will be allocated.
next_id: u32 = 2,

/// Object ids that have been released by the compositor.
free_ids: std.ArrayList(u32) = .empty,

objects: std.AutoHashMapUnmanaged(Object, ObjectInfo) = .{},

/// A buffer to read data into.
recv_buffer: []u8,

/// Keeps track of the where we should start reading into the recv_buffer.
recv_index: u32 = 0,

/// keep the recv iov with the struct so we can return pointers to it
recv_iov: [1]std.posix.iovec = undefined,

/// A buffer to read control messages into.
control_recv_buffer: []u8,

/// Keeps track of the where we should start reading into the control_recv_buffer.
control_index: u32 = 0,

recv_msghdr: std.posix.msghdr = undefined,

connection: wire.Connection,

pub const ObjectInfo = struct {
    interface_name: String,
    interface_version: Uint,
    msg_callback: ?Connection.MessageCallback,
    msg_userdata: usize,
    delete_listener: ?DeleteListener,
};

pub const DeleteListener = struct {
    callback: *const fn (connection: *Connection, Object, ObjectInfo) void,
    userdata: usize,
};

pub const OpenOptions = struct {
    send_buffer_size: u32 = shimizu.MAX_MESSAGE_SIZE,
    recv_buffer_size: u32 = shimizu.MAX_MESSAGE_SIZE,
    control_send_buffer_size: u32 = 1024,
    control_recv_buffer_size: u32 = 1024,
};

/// Open a connection to the Wayland compositor, handling the various environment variables that may be set.
///
/// See also `findConnectionLocation()`.
///
/// - https://wayland-book.com/protocol-design/wire-protocol.html#transports
pub fn open(allocator: std.mem.Allocator, options: OpenOptions) !@This() {
    const location = try shimizu.findConnectionLocation(allocator);
    defer location.deinit(allocator);

    const send_buffer = try allocator.alloc(u8, options.send_buffer_size);
    errdefer allocator.free(send_buffer);

    const recv_buffer = try allocator.alloc(u8, options.recv_buffer_size);
    errdefer allocator.free(recv_buffer);

    const control_send_buffer = try allocator.alloc(u8, options.control_send_buffer_size);
    errdefer allocator.free(control_send_buffer);

    const control_recv_buffer = try allocator.alloc(u8, options.control_recv_buffer_size);
    errdefer allocator.free(control_recv_buffer);

    const socket = switch (location) {
        .fd => |socket_fd| socket_fd,
        .path => |path| blk: {
            const stream = try std.net.connectUnixSocket(path);
            errdefer stream.close();

            break :blk stream.handle;
        },
    };

    return @This(){
        .gpa = allocator,
        .socket = socket,
        .recv_buffer = recv_buffer,
        .control_recv_buffer = control_recv_buffer,
        .connection = .{
            .vtable = CONNECTION_VTABLE,
            .message_writer = .{
                .vtable = message_writer_vtable,
                .buffer = send_buffer,
            },
            .control_buffer = control_send_buffer,
        },
    };
}

pub fn close(this: *@This()) void {
    // check for error messages
    if (builtin.mode == .Debug and builtin.os.tag == .linux) {
        var iov = [_]std.posix.iovec{
            .{
                // only read into the unused portion of the buffer
                .base = this.recv_buffer[this.recv_index..].ptr,
                .len = this.recv_buffer[this.recv_index..].len,
            },
        };

        const control_recv_unused = this.control_recv_buffer[this.control_index..];
        var recv_msg = std.os.linux.msghdr{
            .name = null,
            .namelen = 0,
            .iov = &iov,
            .iovlen = iov.len,
            // only read into the unused portion of the buffer
            .control = control_recv_unused.ptr,
            .controllen = @intCast(control_recv_unused.len),
            .flags = 0,
        };

        // TODO: switch to std.posix.recvmsg: https://github.com/ziglang/zig/issues/20660
        const bytes_read = std.os.linux.recvmsg(this.socket, &recv_msg, std.os.linux.MSG.DONTWAIT);
        const errno = std.os.linux.E.init(bytes_read);
        if (errno == .SUCCESS) {
            this.recv_index += @intCast(bytes_read);
            this.control_index += @intCast(recv_msg.controllen);
        } else if (errno != .AGAIN) {
            log.warn("error while reading from socket: {}", .{errno});
        }

        // search for error messages
        var index: usize = 0;
        var control_index: usize = 0;
        while (this.recv_buffer[index..this.recv_index].len > @sizeOf(Header)) {
            const header: *const Header = @ptrCast(@alignCast(this.recv_buffer[index..][0..@sizeOf(Header)]));

            if (header.object == .wl_display) {
                const event = shimizu.wire.deserialize(core.wl_display.Event, this.recv_buffer[0..this.recv_index], &index, this.control_recv_buffer[0..this.control_index], &control_index) catch |deserialize_err| {
                    log.warn("error deserializing message: {}", .{deserialize_err});
                    index += std.mem.alignForward(usize, header.size(), @sizeOf(Word));
                    continue;
                };
                switch (event) {
                    .@"error" => |err| if (this.objects.get(err.object_id)) |object_info| {
                        log.warn("{s}@{} error {} \"{f}\"", .{ object_info.interface_name, @intFromEnum(err.object_id), err.code, std.zig.fmtString(err.message) });
                    } else {
                        log.warn("unknown@{} error {} \"{f}\"", .{ @intFromEnum(err.object_id), err.code, std.zig.fmtString(err.message) });
                    },
                    else => {},
                }
            } else {
                index += std.mem.alignForward(usize, header.size(), @sizeOf(Word));
            }
        }

        if (this.connection.message_start != null) {
            log.warn("PosixConnection.close called before message finished being written", .{});
        }
        if (this.connection.message_writer.buffered().len > 0) {
            log.warn("Unsent bytes left in send buffer", .{});
            std.debug.dumpHex(this.connection.message_writer.buffered());
        }
        if (this.connection.control_end > 0) {
            log.warn("Unsent bytes left in control send buffer", .{});
            std.debug.dumpHex(this.connection.control_buffer[0..this.connection.control_end]);
        }
    }

    var object_iter = this.objects.iterator();
    while (object_iter.next()) |entry| {
        if (entry.value_ptr.*.delete_listener) |delete_listener| {
            delete_listener.callback(&this.connection, entry.key_ptr.*, entry.value_ptr.*);
        }
    }
    this.objects.deinit(this.gpa);

    this.gpa.free(this.connection.message_writer.buffer);
    this.gpa.free(this.connection.control_buffer);

    this.free_ids.deinit(this.gpa);
    this.gpa.free(this.recv_buffer);
    this.gpa.free(this.control_recv_buffer);
    std.posix.close(this.socket);
}

pub fn getDisplay(this: *@This()) core.wl_display {
    _ = this;
    return @enumFromInt(@intFromEnum(Object.wl_display));
}

const message_writer_vtable = &std.Io.Writer.VTable{
    .drain = messageWriterDrain,
};

fn messageWriterDrain(writer: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
    const connection: *wire.Connection = @fieldParentPtr("message_writer", writer);
    const this: *@This() = @fieldParentPtr("connection", connection);

    _ = data;
    _ = splat;

    const message_end = connection.message_start orelse connection.message_writer.end;
    std.debug.assert(message_end <= connection.message_writer.end);

    _ = this.flushSendBuffers() catch |err| switch (err) {
        else => return error.WriteFailed,
    };

    return 0;
}

const CONNECTION_VTABLE = &Connection.VTable{
    .create_id_fn = connectionCreateId,
    .destroy_id_fn = connectionDestroyId,
    .set_object_message_callback_fn = connectionSetObjectMessageCallback,
};

fn connectionCreateId(connection: *wire.Connection, name: [:0]const u8, version: u32) Connection.Error!Object {
    const this: *@This() = @fieldParentPtr("connection", connection);
    try this.objects.ensureUnusedCapacity(this.gpa, 1);

    const id = this.free_ids.pop() orelse alloc_id: {
        defer this.next_id += 1;
        break :alloc_id this.next_id;
    };

    this.objects.putAssumeCapacityNoClobber(@enumFromInt(id), .{
        .interface_name = name,
        .interface_version = version,
        .msg_callback = null,
        .msg_userdata = undefined,
        .delete_listener = null,
    });

    return @enumFromInt(id);
}

fn connectionDestroyId(connection: *wire.Connection, object_id: Object) void {
    const this: *@This() = @fieldParentPtr("connection", connection);
    const entry = this.objects.fetchRemove(object_id) orelse {
        std.log.warn("Unknown object id destroyed", .{});
        std.debug.dumpCurrentStackTrace(@returnAddress());
        return;
    };
    _ = entry;
    // if (entry.value.delete_listener) |listen| {
    //     listen.callback();
    // }
}

pub fn flushSendBuffers(this: *@This()) !usize {
    const message_end = this.connection.message_start orelse this.connection.message_writer.end;
    std.debug.assert(message_end <= this.connection.message_writer.end);

    const bytes_to_write = this.connection.message_writer.buffer[0..message_end];
    const msg_iov = [_]std.posix.iovec_const{
        .{
            .base = bytes_to_write.ptr,
            .len = bytes_to_write.len,
        },
    };

    const socket_msg = std.posix.msghdr_const{
        .name = null,
        .namelen = 0,
        .iov = &msg_iov,
        .iovlen = msg_iov.len,
        .control = this.connection.control_buffer.ptr,
        .controllen = @intCast(this.connection.control_end),
        .flags = 0,
    };

    const n = try std.posix.sendmsg(this.socket, &socket_msg, 0);
    std.debug.assert(this.connection.message_writer.consume(n) == 0);
    this.connection.control_end = 0;
    return n;
}

pub fn recv(this: *@This()) !void {
    _ = try this.flushSendBuffers();
    // TODO: switch to std.posix.recvmsg: https://github.com/ziglang/zig/issues/20660
    const bytes_read = std.os.linux.recvmsg(this.socket, this.getRecvMsgHdr(), 0);
    try this.processRecvMsgReturn(bytes_read);
}

/// Get a recvmsg msghdr filled out and ready to be passed to recvmsg.
///
/// Exposed to make integrating with stuff like `libxev` easier.
pub fn getRecvMsgHdr(this: *@This()) *std.posix.msghdr {
    this.recv_iov = [_]std.posix.iovec{
        .{
            // only read into the unused portion of the buffer
            .base = this.recv_buffer[this.recv_index..].ptr,
            .len = this.recv_buffer[this.recv_index..].len,
        },
    };

    const control_recv_unused = this.control_recv_buffer[this.control_index..];

    this.recv_msghdr = .{
        .name = null,
        .namelen = 0,
        .iov = &this.recv_iov,
        .iovlen = this.recv_iov.len,
        // only read into the unused portion of the buffer
        .control = control_recv_unused.ptr,
        .controllen = @intCast(control_recv_unused.len),
        .flags = 0,
    };

    return &this.recv_msghdr;
}

/// Update all the necessary state after a recvmsg call and dispatch currently read messages.
///
/// Should be called immediately after the recvmsg call, as errno might be a threadlocal variable.
pub fn processRecvMsgReturn(this: *@This(), bytes_read: usize) !void {
    const res = std.posix.errno(bytes_read);
    if (res != .SUCCESS) {
        std.debug.print("error while reading from socket: {}", .{res});
        return error.Unknown;
    }
    this.recv_index += @intCast(bytes_read);
    this.control_index += @intCast(this.recv_msghdr.controllen);

    const unused = try this.dispatchMessages(
        this.recv_buffer[0..this.recv_index],
        this.control_recv_buffer[0..this.control_index],
    );

    // move unused portions of the recv buffers to the start of their buffers
    for (this.recv_buffer[0..unused.buffer.len], unused.buffer) |*dest, src| {
        dest.* = src;
    }
    for (this.control_recv_buffer[0..unused.control.len], unused.control) |*dest, src| {
        dest.* = src;
    }
    this.recv_index = @intCast(unused.buffer.len);
    this.control_index = @intCast(unused.control.len);
}

pub fn dispatchMessages(this: *@This(), buffer: []const u8, control_messages: []const u8) !struct { buffer: []const u8, control: []const u8 } {
    var index: usize = 0;
    var control_index: usize = 0;

    while (buffer[index..].len >= @sizeOf(Header)) {
        const header: *const Header = @ptrCast(@alignCast(buffer[index..][0..@sizeOf(Header)]));
        const message_bytes = buffer[index..][0..header.size()];

        if (this.objects.get(header.object)) |object_info| {
            if (object_info.msg_callback) |msg_callback| {
                var sub_index: usize = 0;
                try msg_callback(
                    object_info.msg_userdata,
                    &this.connection,
                    header.object,
                    message_bytes,
                    &sub_index,
                    control_messages,
                    &control_index,
                );
            }
            index += std.mem.alignForward(usize, header.size(), @sizeOf(Word));
        } else if (header.object == .wl_display) {
            switch (try shimizu.wire.deserialize(core.wl_display.Event, buffer, &index, control_messages, &control_index)) {
                .@"error" => |err| if (this.objects.get(err.object_id)) |object_info| {
                    log.warn("{s}@{} error {} \"{f}\"", .{ object_info.interface_name, @intFromEnum(err.object_id), err.code, std.zig.fmtString(err.message) });
                } else {
                    log.warn("unknown@{} error {} \"{f}\"", .{ @intFromEnum(err.object_id), err.code, std.zig.fmtString(err.message) });
                },
                .delete_id => |delete_id| {
                    if (this.objects.fetchRemove(@enumFromInt(delete_id.id))) |entry| {
                        if (entry.value.delete_listener) |delete_listener| {
                            delete_listener.callback(&this.connection, entry.key, entry.value);
                        }
                    }
                    this.free_ids.append(this.gpa, delete_id.id) catch {
                        log.debug("{*} leaked id {}", .{ this, delete_id.id });
                    };
                },
            }
        } else {
            std.log.warn("unknown object id = 0x{x}", .{@intFromEnum(header.object)});
            return error.UnknownObject;
        }
    }

    return .{
        .buffer = buffer[index..],
        .control = control_messages[control_index..],
    };
}

fn connectionSetObjectMessageCallback(connection: *Connection, object: Object, msg_callback: ?Connection.MessageCallback, userdata: usize) Connection.Error!void {
    const this: *@This() = @fieldParentPtr("connection", connection);
    const object_info = this.objects.getPtr(object) orelse
        std.debug.panic("Tried to set message callback for unknown object id {} ({?*}, 0x{x})", .{ object, msg_callback, userdata });
    object_info.msg_callback = msg_callback;
    object_info.msg_userdata = userdata;
}

pub fn removeListener(this: @This()) void {
    this.connection.objects.getPtr(this.id.asObject()).?.listener = null;
}

const Connection = shimizu.Connection;
const Header = shimizu.Header;
const Object = shimizu.Object;
const String = shimizu.String;
const Uint = shimizu.Uint;
const Word = shimizu.Word;

const log = std.log.scoped(.shimizu);

const builtin = @import("builtin");
const core = @import("core");
const shimizu = @import("../shimizu.zig");
const std = @import("std");
const wire = @import("wire");
