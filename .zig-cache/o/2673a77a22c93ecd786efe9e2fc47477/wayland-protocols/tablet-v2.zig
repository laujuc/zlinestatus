// 
// Copyright 2014 © Stephen "Lyude" Chandler Paul
// Copyright 2015-2016 © Red Hat, Inc.
// 
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation files
// (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge,
// publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
// 
// The above copyright notice and this permission notice (including the
// next paragraph) shall be included in all copies or substantial
// portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// 
// 

const wire = @import("wire");
/// controller object for graphic tablet devices
///
/// 
/// An object that provides access to the graphics tablets available on this
/// system. All tablets are associated with a seat, to get access to the
/// actual tablets, use wp_tablet_manager.get_tablet_seat.
/// 
/// 
pub const zwp_tablet_manager_v2 = enum(u32) {
    _,

    pub const NAME = "zwp_tablet_manager_v2";
    pub const VERSION = 1;

    pub const Request = union(enum) {
        get_tablet_seat: Request.GetTabletSeat,
        destroy: Request.Destroy,

        /// get the tablet seat
        ///
        /// 
        /// Get the wp_tablet_seat object for the given seat. This object
        /// provides access to all graphics tablets in this seat.
        /// 
        /// 
        pub const GetTabletSeat = struct {
            pub const NAME = "get_tablet_seat";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            tablet_seat: wire.NewId.WithInterface(tablet_v2.zwp_tablet_seat_v2),
            /// The wl_seat object to retrieve the tablets for
            seat: wayland.wl_seat,
        };

        /// release the memory for the tablet manager object
        ///
        /// 
        /// Destroy the wp_tablet_manager object. Objects created from this
        /// object are unaffected and should be destroyed separately.
        /// 
        /// 
        pub const Destroy = struct {
            pub const NAME = "destroy";
            pub const OPCODE = 1;
            pub const SINCE = 0;
        };

    };

    pub const Event = union(enum) {

    };

    pub fn get_tablet_seat(this: zwp_tablet_manager_v2, connection: *wire.Connection, seat: wayland.wl_seat) !tablet_v2.zwp_tablet_seat_v2 {
        const new_id = try connection.createId(tablet_v2.zwp_tablet_seat_v2.NAME, tablet_v2.zwp_tablet_seat_v2.VERSION);
        errdefer connection.destroyId(new_id);
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.GetTabletSeat.OPCODE);
        try connection.writeStruct(@This().Request.GetTabletSeat, .{
            .tablet_seat = @enumFromInt(@intFromEnum(new_id)),
            .seat = seat,
        });
        try connection.end();
        return @enumFromInt(@intFromEnum(new_id));
    }

    pub fn destroy(this: zwp_tablet_manager_v2, connection: *wire.Connection) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Destroy.OPCODE);
        try connection.writeStruct(@This().Request.Destroy, .{
        });
        try connection.end();
    }

};

