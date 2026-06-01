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

/// timed presentation related wl_surface requests
///
/// 
/// 
/// 
/// 
/// 
/// The main feature of this interface is accurate presentation
/// timing feedback to ensure smooth video playback while maintaining
/// audio/video synchronization. Some features use the concept of a
/// presentation clock, which is defined in the
/// presentation.clock_id event.
/// 
/// A content update for a wl_surface is submitted by a
/// wl_surface.commit request. Request 'feedback' associates with
/// the wl_surface.commit and provides feedback on the content
/// update, particularly the final realized presentation time.
/// 
/// 
/// 
/// 
/// When the final realized presentation time is available, e.g.
/// after a framebuffer flip completes, the requested
/// presentation_feedback.presented events are sent. The final
/// presentation time can differ from the compositor's predicted
/// display update time and the update's target time, especially
/// when the compositor misses its target vertical blanking period.
/// 
/// 
pub const wp_presentation = opaque {
    pub const NAME = "wp_presentation";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wp_presentation_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wp_presentation",
        .version = 2,
        .requests = &wp_presentation.REQUESTS,
        .request_count = wp_presentation.REQUESTS.len,
        .events = &wp_presentation.EVENTS,
        .event_count = wp_presentation.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "feedback",
            .signature = "on",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
                @extern(?*const wl_interface, .{ .name = "wp_presentation_feedback_interface" }),
            },
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "clock_id",
            .signature = "u",
            .types = &.{
                null,
            },
        },
    };

        pub const Error = enum(wire.Uint) {
            invalid_timestamp = 0,
            invalid_flag = 1,
        };

    pub const EventListener = extern struct {
        clock_id: *const fn(?*anyopaque, *wp_presentation, clk_id: u32) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn feedback(this: *@This(), surface: *wayland.wl_surface) error{Failure}!*wp_presentation_feedback {
        var args: [2]wl_argument = .{            .{ .object = @ptrCast(surface) },
            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 1, wp_presentation_feedback.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

};

comptime { _ = wp_presentation.INTERFACE; }
/// presentation time feedback event
///
/// 
/// A presentation_feedback object returns an indication that a
/// wl_surface content update has become visible to the user.
/// One object corresponds to one content update submission
/// (wl_surface.commit). There are two possible outcomes: the
/// content update is presented to the user, and a presentation
/// timestamp delivered; or, the user did not see the content
/// update because it was superseded or its surface destroyed,
/// and the content update is discarded.
/// 
/// Once a presentation_feedback object has delivered a 'presented'
/// or 'discarded' event it is automatically destroyed.
/// 
/// 
pub const wp_presentation_feedback = opaque {
    pub const NAME = "wp_presentation_feedback";
    pub const VERSION = 2;

    comptime {
        @export(INTERFACE, .{ .name = "wp_presentation_feedback_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wp_presentation_feedback",
        .version = 2,
        .requests = &wp_presentation_feedback.REQUESTS,
        .request_count = wp_presentation_feedback.REQUESTS.len,
        .events = &wp_presentation_feedback.EVENTS,
        .event_count = wp_presentation_feedback.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "sync_output",
            .signature = "o",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_output_interface" }),
            },
        },
        wl_message{
            .name = "presented",
            .signature = "uuuuuuu",
            .types = &.{
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
            .name = "discarded",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
    };

        pub const Kind = packed struct(wire.Uint) {
            /// presentation was vsync'd
            ///
            /// 
            /// The presentation was synchronized to the "vertical retrace" by
            /// the display hardware such that tearing does not happen.
            /// Relying on software scheduling is not acceptable for this
            /// flag. If presentation is done by a copy to the active
            /// frontbuffer, then it must guarantee that tearing cannot
            /// happen.
            /// 
            /// 
            vsync: bool,
            /// hardware provided the presentation timestamp
            ///
            /// 
            /// The display hardware provided measurements that the hardware
            /// driver converted into a presentation timestamp. Sampling a
            /// clock in software is not acceptable for this flag.
            /// 
            /// 
            hw_clock: bool,
            /// hardware signalled the start of the presentation
            ///
            /// 
            /// The display hardware signalled that it started using the new
            /// image content. The opposite of this is e.g. a timer being used
            /// to guess when the display hardware has switched to the new
            /// image content.
            /// 
            /// 
            hw_completion: bool,
            /// presentation was done zero-copy
            ///
            /// 
            /// The presentation of this update was done zero-copy. This means
            /// the buffer from the client was given to display hardware as
            /// is, without copying it. Compositing with OpenGL counts as
            /// copying, even if textured directly from the client buffer.
            /// Possible zero-copy cases include direct scanout of a
            /// fullscreen surface and a surface on a hardware overlay.
            /// 
            /// 
            zero_copy: bool,
            padding_1: u28 = 0,
        };

    pub const EventListener = extern struct {
        sync_output: *const fn(?*anyopaque, *wp_presentation_feedback, output: *wayland.wl_output) callconv(.c) void,
        presented: *const fn(?*anyopaque, *wp_presentation_feedback, tv_sec_hi: u32, tv_sec_lo: u32, tv_nsec: u32, refresh: u32, seq_hi: u32, seq_lo: u32, flags: wp_presentation_feedback.Kind) callconv(.c) void,
        discarded: *const fn(?*anyopaque, *wp_presentation_feedback) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

};

comptime { _ = wp_presentation_feedback.INTERFACE; }
/// surface cropping and scaling
///
/// 
/// The global interface exposing surface cropping and scaling
/// capabilities is used to instantiate an interface extension for a
/// wl_surface object. This extended interface will then allow
/// cropping and scaling the surface contents, effectively
/// disconnecting the direct relationship between the buffer and the
/// surface size.
/// 
/// 
pub const wp_viewporter = opaque {
    pub const NAME = "wp_viewporter";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wp_viewporter_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wp_viewporter",
        .version = 1,
        .requests = &wp_viewporter.REQUESTS,
        .request_count = wp_viewporter.REQUESTS.len,
        .events = &wp_viewporter.EVENTS,
        .event_count = wp_viewporter.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "get_viewport",
            .signature = "no",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wp_viewport_interface" }),
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
            },
        },
    };

    pub const EVENTS = [_]wl_message{
    };

        pub const Error = enum(wire.Uint) {
            viewport_exists = 0,
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

    pub fn get_viewport(this: *@This(), surface: *wayland.wl_surface) error{Failure}!*wp_viewport {
        var args: [2]wl_argument = .{            .{ .object = null },
            .{ .object = @ptrCast(surface) },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 1, wp_viewport.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

};

comptime { _ = wp_viewporter.INTERFACE; }
/// crop and scale interface to a wl_surface
///
/// 
/// An additional interface to a wl_surface object, which allows the
/// client to specify the cropping and scaling of the surface
/// contents.
/// 
/// This interface works with two concepts: the source rectangle (src_x,
/// src_y, src_width, src_height), and the destination size (dst_width,
/// dst_height). The contents of the source rectangle are scaled to the
/// destination size, and content outside the source rectangle is ignored.
/// This state is double-buffered, see wl_surface.commit.
/// 
/// The two parts of crop and scale state are independent: the source
/// rectangle, and the destination size. Initially both are unset, that
/// is, no scaling is applied. The whole of the current wl_buffer is
/// used as the source, and the surface size is as defined in
/// wl_surface.attach.
/// 
/// If the destination size is set, it causes the surface size to become
/// dst_width, dst_height. The source (rectangle) is scaled to exactly
/// this size. This overrides whatever the attached wl_buffer size is,
/// unless the wl_buffer is NULL. If the wl_buffer is NULL, the surface
/// has no content and therefore no size. Otherwise, the size is always
/// at least 1x1 in surface local coordinates.
/// 
/// If the source rectangle is set, it defines what area of the wl_buffer is
/// taken as the source. If the source rectangle is set and the destination
/// size is not set, then src_width and src_height must be integers, and the
/// surface size becomes the source rectangle size. This results in cropping
/// without scaling. If src_width or src_height are not integers and
/// destination size is not set, the bad_size protocol error is raised when
/// the surface state is applied.
/// 
/// The coordinate transformations from buffer pixel coordinates up to
/// the surface-local coordinates happen in the following order:
/// 1. buffer_transform (wl_surface.set_buffer_transform)
/// 2. buffer_scale (wl_surface.set_buffer_scale)
/// 3. crop and scale (wp_viewport.set*)
/// This means, that the source rectangle coordinates of crop and scale
/// are given in the coordinates after the buffer transform and scale,
/// i.e. in the coordinates that would be the surface-local coordinates
/// if the crop and scale was not applied.
/// 
/// If src_x or src_y are negative, the bad_value protocol error is raised.
/// Otherwise, if the source rectangle is partially or completely outside of
/// the non-NULL wl_buffer, then the out_of_buffer protocol error is raised
/// when the surface state is applied. A NULL wl_buffer does not raise the
/// out_of_buffer error.
/// 
/// If the wl_surface associated with the wp_viewport is destroyed,
/// all wp_viewport requests except 'destroy' raise the protocol error
/// no_surface.
/// 
/// If the wp_viewport object is destroyed, the crop and scale
/// state is removed from the wl_surface. The change will be applied
/// on the next wl_surface.commit.
/// 
/// 
pub const wp_viewport = opaque {
    pub const NAME = "wp_viewport";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "wp_viewport_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "wp_viewport",
        .version = 1,
        .requests = &wp_viewport.REQUESTS,
        .request_count = wp_viewport.REQUESTS.len,
        .events = &wp_viewport.EVENTS,
        .event_count = wp_viewport.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "set_source",
            .signature = "ffff",
            .types = &.{
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "set_destination",
            .signature = "ii",
            .types = &.{
                null,
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
    };

        pub const Error = enum(wire.Uint) {
            bad_value = 0,
            bad_size = 1,
            out_of_buffer = 2,
            no_surface = 3,
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

    pub fn set_source(this: *@This(), x: wire.Fixed, y: wire.Fixed, width: wire.Fixed, height: wire.Fixed)void {
        var args: [4]wl_argument = .{            .{ .fixed = x },
            .{ .fixed = y },
            .{ .fixed = width },
            .{ .fixed = height },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_destination(this: *@This(), width: i32, height: i32)void {
        var args: [2]wl_argument = .{            .{ .int = width },
            .{ .int = height },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = wp_viewport.INTERFACE; }
/// create desktop-style surfaces
///
/// 
/// The xdg_wm_base interface is exposed as a global object enabling clients
/// to turn their wl_surfaces into windows in a desktop environment. It
/// defines the basic functionality needed for clients and the compositor to
/// create windows that can be dragged, resized, maximized, etc, as well as
/// creating transient windows such as popup menus.
/// 
/// 
pub const xdg_wm_base = opaque {
    pub const NAME = "xdg_wm_base";
    pub const VERSION = 2;

    comptime {
        @export(INTERFACE, .{ .name = "xdg_wm_base_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "xdg_wm_base",
        .version = 6,
        .requests = &xdg_wm_base.REQUESTS,
        .request_count = xdg_wm_base.REQUESTS.len,
        .events = &xdg_wm_base.EVENTS,
        .event_count = xdg_wm_base.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "create_positioner",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "xdg_positioner_interface" }),
            },
        },
        wl_message{
            .name = "get_xdg_surface",
            .signature = "no",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "xdg_surface_interface" }),
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
            },
        },
        wl_message{
            .name = "pong",
            .signature = "u",
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
    };

        pub const Error = enum(wire.Uint) {
            role = 0,
            defunct_surfaces = 1,
            not_the_topmost_popup = 2,
            invalid_popup_parent = 3,
            invalid_surface_state = 4,
            invalid_positioner = 5,
            unresponsive = 6,
        };

    pub const EventListener = extern struct {
        ping: *const fn(?*anyopaque, *xdg_wm_base, serial: u32) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn create_positioner(this: *@This()) error{Failure}!*xdg_positioner {
        var args: [1]wl_argument = .{            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 1, xdg_positioner.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn get_xdg_surface(this: *@This(), surface: *wayland.wl_surface) error{Failure}!*xdg_surface {
        var args: [2]wl_argument = .{            .{ .object = null },
            .{ .object = @ptrCast(surface) },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 2, xdg_surface.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn pong(this: *@This(), serial: u32)void {
        var args: [1]wl_argument = .{            .{ .uint = serial },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 3, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = xdg_wm_base.INTERFACE; }
/// child surface positioner
///
/// 
/// The xdg_positioner provides a collection of rules for the placement of a
/// child surface relative to a parent surface. Rules can be defined to ensure
/// the child surface remains within the visible area's borders, and to
/// specify how the child surface changes its position, such as sliding along
/// an axis, or flipping around a rectangle. These positioner-created rules are
/// constrained by the requirement that a child surface must intersect with or
/// be at least partially adjacent to its parent surface.
/// 
/// See the various requests for details about possible rules.
/// 
/// At the time of the request, the compositor makes a copy of the rules
/// specified by the xdg_positioner. Thus, after the request is complete the
/// xdg_positioner object can be destroyed or reused; further changes to the
/// object will have no effect on previous usages.
/// 
/// For an xdg_positioner object to be considered complete, it must have a
/// non-zero size set by set_size, and a non-zero anchor rectangle set by
/// set_anchor_rect. Passing an incomplete xdg_positioner object when
/// positioning a surface raises an invalid_positioner error.
/// 
/// 
pub const xdg_positioner = opaque {
    pub const NAME = "xdg_positioner";
    pub const VERSION = 6;

    comptime {
        @export(INTERFACE, .{ .name = "xdg_positioner_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "xdg_positioner",
        .version = 6,
        .requests = &xdg_positioner.REQUESTS,
        .request_count = xdg_positioner.REQUESTS.len,
        .events = &xdg_positioner.EVENTS,
        .event_count = xdg_positioner.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "set_size",
            .signature = "ii",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "set_anchor_rect",
            .signature = "iiii",
            .types = &.{
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "set_anchor",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "set_gravity",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "set_constraint_adjustment",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "set_offset",
            .signature = "ii",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "set_reactive",
            .signature = "3",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "set_parent_size",
            .signature = "3ii",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "set_parent_configure",
            .signature = "3u",
            .types = &.{
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
    };

        pub const Error = enum(wire.Uint) {
            invalid_input = 0,
        };

        pub const Anchor = enum(wire.Uint) {
            none = 0,
            top = 1,
            bottom = 2,
            left = 3,
            right = 4,
            top_left = 5,
            bottom_left = 6,
            top_right = 7,
            bottom_right = 8,
        };

        pub const Gravity = enum(wire.Uint) {
            none = 0,
            top = 1,
            bottom = 2,
            left = 3,
            right = 4,
            top_left = 5,
            bottom_left = 6,
            top_right = 7,
            bottom_right = 8,
        };

        pub const ConstraintAdjustment = packed struct(wire.Uint) {
            /// move along the x axis until unconstrained
            ///
            /// 
            /// Slide the surface along the x axis until it is no longer constrained.
            /// 
            /// First try to slide towards the direction of the gravity on the x axis
            /// until either the edge in the opposite direction of the gravity is
            /// unconstrained or the edge in the direction of the gravity is
            /// constrained.
            /// 
            /// Then try to slide towards the opposite direction of the gravity on the
            /// x axis until either the edge in the direction of the gravity is
            /// unconstrained or the edge in the opposite direction of the gravity is
            /// constrained.
            /// 
            /// 
            slide_x: bool,
            /// move along the y axis until unconstrained
            ///
            /// 
            /// Slide the surface along the y axis until it is no longer constrained.
            /// 
            /// First try to slide towards the direction of the gravity on the y axis
            /// until either the edge in the opposite direction of the gravity is
            /// unconstrained or the edge in the direction of the gravity is
            /// constrained.
            /// 
            /// Then try to slide towards the opposite direction of the gravity on the
            /// y axis until either the edge in the direction of the gravity is
            /// unconstrained or the edge in the opposite direction of the gravity is
            /// constrained.
            /// 
            /// 
            slide_y: bool,
            /// invert the anchor and gravity on the x axis
            ///
            /// 
            /// Invert the anchor and gravity on the x axis if the surface is
            /// constrained on the x axis. For example, if the left edge of the
            /// surface is constrained, the gravity is 'left' and the anchor is
            /// 'left', change the gravity to 'right' and the anchor to 'right'.
            /// 
            /// If the adjusted position also ends up being constrained, the resulting
            /// position of the flip_x adjustment will be the one before the
            /// adjustment.
            /// 
            /// 
            flip_x: bool,
            /// invert the anchor and gravity on the y axis
            ///
            /// 
            /// Invert the anchor and gravity on the y axis if the surface is
            /// constrained on the y axis. For example, if the bottom edge of the
            /// surface is constrained, the gravity is 'bottom' and the anchor is
            /// 'bottom', change the gravity to 'top' and the anchor to 'top'.
            /// 
            /// The adjusted position is calculated given the original anchor
            /// rectangle and offset, but with the new flipped anchor and gravity
            /// values.
            /// 
            /// If the adjusted position also ends up being constrained, the resulting
            /// position of the flip_y adjustment will be the one before the
            /// adjustment.
            /// 
            /// 
            flip_y: bool,
            /// horizontally resize the surface
            ///
            /// 
            /// Resize the surface horizontally so that it is completely
            /// unconstrained.
            /// 
            /// 
            resize_x: bool,
            /// vertically resize the surface
            ///
            /// 
            /// Resize the surface vertically so that it is completely unconstrained.
            /// 
            /// 
            resize_y: bool,
            padding_1: u26 = 0,
            pub const none: @This() = @bitCast(@as(u32, 0b0));
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

    pub fn set_size(this: *@This(), width: i32, height: i32)void {
        var args: [2]wl_argument = .{            .{ .int = width },
            .{ .int = height },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_anchor_rect(this: *@This(), x: i32, y: i32, width: i32, height: i32)void {
        var args: [4]wl_argument = .{            .{ .int = x },
            .{ .int = y },
            .{ .int = width },
            .{ .int = height },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_anchor(this: *@This(), anchor: xdg_positioner.Anchor)void {
        var args: [1]wl_argument = .{            .{ .uint = @intFromEnum(anchor) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 3, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_gravity(this: *@This(), gravity: xdg_positioner.Gravity)void {
        var args: [1]wl_argument = .{            .{ .uint = @intFromEnum(gravity) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 4, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_constraint_adjustment(this: *@This(), constraint_adjustment: xdg_positioner.ConstraintAdjustment)void {
        var args: [1]wl_argument = .{            .{ .uint = @intFromEnum(constraint_adjustment) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 5, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_offset(this: *@This(), x: i32, y: i32)void {
        var args: [2]wl_argument = .{            .{ .int = x },
            .{ .int = y },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 6, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_reactive(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 7, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_parent_size(this: *@This(), parent_width: i32, parent_height: i32)void {
        var args: [2]wl_argument = .{            .{ .int = parent_width },
            .{ .int = parent_height },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 8, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_parent_configure(this: *@This(), serial: u32)void {
        var args: [1]wl_argument = .{            .{ .uint = serial },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 9, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = xdg_positioner.INTERFACE; }
/// desktop user interface surface base interface
///
/// 
/// An interface that may be implemented by a wl_surface, for
/// implementations that provide a desktop-style user interface.
/// 
/// It provides a base set of functionality required to construct user
/// interface elements requiring management by the compositor, such as
/// toplevel windows, menus, etc. The types of functionality are split into
/// xdg_surface roles.
/// 
/// Creating an xdg_surface does not set the role for a wl_surface. In order
/// to map an xdg_surface, the client must create a role-specific object
/// using, e.g., get_toplevel, get_popup. The wl_surface for any given
/// xdg_surface can have at most one role, and may not be assigned any role
/// not based on xdg_surface.
/// 
/// A role must be assigned before any other requests are made to the
/// xdg_surface object.
/// 
/// The client must call wl_surface.commit on the corresponding wl_surface
/// for the xdg_surface state to take effect.
/// 
/// Creating an xdg_surface from a wl_surface which has a buffer attached or
/// committed is a client error, and any attempts by a client to attach or
/// manipulate a buffer prior to the first xdg_surface.configure call must
/// also be treated as errors.
/// 
/// After creating a role-specific object and setting it up (e.g. by sending
/// the title, app ID, size constraints, parent, etc), the client must
/// perform an initial commit without any buffer attached. The compositor
/// will reply with initial wl_surface state such as
/// wl_surface.preferred_buffer_scale followed by an xdg_surface.configure
/// event. The client must acknowledge it and is then allowed to attach a
/// buffer to map the surface.
/// 
/// Mapping an xdg_surface-based role surface is defined as making it
/// possible for the surface to be shown by the compositor. Note that
/// a mapped surface is not guaranteed to be visible once it is mapped.
/// 
/// For an xdg_surface to be mapped by the compositor, the following
/// conditions must be met:
/// (1) the client has assigned an xdg_surface-based role to the surface
/// (2) the client has set and committed the xdg_surface state and the
/// role-dependent state to the surface
/// (3) the client has committed a buffer to the surface
/// 
/// A newly-unmapped surface is considered to have met condition (1) out
/// of the 3 required conditions for mapping a surface if its role surface
/// has not been destroyed, i.e. the client must perform the initial commit
/// again before attaching a buffer.
/// 
/// 
pub const xdg_surface = opaque {
    pub const NAME = "xdg_surface";
    pub const VERSION = 6;

    comptime {
        @export(INTERFACE, .{ .name = "xdg_surface_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "xdg_surface",
        .version = 6,
        .requests = &xdg_surface.REQUESTS,
        .request_count = xdg_surface.REQUESTS.len,
        .events = &xdg_surface.EVENTS,
        .event_count = xdg_surface.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "get_toplevel",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "xdg_toplevel_interface" }),
            },
        },
        wl_message{
            .name = "get_popup",
            .signature = "n?oo",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "xdg_popup_interface" }),
                @extern(?*const wl_interface, .{ .name = "xdg_surface_interface" }),
                @extern(?*const wl_interface, .{ .name = "xdg_positioner_interface" }),
            },
        },
        wl_message{
            .name = "set_window_geometry",
            .signature = "iiii",
            .types = &.{
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "ack_configure",
            .signature = "u",
            .types = &.{
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "configure",
            .signature = "u",
            .types = &.{
                null,
            },
        },
    };

        pub const Error = enum(wire.Uint) {
            not_constructed = 1,
            already_constructed = 2,
            unconfigured_buffer = 3,
            invalid_serial = 4,
            invalid_size = 5,
            defunct_role_object = 6,
        };

    pub const EventListener = extern struct {
        configure: *const fn(?*anyopaque, *xdg_surface, serial: u32) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn get_toplevel(this: *@This()) error{Failure}!*xdg_toplevel {
        var args: [1]wl_argument = .{            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 1, xdg_toplevel.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn get_popup(this: *@This(), parent: ?*xdg_shell.xdg_surface, positioner: *xdg_shell.xdg_positioner) error{Failure}!*xdg_popup {
        var args: [3]wl_argument = .{            .{ .object = null },
            .{ .object = @ptrCast(parent) },
            .{ .object = @ptrCast(positioner) },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 2, xdg_popup.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn set_window_geometry(this: *@This(), x: i32, y: i32, width: i32, height: i32)void {
        var args: [4]wl_argument = .{            .{ .int = x },
            .{ .int = y },
            .{ .int = width },
            .{ .int = height },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 3, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn ack_configure(this: *@This(), serial: u32)void {
        var args: [1]wl_argument = .{            .{ .uint = serial },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 4, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = xdg_surface.INTERFACE; }
/// toplevel surface
///
/// 
/// This interface defines an xdg_surface role which allows a surface to,
/// among other things, set window-like properties such as maximize,
/// fullscreen, and minimize, set application-specific metadata like title and
/// id, and well as trigger user interactive operations such as interactive
/// resize and move.
/// 
/// A xdg_toplevel by default is responsible for providing the full intended
/// visual representation of the toplevel, which depending on the window
/// state, may mean things like a title bar, window controls and drop shadow.
/// 
/// Unmapping an xdg_toplevel means that the surface cannot be shown
/// by the compositor until it is explicitly mapped again.
/// All active operations (e.g., move, resize) are canceled and all
/// attributes (e.g. title, state, stacking, ...) are discarded for
/// an xdg_toplevel surface when it is unmapped. The xdg_toplevel returns to
/// the state it had right after xdg_surface.get_toplevel. The client
/// can re-map the toplevel by performing a commit without any buffer
/// attached, waiting for a configure event and handling it as usual (see
/// xdg_surface description).
/// 
/// Attaching a null buffer to a toplevel unmaps the surface.
/// 
/// 
pub const xdg_toplevel = opaque {
    pub const NAME = "xdg_toplevel";
    pub const VERSION = 6;

    comptime {
        @export(INTERFACE, .{ .name = "xdg_toplevel_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "xdg_toplevel",
        .version = 6,
        .requests = &xdg_toplevel.REQUESTS,
        .request_count = xdg_toplevel.REQUESTS.len,
        .events = &xdg_toplevel.EVENTS,
        .event_count = xdg_toplevel.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "set_parent",
            .signature = "?o",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "xdg_toplevel_interface" }),
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
            .name = "set_app_id",
            .signature = "s",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "show_window_menu",
            .signature = "ouii",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_seat_interface" }),
                null,
                null,
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
            .name = "set_max_size",
            .signature = "ii",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "set_min_size",
            .signature = "ii",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "set_maximized",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "unset_maximized",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "set_fullscreen",
            .signature = "?o",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_output_interface" }),
            },
        },
        wl_message{
            .name = "unset_fullscreen",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "set_minimized",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "configure",
            .signature = "iia",
            .types = &.{
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "close",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "configure_bounds",
            .signature = "4ii",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "wm_capabilities",
            .signature = "5a",
            .types = &.{
                null,
            },
        },
    };

        pub const Error = enum(wire.Uint) {
            invalid_resize_edge = 0,
            invalid_parent = 1,
            invalid_size = 2,
        };

        pub const ResizeEdge = enum(wire.Uint) {
            none = 0,
            top = 1,
            bottom = 2,
            left = 4,
            top_left = 5,
            bottom_left = 6,
            right = 8,
            top_right = 9,
            bottom_right = 10,
        };

        pub const State = enum(wire.Uint) {
            /// the surface is maximized
            ///
            /// 
            /// The surface is maximized. The window geometry specified in the configure
            /// event must be obeyed by the client, or the xdg_wm_base.invalid_surface_state
            /// error is raised.
            /// 
            /// The client should draw without shadow or other
            /// decoration outside of the window geometry.
            /// 
            /// 
            maximized = 1,
            /// the surface is fullscreen
            ///
            /// 
            /// The surface is fullscreen. The window geometry specified in the
            /// configure event is a maximum; the client cannot resize beyond it. For
            /// a surface to cover the whole fullscreened area, the geometry
            /// dimensions must be obeyed by the client. For more details, see
            /// xdg_toplevel.set_fullscreen.
            /// 
            /// 
            fullscreen = 2,
            /// the surface is being resized
            ///
            /// 
            /// The surface is being resized. The window geometry specified in the
            /// configure event is a maximum; the client cannot resize beyond it.
            /// Clients that have aspect ratio or cell sizing configuration can use
            /// a smaller size, however.
            /// 
            /// 
            resizing = 3,
            /// the surface is now activated
            ///
            /// 
            /// Client window decorations should be painted as if the window is
            /// active. Do not assume this means that the window actually has
            /// keyboard or pointer focus.
            /// 
            /// 
            activated = 4,
            /// the surface’s left edge is tiled
            ///
            /// 
            /// The window is currently in a tiled layout and the left edge is
            /// considered to be adjacent to another part of the tiling grid.
            /// 
            /// The client should draw without shadow or other decoration outside of
            /// the window geometry on the left edge.
            /// 
            /// 
            tiled_left = 5,
            /// the surface’s right edge is tiled
            ///
            /// 
            /// The window is currently in a tiled layout and the right edge is
            /// considered to be adjacent to another part of the tiling grid.
            /// 
            /// The client should draw without shadow or other decoration outside of
            /// the window geometry on the right edge.
            /// 
            /// 
            tiled_right = 6,
            /// the surface’s top edge is tiled
            ///
            /// 
            /// The window is currently in a tiled layout and the top edge is
            /// considered to be adjacent to another part of the tiling grid.
            /// 
            /// The client should draw without shadow or other decoration outside of
            /// the window geometry on the top edge.
            /// 
            /// 
            tiled_top = 7,
            /// the surface’s bottom edge is tiled
            ///
            /// 
            /// The window is currently in a tiled layout and the bottom edge is
            /// considered to be adjacent to another part of the tiling grid.
            /// 
            /// The client should draw without shadow or other decoration outside of
            /// the window geometry on the bottom edge.
            /// 
            /// 
            tiled_bottom = 8,
            /// surface repaint is suspended
            ///
            /// 
            /// The surface is currently not ordinarily being repainted; for
            /// example because its content is occluded by another window, or its
            /// outputs are switched off due to screen locking.
            /// 
            /// 
            suspended = 9,
        };

        pub const WmCapabilities = enum(wire.Uint) {
            window_menu = 1,
            maximize = 2,
            fullscreen = 3,
            minimize = 4,
        };

    pub const EventListener = extern struct {
        configure: *const fn(?*anyopaque, *xdg_toplevel, width: i32, height: i32, states: wire.Array) callconv(.c) void,
        close: *const fn(?*anyopaque, *xdg_toplevel) callconv(.c) void,
        configure_bounds: *const fn(?*anyopaque, *xdg_toplevel, width: i32, height: i32) callconv(.c) void,
        wm_capabilities: *const fn(?*anyopaque, *xdg_toplevel, capabilities: wire.Array) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn set_parent(this: *@This(), parent: ?*xdg_shell.xdg_toplevel)void {
        var args: [1]wl_argument = .{            .{ .object = @ptrCast(parent) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_title(this: *@This(), title: [*:0]const u8)void {
        var args: [1]wl_argument = .{            .{ .string = title },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_app_id(this: *@This(), app_id: [*:0]const u8)void {
        var args: [1]wl_argument = .{            .{ .string = app_id },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 3, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn show_window_menu(this: *@This(), seat: *wayland.wl_seat, serial: u32, x: i32, y: i32)void {
        var args: [4]wl_argument = .{            .{ .object = @ptrCast(seat) },
            .{ .uint = serial },
            .{ .int = x },
            .{ .int = y },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 4, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn move(this: *@This(), seat: *wayland.wl_seat, serial: u32)void {
        var args: [2]wl_argument = .{            .{ .object = @ptrCast(seat) },
            .{ .uint = serial },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 5, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn resize(this: *@This(), seat: *wayland.wl_seat, serial: u32, edges: xdg_toplevel.ResizeEdge)void {
        var args: [3]wl_argument = .{            .{ .object = @ptrCast(seat) },
            .{ .uint = serial },
            .{ .uint = @intFromEnum(edges) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 6, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_max_size(this: *@This(), width: i32, height: i32)void {
        var args: [2]wl_argument = .{            .{ .int = width },
            .{ .int = height },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 7, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_min_size(this: *@This(), width: i32, height: i32)void {
        var args: [2]wl_argument = .{            .{ .int = width },
            .{ .int = height },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 8, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_maximized(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 9, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn unset_maximized(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 10, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_fullscreen(this: *@This(), output: ?*wayland.wl_output)void {
        var args: [1]wl_argument = .{            .{ .object = @ptrCast(output) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 11, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn unset_fullscreen(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 12, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn set_minimized(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 13, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = xdg_toplevel.INTERFACE; }
/// short-lived, popup surfaces for menus
///
/// 
/// A popup surface is a short-lived, temporary surface. It can be used to
/// implement for example menus, popovers, tooltips and other similar user
/// interface concepts.
/// 
/// A popup can be made to take an explicit grab. See xdg_popup.grab for
/// details.
/// 
/// When the popup is dismissed, a popup_done event will be sent out, and at
/// the same time the surface will be unmapped. See the xdg_popup.popup_done
/// event for details.
/// 
/// Explicitly destroying the xdg_popup object will also dismiss the popup and
/// unmap the surface. Clients that want to dismiss the popup when another
/// surface of their own is clicked should dismiss the popup using the destroy
/// request.
/// 
/// A newly created xdg_popup will be stacked on top of all previously created
/// xdg_popup surfaces associated with the same xdg_toplevel.
/// 
/// The parent of an xdg_popup must be mapped (see the xdg_surface
/// description) before the xdg_popup itself.
/// 
/// The client must call wl_surface.commit on the corresponding wl_surface
/// for the xdg_popup state to take effect.
/// 
/// 
pub const xdg_popup = opaque {
    pub const NAME = "xdg_popup";
    pub const VERSION = 6;

    comptime {
        @export(INTERFACE, .{ .name = "xdg_popup_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "xdg_popup",
        .version = 6,
        .requests = &xdg_popup.REQUESTS,
        .request_count = xdg_popup.REQUESTS.len,
        .events = &xdg_popup.EVENTS,
        .event_count = xdg_popup.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "grab",
            .signature = "ou",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_seat_interface" }),
                null,
            },
        },
        wl_message{
            .name = "reposition",
            .signature = "3ou",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "xdg_positioner_interface" }),
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "configure",
            .signature = "iiii",
            .types = &.{
                null,
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
        wl_message{
            .name = "repositioned",
            .signature = "3u",
            .types = &.{
                null,
            },
        },
    };

        pub const Error = enum(wire.Uint) {
            invalid_grab = 0,
        };

    pub const EventListener = extern struct {
        configure: *const fn(?*anyopaque, *xdg_popup, x: i32, y: i32, width: i32, height: i32) callconv(.c) void,
        popup_done: *const fn(?*anyopaque, *xdg_popup) callconv(.c) void,
        repositioned: *const fn(?*anyopaque, *xdg_popup, token: u32) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn grab(this: *@This(), seat: *wayland.wl_seat, serial: u32)void {
        var args: [2]wl_argument = .{            .{ .object = @ptrCast(seat) },
            .{ .uint = serial },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn reposition(this: *@This(), positioner: *xdg_shell.xdg_positioner, token: u32)void {
        var args: [2]wl_argument = .{            .{ .object = @ptrCast(positioner) },
            .{ .uint = token },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

};

comptime { _ = xdg_popup.INTERFACE; }
/// factory for creating dmabuf-based wl_buffers
///
/// 
/// This interface offers ways to create generic dmabuf-based wl_buffers.
/// 
/// For more information about dmabuf, see:
/// https://www.kernel.org/doc/html/next/userspace-api/dma-buf-alloc-exchange.html
/// 
/// Clients can use the get_surface_feedback request to get dmabuf feedback
/// for a particular surface. If the client wants to retrieve feedback not
/// tied to a surface, they can use the get_default_feedback request.
/// 
/// The following are required from clients:
/// 
/// - Clients must ensure that either all data in the dma-buf is
/// coherent for all subsequent read access or that coherency is
/// correctly handled by the underlying kernel-side dma-buf
/// implementation.
/// 
/// - Don't make any more attachments after sending the buffer to the
/// compositor. Making more attachments later increases the risk of
/// the compositor not being able to use (re-import) an existing
/// dmabuf-based wl_buffer.
/// 
/// The underlying graphics stack must ensure the following:
/// 
/// - The dmabuf file descriptors relayed to the server will stay valid
/// for the whole lifetime of the wl_buffer. This means the server may
/// at any time use those fds to import the dmabuf into any kernel
/// sub-system that might accept it.
/// 
/// However, when the underlying graphics stack fails to deliver the
/// promise, because of e.g. a device hot-unplug which raises internal
/// errors, after the wl_buffer has been successfully created the
/// compositor must not raise protocol errors to the client when dmabuf
/// import later fails.
/// 
/// To create a wl_buffer from one or more dmabufs, a client creates a
/// zwp_linux_dmabuf_params_v1 object with a zwp_linux_dmabuf_v1.create_params
/// request. All planes required by the intended format are added with
/// the 'add' request. Finally, a 'create' or 'create_immed' request is
/// issued, which has the following outcome depending on the import success.
/// 
/// The 'create' request,
/// - on success, triggers a 'created' event which provides the final
/// wl_buffer to the client.
/// - on failure, triggers a 'failed' event to convey that the server
/// cannot use the dmabufs received from the client.
/// 
/// For the 'create_immed' request,
/// - on success, the server immediately imports the added dmabufs to
/// create a wl_buffer. No event is sent from the server in this case.
/// - on failure, the server can choose to either:
/// - terminate the client by raising a fatal error.
/// - mark the wl_buffer as failed, and send a 'failed' event to the
/// client. If the client uses a failed wl_buffer as an argument to any
/// request, the behaviour is compositor implementation-defined.
/// 
/// For all DRM formats and unless specified in another protocol extension,
/// pre-multiplied alpha is used for pixel values.
/// 
/// Unless specified otherwise in another protocol extension, implicit
/// synchronization is used. In other words, compositors and clients must
/// wait and signal fences implicitly passed via the DMA-BUF's reservation
/// mechanism.
/// 
/// 
pub const zwp_linux_dmabuf_v1 = opaque {
    pub const NAME = "zwp_linux_dmabuf_v1";
    pub const VERSION = 3;

    comptime {
        @export(INTERFACE, .{ .name = "zwp_linux_dmabuf_v1_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "zwp_linux_dmabuf_v1",
        .version = 5,
        .requests = &zwp_linux_dmabuf_v1.REQUESTS,
        .request_count = zwp_linux_dmabuf_v1.REQUESTS.len,
        .events = &zwp_linux_dmabuf_v1.EVENTS,
        .event_count = zwp_linux_dmabuf_v1.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "create_params",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "zwp_linux_buffer_params_v1_interface" }),
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
        wl_message{
            .name = "modifier",
            .signature = "3uuu",
            .types = &.{
                null,
                null,
                null,
            },
        },
    };

    pub const EventListener = extern struct {
        format: *const fn(?*anyopaque, *zwp_linux_dmabuf_v1, format: u32) callconv(.c) void,
        modifier: *const fn(?*anyopaque, *zwp_linux_dmabuf_v1, format: u32, modifier_hi: u32, modifier_lo: u32) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn create_params(this: *@This()) error{Failure}!*zwp_linux_buffer_params_v1 {
        var args: [1]wl_argument = .{            .{ .object = null },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 1, zwp_linux_buffer_params_v1.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

};

comptime { _ = zwp_linux_dmabuf_v1.INTERFACE; }
/// parameters for creating a dmabuf-based wl_buffer
///
/// 
/// This temporary object is a collection of dmabufs and other
/// parameters that together form a single logical buffer. The temporary
/// object may eventually create one wl_buffer unless cancelled by
/// destroying it before requesting 'create'.
/// 
/// Single-planar formats only require one dmabuf, however
/// multi-planar formats may require more than one dmabuf. For all
/// formats, an 'add' request must be called once per plane (even if the
/// underlying dmabuf fd is identical).
/// 
/// You must use consecutive plane indices ('plane_idx' argument for 'add')
/// from zero to the number of planes used by the drm_fourcc format code.
/// All planes required by the format must be given exactly once, but can
/// be given in any order. Each plane index can only be set once; subsequent
/// calls with a plane index which has already been set will result in a
/// plane_set error being generated.
/// 
/// 
pub const zwp_linux_buffer_params_v1 = opaque {
    pub const NAME = "zwp_linux_buffer_params_v1";
    pub const VERSION = 5;

    comptime {
        @export(INTERFACE, .{ .name = "zwp_linux_buffer_params_v1_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "zwp_linux_buffer_params_v1",
        .version = 5,
        .requests = &zwp_linux_buffer_params_v1.REQUESTS,
        .request_count = zwp_linux_buffer_params_v1.REQUESTS.len,
        .events = &zwp_linux_buffer_params_v1.EVENTS,
        .event_count = zwp_linux_buffer_params_v1.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "add",
            .signature = "huuuuu",
            .types = &.{
                null,
                null,
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "create",
            .signature = "iiuu",
            .types = &.{
                null,
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "create_immed",
            .signature = "2niiuu",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_buffer_interface" }),
                null,
                null,
                null,
                null,
            },
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "created",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "wl_buffer_interface" }),
            },
        },
        wl_message{
            .name = "failed",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
    };

        pub const Error = enum(wire.Uint) {
            already_used = 0,
            plane_idx = 1,
            plane_set = 2,
            incomplete = 3,
            invalid_format = 4,
            invalid_dimensions = 5,
            out_of_bounds = 6,
            invalid_wl_buffer = 7,
        };

        pub const Flags = packed struct(wire.Uint) {
            y_invert: bool,
            interlaced: bool,
            bottom_first: bool,
            padding_1: u29 = 0,
        };

    pub const EventListener = extern struct {
        created: *const fn(?*anyopaque, *zwp_linux_buffer_params_v1, *wl_buffer) callconv(.c) void,
        failed: *const fn(?*anyopaque, *zwp_linux_buffer_params_v1) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

    pub fn add(this: *@This(), fd: wire.Fd, plane_idx: u32, offset: u32, stride: u32, modifier_hi: u32, modifier_lo: u32)void {
        var args: [6]wl_argument = .{            .{ .fd = @intFromEnum(fd) },
            .{ .uint = plane_idx },
            .{ .uint = offset },
            .{ .uint = stride },
            .{ .uint = modifier_hi },
            .{ .uint = modifier_lo },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn create(this: *@This(), width: i32, height: i32, format: u32, flags: zwp_linux_buffer_params_v1.Flags)void {
        var args: [4]wl_argument = .{            .{ .int = width },
            .{ .int = height },
            .{ .uint = format },
            .{ .uint = @intFromEnum(flags) },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 2, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn create_immed(this: *@This(), width: i32, height: i32, format: u32, flags: zwp_linux_buffer_params_v1.Flags) error{Failure}!*wl_buffer {
        var args: [5]wl_argument = .{            .{ .object = null },
            .{ .int = width },
            .{ .int = height },
            .{ .uint = format },
            .{ .uint = @intFromEnum(flags) },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 3, wl_buffer.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

};

comptime { _ = zwp_linux_buffer_params_v1.INTERFACE; }
/// dmabuf feedback
///
/// 
/// This object advertises dmabuf parameters feedback. This includes the
/// preferred devices and the supported formats/modifiers.
/// 
/// The parameters are sent once when this object is created and whenever they
/// change. The done event is always sent once after all parameters have been
/// sent. When a single parameter changes, all parameters are re-sent by the
/// compositor.
/// 
/// Compositors can re-send the parameters when the current client buffer
/// allocations are sub-optimal. Compositors should not re-send the
/// parameters if re-allocating the buffers would not result in a more optimal
/// configuration. In particular, compositors should avoid sending the exact
/// same parameters multiple times in a row.
/// 
/// The tranche_target_device and tranche_formats events are grouped by
/// tranches of preference. For each tranche, a tranche_target_device, one
/// tranche_flags and one or more tranche_formats events are sent, followed
/// by a tranche_done event finishing the list. The tranches are sent in
/// descending order of preference. All formats and modifiers in the same
/// tranche have the same preference.
/// 
/// To send parameters, the compositor sends one main_device event, tranches
/// (each consisting of one tranche_target_device event, one tranche_flags
/// event, tranche_formats events and then a tranche_done event), then one
/// done event.
/// 
/// 
pub const zwp_linux_dmabuf_feedback_v1 = opaque {
    pub const NAME = "zwp_linux_dmabuf_feedback_v1";
    pub const VERSION = 5;

    comptime {
        @export(INTERFACE, .{ .name = "zwp_linux_dmabuf_feedback_v1_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "zwp_linux_dmabuf_feedback_v1",
        .version = 5,
        .requests = &zwp_linux_dmabuf_feedback_v1.REQUESTS,
        .request_count = zwp_linux_dmabuf_feedback_v1.REQUESTS.len,
        .events = &zwp_linux_dmabuf_feedback_v1.EVENTS,
        .event_count = zwp_linux_dmabuf_feedback_v1.EVENTS.len,
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
            .name = "done",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "format_table",
            .signature = "hu",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "main_device",
            .signature = "a",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "tranche_done",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "tranche_target_device",
            .signature = "a",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "tranche_formats",
            .signature = "a",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "tranche_flags",
            .signature = "u",
            .types = &.{
                null,
            },
        },
    };

        pub const TrancheFlags = packed struct(wire.Uint) {
            scanout: bool,
            padding_1: u31 = 0,
        };

    pub const EventListener = extern struct {
        done: *const fn(?*anyopaque, *zwp_linux_dmabuf_feedback_v1) callconv(.c) void,
        format_table: *const fn(?*anyopaque, *zwp_linux_dmabuf_feedback_v1, fd: wire.Fd, size: u32) callconv(.c) void,
        main_device: *const fn(?*anyopaque, *zwp_linux_dmabuf_feedback_v1, device: wire.Array) callconv(.c) void,
        tranche_done: *const fn(?*anyopaque, *zwp_linux_dmabuf_feedback_v1) callconv(.c) void,
        tranche_target_device: *const fn(?*anyopaque, *zwp_linux_dmabuf_feedback_v1, device: wire.Array) callconv(.c) void,
        tranche_formats: *const fn(?*anyopaque, *zwp_linux_dmabuf_feedback_v1, indices: wire.Array) callconv(.c) void,
        tranche_flags: *const fn(?*anyopaque, *zwp_linux_dmabuf_feedback_v1, flags: zwp_linux_dmabuf_feedback_v1.TrancheFlags) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = zwp_linux_dmabuf_feedback_v1.INTERFACE; }
/// controller object for graphic tablet devices
///
/// 
/// An object that provides access to the graphics tablets available on this
/// system. All tablets are associated with a seat, to get access to the
/// actual tablets, use wp_tablet_manager.get_tablet_seat.
/// 
/// 
pub const zwp_tablet_manager_v2 = opaque {
    pub const NAME = "zwp_tablet_manager_v2";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "zwp_tablet_manager_v2_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "zwp_tablet_manager_v2",
        .version = 1,
        .requests = &zwp_tablet_manager_v2.REQUESTS,
        .request_count = zwp_tablet_manager_v2.REQUESTS.len,
        .events = &zwp_tablet_manager_v2.EVENTS,
        .event_count = zwp_tablet_manager_v2.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "get_tablet_seat",
            .signature = "no",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "zwp_tablet_seat_v2_interface" }),
                @extern(?*const wl_interface, .{ .name = "wl_seat_interface" }),
            },
        },
        wl_message{
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EVENTS = [_]wl_message{
    };

    pub const EventListener = extern struct {
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn get_tablet_seat(this: *@This(), seat: *wayland.wl_seat) error{Failure}!*zwp_tablet_seat_v2 {
        var args: [2]wl_argument = .{            .{ .object = null },
            .{ .object = @ptrCast(seat) },
        };

        return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), 0, zwp_tablet_seat_v2.INTERFACE, wl_proxy_get_version(@ptrCast(this)), .{}, &args        ) orelse return error.Failure);
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = zwp_tablet_manager_v2.INTERFACE; }
/// controller object for graphic tablet devices of a seat
///
/// 
/// An object that provides access to the graphics tablets available on this
/// seat. After binding to this interface, the compositor sends a set of
/// wp_tablet_seat.tablet_added and wp_tablet_seat.tool_added events.
/// 
/// 
pub const zwp_tablet_seat_v2 = opaque {
    pub const NAME = "zwp_tablet_seat_v2";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "zwp_tablet_seat_v2_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "zwp_tablet_seat_v2",
        .version = 1,
        .requests = &zwp_tablet_seat_v2.REQUESTS,
        .request_count = zwp_tablet_seat_v2.REQUESTS.len,
        .events = &zwp_tablet_seat_v2.EVENTS,
        .event_count = zwp_tablet_seat_v2.EVENTS.len,
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
            .name = "tablet_added",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "zwp_tablet_v2_interface" }),
            },
        },
        wl_message{
            .name = "tool_added",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "zwp_tablet_tool_v2_interface" }),
            },
        },
        wl_message{
            .name = "pad_added",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "zwp_tablet_pad_v2_interface" }),
            },
        },
    };

    pub const EventListener = extern struct {
        tablet_added: *const fn(?*anyopaque, *zwp_tablet_seat_v2, *zwp_tablet_v2) callconv(.c) void,
        tool_added: *const fn(?*anyopaque, *zwp_tablet_seat_v2, *zwp_tablet_tool_v2) callconv(.c) void,
        pad_added: *const fn(?*anyopaque, *zwp_tablet_seat_v2, *zwp_tablet_pad_v2) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = zwp_tablet_seat_v2.INTERFACE; }
/// a physical tablet tool
///
/// 
/// An object that represents a physical tool that has been, or is
/// currently in use with a tablet in this seat. Each wp_tablet_tool
/// object stays valid until the client destroys it; the compositor
/// reuses the wp_tablet_tool object to indicate that the object's
/// respective physical tool has come into proximity of a tablet again.
/// 
/// A wp_tablet_tool object's relation to a physical tool depends on the
/// tablet's ability to report serial numbers. If the tablet supports
/// this capability, then the object represents a specific physical tool
/// and can be identified even when used on multiple tablets.
/// 
/// A tablet tool has a number of static characteristics, e.g. tool type,
/// hardware_serial and capabilities. These capabilities are sent in an
/// event sequence after the wp_tablet_seat.tool_added event before any
/// actual events from this tool. This initial event sequence is
/// terminated by a wp_tablet_tool.done event.
/// 
/// Tablet tool events are grouped by wp_tablet_tool.frame events.
/// Any events received before a wp_tablet_tool.frame event should be
/// considered part of the same hardware state change.
/// 
/// 
pub const zwp_tablet_tool_v2 = opaque {
    pub const NAME = "zwp_tablet_tool_v2";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "zwp_tablet_tool_v2_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "zwp_tablet_tool_v2",
        .version = 1,
        .requests = &zwp_tablet_tool_v2.REQUESTS,
        .request_count = zwp_tablet_tool_v2.REQUESTS.len,
        .events = &zwp_tablet_tool_v2.EVENTS,
        .event_count = zwp_tablet_tool_v2.EVENTS.len,
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
            .name = "destroy",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "type",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "hardware_serial",
            .signature = "uu",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "hardware_id_wacom",
            .signature = "uu",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "capability",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "done",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "removed",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "proximity_in",
            .signature = "uoo",
            .types = &.{
                null,
                @extern(?*const wl_interface, .{ .name = "zwp_tablet_v2_interface" }),
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
            },
        },
        wl_message{
            .name = "proximity_out",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "down",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "up",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "motion",
            .signature = "ff",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "pressure",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "distance",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "tilt",
            .signature = "ff",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "rotation",
            .signature = "f",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "slider",
            .signature = "i",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "wheel",
            .signature = "fi",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "button",
            .signature = "uuu",
            .types = &.{
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "frame",
            .signature = "u",
            .types = &.{
                null,
            },
        },
    };

        pub const Type = enum(wire.Uint) {
            pen = 0x140,
            eraser = 0x141,
            brush = 0x142,
            pencil = 0x143,
            airbrush = 0x144,
            finger = 0x145,
            mouse = 0x146,
            lens = 0x147,
        };

        pub const Capability = enum(wire.Uint) {
            tilt = 1,
            pressure = 2,
            distance = 3,
            rotation = 4,
            slider = 5,
            wheel = 6,
        };

        pub const ButtonState = enum(wire.Uint) {
            released = 0,
            pressed = 1,
        };

        pub const Error = enum(wire.Uint) {
            role = 0,
        };

    pub const EventListener = extern struct {
        @"type": *const fn(?*anyopaque, *zwp_tablet_tool_v2, tool_type: zwp_tablet_tool_v2.Type) callconv(.c) void,
        hardware_serial: *const fn(?*anyopaque, *zwp_tablet_tool_v2, hardware_serial_hi: u32, hardware_serial_lo: u32) callconv(.c) void,
        hardware_id_wacom: *const fn(?*anyopaque, *zwp_tablet_tool_v2, hardware_id_hi: u32, hardware_id_lo: u32) callconv(.c) void,
        capability: *const fn(?*anyopaque, *zwp_tablet_tool_v2, capability: zwp_tablet_tool_v2.Capability) callconv(.c) void,
        done: *const fn(?*anyopaque, *zwp_tablet_tool_v2) callconv(.c) void,
        removed: *const fn(?*anyopaque, *zwp_tablet_tool_v2) callconv(.c) void,
        proximity_in: *const fn(?*anyopaque, *zwp_tablet_tool_v2, serial: u32, tablet: *tablet_v2.zwp_tablet_v2, surface: *wayland.wl_surface) callconv(.c) void,
        proximity_out: *const fn(?*anyopaque, *zwp_tablet_tool_v2) callconv(.c) void,
        down: *const fn(?*anyopaque, *zwp_tablet_tool_v2, serial: u32) callconv(.c) void,
        up: *const fn(?*anyopaque, *zwp_tablet_tool_v2) callconv(.c) void,
        motion: *const fn(?*anyopaque, *zwp_tablet_tool_v2, x: wire.Fixed, y: wire.Fixed) callconv(.c) void,
        pressure: *const fn(?*anyopaque, *zwp_tablet_tool_v2, pressure: u32) callconv(.c) void,
        distance: *const fn(?*anyopaque, *zwp_tablet_tool_v2, distance: u32) callconv(.c) void,
        tilt: *const fn(?*anyopaque, *zwp_tablet_tool_v2, tilt_x: wire.Fixed, tilt_y: wire.Fixed) callconv(.c) void,
        rotation: *const fn(?*anyopaque, *zwp_tablet_tool_v2, degrees: wire.Fixed) callconv(.c) void,
        slider: *const fn(?*anyopaque, *zwp_tablet_tool_v2, position: i32) callconv(.c) void,
        wheel: *const fn(?*anyopaque, *zwp_tablet_tool_v2, degrees: wire.Fixed, clicks: i32) callconv(.c) void,
        button: *const fn(?*anyopaque, *zwp_tablet_tool_v2, serial: u32, button: u32, state: zwp_tablet_tool_v2.ButtonState) callconv(.c) void,
        frame: *const fn(?*anyopaque, *zwp_tablet_tool_v2, time: u32) callconv(.c) void,
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

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = zwp_tablet_tool_v2.INTERFACE; }
/// graphics tablet device
///
/// 
/// The wp_tablet interface represents one graphics tablet device. The
/// tablet interface itself does not generate events; all events are
/// generated by wp_tablet_tool objects when in proximity above a tablet.
/// 
/// A tablet has a number of static characteristics, e.g. device name and
/// pid/vid. These capabilities are sent in an event sequence after the
/// wp_tablet_seat.tablet_added event. This initial event sequence is
/// terminated by a wp_tablet.done event.
/// 
/// 
pub const zwp_tablet_v2 = opaque {
    pub const NAME = "zwp_tablet_v2";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "zwp_tablet_v2_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "zwp_tablet_v2",
        .version = 1,
        .requests = &zwp_tablet_v2.REQUESTS,
        .request_count = zwp_tablet_v2.REQUESTS.len,
        .events = &zwp_tablet_v2.EVENTS,
        .event_count = zwp_tablet_v2.EVENTS.len,
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
            .name = "name",
            .signature = "s",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "id",
            .signature = "uu",
            .types = &.{
                null,
                null,
            },
        },
        wl_message{
            .name = "path",
            .signature = "s",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "done",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "removed",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
    };

    pub const EventListener = extern struct {
        name: *const fn(?*anyopaque, *zwp_tablet_v2, name: [*:0]const u8) callconv(.c) void,
        id: *const fn(?*anyopaque, *zwp_tablet_v2, vid: u32, pid: u32) callconv(.c) void,
        path: *const fn(?*anyopaque, *zwp_tablet_v2, path: [*:0]const u8) callconv(.c) void,
        done: *const fn(?*anyopaque, *zwp_tablet_v2) callconv(.c) void,
        removed: *const fn(?*anyopaque, *zwp_tablet_v2) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = zwp_tablet_v2.INTERFACE; }
/// pad ring
///
/// 
/// A circular interaction area, such as the touch ring on the Wacom Intuos
/// Pro series tablets.
/// 
/// Events on a ring are logically grouped by the wl_tablet_pad_ring.frame
/// event.
/// 
/// 
pub const zwp_tablet_pad_ring_v2 = opaque {
    pub const NAME = "zwp_tablet_pad_ring_v2";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "zwp_tablet_pad_ring_v2_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "zwp_tablet_pad_ring_v2",
        .version = 1,
        .requests = &zwp_tablet_pad_ring_v2.REQUESTS,
        .request_count = zwp_tablet_pad_ring_v2.REQUESTS.len,
        .events = &zwp_tablet_pad_ring_v2.EVENTS,
        .event_count = zwp_tablet_pad_ring_v2.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "set_feedback",
            .signature = "su",
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
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "source",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "angle",
            .signature = "f",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "stop",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "frame",
            .signature = "u",
            .types = &.{
                null,
            },
        },
    };

        pub const Source = enum(wire.Uint) {
            finger = 1,
        };

    pub const EventListener = extern struct {
        source: *const fn(?*anyopaque, *zwp_tablet_pad_ring_v2, source: zwp_tablet_pad_ring_v2.Source) callconv(.c) void,
        angle: *const fn(?*anyopaque, *zwp_tablet_pad_ring_v2, degrees: wire.Fixed) callconv(.c) void,
        stop: *const fn(?*anyopaque, *zwp_tablet_pad_ring_v2) callconv(.c) void,
        frame: *const fn(?*anyopaque, *zwp_tablet_pad_ring_v2, time: u32) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn set_feedback(this: *@This(), description: [*:0]const u8, serial: u32)void {
        var args: [2]wl_argument = .{            .{ .string = description },
            .{ .uint = serial },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = zwp_tablet_pad_ring_v2.INTERFACE; }
/// pad strip
///
/// 
/// A linear interaction area, such as the strips found in Wacom Cintiq
/// models.
/// 
/// Events on a strip are logically grouped by the wl_tablet_pad_strip.frame
/// event.
/// 
/// 
pub const zwp_tablet_pad_strip_v2 = opaque {
    pub const NAME = "zwp_tablet_pad_strip_v2";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "zwp_tablet_pad_strip_v2_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "zwp_tablet_pad_strip_v2",
        .version = 1,
        .requests = &zwp_tablet_pad_strip_v2.REQUESTS,
        .request_count = zwp_tablet_pad_strip_v2.REQUESTS.len,
        .events = &zwp_tablet_pad_strip_v2.EVENTS,
        .event_count = zwp_tablet_pad_strip_v2.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "set_feedback",
            .signature = "su",
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
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "source",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "position",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "stop",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "frame",
            .signature = "u",
            .types = &.{
                null,
            },
        },
    };

        pub const Source = enum(wire.Uint) {
            finger = 1,
        };

    pub const EventListener = extern struct {
        source: *const fn(?*anyopaque, *zwp_tablet_pad_strip_v2, source: zwp_tablet_pad_strip_v2.Source) callconv(.c) void,
        position: *const fn(?*anyopaque, *zwp_tablet_pad_strip_v2, position: u32) callconv(.c) void,
        stop: *const fn(?*anyopaque, *zwp_tablet_pad_strip_v2) callconv(.c) void,
        frame: *const fn(?*anyopaque, *zwp_tablet_pad_strip_v2, time: u32) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn set_feedback(this: *@This(), description: [*:0]const u8, serial: u32)void {
        var args: [2]wl_argument = .{            .{ .string = description },
            .{ .uint = serial },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = zwp_tablet_pad_strip_v2.INTERFACE; }
/// a set of buttons, rings and strips
///
/// 
/// A pad group describes a distinct (sub)set of buttons, rings and strips
/// present in the tablet. The criteria of this grouping is usually positional,
/// eg. if a tablet has buttons on the left and right side, 2 groups will be
/// presented. The physical arrangement of groups is undisclosed and may
/// change on the fly.
/// 
/// Pad groups will announce their features during pad initialization. Between
/// the corresponding wp_tablet_pad.group event and wp_tablet_pad_group.done, the
/// pad group will announce the buttons, rings and strips contained in it,
/// plus the number of supported modes.
/// 
/// Modes are a mechanism to allow multiple groups of actions for every element
/// in the pad group. The number of groups and available modes in each is
/// persistent across device plugs. The current mode is user-switchable, it
/// will be announced through the wp_tablet_pad_group.mode_switch event both
/// whenever it is switched, and after wp_tablet_pad.enter.
/// 
/// The current mode logically applies to all elements in the pad group,
/// although it is at clients' discretion whether to actually perform different
/// actions, and/or issue the respective .set_feedback requests to notify the
/// compositor. See the wp_tablet_pad_group.mode_switch event for more details.
/// 
/// 
pub const zwp_tablet_pad_group_v2 = opaque {
    pub const NAME = "zwp_tablet_pad_group_v2";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "zwp_tablet_pad_group_v2_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "zwp_tablet_pad_group_v2",
        .version = 1,
        .requests = &zwp_tablet_pad_group_v2.REQUESTS,
        .request_count = zwp_tablet_pad_group_v2.REQUESTS.len,
        .events = &zwp_tablet_pad_group_v2.EVENTS,
        .event_count = zwp_tablet_pad_group_v2.EVENTS.len,
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
            .name = "buttons",
            .signature = "a",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "ring",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "zwp_tablet_pad_ring_v2_interface" }),
            },
        },
        wl_message{
            .name = "strip",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "zwp_tablet_pad_strip_v2_interface" }),
            },
        },
        wl_message{
            .name = "modes",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "done",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "mode_switch",
            .signature = "uuu",
            .types = &.{
                null,
                null,
                null,
            },
        },
    };

    pub const EventListener = extern struct {
        buttons: *const fn(?*anyopaque, *zwp_tablet_pad_group_v2, buttons: wire.Array) callconv(.c) void,
        ring: *const fn(?*anyopaque, *zwp_tablet_pad_group_v2, *zwp_tablet_pad_ring_v2) callconv(.c) void,
        strip: *const fn(?*anyopaque, *zwp_tablet_pad_group_v2, *zwp_tablet_pad_strip_v2) callconv(.c) void,
        modes: *const fn(?*anyopaque, *zwp_tablet_pad_group_v2, modes: u32) callconv(.c) void,
        done: *const fn(?*anyopaque, *zwp_tablet_pad_group_v2) callconv(.c) void,
        mode_switch: *const fn(?*anyopaque, *zwp_tablet_pad_group_v2, time: u32, serial: u32, mode: u32) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = zwp_tablet_pad_group_v2.INTERFACE; }
/// a set of buttons, rings and strips
///
/// 
/// A pad device is a set of buttons, rings and strips
/// usually physically present on the tablet device itself. Some
/// exceptions exist where the pad device is physically detached, e.g. the
/// Wacom ExpressKey Remote.
/// 
/// Pad devices have no axes that control the cursor and are generally
/// auxiliary devices to the tool devices used on the tablet surface.
/// 
/// A pad device has a number of static characteristics, e.g. the number
/// of rings. These capabilities are sent in an event sequence after the
/// wp_tablet_seat.pad_added event before any actual events from this pad.
/// This initial event sequence is terminated by a wp_tablet_pad.done
/// event.
/// 
/// All pad features (buttons, rings and strips) are logically divided into
/// groups and all pads have at least one group. The available groups are
/// notified through the wp_tablet_pad.group event; the compositor will
/// emit one event per group before emitting wp_tablet_pad.done.
/// 
/// Groups may have multiple modes. Modes allow clients to map multiple
/// actions to a single pad feature. Only one mode can be active per group,
/// although different groups may have different active modes.
/// 
/// 
pub const zwp_tablet_pad_v2 = opaque {
    pub const NAME = "zwp_tablet_pad_v2";
    pub const VERSION = 1;

    comptime {
        @export(INTERFACE, .{ .name = "zwp_tablet_pad_v2_interface" });
    }

    pub const INTERFACE: *const wl_interface = &.{
        .name = "zwp_tablet_pad_v2",
        .version = 1,
        .requests = &zwp_tablet_pad_v2.REQUESTS,
        .request_count = zwp_tablet_pad_v2.REQUESTS.len,
        .events = &zwp_tablet_pad_v2.EVENTS,
        .event_count = zwp_tablet_pad_v2.EVENTS.len,
    };

    pub const REQUESTS = [_]wl_message{
        wl_message{
            .name = "set_feedback",
            .signature = "usu",
            .types = &.{
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
    };

    pub const EVENTS = [_]wl_message{
        wl_message{
            .name = "group",
            .signature = "n",
            .types = &.{
                @extern(?*const wl_interface, .{ .name = "zwp_tablet_pad_group_v2_interface" }),
            },
        },
        wl_message{
            .name = "path",
            .signature = "s",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "buttons",
            .signature = "u",
            .types = &.{
                null,
            },
        },
        wl_message{
            .name = "done",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
        wl_message{
            .name = "button",
            .signature = "uuu",
            .types = &.{
                null,
                null,
                null,
            },
        },
        wl_message{
            .name = "enter",
            .signature = "uoo",
            .types = &.{
                null,
                @extern(?*const wl_interface, .{ .name = "zwp_tablet_v2_interface" }),
                @extern(?*const wl_interface, .{ .name = "wl_surface_interface" }),
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
            .name = "removed",
            .signature = "",
            .types = &[0]?*const wl_interface{},
        },
    };

        pub const ButtonState = enum(wire.Uint) {
            released = 0,
            pressed = 1,
        };

    pub const EventListener = extern struct {
        group: *const fn(?*anyopaque, *zwp_tablet_pad_v2, *zwp_tablet_pad_group_v2) callconv(.c) void,
        path: *const fn(?*anyopaque, *zwp_tablet_pad_v2, path: [*:0]const u8) callconv(.c) void,
        buttons: *const fn(?*anyopaque, *zwp_tablet_pad_v2, buttons: u32) callconv(.c) void,
        done: *const fn(?*anyopaque, *zwp_tablet_pad_v2) callconv(.c) void,
        button: *const fn(?*anyopaque, *zwp_tablet_pad_v2, time: u32, button: u32, state: zwp_tablet_pad_v2.ButtonState) callconv(.c) void,
        enter: *const fn(?*anyopaque, *zwp_tablet_pad_v2, serial: u32, tablet: *tablet_v2.zwp_tablet_v2, surface: *wayland.wl_surface) callconv(.c) void,
        leave: *const fn(?*anyopaque, *zwp_tablet_pad_v2, serial: u32, surface: *wayland.wl_surface) callconv(.c) void,
        removed: *const fn(?*anyopaque, *zwp_tablet_pad_v2) callconv(.c) void,
    };

    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
    }

    pub fn set_feedback(this: *@This(), button: u32, description: [*:0]const u8, serial: u32)void {
        var args: [3]wl_argument = .{            .{ .uint = button },
            .{ .string = description },
            .{ .uint = serial },
        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 0, null, wl_proxy_get_version(@ptrCast(this)), .{}, &args        );
    }

    pub fn destroy(this: *@This())void {
        var args: [0]wl_argument = .{        };

        _ = wl_proxy_marshal_array_flags(@ptrCast(this), 1, null, wl_proxy_get_version(@ptrCast(this)), .{ .destroy = true }, &args        );
    }

};

comptime { _ = zwp_tablet_pad_v2.INTERFACE; }
const tablet_v2 = @This();
const wayland = @This();
const presentation_time = @This();
const xdg_shell = @This();
const linux_dmabuf_v1 = @This();
const wl_display = @import("core").wl_display;
const wl_registry = @import("core").wl_registry;
const wl_callback = @import("core").wl_callback;
const wl_compositor = @import("core").wl_compositor;
const wl_shm_pool = @import("core").wl_shm_pool;
const wl_shm = @import("core").wl_shm;
const wl_buffer = @import("core").wl_buffer;
const wl_data_offer = @import("core").wl_data_offer;
const wl_data_source = @import("core").wl_data_source;
const wl_data_device = @import("core").wl_data_device;
const wl_data_device_manager = @import("core").wl_data_device_manager;
const wl_shell = @import("core").wl_shell;
const wl_shell_surface = @import("core").wl_shell_surface;
const wl_surface = @import("core").wl_surface;
const wl_seat = @import("core").wl_seat;
const wl_pointer = @import("core").wl_pointer;
const wl_keyboard = @import("core").wl_keyboard;
const wl_touch = @import("core").wl_touch;
const wl_output = @import("core").wl_output;
const wl_region = @import("core").wl_region;
const wl_subcompositor = @import("core").wl_subcompositor;
const wl_subsurface = @import("core").wl_subsurface;
