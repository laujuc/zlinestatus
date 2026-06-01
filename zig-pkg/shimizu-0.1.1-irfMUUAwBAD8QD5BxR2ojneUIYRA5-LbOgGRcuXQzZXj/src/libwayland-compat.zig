pub const wl_list = extern struct {
    prev: ?*wl_list,
    next: ?*wl_list,
};

pub const wl_proxy = wire.compat.wl_proxy;

pub const wl_display = core_compat.wl_display;
pub const wl_event_queue = opaque {};

pub const wl_dispatcher_func_t = *const fn (user_data: ?*const anyopaque, target: ?*anyopaque, opcode: u32, *const wl_message, [*]wl_argument) callconv(.c) void;
pub const wl_log_func_t = *const fn (fmt: [*:0]const u8, ...) callconv(.c) void;

pub const wl_message = wire.compat.wl_message;
pub const wl_interface = wire.compat.wl_interface;
pub const wl_array = wire.compat.wl_array;
pub const wl_argument = wire.compat.wl_argument;
pub const MarshalFlags = wire.compat.MarshalFlags;

pub const LibWaylandClient = struct {
    handle: std.DynLib,

    wl_event_queue_destroy: *const fn (*wl_event_queue) callconv(.c) void,
    wl_proxy_marshal_array_flags: *const fn (*wl_proxy, opcode: u32, interface: ?*const wl_interface, version: u32, flags: MarshalFlags, args: ?[*]wl_argument) callconv(.c) ?*wl_proxy,
    wl_proxy_create: *const fn (*wl_proxy, *const wl_interface) callconv(.c) ?*wl_proxy,
    wl_proxy_marshal_array_constructor: *const fn (*wl_proxy, opcode: u32, args: [*]wl_argument, *const wl_interface) callconv(.c) ?*wl_proxy,
    wl_proxy_marshal_array_constructor_versioned: *const fn (*wl_proxy, opcode: u32, args: [*]wl_argument, *const wl_interface, version: u32) callconv(.c) ?*wl_proxy,
    wl_proxy_destroy: *const fn (?*wl_proxy) callconv(.c) void,
    wl_proxy_add_listener: *const fn (*wl_proxy, [*]const ?*const fn () callconv(.c) void, ?*anyopaque) callconv(.c) c_int,
    wl_proxy_get_listener: *const fn (*wl_proxy) callconv(.c) ?*const anyopaque,
    wl_proxy_add_dispatcher: *const fn (*wl_proxy, dispatcher_func: wl_dispatcher_func_t, ?*const anyopaque) callconv(.c) c_int,
    wl_proxy_set_user_data: *const fn (*wl_proxy, ?*anyopaque) callconv(.c) void,
    wl_proxy_get_user_data: *const fn (*wl_proxy) callconv(.c) ?*anyopaque,
    wl_proxy_get_version: *const fn (*wl_proxy) callconv(.c) u32,
    wl_proxy_get_id: *const fn (*wl_proxy) callconv(.c) u32,
    wl_proxy_set_tag: *const fn (*wl_proxy, tag: ?*const [*:0]const u8) callconv(.c) u32,
    wl_proxy_get_tag: *const fn (*wl_proxy) callconv(.c) ?*const [*:0]const u8,
    wl_proxy_get_class: *const fn (*wl_proxy) callconv(.c) [*:0]const u8,
    wl_proxy_set_queue: *const fn (*wl_proxy, *wl_event_queue) callconv(.c) void,
    wl_display_connect: *const fn (name: ?[*:0]const u8) callconv(.c) ?*wl_display,
    wl_display_connect_to_fd: *const fn (fd: c_int) callconv(.c) ?*wl_display,
    wl_display_disconnect: *const fn (*wl_display) callconv(.c) void,
    wl_display_get_fd: *const fn (*wl_display) callconv(.c) c_int,
    wl_display_dispatch: *const fn (*wl_display) callconv(.c) c_int,
    wl_display_dispatch_queue: *const fn (*wl_display, queue: ?*wl_event_queue) callconv(.c) c_int,
    wl_display_dispatch_queue_pending: *const fn (*wl_display, queue: *wl_event_queue) callconv(.c) c_int,
    wl_display_dispatch_pending: *const fn (*wl_display) callconv(.c) c_int,
    wl_display_get_error: *const fn (*wl_display) callconv(.c) c_int,
    wl_display_get_protocol_error: *const fn (*wl_display, **const wl_interface, id: *u32) callconv(.c) u32,
    wl_display_flush: *const fn (*wl_display) callconv(.c) c_int,
    wl_display_roundtrip_queue: *const fn (*wl_display, *wl_event_queue) callconv(.c) c_int,
    wl_display_roundtrip: *const fn (*wl_display) callconv(.c) c_int,
    wl_display_create_queue: *const fn (*wl_display) callconv(.c) ?*wl_event_queue,
    wl_display_prepare_read_queue: *const fn (*wl_display, *wl_event_queue) callconv(.c) c_int,
    wl_display_prepare_read: *const fn (*wl_display) callconv(.c) c_int,
    wl_display_cancel_read: *const fn (*wl_display) callconv(.c) void,
    wl_display_read_events: *const fn (*wl_display) callconv(.c) c_int,
    wl_log_set_handler_client: *const fn (wl_log_func_t) callconv(.c) void,

    // wl_proxy_create_wrapper: *const fn (?*anyopaque) callconv(.c) ?*anyopaque,
    // wl_proxy_wrapper_destroy: *const fn (?*anyopaque) callconv(.c) void,
    // wl_proxy_marshal_array: *const fn (*wl_proxy, opcode: u32, args: [*]wl_argument) callconv(.c) void,
    // wl_proxy_marshal_constructor: *const fn (*wl_proxy, opcode: u32, *const wl_interface, ...) callconv(.c) void,
    // wl_proxy_marshal_constructor_versioned: *const fn (*wl_proxy, *const wl_interface, version: u32, ...) callconv(.c) ?*wl_proxy,
    // wl_proxy_marshal: *const fn (*wl_proxy, opcode: u32, ...) callconv(.c) void,
    // wl_proxy_marshal_flags: *const fn (*wl_proxy, opcode: u32, interface: ?*const wl_interface, version: u32, flags: u32, ...) callconv(.c) ?*wl_proxy,
    // wl_proxy_get_display: *const fn (*wl_proxy) callconv(.c) *wl_display,
    // wl_proxy_get_queue: *const fn (*wl_proxy) callconv(.c) *wl_event_queue,
    // wl_event_queue_get_name: *const fn (*wl_event_queue) callconv(.c) ?[*:0]const u8,
    // wl_display_create_queue_with_name: *const fn (*wl_display, name: [*:0]const u8) callconv(.c) ?*wl_event_queue,
    // wl_display_set_max_buffer_size: *const fn (*wl_display, max_buffer_size: usize) callconv(.c) void,

    pub fn load() !LibWaylandClient {
        var lib: LibWaylandClient = undefined;
        lib.handle = std.DynLib.open("libwayland-client.so.0") catch return error.LibraryNotFound;
        var failed = false;
        inline for (@typeInfo(LibWaylandClient).@"struct".fields[1..]) |field| {
            @field(lib, field.name) = lib.handle.lookup(field.type, field.name) orelse blk: {
                std.log.err("Symbol lookup failed for {s}", .{field.name});
                failed = true;
                break :blk undefined;
            };
        }
        if (failed) return error.SymbolLookup;
        return lib;
    }

    var global: ?*LibWaylandClient = null;
    const global_fn_forwards = struct {
        export fn wl_proxy_add_listener(proxy: *wl_proxy, listener: [*]const ?*const fn () callconv(.c) void, data: ?*anyopaque) c_int {
            return @call(.always_tail, LibWaylandClient.global.?.wl_proxy_add_listener, .{ proxy, listener, data });
        }

        export fn wl_proxy_get_version(proxy: *wl_proxy) u32 {
            return @call(.always_tail, LibWaylandClient.global.?.wl_proxy_get_version, .{proxy});
        }

        export fn wl_proxy_marshal_array_flags(proxy: *wl_proxy, opcode: u32, interface: ?*const wl_interface, version: u32, flags: MarshalFlags, args: ?[*]wl_argument) ?*wl_proxy {
            return @call(.always_tail, LibWaylandClient.global.?.wl_proxy_marshal_array_flags, .{ proxy, opcode, interface, version, flags, args });
        }

        export fn wl_proxy_destroy(proxy: ?*wl_proxy) void {
            return @call(.always_tail, LibWaylandClient.global.?.wl_proxy_destroy, .{proxy});
        }
    };

    pub fn makeCurrent(lib: ?*LibWaylandClient) void {
        _ = global_fn_forwards.wl_proxy_add_listener;
        _ = global_fn_forwards.wl_proxy_get_version;
        _ = global_fn_forwards.wl_proxy_marshal_array_flags;
        _ = global_fn_forwards.wl_proxy_destroy;
        global = lib;
    }
};

const core_compat = @import("core-compat");
const std = @import("std");
const shimizu = @import("./shimizu.zig");
const wire = @import("wire");
