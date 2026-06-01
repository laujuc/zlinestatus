pub fn main() !void {
    var general_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = general_allocator.deinit();
    const gpa = general_allocator.allocator();

    const args_text = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args_text);

    if (args_text.len != 2) {
        std.debug.print("Expected 1 argument, found {}", .{args_text.len - 1});
        std.process.exit(1);
    }

    var protocols: shimizu.scanner.Database = .empty;
    defer protocols.deinit(gpa);

    if (std.fs.cwd().openFile("/usr/share/wayland/wayland.xml", .{})) |wayland_file| {
        wayland_file.close();

        // The wayland-protocols are ordered stable -> staging -> unstable because duplicate interfaces are
        // ignored, and we want to prefer more stable protocols over unstable protocols.
        const default_protocol_paths = [_][]const u8{
            "/usr/share/wayland/",
            "/usr/share/wayland-protocols/stable",
            "/usr/share/wayland-protocols/staging",
            "/usr/share/wayland-protocols/unstable",
        };
        for (default_protocol_paths) |path| {
            readProtocolsRecursive(gpa, &protocols, path) catch |err| {
                std.log.warn("Failed to read wayland protocols from {s}: {t}", .{ path, err });
                continue;
            };
        }
    } else |_| {
        // read embedded wayland protocol data
        var reader = std.Io.Reader.fixed(@embedFile("embedded_protocols"));
        protocols = try .readSerializedData(gpa, &reader);
    }

    const child_executable_path = args_text[1];

    // Open a connection to the wayland we will be proxying
    const server_socket = switch (try shimizu.findConnectionLocation(gpa)) {
        .fd => |socket_fd| socket_fd,
        .path => |path| blk: {
            defer gpa.free(path);
            const stream = try std.net.connectUnixSocket(path);
            errdefer stream.close();
            break :blk stream.handle;
        },
    };
    defer std.posix.close(server_socket);

    const client_socket, const child_socket = blk: {
        var sockets: [2]std.os.linux.fd_t = undefined;
        const res = std.os.linux.socketpair(std.os.linux.AF.UNIX, std.os.linux.SOCK.STREAM | std.os.linux.SOCK.CLOEXEC, 0, &sockets);
        switch (std.os.linux.E.init(res)) {
            .SUCCESS => {},
            else => |e| {
                std.debug.print("Error opening socketpair: {t}", .{e});
                std.process.exit(1);
            },
        }
        break :blk sockets;
    };
    defer _ = std.os.linux.close(client_socket);
    errdefer _ = std.os.linux.close(child_socket);

    var child_env_map = try std.process.getEnvMap(gpa);
    defer child_env_map.deinit();
    const child_socket_text = try std.fmt.allocPrint(gpa, "{}", .{child_socket});
    defer gpa.free(child_socket_text);
    try child_env_map.put("WAYLAND_SOCKET", child_socket_text);

    const child_socket_flags = try std.posix.fcntl(child_socket, std.posix.F.GETFD, 0);
    _ = try std.posix.fcntl(child_socket, std.posix.F.SETFD, child_socket_flags & ~@as(usize, std.posix.FD_CLOEXEC));

    var child_process = std.process.Child.init(&.{child_executable_path}, gpa);
    errdefer _ = child_process.kill() catch {};
    child_process.env_map = &child_env_map;
    child_process.stdout_behavior = .Pipe;
    child_process.stderr_behavior = .Pipe;

    try child_process.spawn();

    _ = std.os.linux.close(child_socket);

    const stdout_buffer = try gpa.alloc(u8, shimizu.MAX_MESSAGE_SIZE);
    defer gpa.free(stdout_buffer);

    const stderr_buffer = try gpa.alloc(u8, shimizu.MAX_MESSAGE_SIZE);
    defer gpa.free(stderr_buffer);

    const server_recv_msg_buffer = try gpa.alloc(u8, shimizu.MAX_MESSAGE_SIZE);
    defer gpa.free(server_recv_msg_buffer);

    const server_recv_control_buffer = try gpa.alloc(u8, 1024);
    defer gpa.free(server_recv_control_buffer);

    const server_send_msg_buffer = try gpa.alloc(u8, shimizu.MAX_MESSAGE_SIZE);
    defer gpa.free(server_send_msg_buffer);

    const server_send_control_buffer = try gpa.alloc(u8, 1024);
    defer gpa.free(server_send_control_buffer);

    const client_recv_msg_buffer = try gpa.alloc(u8, shimizu.MAX_MESSAGE_SIZE);
    defer gpa.free(client_recv_msg_buffer);

    const client_recv_control_buffer = try gpa.alloc(u8, 1024);
    defer gpa.free(client_recv_control_buffer);

    const client_send_msg_buffer = try gpa.alloc(u8, shimizu.MAX_MESSAGE_SIZE);
    defer gpa.free(client_send_msg_buffer);

    const client_send_control_buffer = try gpa.alloc(u8, 1024);
    defer gpa.free(client_send_control_buffer);

    const stdout_file = std.fs.File.stdout();
    const stderr_file = std.fs.File.stderr();

    var stdout_writer = stdout_file.writer(stdout_buffer[0..]);
    const stdout = &stdout_writer.interface;

    var stderr_writer = stderr_file.writer(stderr_buffer[0..]);
    const stderr = &stderr_writer.interface;
    _ = stderr;

    var server_reader = UnixDomainSocketReader.init(server_socket, server_recv_msg_buffer, server_recv_control_buffer);
    var server_writer = UnixDomainSocketWriter.init(server_socket, server_send_msg_buffer, server_send_control_buffer);

    var client_reader = UnixDomainSocketReader.init(client_socket, client_recv_msg_buffer, client_recv_control_buffer);
    var client_writer = UnixDomainSocketWriter.init(client_socket, client_send_msg_buffer, client_send_control_buffer);

    var objects: std.AutoArrayHashMapUnmanaged(shimizu.wire.Object, shimizu.scanner.Database.Interface.Name) = .empty;
    defer objects.deinit(gpa);
    try objects.put(gpa, .wl_display, protocols.interface_names.find("wl_display").?);

    var poll_fds = [_]std.posix.pollfd{
        .{ .fd = server_socket, .events = std.posix.POLL.IN, .revents = undefined },
        .{ .fd = client_socket, .events = std.posix.POLL.IN, .revents = undefined },
        .{ .fd = child_process.stdout.?.handle, .events = std.posix.POLL.IN, .revents = undefined },
        .{ .fd = child_process.stderr.?.handle, .events = std.posix.POLL.IN, .revents = undefined },
    };
    while (true) {
        if (poll_fds[0].fd == -1 and poll_fds[1].fd == -1 and poll_fds[2].fd == -1 and poll_fds[3].fd == -1) {
            break;
        }
        const num_fds_ready = try std.posix.poll(&poll_fds, -1);
        _ = num_fds_ready;

        const err_mask = std.posix.POLL.ERR | std.posix.POLL.NVAL | std.posix.POLL.HUP;
        if (poll_fds[0].revents & std.posix.POLL.IN != 0) {
            // bytes from server
            try readAndForwardSocket(
                &server_reader,
                &client_writer,
                stdout,
                &protocols,
                gpa,
                &objects,
                false,
            );
        }
        if (poll_fds[0].revents & err_mask != 0) {
            poll_fds[0].fd = -1;
            try std.posix.shutdown(client_socket, .send);
        }

        if (poll_fds[1].revents & std.posix.POLL.IN != 0) {
            // bytes from client
            try readAndForwardSocket(
                &client_reader,
                &server_writer,
                stdout,
                &protocols,
                gpa,
                &objects,
                true,
            );
        }
        if (poll_fds[1].revents & err_mask != 0) {
            poll_fds[1].fd = -1;
            try std.posix.shutdown(server_socket, .send);
        }

        if (poll_fds[2].revents & std.posix.POLL.IN != 0) {
            std.debug.print("downstream stdout:\n", .{});
            // bytes from downstream stdout
            const bytes_received = try std.posix.read(child_process.stdout.?.handle, stdout_buffer);
            if (bytes_received != 0) {
                var iter = std.mem.splitScalar(u8, std.mem.trimRight(u8, stdout_buffer[0..bytes_received], "\n"), '\n');
                while (iter.next()) |line| {
                    try stdout.writeAll("child stdout> ");
                    try stdout.writeAll(line);
                    try stdout.writeAll("\n");
                }
            }
        }
        if (poll_fds[2].revents & err_mask != 0) {
            poll_fds[2].fd = -1;
        }

        if (poll_fds[3].revents & std.posix.POLL.IN != 0) {
            // bytes from downstream stderr
            const bytes_received = try std.posix.read(child_process.stderr.?.handle, stderr_buffer);
            if (bytes_received != 0) {
                var iter = std.mem.splitScalar(u8, std.mem.trimRight(u8, stderr_buffer[0..bytes_received], "\n"), '\n');
                while (iter.next()) |line| {
                    try stdout.writeAll("child stderr> ");
                    try stdout.writeAll(line);
                    try stdout.writeAll("\n");
                }
            }
        }
        if (poll_fds[3].revents & err_mask != 0) {
            poll_fds[3].fd = -1;
        }

        try server_writer.msg_writer.flush();
        try client_writer.msg_writer.flush();
        try stdout.flush();
    }

    const term = try child_process.wait();
    std.debug.print("child process terminated: {}\n", .{term});
}

