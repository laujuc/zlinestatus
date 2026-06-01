// 
// Copyright © 2017 Drew DeVault
// 
// Permission to use, copy, modify, distribute, and sell this
// software and its documentation for any purpose is hereby granted
// without fee, provided that the above copyright notice appear in
// all copies and that both that copyright notice and this permission
// notice appear in supporting documentation, and that the name of
// the copyright holders not be used in advertising or publicity
// pertaining to distribution of the software without specific,
// written prior permission.  The copyright holders make no
// representations about the suitability of this software for any
// purpose.  It is provided "as is" without express or implied
// warranty.
// 
// THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS
// SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS, IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
// SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
// AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
// ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
// THIS SOFTWARE.
// 
// 

const wire = @import("wire");
/// create surfaces that are layers of the desktop
///
/// 
/// Clients can use this interface to assign the surface_layer role to
/// wl_surfaces. Such surfaces are assigned to a "layer" of the output and
/// rendered with a defined z-depth respective to each other. They may also be
/// anchored to the edges and corners of a screen and specify input handling
/// semantics. This interface should be suitable for the implementation of
/// many desktop shell components, and a broad number of other applications
/// that interact with the desktop.
/// 
/// 
pub const zwlr_layer_shell_v1 = enum(u32) {
    _,

    pub const NAME = "zwlr_layer_shell_v1";
    pub const VERSION = 4;

    pub const Request = union(enum) {
        get_layer_surface: Request.GetLayerSurface,
        destroy: Request.Destroy,

        /// create a layer_surface from a surface
        ///
        /// 
        /// Create a layer surface for an existing surface. This assigns the role of
        /// layer_surface, or raises a protocol error if another role is already
        /// assigned.
        /// 
        /// Creating a layer surface from a wl_surface which has a buffer attached
        /// or committed is a client error, and any attempts by a client to attach
        /// or manipulate a buffer prior to the first layer_surface.configure call
        /// must also be treated as errors.
        /// 
        /// After creating a layer_surface object and setting it up, the client
        /// must perform an initial commit without any buffer attached.
        /// The compositor will reply with a layer_surface.configure event.
        /// The client must acknowledge it and is then allowed to attach a buffer
        /// to map the surface.
        /// 
        /// You may pass NULL for output to allow the compositor to decide which
        /// output to use. Generally this will be the one that the user most
        /// recently interacted with.
        /// 
        /// Clients can specify a namespace that defines the purpose of the layer
        /// surface.
        /// 
        /// 
        pub const GetLayerSurface = struct {
            pub const NAME = "get_layer_surface";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            id: wire.NewId.WithInterface(wlr_layer_shell_unstable_v1.zwlr_layer_surface_v1),
            surface: wayland.wl_surface,
            output: ?wayland.wl_output,
            /// layer to add this surface to
            layer: zwlr_layer_shell_v1.Layer,
            /// namespace for the layer surface
            namespace: wire.String,
        };

        /// destroy the layer_shell object
        ///
        /// 
        /// This request indicates that the client will not use the layer_shell
        /// object any more. Objects that have been created through this instance
        /// are not affected.
        /// 
        /// 
        pub const Destroy = struct {
            pub const NAME = "destroy";
            pub const OPCODE = 1;
            pub const SINCE = 3;
        };

    };

    pub const Event = union(enum) {

    };

        pub const Error = enum(wire.Uint) {
            role = 0,
            invalid_layer = 1,
            already_constructed = 2,
        };

        pub const Layer = enum(wire.Uint) {
            background = 0,
            bottom = 1,
            top = 2,
            overlay = 3,
        };

    pub fn get_layer_surface(this: zwlr_layer_shell_v1, connection: *wire.Connection, surface: wayland.wl_surface, output: ?wayland.wl_output, layer: zwlr_layer_shell_v1.Layer, namespace: wire.String) !wlr_layer_shell_unstable_v1.zwlr_layer_surface_v1 {
        const new_id = try connection.createId(wlr_layer_shell_unstable_v1.zwlr_layer_surface_v1.NAME, wlr_layer_shell_unstable_v1.zwlr_layer_surface_v1.VERSION);
        errdefer connection.destroyId(new_id);
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.GetLayerSurface.OPCODE);
        try connection.writeStruct(@This().Request.GetLayerSurface, .{
            .id = @enumFromInt(@intFromEnum(new_id)),
            .surface = surface,
            .output = output,
            .layer = layer,
            .namespace = namespace,
        });
        try connection.end();
        return @enumFromInt(@intFromEnum(new_id));
    }

    pub fn destroy(this: zwlr_layer_shell_v1, connection: *wire.Connection) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Destroy.OPCODE);
        try connection.writeStruct(@This().Request.Destroy, .{
        });
        try connection.end();
    }

};

