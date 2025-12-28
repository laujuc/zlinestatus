const std = @import("std");

pub const CallbackAction = enum { disarm, rearm };
pub const RunMode = enum { no_wait, once, until_done };
pub const CompletionState = enum { dead, active };

pub const Completion = struct {
    pub const Recv = struct { fd: std.posix.socket_t, msghdr: *std.posix.msghdr };
    pub const Send = struct { fd: std.posix.socket_t, msghdr: *std.posix.msghdr_const };
    pub const Op = union(enum) { recvmsg: Recv, sendmsg: Send };

    op: Op = undefined,
    userdata: ?*anyopaque = null,
    callback: ?*const fn (?*anyopaque, *Loop, *Completion, Result) CallbackAction = null,
    state_val: CompletionState = .dead,

    pub fn state(self: *Completion) CompletionState {
        return self.state_val;
    }
};

pub const Result = struct {
    recvmsg: anyerror!usize = 0,
    sendmsg: anyerror!usize = 0,
};

pub const Loop = struct {
    pub fn init(_: anytype) !Loop {
        return .{};
    }
    pub fn deinit(_: *Loop) void {}

    pub fn add(self: *Loop, completion: *Completion) void {
        completion.state_val = .active;
        if (completion.callback) |cb| {
            const res = switch (completion.op) {
                .recvmsg => |op| Result{ .recvmsg = readMsg(op.fd, op.msghdr) },
                .sendmsg => |op| Result{ .sendmsg = writeMsg(op.fd, op.msghdr) },
            };
            _ = cb(completion.userdata, self, completion, res);
        }
        completion.state_val = .dead;
    }

    pub fn run(_: *Loop, _: RunMode) !void {
        return;
    }
};

pub const IO_Uring = struct {
    pub const Loop = @import("main.zig").Loop;
};

fn readMsg(fd: std.posix.socket_t, msg: *std.posix.msghdr) !usize {
    if (msg.iovlen == 0) return 0;
    const first = msg.iov[0];
    const buf = first.base[0..first.len];
    return std.posix.read(fd, buf);
}

fn writeMsg(fd: std.posix.socket_t, msg: *const std.posix.msghdr_const) !usize {
    if (msg.iovlen == 0) return 0;
    const first = msg.iov[0];
    const buf = first.base[0..first.len];
    return std.posix.write(fd, buf);
}