pub fn readAndForwardSocket(
    upstream: *UnixDomainSocketReader,
    downstream: *UnixDomainSocketWriter,
    stdout: *std.Io.Writer,
    protocols: *const shimizu.scanner.Database,
    gpa: std.mem.Allocator,
    objects: *std.AutoArrayHashMapUnmanaged(shimizu.wire.Object, shimizu.scanner.Database.Interface.Name),
    client_to_server: bool,
) !void {
    // Using `fill(0)` or `fill(1)` here instead of `fillMore()` causes the program to hang when exiting.
    try upstream.msg_reader.fillMore();

    while (try forwardMessage(
        upstream,
        downstream,
        stdout,
        protocols,
        gpa,
        objects,
        client_to_server,
    )) {}
}

pub fn forwardMessage(
    upstream: *UnixDomainSocketReader,
    downstream: *UnixDomainSocketWriter,
    stdout: *std.Io.Writer,
    protocols: *const shimizu.scanner.Database,
    gpa: std.mem.Allocator,
    objects: *std.AutoArrayHashMapUnmanaged(shimizu.wire.Object, shimizu.scanner.Database.Interface.Name),
    client_to_server: bool,
) !bool {
    if (upstream.msg_reader.bufferedLen() < @sizeOf(shimizu.wire.Header)) return false;
    const header = try upstream.msg_reader.peekStruct(shimizu.wire.Header, builtin.cpu.arch.endian());

    if (upstream.msg_reader.bufferedLen() < header.size_and_opcode.size) return false;
    const message_bytes = try upstream.msg_reader.take(header.size_and_opcode.size);

    if (objects.get(header.object)) |object_interface_id| {
        const object_interface = protocols.interfaces.get(object_interface_id) orelse @panic("corrupt interface id");
        const interface_message_list = if (client_to_server)
            object_interface.requests.slice(protocols)
        else
            object_interface.events.slice(protocols);
        if (header.size_and_opcode.opcode >= interface_message_list.len) {
            std.debug.panic("opcode {} out of range for interface {s}, client_to_server = {}", .{
                header.size_and_opcode.opcode,
                protocols.interface_names.getString(object_interface_id),
                client_to_server,
            });
        }
        const message_info = interface_message_list[header.opcode()];

        try stdout.print("{s} {s}@{}::{s}(", .{
            if (client_to_server)
                "request "
            else
                "event ",
            protocols.interface_names.getString(object_interface_id),
            @intFromEnum(header.object),
            protocols.message_names.getString(message_info.name),
        });

        var message_reader = std.Io.Reader.fixed(message_bytes[@sizeOf(shimizu.wire.Header)..]);
        for (message_info.args.slice(protocols), 0..) |arg, i| {
            if (i > 0) try stdout.writeAll(", ");
            switch (arg.kind) {
                .uint => try stdout.print("{d}", .{try message_reader.takeInt(u32, builtin.cpu.arch.endian())}),
                .int => try stdout.print("{d}", .{try message_reader.takeInt(i32, builtin.cpu.arch.endian())}),
                .fixed => {
                    const raw = try message_reader.takeInt(u32, builtin.cpu.arch.endian());
                    const fixed: shimizu.wire.Fixed = @bitCast(raw);
                    try stdout.print("0x{x}.{x:0>2}", .{ fixed.integer, fixed.fraction });
                },
                .string, .string_optional => {
                    const str_len = try message_reader.takeInt(u32, builtin.cpu.arch.endian());
                    const str = try message_reader.peek(str_len);
                    try stdout.print("\"{f}\"", .{std.zig.fmtString(str[0..str.len -| 1])});
                    const aligned_size = std.mem.alignForward(usize, str_len, @sizeOf(u32));
                    try message_reader.discardAll(aligned_size);
                },
                .array, .array_optional => {
                    const array_len = try message_reader.takeInt(u32, builtin.cpu.arch.endian());
                    const array = try message_reader.peek(array_len);
                    try stdout.print("{any}", .{array});
                    const aligned_size = std.mem.alignForward(usize, array_len, @sizeOf(u32));
                    try message_reader.discardAll(aligned_size);
                },
                .fd => {
                    const start = upstream.control_seek;
                    const fd = try shimizu.wire.readFd(upstream.control_buffer[0..upstream.control_end], &upstream.control_seek);
                    const end = upstream.control_seek;
                    @memcpy(downstream.control_buffer[downstream.control_end..][0 .. end - start], upstream.control_buffer[start..end]);
                    downstream.control_end += end - start;
                    try stdout.print("fd@{}", .{fd});
                },
                .new_id => |interface_id| {
                    const new_obj_id = try message_reader.takeEnumNonexhaustive(shimizu.wire.Object, builtin.cpu.arch.endian());

                    try objects.put(gpa, new_obj_id, interface_id);
                    try stdout.print("{s}@{d}", .{ protocols.interface_names.getString(interface_id), new_obj_id });
                },
                .new_id_generic => {
                    const interface_str_len = try message_reader.takeInt(u32, builtin.cpu.arch.endian());
                    const interface_str_nul = try message_reader.peek(interface_str_len);
                    const interface_str = interface_str_nul[0 .. interface_str_len - 1 :0];
                    const aligned_size = std.mem.alignForward(usize, interface_str_len, @sizeOf(u32));
                    try message_reader.discardAll(aligned_size);

                    const version = try message_reader.takeInt(u32, builtin.cpu.arch.endian());
                    const new_obj_id = try message_reader.takeEnumNonexhaustive(shimizu.wire.Object, builtin.cpu.arch.endian());

                    const interface_id = protocols.interface_names.find(interface_str) orelse {
                        std.debug.panic("Unknown interface name \"{f}\"", .{std.zig.fmtString(interface_str)});
                    };

                    try objects.put(gpa, new_obj_id, interface_id);

                    try stdout.print("{s}:{}@{d}", .{ protocols.interface_names.getString(interface_id), version, new_obj_id });
                },
                .object, .object_optional => |interface_id| {
                    const obj_id = try message_reader.takeEnumNonexhaustive(shimizu.wire.Object, builtin.cpu.arch.endian());

                    const interface_name = protocols.interface_names.getString(interface_id);
                    if (@intFromEnum(obj_id) == 0) {
                        try stdout.print("{s}@null", .{interface_name});
                        continue;
                    }

                    blk: {
                        const stored_interface_id = objects.get(obj_id) orelse {
                            std.log.warn("unknown object {s}@{d}", .{ interface_name, obj_id });
                            break :blk;
                        };
                        const stored_interface_name = protocols.interface_names.getString(stored_interface_id);
                        if (stored_interface_id != interface_id) {
                            std.log.warn("mismatched interface for {s}@{d}, used for {s}", .{ interface_name, obj_id, stored_interface_name });
                        }
                    }

                    try stdout.print("{s}@{d}", .{ interface_name, obj_id });
                },
                .object_generic, .object_generic_optional => {
                    const obj_id = try message_reader.takeEnumNonexhaustive(shimizu.wire.Object, builtin.cpu.arch.endian());

                    const stored_interface_id = objects.get(obj_id) orelse {
                        try stdout.print("unknown@{d}", .{obj_id});
                        continue;
                    };
                    const stored_interface_name = protocols.interface_names.getString(stored_interface_id);

                    try stdout.print("{s}@{d}", .{ stored_interface_name, obj_id });
                },
                .@"enum" => |enum_key| {
                    const value = try message_reader.takeInt(u32, builtin.cpu.arch.endian());
                    if (protocols.enum_entries.get(.{
                        .interface = enum_key.interface,
                        .name = enum_key.name,
                        .value = value,
                    })) |enum_entry_info| {
                        const name = protocols.enum_entry_names.getString(enum_entry_info.name);
                        try stdout.writeByte('.');
                        try stdout.writeAll(name);
                    } else {
                        try stdout.print("{}", .{value});
                    }
                },
            }
        }
        try stdout.writeAll(")\n");
    } else {
        std.debug.panic("unknown object id = {}", .{@intFromEnum(header.object)});
    }

    try downstream.msg_writer.writeAll(message_bytes);
    return true;
}

