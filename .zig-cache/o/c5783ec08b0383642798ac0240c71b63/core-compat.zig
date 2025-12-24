const std = @import("std");
const wire = @import("wire");

const wl_proxy = wire.compat.wl_proxy;
const wl_interface = wire.compat.wl_interface;
const wl_message = wire.compat.wl_message;
const wl_object = wire.compat.wl_object;
const wl_argument = wire.compat.wl_argument;
const MarshalFlags = wire.compat.MarshalFlags;

extern fn wl_proxy_add_listener(proxy: *wl_proxy, listener: [*]const ?*const fn () callconv(.c) void, data: ?*anyopaque) c_int;
extern fn wl_proxy_get_version(proxy: *wl_proxy) u32;
extern fn wl_proxy_marshal_array_flags(proxy: *wl_proxy, opcode: u32, interface: ?*const wl_interface, version: u32, flags: MarshalFlags, args: ?[*]wl_argument) ?*wl_proxy;
extern fn wl_proxy_destroy(proxy: ?*wl_proxy) void;

/// core global object
///
/// 
/// The core global object.  This is a special singleton object.  It
/// is used for internal Wayland protocol features.
/// 
/// 
pub const wl_display = opaque {
    pub const NAME = "wl_display";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wl_display_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_display",
        .version = 1,
        .requests = &wl_display.REQUESTS,
        .request_count = wl_display.REQUESTS.len,
        .events = &wl_display.EVENTS,
        .event_count = wl_display.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "sync",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_callback_interface" }),
            },
        },
        wl_message{
            .name = "get_registry",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_registry_interface" }),
            },
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "error",
            .signature = "ous",
            .types = &.{
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "delete_id",
            .signature = "u",
            .types = &.{
                null,
            },
        },
    };

        pub const Error = enum(wire.Uint) {
            invalid_object = 0,
            invalid_method = 1,
            no_memory = 2,
            implementation = 3,
        };

    pub const EventListener = extern struct {
        @"error": *const fn(?*anyopaque, *wl_display, object_id: *wl_object, code: u32, message: [*:0]const u8) callconv(.c) void,
        delete_id: *const fn(?*anyopaque, *wl_display, id: u32) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn sync(this: *@This()) error{Failure}!*wl_callback {
        var args: [1]wl_argument = .{            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 0, wl_callback.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn get_registry(this: *@This()) error{Failure}!*wl_registry {
        var args: [1]wl_argument = .{            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 1, wl_registry.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

};

comptime { _ = wl_display.INTERFACE; }
/// global registry object
///
/// 
/// The singleton global registry object.  The server has a number of
/// global objects that are available to all clients.  These objects
/// typically represent an actual object in the server (for example,
/// an input device) or they are singleton objects that provide
/// extension functionality.
/// 
/// When a client creates a registry object, the registry object
/// will emit a global event for each global currently in the
/// registry.  Globals come and go as a result of device or
/// monitor hotplugs, reconfiguration or other events, and the
/// registry will send out global and global_remove events to
/// keep the client up to date with the changes.  To mark the end
/// of the initial burst of events, the client can use the
/// wl_display.sync request immediately after calling
/// wl_display.get_registry.
/// 
/// A client can bind to a global object by using the bind
/// request.  This creates a client-side handle that lets the object
/// emit events to the client and lets the client invoke requests on
/// the object.
/// 
/// 
pub const wl_registry = opaque {
    pub const NAME = "wl_registry";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wl_registry_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_registry",
        .version = 1,
        .requests = &wl_registry.REQUESTS,
        .request_count = wl_registry.REQUESTS.len,
        .events = &wl_registry.EVENTS,
        .event_count = wl_registry.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "bind",
            .signature = "usun",
            .types = &.{
                null,
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "global",
            .signature = "usu",
            .types = &.{
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "global_remove",
            .signature = "u",
            .types = &.{
                null,
            },
        },
    };

    pub const EventListener = extern struct {
        global: *const fn(?*anyopaque, *wl_registry, name: u32, interface: [*:0]const u8, version: u32) callconv(.c) void,
        global_remove: *const fn(?*anyopaque, *wl_registry, name: u32) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn bind(this: *@This(), name: u32, interface: *const wl_interface, version: u32) error{Failure}!*wl_proxy {
        var args: [3]wl_argument = .{            .{ .uint = name },
            .{ .string = interface.name },
            .{ .uint = version },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 0, interface, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

};

comptime { _ = wl_registry.INTERFACE; }
/// callback object
///
/// 
/// Clients can handle the 'done' event to get notified when
/// the related request is done.
/// 
/// Note, because wl_callback objects are created from multiple independent
/// factory interfaces, the wl_callback interface is frozen at version 1.
/// 
/// 
pub const wl_callback = opaque {
    pub const NAME = "wl_callback";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wl_callback_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_callback",
        .version = 1,
        .requests = &wl_callback.REQUESTS,
        .request_count = wl_callback.REQUESTS.len,
        .events = &wl_callback.EVENTS,
        .event_count = wl_callback.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "done",
            .signature = "u",
            .types = &.{
                null,
            },
        },
    };

    pub const EventListener = extern struct {
        done: *const fn(?*anyopaque, *wl_callback, callback_data: u32) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

};

comptime { _ = wl_callback.INTERFACE; }
/// the compositor singleton
///
/// 
/// A compositor.  This object is a singleton global.  The
/// compositor is in charge of combining the contents of multiple
/// surfaces into one displayable output.
/// 
/// 
pub const wl_compositor = opaque {
    pub const NAME = "wl_compositor";
    pub const VERSION = 4;

    comptime {
        @export(INTERFACE, .{ .name = "wl_compositor_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_compositor",
        .version = 6,
        .requests = &wl_compositor.REQUESTS,
        .request_count = wl_compositor.REQUESTS.len,
        .events = &wl_compositor.EVENTS,
        .event_count = wl_compositor.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "create_surface",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
            },
        },
        wl_message{
            .name = "create_region",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_region_interface" }),
            },
        },
    };

    pub const EVENTS = [_]wl_message{
    };

    pub const EventListener = extern struct {
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn create_surface(this: *@This()) error{Failure}!*wl_surface {
        var args: [1]wl_argument = .{            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 0, wl_surface.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn create_region(this: *@This()) error{Failure}!*wl_region {
        var args: [1]wl_argument = .{            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 1, wl_region.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

};

comptime { _ = wl_compositor.INTERFACE; }
/// a shared memory pool
///
/// 
/// The wl_shm_pool object encapsulates a piece of memory shared
/// between the compositor and client.  Through the wl_shm_pool
/// object, the client can allocate shared memory wl_buffer objects.
/// All objects created through the same pool share the same
/// underlying mapped memory. Reusing the mapped memory avoids the
/// setup/teardown overhead and is useful when interactively resizing
/// a surface or for many small buffers.
/// 
/// 
pub const wl_shm_pool = opaque {
    pub const NAME = "wl_shm_pool";
    pub const VERSION = 2;

    comptime {
        @export(INTERFACE, .{ .name = "wl_shm_pool_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_shm_pool",
        .version = 2,
        .requests = &wl_shm_pool.REQUESTS,
        .request_count = wl_shm_pool.REQUESTS.len,
        .events = &wl_shm_pool.EVENTS,
        .event_count = wl_shm_pool.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "create_buffer",
            .signature = "niiiiu",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_buffer_interface" }),
                null,
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "resize",
            .signature = "i",
            .types = &.{
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
    };

    pub const EventListener = extern struct {
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn create_buffer(this: *@This(), offset: i32, width: i32, height: i32, stride: i32, format: wl_shm.Format) error{Failure}!*wl_buffer {
        var args: [6]wl_argument = .{            .{ .object = null },
            .{ .int = offset },
            .{ .int = width },
            .{ .int = height },
            .{ .int = stride },
            .{ .uint = @intFromEnum(format) },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 0, wl_buffer.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn resize(this: *@This(), size: i32)void {
        var args: [1]wl_argument = .{            .{ .int = size },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = wl_shm_pool.INTERFACE; }
/// shared memory support
///
/// 
/// A singleton global object that provides support for shared
/// memory.
/// 
/// Clients can create wl_shm_pool objects using the create_pool
/// request.
/// 
/// On binding the wl_shm object one or more format events
/// are emitted to inform clients about the valid pixel formats
/// that can be used for buffers.
/// 
/// 
pub const wl_shm = opaque {
    pub const NAME = "wl_shm";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wl_shm_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_shm",
        .version = 2,
        .requests = &wl_shm.REQUESTS,
        .request_count = wl_shm.REQUESTS.len,
        .events = &wl_shm.EVENTS,
        .event_count = wl_shm.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "create_pool",
            .signature = "nhi",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_shm_pool_interface" }),
                null,
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "format",
            .signature = "u",
            .types = &.{
                null,
            },
        },
    };

        pub const Error = enum(wire.Uint) {
            invalid_format = 0,
            invalid_stride = 1,
            invalid_fd = 2,
        };

        pub const Format = enum(wire.Uint) {
            argb8888 = 0,
            xrgb8888 = 1,
            c8 = 0x20203843,
            rgb332 = 0x38424752,
            bgr233 = 0x38524742,
            xrgb4444 = 0x32315258,
            xbgr4444 = 0x32314258,
            rgbx4444 = 0x32315852,
            bgrx4444 = 0x32315842,
            argb4444 = 0x32315241,
            abgr4444 = 0x32314241,
            rgba4444 = 0x32314152,
            bgra4444 = 0x32314142,
            xrgb1555 = 0x35315258,
            xbgr1555 = 0x35314258,
            rgbx5551 = 0x35315852,
            bgrx5551 = 0x35315842,
            argb1555 = 0x35315241,
            abgr1555 = 0x35314241,
            rgba5551 = 0x35314152,
            bgra5551 = 0x35314142,
            rgb565 = 0x36314752,
            bgr565 = 0x36314742,
            rgb888 = 0x34324752,
            bgr888 = 0x34324742,
            xbgr8888 = 0x34324258,
            rgbx8888 = 0x34325852,
            bgrx8888 = 0x34325842,
            abgr8888 = 0x34324241,
            rgba8888 = 0x34324152,
            bgra8888 = 0x34324142,
            xrgb2101010 = 0x30335258,
            xbgr2101010 = 0x30334258,
            rgbx1010102 = 0x30335852,
            bgrx1010102 = 0x30335842,
            argb2101010 = 0x30335241,
            abgr2101010 = 0x30334241,
            rgba1010102 = 0x30334152,
            bgra1010102 = 0x30334142,
            yuyv = 0x56595559,
            yvyu = 0x55595659,
            uyvy = 0x59565955,
            vyuy = 0x59555956,
            ayuv = 0x56555941,
            nv12 = 0x3231564e,
            nv21 = 0x3132564e,
            nv16 = 0x3631564e,
            nv61 = 0x3136564e,
            yuv410 = 0x39565559,
            yvu410 = 0x39555659,
            yuv411 = 0x31315559,
            yvu411 = 0x31315659,
            yuv420 = 0x32315559,
            yvu420 = 0x32315659,
            yuv422 = 0x36315559,
            yvu422 = 0x36315659,
            yuv444 = 0x34325559,
            yvu444 = 0x34325659,
            r8 = 0x20203852,
            r16 = 0x20363152,
            rg88 = 0x38384752,
            gr88 = 0x38385247,
            rg1616 = 0x32334752,
            gr1616 = 0x32335247,
            xrgb16161616f = 0x48345258,
            xbgr16161616f = 0x48344258,
            argb16161616f = 0x48345241,
            abgr16161616f = 0x48344241,
            xyuv8888 = 0x56555958,
            vuy888 = 0x34325556,
            vuy101010 = 0x30335556,
            y210 = 0x30313259,
            y212 = 0x32313259,
            y216 = 0x36313259,
            y410 = 0x30313459,
            y412 = 0x32313459,
            y416 = 0x36313459,
            xvyu2101010 = 0x30335658,
            xvyu12_16161616 = 0x36335658,
            xvyu16161616 = 0x38345658,
            y0l0 = 0x304c3059,
            x0l0 = 0x304c3058,
            y0l2 = 0x324c3059,
            x0l2 = 0x324c3058,
            yuv420_8bit = 0x38305559,
            yuv420_10bit = 0x30315559,
            xrgb8888_a8 = 0x38415258,
            xbgr8888_a8 = 0x38414258,
            rgbx8888_a8 = 0x38415852,
            bgrx8888_a8 = 0x38415842,
            rgb888_a8 = 0x38413852,
            bgr888_a8 = 0x38413842,
            rgb565_a8 = 0x38413552,
            bgr565_a8 = 0x38413542,
            nv24 = 0x3432564e,
            nv42 = 0x3234564e,
            p210 = 0x30313250,
            p010 = 0x30313050,
            p012 = 0x32313050,
            p016 = 0x36313050,
            axbxgxrx106106106106 = 0x30314241,
            nv15 = 0x3531564e,
            q410 = 0x30313451,
            q401 = 0x31303451,
            xrgb16161616 = 0x38345258,
            xbgr16161616 = 0x38344258,
            argb16161616 = 0x38345241,
            abgr16161616 = 0x38344241,
            c1 = 0x20203143,
            c2 = 0x20203243,
            c4 = 0x20203443,
            d1 = 0x20203144,
            d2 = 0x20203244,
            d4 = 0x20203444,
            d8 = 0x20203844,
            r1 = 0x20203152,
            r2 = 0x20203252,
            r4 = 0x20203452,
            r10 = 0x20303152,
            r12 = 0x20323152,
            avuy8888 = 0x59555641,
            xvuy8888 = 0x59555658,
            p030 = 0x30333050,
        };

    pub const EventListener = extern struct {
        format: *const fn(?*anyopaque, *wl_shm, format: wl_shm.Format) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn create_pool(this: *@This(), fd: wire.Fd, size: i32) error{Failure}!*wl_shm_pool {
        var args: [3]wl_argument = .{            .{ .object = null },
            .{ .fd = @intFromEnum(fd) },
            .{ .int = size },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 0, wl_shm_pool.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

};

comptime { _ = wl_shm.INTERFACE; }
/// content for a wl_surface
///
/// 
/// A buffer provides the content for a wl_surface. Buffers are
/// created through factory interfaces such as wl_shm, wp_linux_buffer_params
/// (from the linux-dmabuf protocol extension) or similar. It has a width and
/// a height and can be attached to a wl_surface, but the mechanism by which a
/// client provides and updates the contents is defined by the buffer factory
/// interface.
/// 
/// Color channels are assumed to be electrical rather than optical (in other
/// words, encoded with a transfer function) unless otherwise specified. If
/// the buffer uses a format that has an alpha channel, the alpha channel is
/// assumed to be premultiplied into the electrical color channel values
/// (after transfer function encoding) unless otherwise specified.
/// 
/// Note, because wl_buffer objects are created from multiple independent
/// factory interfaces, the wl_buffer interface is frozen at version 1.
/// 
/// 
pub const wl_buffer = opaque {
    pub const NAME = "wl_buffer";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wl_buffer_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_buffer",
        .version = 1,
        .requests = &wl_buffer.REQUESTS,
        .request_count = wl_buffer.REQUESTS.len,
        .events = &wl_buffer.EVENTS,
        .event_count = wl_buffer.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "release",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EventListener = extern struct {
        release: *const fn(?*anyopaque, *wl_buffer) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = wl_buffer.INTERFACE; }
/// offer to transfer data
///
/// 
/// A wl_data_offer represents a piece of data offered for transfer
/// by another client (the source client).  It is used by the
/// copy-and-paste and drag-and-drop mechanisms.  The offer
/// describes the different mime types that the data can be
/// converted to and provides the mechanism for transferring the
/// data directly from the source client.
/// 
/// 
pub const wl_data_offer = opaque {
    pub const NAME = "wl_data_offer";
    pub const VERSION = 3;

    comptime {
        @export(INTERFACE, .{ .name = "wl_data_offer_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_data_offer",
        .version = 3,
        .requests = &wl_data_offer.REQUESTS,
        .request_count = wl_data_offer.REQUESTS.len,
        .events = &wl_data_offer.EVENTS,
        .event_count = wl_data_offer.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "accept",
            .signature = "u?s",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "receive",
            .signature = "sh",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "finish",
            .signature = "3",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "set_actions",
            .signature = "3uu",
            .types = &.{
                null,
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "offer",
            .signature = "s",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "source_actions",
            .signature = "3u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "action",
            .signature = "3u",
            .types = &.{
                null,
            },
        },
    };

        pub const Error = enum(wire.Uint) {
            invalid_finish = 0,
            invalid_action_mask = 1,
            invalid_action = 2,
            invalid_offer = 3,
        };

    pub const EventListener = extern struct {
        offer: *const fn(?*anyopaque, *wl_data_offer, mime_type: [*:0]const u8) callconv(.c) void,
        source_actions: *const fn(?*anyopaque, *wl_data_offer, source_actions: wl_data_device_manager.DndAction) callconv(.c) void,
        action: *const fn(?*anyopaque, *wl_data_offer, dnd_action: wl_data_device_manager.DndAction) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn accept(this: *@This(), serial: u32, mime_type: ?[*:0]const u8)void {
        var args: [2]wl_argument = .{            .{ .uint = serial },
            .{ .string = mime_type },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn receive(this: *@This(), mime_type: [*:0]const u8, fd: wire.Fd)void {
        var args: [2]wl_argument = .{            .{ .string = mime_type },
            .{ .fd = @intFromEnum(fd) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn finish(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 3, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_actions(this: *@This(), dnd_actions: wl_data_device_manager.DndAction, preferred_action: wl_data_device_manager.DndAction)void {
        var args: [2]wl_argument = .{            .{ .uint = @intFromEnum(dnd_actions) },
            .{ .uint = @intFromEnum(preferred_action) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 4, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = wl_data_offer.INTERFACE; }
/// offer to transfer data
///
/// 
/// The wl_data_source object is the source side of a wl_data_offer.
/// It is created by the source client in a data transfer and
/// provides a way to describe the offered data and a way to respond
/// to requests to transfer the data.
/// 
/// 
pub const wl_data_source = opaque {
    pub const NAME = "wl_data_source";
    pub const VERSION = 3;

    comptime {
        @export(INTERFACE, .{ .name = "wl_data_source_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_data_source",
        .version = 3,
        .requests = &wl_data_source.REQUESTS,
        .request_count = wl_data_source.REQUESTS.len,
        .events = &wl_data_source.EVENTS,
        .event_count = wl_data_source.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "offer",
            .signature = "s",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "set_actions",
            .signature = "3u",
            .types = &.{
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "target",
            .signature = "?s",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "send",
            .signature = "sh",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "cancelled",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "dnd_drop_performed",
            .signature = "3",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "dnd_finished",
            .signature = "3",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "action",
            .signature = "3u",
            .types = &.{
                null,
            },
        },
    };

        pub const Error = enum(wire.Uint) {
            invalid_action_mask = 0,
            invalid_source = 1,
        };

    pub const EventListener = extern struct {
        target: *const fn(?*anyopaque, *wl_data_source, mime_type: ?[*:0]const u8) callconv(.c) void,
        send: *const fn(?*anyopaque, *wl_data_source, mime_type: [*:0]const u8, fd: wire.Fd) callconv(.c) void,
        cancelled: *const fn(?*anyopaque, *wl_data_source) callconv(.c) void,
        dnd_drop_performed: *const fn(?*anyopaque, *wl_data_source) callconv(.c) void,
        dnd_finished: *const fn(?*anyopaque, *wl_data_source) callconv(.c) void,
        action: *const fn(?*anyopaque, *wl_data_source, dnd_action: wl_data_device_manager.DndAction) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn offer(this: *@This(), mime_type: [*:0]const u8)void {
        var args: [1]wl_argument = .{            .{ .string = mime_type },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn set_actions(this: *@This(), dnd_actions: wl_data_device_manager.DndAction)void {
        var args: [1]wl_argument = .{            .{ .uint = @intFromEnum(dnd_actions) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = wl_data_source.INTERFACE; }
/// data transfer device
///
/// 
/// There is one wl_data_device per seat which can be obtained
/// from the global wl_data_device_manager singleton.
/// 
/// A wl_data_device provides access to inter-client data transfer
/// mechanisms such as copy-and-paste and drag-and-drop.
/// 
/// 
pub const wl_data_device = opaque {
    pub const NAME = "wl_data_device";
    pub const VERSION = 3;

    comptime {
        @export(INTERFACE, .{ .name = "wl_data_device_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_data_device",
        .version = 3,
        .requests = &wl_data_device.REQUESTS,
        .request_count = wl_data_device.REQUESTS.len,
        .events = &wl_data_device.EVENTS,
        .event_count = wl_data_device.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "start_drag",
            .signature = "?oo?ou",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_data_source_interface" }),
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
                null,
            },
        },
        wl_message{
            .name = "set_selection",
            .signature = "?ou",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_data_source_interface" }),
                null,
            },
        },
        wl_message{
            .name = "release",
            .signature = "2",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "data_offer",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_data_offer_interface" }),
            },
        },
        wl_message{
            .name = "enter",
            .signature = "uoff?o",
            .types = &.{
                null,
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
                null,
                null,
                @extern(?*const wl_interface, .{ .name = "wl_data_offer_interface" }),
            },
        },
        wl_message{
            .name = "leave",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "motion",
            .signature = "uff",
            .types = &.{
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "drop",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "selection",
            .signature = "?o",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_data_offer_interface" }),
            },
        },
    };

        pub const Error = enum(wire.Uint) {
            role = 0,
            used_source = 1,
        };

    pub const EventListener = extern struct {
        data_offer: *const fn(?*anyopaque, *wl_data_device, *wl_data_offer) callconv(.c) void,
        enter: *const fn(?*anyopaque, *wl_data_device, serial: u32, surface: *wayland.wl_surface, x: wire.Fixed, y: wire.Fixed, id: ?*wayland.wl_data_offer) callconv(.c) void,
        leave: *const fn(?*anyopaque, *wl_data_device) callconv(.c) void,
        motion: *const fn(?*anyopaque, *wl_data_device, time: u32, x: wire.Fixed, y: wire.Fixed) callconv(.c) void,
        drop: *const fn(?*anyopaque, *wl_data_device) callconv(.c) void,
        selection: *const fn(?*anyopaque, *wl_data_device, id: ?*wayland.wl_data_offer) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn start_drag(this: *@This(), source: ?*wayland.wl_data_source, origin: *wayland.wl_surface, icon: ?*wayland.wl_surface, serial: u32)void {
        var args: [4]wl_argument = .{            .{ .object = @ptrCast(source) },
            .{ .object = @ptrCast(origin) },
            .{ .object = @ptrCast(icon) },
            .{ .uint = serial },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_selection(this: *@This(), source: ?*wayland.wl_data_source, serial: u32)void {
        var args: [2]wl_argument = .{            .{ .object = @ptrCast(source) },
            .{ .uint = serial },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn release(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = wl_data_device.INTERFACE; }
/// data transfer interface
///
/// 
/// The wl_data_device_manager is a singleton global object that
/// provides access to inter-client data transfer mechanisms such as
/// copy-and-paste and drag-and-drop.  These mechanisms are tied to
/// a wl_seat and this interface lets a client get a wl_data_device
/// corresponding to a wl_seat.
/// 
/// Depending on the version bound, the objects created from the bound
/// wl_data_device_manager object will have different requirements for
/// functioning properly. See wl_data_source.set_actions,
/// wl_data_offer.accept and wl_data_offer.finish for details.
/// 
/// 
pub const wl_data_device_manager = opaque {
    pub const NAME = "wl_data_device_manager";
    pub const VERSION = 3;

    comptime {
        @export(INTERFACE, .{ .name = "wl_data_device_manager_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_data_device_manager",
        .version = 3,
        .requests = &wl_data_device_manager.REQUESTS,
        .request_count = wl_data_device_manager.REQUESTS.len,
        .events = &wl_data_device_manager.EVENTS,
        .event_count = wl_data_device_manager.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "create_data_source",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_data_source_interface" }),
            },
        },
        wl_message{
            .name = "get_data_device",
            .signature = "no",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_data_device_interface" }),
                @extern(?*const wl_interface, .{ .name = "wl_seat_interface" }),
            },
        },
    };

    pub const EVENTS = [_]wl_message{
    };

        pub const DndAction = packed struct(wire.Uint) {
            copy: bool,
            move: bool,
            ask: bool,
            padding_1: u29 = 0,
            pub const none: @This() = @bitCast(@as(u32, 0b0));
        };

    pub const EventListener = extern struct {
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn create_data_source(this: *@This()) error{Failure}!*wl_data_source {
        var args: [1]wl_argument = .{            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 0, wl_data_source.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn get_data_device(this: *@This(), seat: *wayland.wl_seat) error{Failure}!*wl_data_device {
        var args: [2]wl_argument = .{            .{ .object = null },
            .{ .object = @ptrCast(seat) },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 1, wl_data_device.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

};

comptime { _ = wl_data_device_manager.INTERFACE; }
/// create desktop-style surfaces
///
/// 
/// This interface is implemented by servers that provide
/// desktop-style user interfaces.
/// 
/// It allows clients to associate a wl_shell_surface with
/// a basic surface.
/// 
/// Note! This protocol is deprecated and not intended for production use.
/// For desktop-style user interfaces, use xdg_shell. Compositors and clients
/// should not implement this interface.
/// 
/// 
pub const wl_shell = opaque {
    pub const NAME = "wl_shell";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wl_shell_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_shell",
        .version = 1,
        .requests = &wl_shell.REQUESTS,
        .request_count = wl_shell.REQUESTS.len,
        .events = &wl_shell.EVENTS,
        .event_count = wl_shell.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "get_shell_surface",
            .signature = "no",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_shell_surface_interface" }),
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
            },
        },
    };

    pub const EVENTS = [_]wl_message{
    };

        pub const Error = enum(wire.Uint) {
            role = 0,
        };

    pub const EventListener = extern struct {
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn get_shell_surface(this: *@This(), surface: *wayland.wl_surface) error{Failure}!*wl_shell_surface {
        var args: [2]wl_argument = .{            .{ .object = null },
            .{ .object = @ptrCast(surface) },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 0, wl_shell_surface.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

};

comptime { _ = wl_shell.INTERFACE; }
/// desktop-style metadata interface
///
/// 
/// An interface that may be implemented by a wl_surface, for
/// implementations that provide a desktop-style user interface.
/// 
/// It provides requests to treat surfaces like toplevel, fullscreen
/// or popup windows, move, resize or maximize them, associate
/// metadata like title and class, etc.
/// 
/// On the server side the object is automatically destroyed when
/// the related wl_surface is destroyed. On the client side,
/// wl_shell_surface_destroy() must be called before destroying
/// the wl_surface object.
/// 
/// 
pub const wl_shell_surface = opaque {
    pub const NAME = "wl_shell_surface";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wl_shell_surface_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_shell_surface",
        .version = 1,
        .requests = &wl_shell_surface.REQUESTS,
        .request_count = wl_shell_surface.REQUESTS.len,
        .events = &wl_shell_surface.EVENTS,
        .event_count = wl_shell_surface.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "pong",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "move",
            .signature = "ou",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_seat_interface" }),
                null,
            },
        },
        wl_message{
            .name = "resize",
            .signature = "ouu",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_seat_interface" }),
                null,
                null,
            },
        },
        wl_message{
            .name = "set_toplevel",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "set_transient",
            .signature = "oiiu",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "set_fullscreen",
            .signature = "uu?o",
            .types = &.{
                null,
                null,
                @extern(?*const wl_interface, .{ .name = "wl_output_interface" }),
            },
        },
        wl_message{
            .name = "set_popup",
            .signature = "ouoiiu",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_seat_interface" }),
                null,
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "set_maximized",
            .signature = "?o",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_output_interface" }),
            },
        },
        wl_message{
            .name = "set_title",
            .signature = "s",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "set_class",
            .signature = "s",
            .types = &.{
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "ping",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "configure",
            .signature = "uii",
            .types = &.{
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "popup_done",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
    };

        pub const Resize = packed struct(wire.Uint) {
            top: bool,
            bottom: bool,
            left: bool,
            right: bool,
            padding_1: u28 = 0,
            pub const none: @This() = @bitCast(@as(u32, 0b0));
            pub const top_left: @This() = @bitCast(@as(u32, 0b101));
            pub const bottom_left: @This() = @bitCast(@as(u32, 0b110));
            pub const top_right: @This() = @bitCast(@as(u32, 0b1001));
            pub const bottom_right: @This() = @bitCast(@as(u32, 0b1010));
        };

        pub const Transient = packed struct(wire.Uint) {
            inactive: bool,
            padding_1: u31 = 0,
        };

        pub const FullscreenMethod = enum(wire.Uint) {
            default = 0,
            scale = 1,
            driver = 2,
            fill = 3,
        };

    pub const EventListener = extern struct {
        ping: *const fn(?*anyopaque, *wl_shell_surface, serial: u32) callconv(.c) void,
        configure: *const fn(?*anyopaque, *wl_shell_surface, edges: wl_shell_surface.Resize, width: i32, height: i32) callconv(.c) void,
        popup_done: *const fn(?*anyopaque, *wl_shell_surface) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn pong(this: *@This(), serial: u32)void {
        var args: [1]wl_argument = .{            .{ .uint = serial },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn move(this: *@This(), seat: *wayland.wl_seat, serial: u32)void {
        var args: [2]wl_argument = .{            .{ .object = @ptrCast(seat) },
            .{ .uint = serial },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn resize(this: *@This(), seat: *wayland.wl_seat, serial: u32, edges: wl_shell_surface.Resize)void {
        var args: [3]wl_argument = .{            .{ .object = @ptrCast(seat) },
            .{ .uint = serial },
            .{ .uint = @intFromEnum(edges) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_toplevel(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 3, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_transient(this: *@This(), parent: *wayland.wl_surface, x: i32, y: i32, flags: wl_shell_surface.Transient)void {
        var args: [4]wl_argument = .{            .{ .object = @ptrCast(parent) },
            .{ .int = x },
            .{ .int = y },
            .{ .uint = @intFromEnum(flags) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 4, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_fullscreen(this: *@This(), method: wl_shell_surface.FullscreenMethod, framerate: u32, output: ?*wayland.wl_output)void {
        var args: [3]wl_argument = .{            .{ .uint = @intFromEnum(method) },
            .{ .uint = framerate },
            .{ .object = @ptrCast(output) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 5, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_popup(this: *@This(), seat: *wayland.wl_seat, serial: u32, parent: *wayland.wl_surface, x: i32, y: i32, flags: wl_shell_surface.Transient)void {
        var args: [6]wl_argument = .{            .{ .object = @ptrCast(seat) },
            .{ .uint = serial },
            .{ .object = @ptrCast(parent) },
            .{ .int = x },
            .{ .int = y },
            .{ .uint = @intFromEnum(flags) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 6, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_maximized(this: *@This(), output: ?*wayland.wl_output)void {
        var args: [1]wl_argument = .{            .{ .object = @ptrCast(output) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 7, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_title(this: *@This(), title: [*:0]const u8)void {
        var args: [1]wl_argument = .{            .{ .string = title },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 8, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_class(this: *@This(), class_: [*:0]const u8)void {
        var args: [1]wl_argument = .{            .{ .string = class_ },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 9, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = wl_shell_surface.INTERFACE; }
/// an onscreen surface
///
/// 
/// A surface is a rectangular area that may be displayed on zero
/// or more outputs, and shown any number of times at the compositor's
/// discretion. They can present wl_buffers, receive user input, and
/// define a local coordinate system.
/// 
/// The size of a surface (and relative positions on it) is described
/// in surface-local coordinates, which may differ from the buffer
/// coordinates of the pixel content, in case a buffer_transform
/// or a buffer_scale is used.
/// 
/// A surface without a "role" is fairly useless: a compositor does
/// not know where, when or how to present it. The role is the
/// purpose of a wl_surface. Examples of roles are a cursor for a
/// pointer (as set by wl_pointer.set_cursor), a drag icon
/// (wl_data_device.start_drag), a sub-surface
/// (wl_subcompositor.get_subsurface), and a window as defined by a
/// shell protocol (e.g. wl_shell.get_shell_surface).
/// 
/// A surface can have only one role at a time. Initially a
/// wl_surface does not have a role. Once a wl_surface is given a
/// role, it is set permanently for the whole lifetime of the
/// wl_surface object. Giving the current role again is allowed,
/// unless explicitly forbidden by the relevant interface
/// specification.
/// 
/// Surface roles are given by requests in other interfaces such as
/// wl_pointer.set_cursor. The request should explicitly mention
/// that this request gives a role to a wl_surface. Often, this
/// request also creates a new protocol object that represents the
/// role and adds additional functionality to wl_surface. When a
/// client wants to destroy a wl_surface, they must destroy this role
/// object before the wl_surface, otherwise a defunct_role_object error is
/// sent.
/// 
/// Destroying the role object does not remove the role from the
/// wl_surface, but it may stop the wl_surface from "playing the role".
/// For instance, if a wl_subsurface object is destroyed, the wl_surface
/// it was created for will be unmapped and forget its position and
/// z-order. It is allowed to create a wl_subsurface for the same
/// wl_surface again, but it is not allowed to use the wl_surface as
/// a cursor (cursor is a different role than sub-surface, and role
/// switching is not allowed).
/// 
/// 
pub const wl_surface = opaque {
    pub const NAME = "wl_surface";
    pub const VERSION = 6;

    comptime {
        @export(INTERFACE, .{ .name = "wl_surface_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_surface",
        .version = 6,
        .requests = &wl_surface.REQUESTS,
        .request_count = wl_surface.REQUESTS.len,
        .events = &wl_surface.EVENTS,
        .event_count = wl_surface.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "attach",
            .signature = "?oii",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_buffer_interface" }),
                null,
                null,
            },
        },
        wl_message{
            .name = "damage",
            .signature = "iiii",
            .types = &.{
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "frame",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_callback_interface" }),
            },
        },
        wl_message{
            .name = "set_opaque_region",
            .signature = "?o",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_region_interface" }),
            },
        },
        wl_message{
            .name = "set_input_region",
            .signature = "?o",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_region_interface" }),
            },
        },
        wl_message{
            .name = "commit",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "set_buffer_transform",
            .signature = "2u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "set_buffer_scale",
            .signature = "3i",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "damage_buffer",
            .signature = "4iiii",
            .types = &.{
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "offset",
            .signature = "5ii",
            .types = &.{
                null,
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "enter",
            .signature = "o",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_output_interface" }),
            },
        },
        wl_message{
            .name = "leave",
            .signature = "o",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_output_interface" }),
            },
        },
        wl_message{
            .name = "preferred_buffer_scale",
            .signature = "6i",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "preferred_buffer_transform",
            .signature = "6u",
            .types = &.{
                null,
            },
        },
    };

        pub const Error = enum(wire.Uint) {
            invalid_scale = 0,
            invalid_transform = 1,
            invalid_size = 2,
            invalid_offset = 3,
            defunct_role_object = 4,
        };

    pub const EventListener = extern struct {
        enter: *const fn(?*anyopaque, *wl_surface, output: *wayland.wl_output) callconv(.c) void,
        leave: *const fn(?*anyopaque, *wl_surface, output: *wayland.wl_output) callconv(.c) void,
        preferred_buffer_scale: *const fn(?*anyopaque, *wl_surface, factor: i32) callconv(.c) void,
        preferred_buffer_transform: *const fn(?*anyopaque, *wl_surface, transform: wl_output.Transform) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn attach(this: *@This(), buffer: ?*wayland.wl_buffer, x: i32, y: i32)void {
        var args: [3]wl_argument = .{            .{ .object = @ptrCast(buffer) },
            .{ .int = x },
            .{ .int = y },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn damage(this: *@This(), x: i32, y: i32, width: i32, height: i32)void {
        var args: [4]wl_argument = .{            .{ .int = x },
            .{ .int = y },
            .{ .int = width },
            .{ .int = height },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn frame(this: *@This()) error{Failure}!*wl_callback {
        var args: [1]wl_argument = .{            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 3, wl_callback.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn set_opaque_region(this: *@This(), region: ?*wayland.wl_region)void {
        var args: [1]wl_argument = .{            .{ .object = @ptrCast(region) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 4, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_input_region(this: *@This(), region: ?*wayland.wl_region)void {
        var args: [1]wl_argument = .{            .{ .object = @ptrCast(region) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 5, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn commit(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 6, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_buffer_transform(this: *@This(), transform: wl_output.Transform)void {
        var args: [1]wl_argument = .{            .{ .uint = @intFromEnum(transform) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 7, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_buffer_scale(this: *@This(), scale: i32)void {
        var args: [1]wl_argument = .{            .{ .int = scale },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 8, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn damage_buffer(this: *@This(), x: i32, y: i32, width: i32, height: i32)void {
        var args: [4]wl_argument = .{            .{ .int = x },
            .{ .int = y },
            .{ .int = width },
            .{ .int = height },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 9, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn offset(this: *@This(), x: i32, y: i32)void {
        var args: [2]wl_argument = .{            .{ .int = x },
            .{ .int = y },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 10, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = wl_surface.INTERFACE; }
/// group of input devices
///
/// 
/// A seat is a group of keyboards, pointer and touch devices. This
/// object is published as a global during start up, or when such a
/// device is hot plugged.  A seat typically has a pointer and
/// maintains a keyboard focus and a pointer focus.
/// 
/// 
pub const wl_seat = opaque {
    pub const NAME = "wl_seat";
    pub const VERSION = 7;

    comptime {
        @export(INTERFACE, .{ .name = "wl_seat_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_seat",
        .version = 9,
        .requests = &wl_seat.REQUESTS,
        .request_count = wl_seat.REQUESTS.len,
        .events = &wl_seat.EVENTS,
        .event_count = wl_seat.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "get_pointer",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_pointer_interface" }),
            },
        },
        wl_message{
            .name = "get_keyboard",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_keyboard_interface" }),
            },
        },
        wl_message{
            .name = "get_touch",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_touch_interface" }),
            },
        },
        wl_message{
            .name = "release",
            .signature = "5",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "capabilities",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "name",
            .signature = "2s",
            .types = &.{
                null,
            },
        },
    };

        pub const Capability = packed struct(wire.Uint) {
            pointer: bool,
            keyboard: bool,
            touch: bool,
            padding_1: u29 = 0,
        };

        pub const Error = enum(wire.Uint) {
            missing_capability = 0,
        };

    pub const EventListener = extern struct {
        capabilities: *const fn(?*anyopaque, *wl_seat, capabilities: wl_seat.Capability) callconv(.c) void,
        name: *const fn(?*anyopaque, *wl_seat, name: [*:0]const u8) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn get_pointer(this: *@This()) error{Failure}!*wl_pointer {
        var args: [1]wl_argument = .{            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 0, wl_pointer.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn get_keyboard(this: *@This()) error{Failure}!*wl_keyboard {
        var args: [1]wl_argument = .{            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 1, wl_keyboard.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn get_touch(this: *@This()) error{Failure}!*wl_touch {
        var args: [1]wl_argument = .{            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 2, wl_touch.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn release(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 3, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = wl_seat.INTERFACE; }
/// pointer input device
///
/// 
/// The wl_pointer interface represents one or more input devices,
/// such as mice, which control the pointer location and pointer_focus
/// of a seat.
/// 
/// The wl_pointer interface generates motion, enter and leave
/// events for the surfaces that the pointer is located over,
/// and button and axis events for button presses, button releases
/// and scrolling.
/// 
/// 
pub const wl_pointer = opaque {
    pub const NAME = "wl_pointer";
    pub const VERSION = 9;

    comptime {
        @export(INTERFACE, .{ .name = "wl_pointer_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_pointer",
        .version = 9,
        .requests = &wl_pointer.REQUESTS,
        .request_count = wl_pointer.REQUESTS.len,
        .events = &wl_pointer.EVENTS,
        .event_count = wl_pointer.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "set_cursor",
            .signature = "u?oii",
            .types = &.{
                null,
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
                null,
                null,
            },
        },
        wl_message{
            .name = "release",
            .signature = "3",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "enter",
            .signature = "uoff",
            .types = &.{
                null,
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
                null,
                null,
            },
        },
        wl_message{
            .name = "leave",
            .signature = "uo",
            .types = &.{
                null,
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
            },
        },
        wl_message{
            .name = "motion",
            .signature = "uff",
            .types = &.{
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "button",
            .signature = "uuuu",
            .types = &.{
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "axis",
            .signature = "uuf",
            .types = &.{
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "frame",
            .signature = "5",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "axis_source",
            .signature = "5u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "axis_stop",
            .signature = "5uu",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "axis_discrete",
            .signature = "5ui",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "axis_value120",
            .signature = "8ui",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "axis_relative_direction",
            .signature = "9uu",
            .types = &.{
                null,
                null,
            },
        },
    };

        pub const Error = enum(wire.Uint) {
            role = 0,
        };

        pub const ButtonState = enum(wire.Uint) {
            released = 0,
            pressed = 1,
        };

        pub const Axis = enum(wire.Uint) {
            vertical_scroll = 0,
            horizontal_scroll = 1,
        };

        pub const AxisSource = enum(wire.Uint) {
            wheel = 0,
            finger = 1,
            continuous = 2,
            wheel_tilt = 3,
        };

        pub const AxisRelativeDirection = enum(wire.Uint) {
            identical = 0,
            inverted = 1,
        };

    pub const EventListener = extern struct {
        enter: *const fn(?*anyopaque, *wl_pointer, serial: u32, surface: *wayland.wl_surface, surface_x: wire.Fixed, surface_y: wire.Fixed) callconv(.c) void,
        leave: *const fn(?*anyopaque, *wl_pointer, serial: u32, surface: *wayland.wl_surface) callconv(.c) void,
        motion: *const fn(?*anyopaque, *wl_pointer, time: u32, surface_x: wire.Fixed, surface_y: wire.Fixed) callconv(.c) void,
        button: *const fn(?*anyopaque, *wl_pointer, serial: u32, time: u32, button: u32, state: wl_pointer.ButtonState) callconv(.c) void,
        axis: *const fn(?*anyopaque, *wl_pointer, time: u32, axis: wl_pointer.Axis, value: wire.Fixed) callconv(.c) void,
        frame: *const fn(?*anyopaque, *wl_pointer) callconv(.c) void,
        axis_source: *const fn(?*anyopaque, *wl_pointer, axis_source: wl_pointer.AxisSource) callconv(.c) void,
        axis_stop: *const fn(?*anyopaque, *wl_pointer, time: u32, axis: wl_pointer.Axis) callconv(.c) void,
        axis_discrete: *const fn(?*anyopaque, *wl_pointer, axis: wl_pointer.Axis, discrete: i32) callconv(.c) void,
        axis_value120: *const fn(?*anyopaque, *wl_pointer, axis: wl_pointer.Axis, value120: i32) callconv(.c) void,
        axis_relative_direction: *const fn(?*anyopaque, *wl_pointer, axis: wl_pointer.Axis, direction: wl_pointer.AxisRelativeDirection) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn set_cursor(this: *@This(), serial: u32, surface: ?*wayland.wl_surface, hotspot_x: i32, hotspot_y: i32)void {
        var args: [4]wl_argument = .{            .{ .uint = serial },
            .{ .object = @ptrCast(surface) },
            .{ .int = hotspot_x },
            .{ .int = hotspot_y },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn release(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = wl_pointer.INTERFACE; }
/// keyboard input device
///
/// 
/// The wl_keyboard interface represents one or more keyboards
/// associated with a seat.
/// 
/// Each wl_keyboard has the following logical state:
/// 
/// - an active surface (possibly null),
/// - the keys currently logically down,
/// - the active modifiers,
/// - the active group.
/// 
/// By default, the active surface is null, the keys currently logically down
/// are empty, the active modifiers and the active group are 0.
/// 
/// 
pub const wl_keyboard = opaque {
    pub const NAME = "wl_keyboard";
    pub const VERSION = 9;

    comptime {
        @export(INTERFACE, .{ .name = "wl_keyboard_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_keyboard",
        .version = 9,
        .requests = &wl_keyboard.REQUESTS,
        .request_count = wl_keyboard.REQUESTS.len,
        .events = &wl_keyboard.EVENTS,
        .event_count = wl_keyboard.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "release",
            .signature = "3",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "keymap",
            .signature = "uhu",
            .types = &.{
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "enter",
            .signature = "uoa",
            .types = &.{
                null,
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
                null,
            },
        },
        wl_message{
            .name = "leave",
            .signature = "uo",
            .types = &.{
                null,
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
            },
        },
        wl_message{
            .name = "key",
            .signature = "uuuu",
            .types = &.{
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "modifiers",
            .signature = "uuuuu",
            .types = &.{
                null,
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "repeat_info",
            .signature = "4ii",
            .types = &.{
                null,
                null,
            },
        },
    };

        pub const KeymapFormat = enum(wire.Uint) {
            no_keymap = 0,
            xkb_v1 = 1,
        };

        pub const KeyState = enum(wire.Uint) {
            released = 0,
            pressed = 1,
        };

    pub const EventListener = extern struct {
        keymap: *const fn(?*anyopaque, *wl_keyboard, format: wl_keyboard.KeymapFormat, fd: wire.Fd, size: u32) callconv(.c) void,
        enter: *const fn(?*anyopaque, *wl_keyboard, serial: u32, surface: *wayland.wl_surface, keys: wire.Array) callconv(.c) void,
        leave: *const fn(?*anyopaque, *wl_keyboard, serial: u32, surface: *wayland.wl_surface) callconv(.c) void,
        key: *const fn(?*anyopaque, *wl_keyboard, serial: u32, time: u32, key: u32, state: wl_keyboard.KeyState) callconv(.c) void,
        modifiers: *const fn(?*anyopaque, *wl_keyboard, serial: u32, mods_depressed: u32, mods_latched: u32, mods_locked: u32, group: u32) callconv(.c) void,
        repeat_info: *const fn(?*anyopaque, *wl_keyboard, rate: i32, delay: i32) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn release(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = wl_keyboard.INTERFACE; }
/// touchscreen input device
///
/// 
/// The wl_touch interface represents a touchscreen
/// associated with a seat.
/// 
/// Touch interactions can consist of one or more contacts.
/// For each contact, a series of events is generated, starting
/// with a down event, followed by zero or more motion events,
/// and ending with an up event. Events relating to the same
/// contact point can be identified by the ID of the sequence.
/// 
/// 
pub const wl_touch = opaque {
    pub const NAME = "wl_touch";
    pub const VERSION = 9;

    comptime {
        @export(INTERFACE, .{ .name = "wl_touch_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_touch",
        .version = 9,
        .requests = &wl_touch.REQUESTS,
        .request_count = wl_touch.REQUESTS.len,
        .events = &wl_touch.EVENTS,
        .event_count = wl_touch.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "release",
            .signature = "3",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "down",
            .signature = "uuoiff",
            .types = &.{
                null,
                null,
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "up",
            .signature = "uui",
            .types = &.{
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "motion",
            .signature = "uiff",
            .types = &.{
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "frame",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "cancel",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "shape",
            .signature = "6iff",
            .types = &.{
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "orientation",
            .signature = "6if",
            .types = &.{
                null,
                null,
            },
        },
    };

    pub const EventListener = extern struct {
        down: *const fn(?*anyopaque, *wl_touch, serial: u32, time: u32, surface: *wayland.wl_surface, id: i32, x: wire.Fixed, y: wire.Fixed) callconv(.c) void,
        up: *const fn(?*anyopaque, *wl_touch, serial: u32, time: u32, id: i32) callconv(.c) void,
        motion: *const fn(?*anyopaque, *wl_touch, time: u32, id: i32, x: wire.Fixed, y: wire.Fixed) callconv(.c) void,
        frame: *const fn(?*anyopaque, *wl_touch) callconv(.c) void,
        cancel: *const fn(?*anyopaque, *wl_touch) callconv(.c) void,
        shape: *const fn(?*anyopaque, *wl_touch, id: i32, major: wire.Fixed, minor: wire.Fixed) callconv(.c) void,
        orientation: *const fn(?*anyopaque, *wl_touch, id: i32, orientation: wire.Fixed) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn release(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = wl_touch.INTERFACE; }
/// compositor output region
///
/// 
/// An output describes part of the compositor geometry.  The
/// compositor works in the 'compositor coordinate system' and an
/// output corresponds to a rectangular area in that space that is
/// actually visible.  This typically corresponds to a monitor that
/// displays part of the compositor space.  This object is published
/// as global during start up, or when a monitor is hotplugged.
/// 
/// 
pub const wl_output = opaque {
    pub const NAME = "wl_output";
    pub const VERSION = 4;

    comptime {
        @export(INTERFACE, .{ .name = "wl_output_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_output",
        .version = 4,
        .requests = &wl_output.REQUESTS,
        .request_count = wl_output.REQUESTS.len,
        .events = &wl_output.EVENTS,
        .event_count = wl_output.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "release",
            .signature = "3",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "geometry",
            .signature = "iiiiussu",
            .types = &.{
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "mode",
            .signature = "uiii",
            .types = &.{
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "done",
            .signature = "2",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "scale",
            .signature = "2i",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "name",
            .signature = "4s",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "description",
            .signature = "4s",
            .types = &.{
                null,
            },
        },
    };

        pub const Subpixel = enum(wire.Uint) {
            unknown = 0,
            none = 1,
            horizontal_rgb = 2,
            horizontal_bgr = 3,
            vertical_rgb = 4,
            vertical_bgr = 5,
        };

        pub const Transform = enum(wire.Uint) {
            normal = 0,
            @"90" = 1,
            @"180" = 2,
            @"270" = 3,
            flipped = 4,
            flipped_90 = 5,
            flipped_180 = 6,
            flipped_270 = 7,
        };

        pub const Mode = packed struct(wire.Uint) {
            current: bool,
            preferred: bool,
            padding_1: u30 = 0,
        };

    pub const EventListener = extern struct {
        geometry: *const fn(?*anyopaque, *wl_output, x: i32, y: i32, physical_width: i32, physical_height: i32, subpixel: wl_output.Subpixel, make: [*:0]const u8, model: [*:0]const u8, transform: wl_output.Transform) callconv(.c) void,
        mode: *const fn(?*anyopaque, *wl_output, flags: wl_output.Mode, width: i32, height: i32, refresh: i32) callconv(.c) void,
        done: *const fn(?*anyopaque, *wl_output) callconv(.c) void,
        scale: *const fn(?*anyopaque, *wl_output, factor: i32) callconv(.c) void,
        name: *const fn(?*anyopaque, *wl_output, name: [*:0]const u8) callconv(.c) void,
        description: *const fn(?*anyopaque, *wl_output, description: [*:0]const u8) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn release(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = wl_output.INTERFACE; }
/// region interface
///
/// 
/// A region object describes an area.
/// 
/// Region objects are used to describe the opaque and input
/// regions of a surface.
/// 
/// 
pub const wl_region = opaque {
    pub const NAME = "wl_region";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wl_region_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_region",
        .version = 1,
        .requests = &wl_region.REQUESTS,
        .request_count = wl_region.REQUESTS.len,
        .events = &wl_region.EVENTS,
        .event_count = wl_region.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "add",
            .signature = "iiii",
            .types = &.{
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "subtract",
            .signature = "iiii",
            .types = &.{
                null,
                null,
                null,
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
    };

    pub const EventListener = extern struct {
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn add(this: *@This(), x: i32, y: i32, width: i32, height: i32)void {
        var args: [4]wl_argument = .{            .{ .int = x },
            .{ .int = y },
            .{ .int = width },
            .{ .int = height },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn subtract(this: *@This(), x: i32, y: i32, width: i32, height: i32)void {
        var args: [4]wl_argument = .{            .{ .int = x },
            .{ .int = y },
            .{ .int = width },
            .{ .int = height },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = wl_region.INTERFACE; }
/// sub-surface compositing
///
/// 
/// The global interface exposing sub-surface compositing capabilities.
/// A wl_surface, that has sub-surfaces associated, is called the
/// parent surface. Sub-surfaces can be arbitrarily nested and create
/// a tree of sub-surfaces.
/// 
/// The root surface in a tree of sub-surfaces is the main
/// surface. The main surface cannot be a sub-surface, because
/// sub-surfaces must always have a parent.
/// 
/// A main surface with its sub-surfaces forms a (compound) window.
/// For window management purposes, this set of wl_surface objects is
/// to be considered as a single window, and it should also behave as
/// such.
/// 
/// The aim of sub-surfaces is to offload some of the compositing work
/// within a window from clients to the compositor. A prime example is
/// a video player with decorations and video in separate wl_surface
/// objects. This should allow the compositor to pass YUV video buffer
/// processing to dedicated overlay hardware when possible.
/// 
/// 
pub const wl_subcompositor = opaque {
    pub const NAME = "wl_subcompositor";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wl_subcompositor_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_subcompositor",
        .version = 1,
        .requests = &wl_subcompositor.REQUESTS,
        .request_count = wl_subcompositor.REQUESTS.len,
        .events = &wl_subcompositor.EVENTS,
        .event_count = wl_subcompositor.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "get_subsurface",
            .signature = "noo",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_subsurface_interface" }),
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
            },
        },
    };

    pub const EVENTS = [_]wl_message{
    };

        pub const Error = enum(wire.Uint) {
            bad_surface = 0,
            bad_parent = 1,
        };

    pub const EventListener = extern struct {
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn get_subsurface(this: *@This(), surface: *wayland.wl_surface, parent: *wayland.wl_surface) error{Failure}!*wl_subsurface {
        var args: [3]wl_argument = .{            .{ .object = null },
            .{ .object = @ptrCast(surface) },
            .{ .object = @ptrCast(parent) },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 1, wl_subsurface.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

};

comptime { _ = wl_subcompositor.INTERFACE; }
/// sub-surface interface to a wl_surface
///
/// 
/// An additional interface to a wl_surface object, which has been
/// made a sub-surface. A sub-surface has one parent surface. A
/// sub-surface's size and position are not limited to that of the parent.
/// Particularly, a sub-surface is not automatically clipped to its
/// parent's area.
/// 
/// A sub-surface becomes mapped, when a non-NULL wl_buffer is applied
/// and the parent surface is mapped. The order of which one happens
/// first is irrelevant. A sub-surface is hidden if the parent becomes
/// hidden, or if a NULL wl_buffer is applied. These rules apply
/// recursively through the tree of surfaces.
/// 
/// The behaviour of a wl_surface.commit request on a sub-surface
/// depends on the sub-surface's mode. The possible modes are
/// synchronized and desynchronized, see methods
/// wl_subsurface.set_sync and wl_subsurface.set_desync. Synchronized
/// mode caches the wl_surface state to be applied when the parent's
/// state gets applied, and desynchronized mode applies the pending
/// wl_surface state directly. A sub-surface is initially in the
/// synchronized mode.
/// 
/// Sub-surfaces also have another kind of state, which is managed by
/// wl_subsurface requests, as opposed to wl_surface requests. This
/// state includes the sub-surface position relative to the parent
/// surface (wl_subsurface.set_position), and the stacking order of
/// the parent and its sub-surfaces (wl_subsurface.place_above and
/// .place_below). This state is applied when the parent surface's
/// wl_surface state is applied, regardless of the sub-surface's mode.
/// As the exception, set_sync and set_desync are effective immediately.
/// 
/// The main surface can be thought to be always in desynchronized mode,
/// since it does not have a parent in the sub-surfaces sense.
/// 
/// Even if a sub-surface is in desynchronized mode, it will behave as
/// in synchronized mode, if its parent surface behaves as in
/// synchronized mode. This rule is applied recursively throughout the
/// tree of surfaces. This means, that one can set a sub-surface into
/// synchronized mode, and then assume that all its child and grand-child
/// sub-surfaces are synchronized, too, without explicitly setting them.
/// 
/// Destroying a sub-surface takes effect immediately. If you need to
/// synchronize the removal of a sub-surface to the parent surface update,
/// unmap the sub-surface first by attaching a NULL wl_buffer, update parent,
/// and then destroy the sub-surface.
/// 
/// If the parent wl_surface object is destroyed, the sub-surface is
/// unmapped.
/// 
/// A sub-surface never has the keyboard focus of any seat.
/// 
/// The wl_surface.offset request is ignored: clients must use set_position
/// instead to move the sub-surface.
/// 
/// 
pub const wl_subsurface = opaque {
    pub const NAME = "wl_subsurface";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wl_subsurface_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wl_subsurface",
        .version = 1,
        .requests = &wl_subsurface.REQUESTS,
        .request_count = wl_subsurface.REQUESTS.len,
        .events = &wl_subsurface.EVENTS,
        .event_count = wl_subsurface.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "set_position",
            .signature = "ii",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "place_above",
            .signature = "o",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
            },
        },
        wl_message{
            .name = "place_below",
            .signature = "o",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
            },
        },
        wl_message{
            .name = "set_sync",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "set_desync",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EVENTS = [_]wl_message{
    };

        pub const Error = enum(wire.Uint) {
            bad_surface = 0,
        };

    pub const EventListener = extern struct {
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn set_position(this: *@This(), x: i32, y: i32)void {
        var args: [2]wl_argument = .{            .{ .int = x },
            .{ .int = y },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn place_above(this: *@This(), sibling: *wayland.wl_surface)void {
        var args: [1]wl_argument = .{            .{ .object = @ptrCast(sibling) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn place_below(this: *@This(), sibling: *wayland.wl_surface)void {
        var args: [1]wl_argument = .{            .{ .object = @ptrCast(sibling) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 3, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_sync(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 4, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_desync(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 5, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = wl_subsurface.INTERFACE; }
const wayland = @This();