/// controller object for graphic tablet devices of a seat
///
/// 
/// An object that provides access to the graphics tablets available on this
/// seat. After binding to this interface, the compositor sends a set of
/// wp_tablet_seat.tablet_added and wp_tablet_seat.tool_added events.
/// 
/// 
pub const zwp_tablet_seat_v2 = enum(u32) {
    _,

    pub const NAME = "zwp_tablet_seat_v2";
    pub const VERSION = 1;

    pub const Request = union(enum) {
        destroy: Request.Destroy,

        /// release the memory for the tablet seat object
        ///
        /// 
        /// Destroy the wp_tablet_seat object. Objects created from this
        /// object are unaffected and should be destroyed separately.
        /// 
        /// 
        pub const Destroy = struct {
            pub const NAME = "destroy";
            pub const OPCODE = 0;
            pub const SINCE = 0;
        };

    };

    pub const Event = union(enum) {
        tablet_added: Event.TabletAdded,
        tool_added: Event.ToolAdded,
        pad_added: Event.PadAdded,

        /// new device notification
        ///
        /// 
        /// This event is sent whenever a new tablet becomes available on this
        /// seat. This event only provides the object id of the tablet, any
        /// static information about the tablet (device name, vid/pid, etc.) is
        /// sent through the wp_tablet interface.
        /// 
        /// 
        pub const TabletAdded = struct {
            pub const NAME = "tablet_added";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            /// the newly added graphics tablet
            id: wire.NewId.WithInterface(tablet_v2.zwp_tablet_v2),
        };

        /// a new tool has been used with a tablet
        ///
        /// 
        /// This event is sent whenever a tool that has not previously been used
        /// with a tablet comes into use. This event only provides the object id
        /// of the tool; any static information about the tool (capabilities,
        /// type, etc.) is sent through the wp_tablet_tool interface.
        /// 
        /// 
        pub const ToolAdded = struct {
            pub const NAME = "tool_added";
            pub const OPCODE = 1;
            pub const SINCE = 0;

            /// the newly added tablet tool
            id: wire.NewId.WithInterface(tablet_v2.zwp_tablet_tool_v2),
        };

        /// new pad notification
        ///
        /// 
        /// This event is sent whenever a new pad is known to the system. Typically,
        /// pads are physically attached to tablets and a pad_added event is
        /// sent immediately after the wp_tablet_seat.tablet_added.
        /// However, some standalone pad devices logically attach to tablets at
        /// runtime, and the client must wait for wp_tablet_pad.enter to know
        /// the tablet a pad is attached to.
        /// 
        /// This event only provides the object id of the pad. All further
        /// features (buttons, strips, rings) are sent through the wp_tablet_pad
        /// interface.
        /// 
        /// 
        pub const PadAdded = struct {
            pub const NAME = "pad_added";
            pub const OPCODE = 2;
            pub const SINCE = 0;

            /// the newly added pad
            id: wire.NewId.WithInterface(tablet_v2.zwp_tablet_pad_v2),
        };

    };

    pub fn destroy(this: zwp_tablet_seat_v2, connection: *wire.Connection) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Destroy.OPCODE);
        try connection.writeStruct(@This().Request.Destroy, .{
        });
        try connection.end();
    }

};

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
pub const zwp_tablet_tool_v2 = enum(u32) {
    _,

    pub const NAME = "zwp_tablet_tool_v2";
    pub const VERSION = 1;

    pub const Request = union(enum) {
        set_cursor: Request.SetCursor,
        destroy: Request.Destroy,

        /// set the tablet tool's surface
        ///
        /// 
        /// Sets the surface of the cursor used for this tool on the given
        /// tablet. This request only takes effect if the tool is in proximity
        /// of one of the requesting client's surfaces or the surface parameter
        /// is the current pointer surface. If there was a previous surface set
        /// with this request it is replaced. If surface is NULL, the cursor
        /// image is hidden.
        /// 
        /// The parameters hotspot_x and hotspot_y define the position of the
        /// pointer surface relative to the pointer location. Its top-left corner
        /// is always at (x, y) - (hotspot_x, hotspot_y), where (x, y) are the
        /// coordinates of the pointer location, in surface-local coordinates.
        /// 
        /// On surface.attach requests to the pointer surface, hotspot_x and
        /// hotspot_y are decremented by the x and y parameters passed to the
        /// request. Attach must be confirmed by wl_surface.commit as usual.
        /// 
        /// The hotspot can also be updated by passing the currently set pointer
        /// surface to this request with new values for hotspot_x and hotspot_y.
        /// 
        /// The current and pending input regions of the wl_surface are cleared,
        /// and wl_surface.set_input_region is ignored until the wl_surface is no
        /// longer used as the cursor. When the use as a cursor ends, the current
        /// and pending input regions become undefined, and the wl_surface is
        /// unmapped.
        /// 
        /// This request gives the surface the role of a wp_tablet_tool cursor. A
        /// surface may only ever be used as the cursor surface for one
        /// wp_tablet_tool. If the surface already has another role or has
        /// previously been used as cursor surface for a different tool, a
        /// protocol error is raised.
        /// 
        /// 
        pub const SetCursor = struct {
            pub const NAME = "set_cursor";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            /// serial of the proximity_in event
            serial: wire.Uint,
            surface: ?wayland.wl_surface,
            /// surface-local x coordinate
            hotspot_x: wire.Int,
            /// surface-local y coordinate
            hotspot_y: wire.Int,
        };

        /// destroy the tool object
        ///
        /// 
        /// This destroys the client's resource for this tool object.
        /// 
        /// 
        pub const Destroy = struct {
            pub const NAME = "destroy";
            pub const OPCODE = 1;
            pub const SINCE = 0;
        };

    };

    pub const Event = union(enum) {
        @"type": Event.Type,
        hardware_serial: Event.HardwareSerial,
        hardware_id_wacom: Event.HardwareIdWacom,
        capability: Event.Capability,
        done: Event.Done,
        removed: Event.Removed,
        proximity_in: Event.ProximityIn,
        proximity_out: Event.ProximityOut,
        down: Event.Down,
        up: Event.Up,
        motion: Event.Motion,
        pressure: Event.Pressure,
        distance: Event.Distance,
        tilt: Event.Tilt,
        rotation: Event.Rotation,
        slider: Event.Slider,
        wheel: Event.Wheel,
        button: Event.Button,
        frame: Event.Frame,

        /// tool type
        ///
        /// 
        /// The tool type is the high-level type of the tool and usually decides
        /// the interaction expected from this tool.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_tool.done event.
        /// 
        /// 
        pub const Type = struct {
            pub const NAME = "type";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            /// the physical tool type
            tool_type: zwp_tablet_tool_v2.Type,
        };

        /// unique hardware serial number of the tool
        ///
        /// 
        /// If the physical tool can be identified by a unique 64-bit serial
        /// number, this event notifies the client of this serial number.
        /// 
        /// If multiple tablets are available in the same seat and the tool is
        /// uniquely identifiable by the serial number, that tool may move
        /// between tablets.
        /// 
        /// Otherwise, if the tool has no serial number and this event is
        /// missing, the tool is tied to the tablet it first comes into
        /// proximity with. Even if the physical tool is used on multiple
        /// tablets, separate wp_tablet_tool objects will be created, one per
        /// tablet.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_tool.done event.
        /// 
        /// 
        pub const HardwareSerial = struct {
            pub const NAME = "hardware_serial";
            pub const OPCODE = 1;
            pub const SINCE = 0;

            /// the unique serial number of the tool, most significant bits
            hardware_serial_hi: wire.Uint,
            /// the unique serial number of the tool, least significant bits
            hardware_serial_lo: wire.Uint,
        };

        /// hardware id notification in Wacom's format
        ///
        /// 
        /// This event notifies the client of a hardware id available on this tool.
        /// 
        /// The hardware id is a device-specific 64-bit id that provides extra
        /// information about the tool in use, beyond the wl_tool.type
        /// enumeration. The format of the id is specific to tablets made by
        /// Wacom Inc. For example, the hardware id of a Wacom Grip
        /// Pen (a stylus) is 0x802.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_tool.done event.
        /// 
        /// 
        pub const HardwareIdWacom = struct {
            pub const NAME = "hardware_id_wacom";
            pub const OPCODE = 2;
            pub const SINCE = 0;

            /// the hardware id, most significant bits
            hardware_id_hi: wire.Uint,
            /// the hardware id, least significant bits
            hardware_id_lo: wire.Uint,
        };

        /// tool capability notification
        ///
        /// 
        /// This event notifies the client of any capabilities of this tool,
        /// beyond the main set of x/y axes and tip up/down detection.
        /// 
        /// One event is sent for each extra capability available on this tool.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_tool.done event.
        /// 
        /// 
        pub const Capability = struct {
            pub const NAME = "capability";
            pub const OPCODE = 3;
            pub const SINCE = 0;

            /// the capability
            capability: zwp_tablet_tool_v2.Capability,
        };

        /// tool description events sequence complete
        ///
        /// 
        /// This event signals the end of the initial burst of descriptive
        /// events. A client may consider the static description of the tool to
        /// be complete and finalize initialization of the tool.
        /// 
        /// 
        pub const Done = struct {
            pub const NAME = "done";
            pub const OPCODE = 4;
            pub const SINCE = 0;
        };

        /// tool removed
        ///
        /// 
        /// This event is sent when the tool is removed from the system and will
        /// send no further events. Should the physical tool come back into
        /// proximity later, a new wp_tablet_tool object will be created.
        /// 
        /// It is compositor-dependent when a tool is removed. A compositor may
        /// remove a tool on proximity out, tablet removal or any other reason.
        /// A compositor may also keep a tool alive until shutdown.
        /// 
        /// If the tool is currently in proximity, a proximity_out event will be
        /// sent before the removed event. See wp_tablet_tool.proximity_out for
        /// the handling of any buttons logically down.
        /// 
        /// When this event is received, the client must wp_tablet_tool.destroy
        /// the object.
        /// 
        /// 
        pub const Removed = struct {
            pub const NAME = "removed";
            pub const OPCODE = 5;
            pub const SINCE = 0;
        };

        /// proximity in event
        ///
        /// 
        /// Notification that this tool is focused on a certain surface.
        /// 
        /// This event can be received when the tool has moved from one surface to
        /// another, or when the tool has come back into proximity above the
        /// surface.
        /// 
        /// If any button is logically down when the tool comes into proximity,
        /// the respective button event is sent after the proximity_in event but
        /// within the same frame as the proximity_in event.
        /// 
        /// 
        pub const ProximityIn = struct {
            pub const NAME = "proximity_in";
            pub const OPCODE = 6;
            pub const SINCE = 0;

            serial: wire.Uint,
            /// The tablet the tool is in proximity of
            tablet: tablet_v2.zwp_tablet_v2,
            /// The current surface the tablet tool is over
            surface: wayland.wl_surface,
        };

        /// proximity out event
        ///
        /// 
        /// Notification that this tool has either left proximity, or is no
        /// longer focused on a certain surface.
        /// 
        /// When the tablet tool leaves proximity of the tablet, button release
        /// events are sent for each button that was held down at the time of
        /// leaving proximity. These events are sent before the proximity_out
        /// event but within the same wp_tablet.frame.
        /// 
        /// If the tool stays within proximity of the tablet, but the focus
        /// changes from one surface to another, a button release event may not
        /// be sent until the button is actually released or the tool leaves the
        /// proximity of the tablet.
        /// 
        /// 
        pub const ProximityOut = struct {
            pub const NAME = "proximity_out";
            pub const OPCODE = 7;
            pub const SINCE = 0;
        };

        /// tablet tool is making contact
        ///
        /// 
        /// Sent whenever the tablet tool comes in contact with the surface of the
        /// tablet.
        /// 
        /// If the tool is already in contact with the tablet when entering the
        /// input region, the client owning said region will receive a
        /// wp_tablet.proximity_in event, followed by a wp_tablet.down
        /// event and a wp_tablet.frame event.
        /// 
        /// Note that this event describes logical contact, not physical
        /// contact. On some devices, a compositor may not consider a tool in
        /// logical contact until a minimum physical pressure threshold is
        /// exceeded.
        /// 
        /// 
        pub const Down = struct {
            pub const NAME = "down";
            pub const OPCODE = 8;
            pub const SINCE = 0;

            serial: wire.Uint,
        };

        /// tablet tool is no longer making contact
        ///
        /// 
        /// Sent whenever the tablet tool stops making contact with the surface of
        /// the tablet, or when the tablet tool moves out of the input region
        /// and the compositor grab (if any) is dismissed.
        /// 
        /// If the tablet tool moves out of the input region while in contact
        /// with the surface of the tablet and the compositor does not have an
        /// ongoing grab on the surface, the client owning said region will
        /// receive a wp_tablet.up event, followed by a wp_tablet.proximity_out
        /// event and a wp_tablet.frame event. If the compositor has an ongoing
        /// grab on this device, this event sequence is sent whenever the grab
        /// is dismissed in the future.
        /// 
        /// Note that this event describes logical contact, not physical
        /// contact. On some devices, a compositor may not consider a tool out
        /// of logical contact until physical pressure falls below a specific
        /// threshold.
        /// 
        /// 
        pub const Up = struct {
            pub const NAME = "up";
            pub const OPCODE = 9;
            pub const SINCE = 0;
        };

        /// motion event
        ///
        /// 
        /// Sent whenever a tablet tool moves.
        /// 
        /// 
        pub const Motion = struct {
            pub const NAME = "motion";
            pub const OPCODE = 10;
            pub const SINCE = 0;

            /// surface-local x coordinate
            x: wire.Fixed,
            /// surface-local y coordinate
            y: wire.Fixed,
        };

        /// pressure change event
        ///
        /// 
        /// Sent whenever the pressure axis on a tool changes. The value of this
        /// event is normalized to a value between 0 and 65535.
        /// 
        /// Note that pressure may be nonzero even when a tool is not in logical
        /// contact. See the down and up events for more details.
        /// 
        /// 
        pub const Pressure = struct {
            pub const NAME = "pressure";
            pub const OPCODE = 11;
            pub const SINCE = 0;

            /// The current pressure value
            pressure: wire.Uint,
        };

        /// distance change event
        ///
        /// 
        /// Sent whenever the distance axis on a tool changes. The value of this
        /// event is normalized to a value between 0 and 65535.
        /// 
        /// Note that distance may be nonzero even when a tool is not in logical
        /// contact. See the down and up events for more details.
        /// 
        /// 
        pub const Distance = struct {
            pub const NAME = "distance";
            pub const OPCODE = 12;
            pub const SINCE = 0;

            /// The current distance value
            distance: wire.Uint,
        };

        /// tilt change event
        ///
        /// 
        /// Sent whenever one or both of the tilt axes on a tool change. Each tilt
        /// value is in degrees, relative to the z-axis of the tablet.
        /// The angle is positive when the top of a tool tilts along the
        /// positive x or y axis.
        /// 
        /// 
        pub const Tilt = struct {
            pub const NAME = "tilt";
            pub const OPCODE = 13;
            pub const SINCE = 0;

            /// The current value of the X tilt axis
            tilt_x: wire.Fixed,
            /// The current value of the Y tilt axis
            tilt_y: wire.Fixed,
        };

        /// z-rotation change event
        ///
        /// 
        /// Sent whenever the z-rotation axis on the tool changes. The
        /// rotation value is in degrees clockwise from the tool's
        /// logical neutral position.
        /// 
        /// 
        pub const Rotation = struct {
            pub const NAME = "rotation";
            pub const OPCODE = 14;
            pub const SINCE = 0;

            /// The current rotation of the Z axis
            degrees: wire.Fixed,
        };

        /// Slider position change event
        ///
        /// 
        /// Sent whenever the slider position on the tool changes. The
        /// value is normalized between -65535 and 65535, with 0 as the logical
        /// neutral position of the slider.
        /// 
        /// The slider is available on e.g. the Wacom Airbrush tool.
        /// 
        /// 
        pub const Slider = struct {
            pub const NAME = "slider";
            pub const OPCODE = 15;
            pub const SINCE = 0;

            /// The current position of slider
            position: wire.Int,
        };

        /// Wheel delta event
        ///
        /// 
        /// Sent whenever the wheel on the tool emits an event. This event
        /// contains two values for the same axis change. The degrees value is
        /// in the same orientation as the wl_pointer.vertical_scroll axis. The
        /// clicks value is in discrete logical clicks of the mouse wheel. This
        /// value may be zero if the movement of the wheel was less
        /// than one logical click.
        /// 
        /// Clients should choose either value and avoid mixing degrees and
        /// clicks. The compositor may accumulate values smaller than a logical
        /// click and emulate click events when a certain threshold is met.
        /// Thus, wl_tablet_tool.wheel events with non-zero clicks values may
        /// have different degrees values.
        /// 
        /// 
        pub const Wheel = struct {
            pub const NAME = "wheel";
            pub const OPCODE = 16;
            pub const SINCE = 0;

            /// The wheel delta in degrees
            degrees: wire.Fixed,
            /// The wheel delta in discrete clicks
            clicks: wire.Int,
        };

        /// button event
        ///
        /// 
        /// Sent whenever a button on the tool is pressed or released.
        /// 
        /// If a button is held down when the tool moves in or out of proximity,
        /// button events are generated by the compositor. See
        /// wp_tablet_tool.proximity_in and wp_tablet_tool.proximity_out for
        /// details.
        /// 
        /// 
        pub const Button = struct {
            pub const NAME = "button";
            pub const OPCODE = 17;
            pub const SINCE = 0;

            serial: wire.Uint,
            /// The button whose state has changed
            button: wire.Uint,
            /// Whether the button was pressed or released
            state: zwp_tablet_tool_v2.ButtonState,
        };

        /// frame event
        ///
        /// 
        /// Marks the end of a series of axis and/or button updates from the
        /// tablet. The Wayland protocol requires axis updates to be sent
        /// sequentially, however all events within a frame should be considered
        /// one hardware event.
        /// 
        /// 
        pub const Frame = struct {
            pub const NAME = "frame";
            pub const OPCODE = 18;
            pub const SINCE = 0;

            /// The time of the event with millisecond granularity
            time: wire.Uint,
        };

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

    pub fn set_cursor(this: zwp_tablet_tool_v2, connection: *wire.Connection, serial: wire.Uint, surface: ?wayland.wl_surface, hotspot_x: wire.Int, hotspot_y: wire.Int) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.SetCursor.OPCODE);
        try connection.writeStruct(@This().Request.SetCursor, .{
            .serial = serial,
            .surface = surface,
            .hotspot_x = hotspot_x,
            .hotspot_y = hotspot_y,
        });
        try connection.end();
    }

    pub fn destroy(this: zwp_tablet_tool_v2, connection: *wire.Connection) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Destroy.OPCODE);
        try connection.writeStruct(@This().Request.Destroy, .{
        });
        try connection.end();
    }

};

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
pub const zwp_tablet_v2 = enum(u32) {
    _,

    pub const NAME = "zwp_tablet_v2";
    pub const VERSION = 1;

    pub const Request = union(enum) {
        destroy: Request.Destroy,

        /// destroy the tablet object
        ///
        /// 
        /// This destroys the client's resource for this tablet object.
        /// 
        /// 
        pub const Destroy = struct {
            pub const NAME = "destroy";
            pub const OPCODE = 0;
            pub const SINCE = 0;
        };

    };

    pub const Event = union(enum) {
        name: Event.Name,
        id: Event.Id,
        path: Event.Path,
        done: Event.Done,
        removed: Event.Removed,

        /// tablet device name
        ///
        /// 
        /// A descriptive name for the tablet device.
        /// 
        /// If the device has no descriptive name, this event is not sent.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet.done event.
        /// 
        /// 
        pub const Name = struct {
            pub const NAME = "name";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            /// the device name
            name: wire.String,
        };

        /// tablet device USB vendor/product id
        ///
        /// 
        /// The USB vendor and product IDs for the tablet device.
        /// 
        /// If the device has no USB vendor/product ID, this event is not sent.
        /// This can happen for virtual devices or non-USB devices, for instance.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet.done event.
        /// 
        /// 
        pub const Id = struct {
            pub const NAME = "id";
            pub const OPCODE = 1;
            pub const SINCE = 0;

            /// USB vendor id
            vid: wire.Uint,
            /// USB product id
            pid: wire.Uint,
        };

        /// path to the device
        ///
        /// 
        /// A system-specific device path that indicates which device is behind
        /// this wp_tablet. This information may be used to gather additional
        /// information about the device, e.g. through libwacom.
        /// 
        /// A device may have more than one device path. If so, multiple
        /// wp_tablet.path events are sent. A device may be emulated and not
        /// have a device path, and in that case this event will not be sent.
        /// 
        /// The format of the path is unspecified, it may be a device node, a
        /// sysfs path, or some other identifier. It is up to the client to
        /// identify the string provided.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet.done event.
        /// 
        /// 
        pub const Path = struct {
            pub const NAME = "path";
            pub const OPCODE = 2;
            pub const SINCE = 0;

            /// path to local device
            path: wire.String,
        };

        /// tablet description events sequence complete
        ///
        /// 
        /// This event is sent immediately to signal the end of the initial
        /// burst of descriptive events. A client may consider the static
        /// description of the tablet to be complete and finalize initialization
        /// of the tablet.
        /// 
        /// 
        pub const Done = struct {
            pub const NAME = "done";
            pub const OPCODE = 3;
            pub const SINCE = 0;
        };

        /// tablet removed event
        ///
        /// 
        /// Sent when the tablet has been removed from the system. When a tablet
        /// is removed, some tools may be removed.
        /// 
        /// When this event is received, the client must wp_tablet.destroy
        /// the object.
        /// 
        /// 
        pub const Removed = struct {
            pub const NAME = "removed";
            pub const OPCODE = 4;
            pub const SINCE = 0;
        };

    };

    pub fn destroy(this: zwp_tablet_v2, connection: *wire.Connection) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Destroy.OPCODE);
        try connection.writeStruct(@This().Request.Destroy, .{
        });
        try connection.end();
    }

};

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
pub const zwp_tablet_pad_ring_v2 = enum(u32) {
    _,

    pub const NAME = "zwp_tablet_pad_ring_v2";
    pub const VERSION = 1;

    pub const Request = union(enum) {
        set_feedback: Request.SetFeedback,
        destroy: Request.Destroy,

        /// set compositor feedback
        ///
        /// 
        /// Request that the compositor use the provided feedback string
        /// associated with this ring. This request should be issued immediately
        /// after a wp_tablet_pad_group.mode_switch event from the corresponding
        /// group is received, or whenever the ring is mapped to a different
        /// action. See wp_tablet_pad_group.mode_switch for more details.
        /// 
        /// Clients are encouraged to provide context-aware descriptions for
        /// the actions associated with the ring; compositors may use this
        /// information to offer visual feedback about the button layout
        /// (eg. on-screen displays).
        /// 
        /// The provided string 'description' is a UTF-8 encoded string to be
        /// associated with this ring, and is considered user-visible; general
        /// internationalization rules apply.
        /// 
        /// The serial argument will be that of the last
        /// wp_tablet_pad_group.mode_switch event received for the group of this
        /// ring. Requests providing other serials than the most recent one will be
        /// ignored.
        /// 
        /// 
        pub const SetFeedback = struct {
            pub const NAME = "set_feedback";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            /// ring description
            description: wire.String,
            /// serial of the mode switch event
            serial: wire.Uint,
        };

        /// destroy the ring object
        ///
        /// 
        /// This destroys the client's resource for this ring object.
        /// 
        /// 
        pub const Destroy = struct {
            pub const NAME = "destroy";
            pub const OPCODE = 1;
            pub const SINCE = 0;
        };

    };

    pub const Event = union(enum) {
        source: Event.Source,
        angle: Event.Angle,
        stop: Event.Stop,
        frame: Event.Frame,

        /// ring event source
        ///
        /// 
        /// Source information for ring events.
        /// 
        /// This event does not occur on its own. It is sent before a
        /// wp_tablet_pad_ring.frame event and carries the source information
        /// for all events within that frame.
        /// 
        /// The source specifies how this event was generated. If the source is
        /// wp_tablet_pad_ring.source.finger, a wp_tablet_pad_ring.stop event
        /// will be sent when the user lifts the finger off the device.
        /// 
        /// This event is optional. If the source is unknown for an interaction,
        /// no event is sent.
        /// 
        /// 
        pub const Source = struct {
            pub const NAME = "source";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            /// the event source
            source: zwp_tablet_pad_ring_v2.Source,
        };

        /// angle changed
        ///
        /// 
        /// Sent whenever the angle on a ring changes.
        /// 
        /// The angle is provided in degrees clockwise from the logical
        /// north of the ring in the pad's current rotation.
        /// 
        /// 
        pub const Angle = struct {
            pub const NAME = "angle";
            pub const OPCODE = 1;
            pub const SINCE = 0;

            /// the current angle in degrees
            degrees: wire.Fixed,
        };

        /// interaction stopped
        ///
        /// 
        /// Stop notification for ring events.
        /// 
        /// For some wp_tablet_pad_ring.source types, a wp_tablet_pad_ring.stop
        /// event is sent to notify a client that the interaction with the ring
        /// has terminated. This enables the client to implement kinetic scrolling.
        /// See the wp_tablet_pad_ring.source documentation for information on
        /// when this event may be generated.
        /// 
        /// Any wp_tablet_pad_ring.angle events with the same source after this
        /// event should be considered as the start of a new interaction.
        /// 
        /// 
        pub const Stop = struct {
            pub const NAME = "stop";
            pub const OPCODE = 2;
            pub const SINCE = 0;
        };

        /// end of a ring event sequence
        ///
        /// 
        /// Indicates the end of a set of ring events that logically belong
        /// together. A client is expected to accumulate the data in all events
        /// within the frame before proceeding.
        /// 
        /// All wp_tablet_pad_ring events before a wp_tablet_pad_ring.frame event belong
        /// logically together. For example, on termination of a finger interaction
        /// on a ring the compositor will send a wp_tablet_pad_ring.source event,
        /// a wp_tablet_pad_ring.stop event and a wp_tablet_pad_ring.frame event.
        /// 
        /// A wp_tablet_pad_ring.frame event is sent for every logical event
        /// group, even if the group only contains a single wp_tablet_pad_ring
        /// event. Specifically, a client may get a sequence: angle, frame,
        /// angle, frame, etc.
        /// 
        /// 
        pub const Frame = struct {
            pub const NAME = "frame";
            pub const OPCODE = 3;
            pub const SINCE = 0;

            /// timestamp with millisecond granularity
            time: wire.Uint,
        };

    };

        pub const Source = enum(wire.Uint) {
            finger = 1,
        };

    pub fn set_feedback(this: zwp_tablet_pad_ring_v2, connection: *wire.Connection, description: wire.String, serial: wire.Uint) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.SetFeedback.OPCODE);
        try connection.writeStruct(@This().Request.SetFeedback, .{
            .description = description,
            .serial = serial,
        });
        try connection.end();
    }

    pub fn destroy(this: zwp_tablet_pad_ring_v2, connection: *wire.Connection) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Destroy.OPCODE);
        try connection.writeStruct(@This().Request.Destroy, .{
        });
        try connection.end();
    }

};

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
pub const zwp_tablet_pad_strip_v2 = enum(u32) {
    _,

    pub const NAME = "zwp_tablet_pad_strip_v2";
    pub const VERSION = 1;

    pub const Request = union(enum) {
        set_feedback: Request.SetFeedback,
        destroy: Request.Destroy,

        /// set compositor feedback
        ///
        /// 
        /// Requests the compositor to use the provided feedback string
        /// associated with this strip. This request should be issued immediately
        /// after a wp_tablet_pad_group.mode_switch event from the corresponding
        /// group is received, or whenever the strip is mapped to a different
        /// action. See wp_tablet_pad_group.mode_switch for more details.
        /// 
        /// Clients are encouraged to provide context-aware descriptions for
        /// the actions associated with the strip, and compositors may use this
        /// information to offer visual feedback about the button layout
        /// (eg. on-screen displays).
        /// 
        /// The provided string 'description' is a UTF-8 encoded string to be
        /// associated with this ring, and is considered user-visible; general
        /// internationalization rules apply.
        /// 
        /// The serial argument will be that of the last
        /// wp_tablet_pad_group.mode_switch event received for the group of this
        /// strip. Requests providing other serials than the most recent one will be
        /// ignored.
        /// 
        /// 
        pub const SetFeedback = struct {
            pub const NAME = "set_feedback";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            /// strip description
            description: wire.String,
            /// serial of the mode switch event
            serial: wire.Uint,
        };

        /// destroy the strip object
        ///
        /// 
        /// This destroys the client's resource for this strip object.
        /// 
        /// 
        pub const Destroy = struct {
            pub const NAME = "destroy";
            pub const OPCODE = 1;
            pub const SINCE = 0;
        };

    };

    pub const Event = union(enum) {
        source: Event.Source,
        position: Event.Position,
        stop: Event.Stop,
        frame: Event.Frame,

        /// strip event source
        ///
        /// 
        /// Source information for strip events.
        /// 
        /// This event does not occur on its own. It is sent before a
        /// wp_tablet_pad_strip.frame event and carries the source information
        /// for all events within that frame.
        /// 
        /// The source specifies how this event was generated. If the source is
        /// wp_tablet_pad_strip.source.finger, a wp_tablet_pad_strip.stop event
        /// will be sent when the user lifts their finger off the device.
        /// 
        /// This event is optional. If the source is unknown for an interaction,
        /// no event is sent.
        /// 
        /// 
        pub const Source = struct {
            pub const NAME = "source";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            /// the event source
            source: zwp_tablet_pad_strip_v2.Source,
        };

        /// position changed
        ///
        /// 
        /// Sent whenever the position on a strip changes.
        /// 
        /// The position is normalized to a range of [0, 65535], the 0-value
        /// represents the top-most and/or left-most position of the strip in
        /// the pad's current rotation.
        /// 
        /// 
        pub const Position = struct {
            pub const NAME = "position";
            pub const OPCODE = 1;
            pub const SINCE = 0;

            /// the current position
            position: wire.Uint,
        };

        /// interaction stopped
        ///
        /// 
        /// Stop notification for strip events.
        /// 
        /// For some wp_tablet_pad_strip.source types, a wp_tablet_pad_strip.stop
        /// event is sent to notify a client that the interaction with the strip
        /// has terminated. This enables the client to implement kinetic
        /// scrolling. See the wp_tablet_pad_strip.source documentation for
        /// information on when this event may be generated.
        /// 
        /// Any wp_tablet_pad_strip.position events with the same source after this
        /// event should be considered as the start of a new interaction.
        /// 
        /// 
        pub const Stop = struct {
            pub const NAME = "stop";
            pub const OPCODE = 2;
            pub const SINCE = 0;
        };

        /// end of a strip event sequence
        ///
        /// 
        /// Indicates the end of a set of events that represent one logical
        /// hardware strip event. A client is expected to accumulate the data
        /// in all events within the frame before proceeding.
        /// 
        /// All wp_tablet_pad_strip events before a wp_tablet_pad_strip.frame event belong
        /// logically together. For example, on termination of a finger interaction
        /// on a strip the compositor will send a wp_tablet_pad_strip.source event,
        /// a wp_tablet_pad_strip.stop event and a wp_tablet_pad_strip.frame
        /// event.
        /// 
        /// A wp_tablet_pad_strip.frame event is sent for every logical event
        /// group, even if the group only contains a single wp_tablet_pad_strip
        /// event. Specifically, a client may get a sequence: position, frame,
        /// position, frame, etc.
        /// 
        /// 
        pub const Frame = struct {
            pub const NAME = "frame";
            pub const OPCODE = 3;
            pub const SINCE = 0;

            /// timestamp with millisecond granularity
            time: wire.Uint,
        };

    };

        pub const Source = enum(wire.Uint) {
            finger = 1,
        };

    pub fn set_feedback(this: zwp_tablet_pad_strip_v2, connection: *wire.Connection, description: wire.String, serial: wire.Uint) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.SetFeedback.OPCODE);
        try connection.writeStruct(@This().Request.SetFeedback, .{
            .description = description,
            .serial = serial,
        });
        try connection.end();
    }

    pub fn destroy(this: zwp_tablet_pad_strip_v2, connection: *wire.Connection) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Destroy.OPCODE);
        try connection.writeStruct(@This().Request.Destroy, .{
        });
        try connection.end();
    }

};

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
pub const zwp_tablet_pad_group_v2 = enum(u32) {
    _,

    pub const NAME = "zwp_tablet_pad_group_v2";
    pub const VERSION = 1;

    pub const Request = union(enum) {
        destroy: Request.Destroy,

        /// destroy the pad object
        ///
        /// 
        /// Destroy the wp_tablet_pad_group object. Objects created from this object
        /// are unaffected and should be destroyed separately.
        /// 
        /// 
        pub const Destroy = struct {
            pub const NAME = "destroy";
            pub const OPCODE = 0;
            pub const SINCE = 0;
        };

    };

    pub const Event = union(enum) {
        buttons: Event.Buttons,
        ring: Event.Ring,
        strip: Event.Strip,
        modes: Event.Modes,
        done: Event.Done,
        mode_switch: Event.ModeSwitch,

        /// buttons announced
        ///
        /// 
        /// Sent on wp_tablet_pad_group initialization to announce the available
        /// buttons in the group. Button indices start at 0, a button may only be
        /// in one group at a time.
        /// 
        /// This event is first sent in the initial burst of events before the
        /// wp_tablet_pad_group.done event.
        /// 
        /// Some buttons are reserved by the compositor. These buttons may not be
        /// assigned to any wp_tablet_pad_group. Compositors may broadcast this
        /// event in the case of changes to the mapping of these reserved buttons.
        /// If the compositor happens to reserve all buttons in a group, this event
        /// will be sent with an empty array.
        /// 
        /// 
        pub const Buttons = struct {
            pub const NAME = "buttons";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            /// buttons in this group
            buttons: wire.Array,
        };

        /// ring announced
        ///
        /// 
        /// Sent on wp_tablet_pad_group initialization to announce available rings.
        /// One event is sent for each ring available on this pad group.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_pad_group.done event.
        /// 
        /// 
        pub const Ring = struct {
            pub const NAME = "ring";
            pub const OPCODE = 1;
            pub const SINCE = 0;

            ring: wire.NewId.WithInterface(tablet_v2.zwp_tablet_pad_ring_v2),
        };

        /// strip announced
        ///
        /// 
        /// Sent on wp_tablet_pad initialization to announce available strips.
        /// One event is sent for each strip available on this pad group.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_pad_group.done event.
        /// 
        /// 
        pub const Strip = struct {
            pub const NAME = "strip";
            pub const OPCODE = 2;
            pub const SINCE = 0;

            strip: wire.NewId.WithInterface(tablet_v2.zwp_tablet_pad_strip_v2),
        };

        /// mode-switch ability announced
        ///
        /// 
        /// Sent on wp_tablet_pad_group initialization to announce that the pad
        /// group may switch between modes. A client may use a mode to store a
        /// specific configuration for buttons, rings and strips and use the
        /// wl_tablet_pad_group.mode_switch event to toggle between these
        /// configurations. Mode indices start at 0.
        /// 
        /// Switching modes is compositor-dependent. See the
        /// wp_tablet_pad_group.mode_switch event for more details.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_pad_group.done event. This event is only sent when more than
        /// more than one mode is available.
        /// 
        /// 
        pub const Modes = struct {
            pub const NAME = "modes";
            pub const OPCODE = 3;
            pub const SINCE = 0;

            /// the number of modes
            modes: wire.Uint,
        };

        /// tablet group description events sequence complete
        ///
        /// 
        /// This event is sent immediately to signal the end of the initial
        /// burst of descriptive events. A client may consider the static
        /// description of the tablet to be complete and finalize initialization
        /// of the tablet group.
        /// 
        /// 
        pub const Done = struct {
            pub const NAME = "done";
            pub const OPCODE = 4;
            pub const SINCE = 0;
        };

        /// mode switch event
        ///
        /// 
        /// Notification that the mode was switched.
        /// 
        /// A mode applies to all buttons, rings and strips in a group
        /// simultaneously, but a client is not required to assign different actions
        /// for each mode. For example, a client may have mode-specific button
        /// mappings but map the ring to vertical scrolling in all modes. Mode
        /// indices start at 0.
        /// 
        /// Switching modes is compositor-dependent. The compositor may provide
        /// visual cues to the user about the mode, e.g. by toggling LEDs on
        /// the tablet device. Mode-switching may be software-controlled or
        /// controlled by one or more physical buttons. For example, on a Wacom
        /// Intuos Pro, the button inside the ring may be assigned to switch
        /// between modes.
        /// 
        /// The compositor will also send this event after wp_tablet_pad.enter on
        /// each group in order to notify of the current mode. Groups that only
        /// feature one mode will use mode=0 when emitting this event.
        /// 
        /// If a button action in the new mode differs from the action in the
        /// previous mode, the client should immediately issue a
        /// wp_tablet_pad.set_feedback request for each changed button.
        /// 
        /// If a ring or strip action in the new mode differs from the action
        /// in the previous mode, the client should immediately issue a
        /// wp_tablet_ring.set_feedback or wp_tablet_strip.set_feedback request
        /// for each changed ring or strip.
        /// 
        /// 
        pub const ModeSwitch = struct {
            pub const NAME = "mode_switch";
            pub const OPCODE = 5;
            pub const SINCE = 0;

            /// the time of the event with millisecond granularity
            time: wire.Uint,
            serial: wire.Uint,
            /// the new mode of the pad
            mode: wire.Uint,
        };

    };

    pub fn destroy(this: zwp_tablet_pad_group_v2, connection: *wire.Connection) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Destroy.OPCODE);
        try connection.writeStruct(@This().Request.Destroy, .{
        });
        try connection.end();
    }

};

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
pub const zwp_tablet_pad_v2 = enum(u32) {
    _,

    pub const NAME = "zwp_tablet_pad_v2";
    pub const VERSION = 1;

    pub const Request = union(enum) {
        set_feedback: Request.SetFeedback,
        destroy: Request.Destroy,

        /// set compositor feedback
        ///
        /// 
        /// Requests the compositor to use the provided feedback string
        /// associated with this button. This request should be issued immediately
        /// after a wp_tablet_pad_group.mode_switch event from the corresponding
        /// group is received, or whenever a button is mapped to a different
        /// action. See wp_tablet_pad_group.mode_switch for more details.
        /// 
        /// Clients are encouraged to provide context-aware descriptions for
        /// the actions associated with each button, and compositors may use
        /// this information to offer visual feedback on the button layout
        /// (e.g. on-screen displays).
        /// 
        /// Button indices start at 0. Setting the feedback string on a button
        /// that is reserved by the compositor (i.e. not belonging to any
        /// wp_tablet_pad_group) does not generate an error but the compositor
        /// is free to ignore the request.
        /// 
        /// The provided string 'description' is a UTF-8 encoded string to be
        /// associated with this ring, and is considered user-visible; general
        /// internationalization rules apply.
        /// 
        /// The serial argument will be that of the last
        /// wp_tablet_pad_group.mode_switch event received for the group of this
        /// button. Requests providing other serials than the most recent one will
        /// be ignored.
        /// 
        /// 
        pub const SetFeedback = struct {
            pub const NAME = "set_feedback";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            /// button index
            button: wire.Uint,
            /// button description
            description: wire.String,
            /// serial of the mode switch event
            serial: wire.Uint,
        };

        /// destroy the pad object
        ///
        /// 
        /// Destroy the wp_tablet_pad object. Objects created from this object
        /// are unaffected and should be destroyed separately.
        /// 
        /// 
        pub const Destroy = struct {
            pub const NAME = "destroy";
            pub const OPCODE = 1;
            pub const SINCE = 0;
        };

    };

    pub const Event = union(enum) {
        group: Event.Group,
        path: Event.Path,
        buttons: Event.Buttons,
        done: Event.Done,
        button: Event.Button,
        enter: Event.Enter,
        leave: Event.Leave,
        removed: Event.Removed,

        /// group announced
        ///
        /// 
        /// Sent on wp_tablet_pad initialization to announce available groups.
        /// One event is sent for each pad group available.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_pad.done event. At least one group will be announced.
        /// 
        /// 
        pub const Group = struct {
            pub const NAME = "group";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            pad_group: wire.NewId.WithInterface(tablet_v2.zwp_tablet_pad_group_v2),
        };

        /// path to the device
        ///
        /// 
        /// A system-specific device path that indicates which device is behind
        /// this wp_tablet_pad. This information may be used to gather additional
        /// information about the device, e.g. through libwacom.
        /// 
        /// The format of the path is unspecified, it may be a device node, a
        /// sysfs path, or some other identifier. It is up to the client to
        /// identify the string provided.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_pad.done event.
        /// 
        /// 
        pub const Path = struct {
            pub const NAME = "path";
            pub const OPCODE = 1;
            pub const SINCE = 0;

            /// path to local device
            path: wire.String,
        };

        /// buttons announced
        ///
        /// 
        /// Sent on wp_tablet_pad initialization to announce the available
        /// buttons.
        /// 
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_pad.done event. This event is only sent when at least one
        /// button is available.
        /// 
        /// 
        pub const Buttons = struct {
            pub const NAME = "buttons";
            pub const OPCODE = 2;
            pub const SINCE = 0;

            /// the number of buttons
            buttons: wire.Uint,
        };

        /// pad description event sequence complete
        ///
        /// 
        /// This event signals the end of the initial burst of descriptive
        /// events. A client may consider the static description of the pad to
        /// be complete and finalize initialization of the pad.
        /// 
        /// 
        pub const Done = struct {
            pub const NAME = "done";
            pub const OPCODE = 3;
            pub const SINCE = 0;
        };

        /// physical button state
        ///
        /// 
        /// Sent whenever the physical state of a button changes.
        /// 
        /// 
        pub const Button = struct {
            pub const NAME = "button";
            pub const OPCODE = 4;
            pub const SINCE = 0;

            /// the time of the event with millisecond granularity
            time: wire.Uint,
            /// the index of the button that changed state
            button: wire.Uint,
            state: zwp_tablet_pad_v2.ButtonState,
        };

        /// enter event
        ///
        /// 
        /// Notification that this pad is focused on the specified surface.
        /// 
        /// 
        pub const Enter = struct {
            pub const NAME = "enter";
            pub const OPCODE = 5;
            pub const SINCE = 0;

            /// serial number of the enter event
            serial: wire.Uint,
            /// the tablet the pad is attached to
            tablet: tablet_v2.zwp_tablet_v2,
            /// surface the pad is focused on
            surface: wayland.wl_surface,
        };

        /// leave event
        ///
        /// 
        /// Notification that this pad is no longer focused on the specified
        /// surface.
        /// 
        /// 
        pub const Leave = struct {
            pub const NAME = "leave";
            pub const OPCODE = 6;
            pub const SINCE = 0;

            /// serial number of the leave event
            serial: wire.Uint,
            /// surface the pad is no longer focused on
            surface: wayland.wl_surface,
        };

        /// pad removed event
        ///
        /// 
        /// Sent when the pad has been removed from the system. When a tablet
        /// is removed its pad(s) will be removed too.
        /// 
        /// When this event is received, the client must destroy all rings, strips
        /// and groups that were offered by this pad, and issue wp_tablet_pad.destroy
        /// the pad itself.
        /// 
        /// 
        pub const Removed = struct {
            pub const NAME = "removed";
            pub const OPCODE = 7;
            pub const SINCE = 0;
        };

    };

        pub const ButtonState = enum(wire.Uint) {
            released = 0,
            pressed = 1,
        };

    pub fn set_feedback(this: zwp_tablet_pad_v2, connection: *wire.Connection, button: wire.Uint, description: wire.String, serial: wire.Uint) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.SetFeedback.OPCODE);
        try connection.writeStruct(@This().Request.SetFeedback, .{
            .button = button,
            .description = description,
            .serial = serial,
        });
        try connection.end();
    }

    pub fn destroy(this: zwp_tablet_pad_v2, connection: *wire.Connection) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Destroy.OPCODE);
        try connection.writeStruct(@This().Request.Destroy, .{
        });
        try connection.end();
    }

};

const tablet_v2 = @This();
const wayland = @import("core");