const UnixDomainSocketReader = struct {
    socket: std.posix.socket_t,
    msg_reader: std.Io.Reader,
    control_buffer: []u8,
    control_seek: usize,
    control_end: usize,

    pub fn init(socket: std.posix.socket_t, msg_buffer: []u8, control_buffer: []u8) UnixDomainSocketReader {
        return UnixDomainSocketReader{
            .socket = socket,
            .msg_reader = .{
                .vtable = vtable,
                .buffer = msg_buffer,
                .seek = 0,
                .end = 0,
            },
            .control_buffer = control_buffer,
            .control_seek = 0,
            .control_end = 0,
        };
    }

    const vtable = &std.Io.Reader.VTable{
        .stream = stream,
    };

    fn stream(r: *std.Io.Reader, w: *std.Io.Writer, limit: std.Io.Limit) std.Io.Reader.StreamError!usize {
        const this: *UnixDomainSocketReader = @fieldParentPtr("msg_reader", r);

        {
            // rebase control message buffer
            const data = this.control_buffer[this.control_seek..this.control_end];
            @memmove(this.control_buffer[0..data.len], data);
            this.control_seek = 0;
            this.control_end = data.len;
        }
        const control_buffer = this.control_buffer[this.control_end..];
        std.debug.assert(control_buffer.len > 1);

        var msg_buffer = limit.slice(try w.writableSliceGreedy(1));
        var recv_iov = [_]std.posix.iovec{
            .{
                // only read into the unused portion of the buffer
                .base = msg_buffer[0..].ptr,
                .len = msg_buffer[0..].len,
            },
        };

        var recv_msghdr = std.os.linux.msghdr{
            .name = null,
            .namelen = 0,
            .iov = recv_iov[0..].ptr,
            .iovlen = recv_iov[0..].len,
            .control = control_buffer.ptr,
            .controllen = @intCast(control_buffer.len),
            .flags = 0,
        };

        const bytes_received = std.os.linux.recvmsg(this.socket, &recv_msghdr, 0);
        const control_bytes_read = recv_msghdr.controllen;

        const res = std.posix.errno(bytes_received);
        switch (res) {
            .SUCCESS => {},
            .AGAIN => return 0,
            .BADF => unreachable,
            .CONNREFUSED => unreachable,
            .FAULT => unreachable, // the receive buffer points outside the process address space
            .INTR => return 0, // we'll just wait for next time
            .INVAL => unreachable, // invalid argument passed
            .NOMEM => return error.ReadFailed, // could not allocate memory for recvmsg
            .NOTCONN => unreachable,
            .NOTSOCK => unreachable,
            .CONNRESET => return error.EndOfStream,
            .ISCONN => unreachable,
            .NFILE => unreachable,
            .NOENT => unreachable,
            .OPNOTSUPP => unreachable,
            .PERM => unreachable,
            .PIPE => unreachable, // only defined when writing to a socket
            .PROTONOSUPPORT => unreachable,
            .PROTOTYPE => unreachable,
            .SOCKTNOSUPPORT => unreachable,
            .SRCH => unreachable, // the pid/uid/gid in the SCM_CREDENTIALS control message did not match; should only happend when writing
            else => unreachable,
        }

        w.advance(bytes_received);
        this.control_end += control_bytes_read;
        return bytes_received;
    }
};