/// layer metadata interface
///
/// 
/// An interface that may be implemented by a wl_surface, for surfaces that
/// are designed to be rendered as a layer of a stacked desktop-like
/// environment.
/// 
/// Layer surface state (layer, size, anchor, exclusive zone,
/// margin, interactivity) is double-buffered, and will be applied at the
/// time wl_surface.commit of the corresponding wl_surface is called.
/// 
/// Attaching a null buffer to a layer surface unmaps it.
/// 
/// Unmapping a layer_surface means that the surface cannot be shown by the
/// compositor until it is explicitly mapped again. The layer_surface
/// returns to the state it had right after layer_shell.get_layer_surface.
/// The client can re-map the surface by performing a commit without any
/// buffer attached, waiting for a configure event and handling it as usual.
/// 
/// 
pub const zwlr_layer_surface_v1 = enum(u32) {
    _,

    pub const NAME = "zwlr_layer_surface_v1";
    pub const VERSION = 4;

    pub const Request = union(enum) {
        set_size: Request.SetSize,
        set_anchor: Request.SetAnchor,
        set_exclusive_zone: Request.SetExclusiveZone,
        set_margin: Request.SetMargin,
        set_keyboard_interactivity: Request.SetKeyboardInteractivity,
        get_popup: Request.GetPopup,
        ack_configure: Request.AckConfigure,
        destroy: Request.Destroy,
        set_layer: Request.SetLayer,

        /// sets the size of the surface
        ///
        /// 
        /// Sets the size of the surface in surface-local coordinates. The
        /// compositor will display the surface centered with respect to its
        /// anchors.
        /// 
        /// If you pass 0 for either value, the compositor will assign it and
        /// inform you of the assignment in the configure event. You must set your
        /// anchor to opposite edges in the dimensions you omit; not doing so is a
        /// protocol error. Both values are 0 by default.
        /// 
        /// Size is double-buffered, see wl_surface.commit.
        /// 
        /// 
        pub const SetSize = struct {
            pub const NAME = "set_size";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            width: wire.Uint,
            height: wire.Uint,
        };

        /// configures the anchor point of the surface
        ///
        /// 
        /// Requests that the compositor anchor the surface to the specified edges
        /// and corners. If two orthogonal edges are specified (e.g. 'top' and
        /// 'left'), then the anchor point will be the intersection of the edges
        /// (e.g. the top left corner of the output); otherwise the anchor point
        /// will be centered on that edge, or in the center if none is specified.
        /// 
        /// Anchor is double-buffered, see wl_surface.commit.
        /// 
        /// 
        pub const SetAnchor = struct {
            pub const NAME = "set_anchor";
            pub const OPCODE = 1;
            pub const SINCE = 0;

            anchor: zwlr_layer_surface_v1.Anchor,
        };

        /// configures the exclusive geometry of this surface
        ///
        /// 
        /// Requests that the compositor avoids occluding an area with other
        /// surfaces. The compositor's use of this information is
        /// implementation-dependent - do not assume that this region will not
        /// actually be occluded.
        /// 
        /// A positive value is only meaningful if the surface is anchored to one
        /// edge or an edge and both perpendicular edges. If the surface is not
        /// anchored, anchored to only two perpendicular edges (a corner), anchored
        /// to only two parallel edges or anchored to all edges, a positive value
        /// will be treated the same as zero.
        /// 
        /// A positive zone is the distance from the edge in surface-local
        /// coordinates to consider exclusive.
        /// 
        /// Surfaces that do not wish to have an exclusive zone may instead specify
        /// how they should interact with surfaces that do. If set to zero, the
        /// surface indicates that it would like to be moved to avoid occluding
        /// surfaces with a positive exclusive zone. If set to -1, the surface
        /// indicates that it would not like to be moved to accommodate for other
        /// surfaces, and the compositor should extend it all the way to the edges
        /// it is anchored to.
        /// 
        /// For example, a panel might set its exclusive zone to 10, so that
        /// maximized shell surfaces are not shown on top of it. A notification
        /// might set its exclusive zone to 0, so that it is moved to avoid
        /// occluding the panel, but shell surfaces are shown underneath it. A
        /// wallpaper or lock screen might set their exclusive zone to -1, so that
        /// they stretch below or over the panel.
        /// 
        /// The default value is 0.
        /// 
        /// Exclusive zone is double-buffered, see wl_surface.commit.
        /// 
        /// 
        pub const SetExclusiveZone = struct {
            pub const NAME = "set_exclusive_zone";
            pub const OPCODE = 2;
            pub const SINCE = 0;

            zone: wire.Int,
        };

        /// sets a margin from the anchor point
        ///
        /// 
        /// Requests that the surface be placed some distance away from the anchor
        /// point on the output, in surface-local coordinates. Setting this value
        /// for edges you are not anchored to has no effect.
        /// 
        /// The exclusive zone includes the margin.
        /// 
        /// Margin is double-buffered, see wl_surface.commit.
        /// 
        /// 
        pub const SetMargin = struct {
            pub const NAME = "set_margin";
            pub const OPCODE = 3;
            pub const SINCE = 0;

            top: wire.Int,
            right: wire.Int,
            bottom: wire.Int,
            left: wire.Int,
        };

        /// requests keyboard events
        ///
        /// 
        /// Set how keyboard events are delivered to this surface. By default,
        /// layer shell surfaces do not receive keyboard events; this request can
        /// be used to change this.
        /// 
        /// This setting is inherited by child surfaces set by the get_popup
        /// request.
        /// 
        /// Layer surfaces receive pointer, touch, and tablet events normally. If
        /// you do not want to receive them, set the input region on your surface
        /// to an empty region.
        /// 
        /// Keyboard interactivity is double-buffered, see wl_surface.commit.
        /// 
        /// 
        pub const SetKeyboardInteractivity = struct {
            pub const NAME = "set_keyboard_interactivity";
            pub const OPCODE = 4;
            pub const SINCE = 0;

            keyboard_interactivity: zwlr_layer_surface_v1.KeyboardInteractivity,
        };

        /// assign this layer_surface as an xdg_popup parent
        ///
        /// 
        /// This assigns an xdg_popup's parent to this layer_surface.  This popup
        /// should have been created via xdg_surface::get_popup with the parent set
        /// to NULL, and this request must be invoked before committing the popup's
        /// initial state.
        /// 
        /// See the documentation of xdg_popup for more details about what an
        /// xdg_popup is and how it is used.
        /// 
        /// 
        pub const GetPopup = struct {
            pub const NAME = "get_popup";
            pub const OPCODE = 5;
            pub const SINCE = 0;

            popup: xdg_shell.xdg_popup,
        };

        /// ack a configure event
        ///
        /// 
        /// When a configure event is received, if a client commits the
        /// surface in response to the configure event, then the client
        /// must make an ack_configure request sometime before the commit
        /// request, passing along the serial of the configure event.
        /// 
        /// If the client receives multiple configure events before it
        /// can respond to one, it only has to ack the last configure event.
        /// 
        /// A client is not required to commit immediately after sending
        /// an ack_configure request - it may even ack_configure several times
        /// before its next surface commit.
        /// 
        /// A client may send multiple ack_configure requests before committing, but
        /// only the last request sent before a commit indicates which configure
        /// event the client really is responding to.
        /// 
        /// 
        pub const AckConfigure = struct {
            pub const NAME = "ack_configure";
            pub const OPCODE = 6;
            pub const SINCE = 0;

            /// the serial from the configure event
            serial: wire.Uint,
        };

        /// destroy the layer_surface
        ///
        /// 
        /// This request destroys the layer surface.
        /// 
        /// 
        pub const Destroy = struct {
            pub const NAME = "destroy";
            pub const OPCODE = 7;
            pub const SINCE = 0;
        };

        /// change the layer of the surface
        ///
        /// 
        /// Change the layer that the surface is rendered on.
        /// 
        /// Layer is double-buffered, see wl_surface.commit.
        /// 
        /// 
        pub const SetLayer = struct {
            pub const NAME = "set_layer";
            pub const OPCODE = 8;
            pub const SINCE = 2;

            /// layer to move this surface to
            layer: zwlr_layer_shell_v1.Layer,
        };

    };

    pub const Event = union(enum) {
        configure: Event.Configure,
        closed: Event.Closed,

        /// suggest a surface change
        ///
        /// 
        /// The configure event asks the client to resize its surface.
        /// 
        /// Clients should arrange their surface for the new states, and then send
        /// an ack_configure request with the serial sent in this configure event at
        /// some point before committing the new surface.
        /// 
        /// The client is free to dismiss all but the last configure event it
        /// received.
        /// 
        /// The width and height arguments specify the size of the window in
        /// surface-local coordinates.
        /// 
        /// The size is a hint, in the sense that the client is free to ignore it if
        /// it doesn't resize, pick a smaller size (to satisfy aspect ratio or
        /// resize in steps of NxM pixels). If the client picks a smaller size and
        /// is anchored to two opposite anchors (e.g. 'top' and 'bottom'), the
        /// surface will be centered on this axis.
        /// 
        /// If the width or height arguments are zero, it means the client should
        /// decide its own window dimension.
        /// 
        /// 
        pub const Configure = struct {
            pub const NAME = "configure";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            serial: wire.Uint,
            width: wire.Uint,
            height: wire.Uint,
        };

        /// surface should be closed
        ///
        /// 
        /// The closed event is sent by the compositor when the surface will no
        /// longer be shown. The output may have been destroyed or the user may
        /// have asked for it to be removed. Further changes to the surface will be
        /// ignored. The client should destroy the resource after receiving this
        /// event, and create a new surface if they so choose.
        /// 
        /// 
        pub const Closed = struct {
            pub const NAME = "closed";
            pub const OPCODE = 1;
            pub const SINCE = 0;
        };

    };

        pub const KeyboardInteractivity = enum(wire.Uint) {
            /// no keyboard focus is possible
            ///
            /// 
            /// This value indicates that this surface is not interested in keyboard
            /// events and the compositor should never assign it the keyboard focus.
            /// 
            /// This is the default value, set for newly created layer shell surfaces.
            /// 
            /// This is useful for e.g. desktop widgets that display information or
            /// only have interaction with non-keyboard input devices.
            /// 
            /// 
            none = 0,
            /// request exclusive keyboard focus
            ///
            /// 
            /// Request exclusive keyboard focus if this surface is above the shell surface layer.
            /// 
            /// For the top and overlay layers, the seat will always give
            /// exclusive keyboard focus to the top-most layer which has keyboard
            /// interactivity set to exclusive. If this layer contains multiple
            /// surfaces with keyboard interactivity set to exclusive, the compositor
            /// determines the one receiving keyboard events in an implementation-
            /// defined manner. In this case, no guarantee is made when this surface
            /// will receive keyboard focus (if ever).
            /// 
            /// For the bottom and background layers, the compositor is allowed to use
            /// normal focus semantics.
            /// 
            /// This setting is mainly intended for applications that need to ensure
            /// they receive all keyboard events, such as a lock screen or a password
            /// prompt.
            /// 
            /// 
            exclusive = 1,
            /// request regular keyboard focus semantics
            ///
            /// 
            /// This requests the compositor to allow this surface to be focused and
            /// unfocused by the user in an implementation-defined manner. The user
            /// should be able to unfocus this surface even regardless of the layer
            /// it is on.
            /// 
            /// Typically, the compositor will want to use its normal mechanism to
            /// manage keyboard focus between layer shell surfaces with this setting
            /// and regular toplevels on the desktop layer (e.g. click to focus).
            /// Nevertheless, it is possible for a compositor to require a special
            /// interaction to focus or unfocus layer shell surfaces (e.g. requiring
            /// a click even if focus follows the mouse normally, or providing a
            /// keybinding to switch focus between layers).
            /// 
            /// This setting is mainly intended for desktop shell components (e.g.
            /// panels) that allow keyboard interaction. Using this option can allow
            /// implementing a desktop shell that can be fully usable without the
            /// mouse.
            /// 
            /// 
            on_demand = 2,
        };

        pub const Error = enum(wire.Uint) {
            invalid_surface_state = 0,
            invalid_size = 1,
            invalid_anchor = 2,
            invalid_keyboard_interactivity = 3,
        };

        pub const Anchor = packed struct(wire.Uint) {
            top: bool,
            bottom: bool,
            left: bool,
            right: bool,
            padding_1: u28 = 0,
        };

    pub fn set_size(this: zwlr_layer_surface_v1, connection: *wire.Connection, width: wire.Uint, height: wire.Uint) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.SetSize.OPCODE);
        try connection.writeStruct(@This().Request.SetSize, .{
            .width = width,
            .height = height,
        });
        try connection.end();
    }

    pub fn set_anchor(this: zwlr_layer_surface_v1, connection: *wire.Connection, anchor: zwlr_layer_surface_v1.Anchor) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.SetAnchor.OPCODE);
        try connection.writeStruct(@This().Request.SetAnchor, .{
            .anchor = anchor,
        });
        try connection.end();
    }

    pub fn set_exclusive_zone(this: zwlr_layer_surface_v1, connection: *wire.Connection, zone: wire.Int) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.SetExclusiveZone.OPCODE);
        try connection.writeStruct(@This().Request.SetExclusiveZone, .{
            .zone = zone,
        });
        try connection.end();
    }

    pub fn set_margin(this: zwlr_layer_surface_v1, connection: *wire.Connection, top: wire.Int, right: wire.Int, bottom: wire.Int, left: wire.Int) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.SetMargin.OPCODE);
        try connection.writeStruct(@This().Request.SetMargin, .{
            .top = top,
            .right = right,
            .bottom = bottom,
            .left = left,
        });
        try connection.end();
    }

    pub fn set_keyboard_interactivity(this: zwlr_layer_surface_v1, connection: *wire.Connection, keyboard_interactivity: zwlr_layer_surface_v1.KeyboardInteractivity) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.SetKeyboardInteractivity.OPCODE);
        try connection.writeStruct(@This().Request.SetKeyboardInteractivity, .{
            .keyboard_interactivity = keyboard_interactivity,
        });
        try connection.end();
    }

    pub fn get_popup(this: zwlr_layer_surface_v1, connection: *wire.Connection, popup: xdg_shell.xdg_popup) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.GetPopup.OPCODE);
        try connection.writeStruct(@This().Request.GetPopup, .{
            .popup = popup,
        });
        try connection.end();
    }

    pub fn ack_configure(this: zwlr_layer_surface_v1, connection: *wire.Connection, serial: wire.Uint) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.AckConfigure.OPCODE);
        try connection.writeStruct(@This().Request.AckConfigure, .{
            .serial = serial,
        });
        try connection.end();
    }

    pub fn destroy(this: zwlr_layer_surface_v1, connection: *wire.Connection) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Destroy.OPCODE);
        try connection.writeStruct(@This().Request.Destroy, .{
        });
        try connection.end();
    }

    pub fn set_layer(this: zwlr_layer_surface_v1, connection: *wire.Connection, layer: zwlr_layer_shell_v1.Layer) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.SetLayer.OPCODE);
        try connection.writeStruct(@This().Request.SetLayer, .{
            .layer = layer,
        });
        try connection.end();
    }

};

const wlr_layer_shell_unstable_v1 = @This();
const wayland = @import("wayland.zig");
const xdg_shell = @import("xdg-shell.zig");