const UnixDomainSocketWriter = struct {
    socket: std.posix.socket_t,
    msg_writer: std.Io.Writer,
    control_buffer: []u8,
    control_end: usize,

    pub fn init(socket: std.posix.socket_t, msg_buffer: []u8, control_buffer: []u8) UnixDomainSocketWriter {
        return UnixDomainSocketWriter{
            .socket = socket,
            .msg_writer = .{
                .vtable = vtable,
                .buffer = msg_buffer,
                .end = 0,
            },
            .control_buffer = control_buffer,
            .control_end = 0,
        };
    }

    const vtable = &std.Io.Writer.VTable{
        .drain = drain,
    };

    fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const this: *UnixDomainSocketWriter = @fieldParentPtr("msg_writer", w);
        const buffered = w.buffered();
        _ = data;
        _ = splat;

        std.debug.assert(buffered.len > 0);

        const send_iov = [_]std.posix.iovec_const{
            .{
                .base = buffered.ptr,
                .len = @intCast(buffered.len),
            },
        };

        const send_msghdr = std.posix.msghdr_const{
            .name = null,
            .namelen = 0,
            .iov = &send_iov,
            .iovlen = send_iov.len,
            .control = this.control_buffer.ptr,
            .controllen = @intCast(this.control_end),
            .flags = 0,
        };

        const bytes_written = std.posix.sendmsg(this.socket, &send_msghdr, 0) catch {
            return error.WriteFailed;
        };
        std.debug.assert(w.consume(bytes_written) == 0);
        {
            // rebase control message buffer
            const remaining = this.control_buffer[send_msghdr.controllen..send_msghdr.controllen];
            @memmove(this.control_buffer[0..remaining.len], remaining);
            w.end = remaining.len;
        }

        return 0;
    }
};

pub fn readProtocolsRecursive(gpa: std.mem.Allocator, protocols: *shimizu.scanner.Database, path: []const u8) !void {
    var protocols_dir = try std.fs.cwd().openDir(path, .{
        .iterate = true,
    });
    defer protocols_dir.close();
    var walker = try protocols_dir.walk(gpa);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".xml")) continue;

        const xml_file = try entry.dir.openFile(entry.basename, .{});
        defer xml_file.close();

        var read_buffer: [4096]u8 = undefined;
        var file_reader = xml_file.reader(read_buffer[0..]);

        var streaming_reader: xml.Reader.Streaming = .init(gpa, &file_reader.interface, .{});
        defer streaming_reader.deinit();
        const reader = &streaming_reader.interface;

        _ = shimizu.scanner.parse.protocol(reader, gpa, protocols) catch |err| switch (err) {
            error.MalformedXml => {
                const loc = reader.errorLocation();
                std.log.err("{}:{}: {}", .{ loc.line, loc.column, reader.errorCode() });
                return error.MalformedXml;
            },
            error.DuplicateInterface => {
                std.log.warn("duplicate interface", .{});
                continue;
            },
            else => |other| return other,
        };
    }
}

const builtin = @import("builtin");
const std = @import("std");
const shimizu = @import("shimizu");
const xml = @import("xml");
