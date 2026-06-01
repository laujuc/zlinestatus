// 
// Copyright © 2013-2014 Collabora, Ltd.
// 
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice (including the next
// paragraph) shall be included in all copies or substantial portions of the
// Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
// 
// 

const wire = @import("wire");
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
pub const wp_presentation = enum(u32) {
    _,

    pub const NAME = "wp_presentation";
    pub const VERSION = 1;

    pub const Request = union(enum) {
        destroy: Request.Destroy,
        feedback: Request.Feedback,

        /// unbind from the presentation interface
        ///
        /// 
        /// Informs the server that the client will no longer be using
        /// this protocol object. Existing objects created by this object
        /// are not affected.
        /// 
        /// 
        pub const Destroy = struct {
            pub const NAME = "destroy";
            pub const OPCODE = 0;
            pub const SINCE = 0;
        };

        /// request presentation feedback information
        ///
        /// 
        /// Request presentation feedback for the current content submission
        /// on the given surface. This creates a new presentation_feedback
        /// object, which will deliver the feedback information once. If
        /// multiple presentation_feedback objects are created for the same
        /// submission, they will all deliver the same information.
        /// 
        /// For details on what information is returned, see the
        /// presentation_feedback interface.
        /// 
        /// 
        pub const Feedback = struct {
            pub const NAME = "feedback";
            pub const OPCODE = 1;
            pub const SINCE = 0;

            /// target surface
            surface: wayland.wl_surface,
            /// new feedback object
            callback: wire.NewId.WithInterface(presentation_time.wp_presentation_feedback),
        };

    };

    pub const Event = union(enum) {
        clock_id: Event.ClockId,

        /// clock ID for timestamps
        ///
        /// 
        /// This event tells the client in which clock domain the
        /// compositor interprets the timestamps used by the presentation
        /// extension. This clock is called the presentation clock.
        /// 
        /// The compositor sends this event when the client binds to the
        /// presentation interface. The presentation clock does not change
        /// during the lifetime of the client connection.
        /// 
        /// The clock identifier is platform dependent. On POSIX platforms, the
        /// identifier value is one of the clockid_t values accepted by
        /// clock_gettime(). clock_gettime() is defined by POSIX.1-2001.
        /// 
        /// Timestamps in this clock domain are expressed as tv_sec_hi,
        /// tv_sec_lo, tv_nsec triples, each component being an unsigned
        /// 32-bit value. Whole seconds are in tv_sec which is a 64-bit
        /// value combined from tv_sec_hi and tv_sec_lo, and the
        /// additional fractional part in tv_nsec as nanoseconds. Hence,
        /// for valid timestamps tv_nsec must be in [0, 999999999].
        /// 
        /// Note that clock_id applies only to the presentation clock,
        /// and implies nothing about e.g. the timestamps used in the
        /// Wayland core protocol input events.
        /// 
        /// Compositors should prefer a clock which does not jump and is
        /// not slewed e.g. by NTP. The absolute value of the clock is
        /// irrelevant. Precision of one millisecond or better is
        /// recommended. Clients must be able to query the current clock
        /// value directly, not by asking the compositor.
        /// 
        /// 
        pub const ClockId = struct {
            pub const NAME = "clock_id";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            /// platform clock identifier
            clk_id: wire.Uint,
        };

    };

        pub const Error = enum(wire.Uint) {
            invalid_timestamp = 0,
            invalid_flag = 1,
        };

    pub fn destroy(this: wp_presentation, connection: *wire.Connection) !void {
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Destroy.OPCODE);
        try connection.writeStruct(@This().Request.Destroy, .{
        });
        try connection.end();
    }

    pub fn feedback(this: wp_presentation, connection: *wire.Connection, surface: wayland.wl_surface) !presentation_time.wp_presentation_feedback {
        const new_id = try connection.createId(presentation_time.wp_presentation_feedback.NAME, presentation_time.wp_presentation_feedback.VERSION);
        errdefer connection.destroyId(new_id);
        try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Feedback.OPCODE);
        try connection.writeStruct(@This().Request.Feedback, .{
            .surface = surface,
            .callback = @enumFromInt(@intFromEnum(new_id)),
        });
        try connection.end();
        return @enumFromInt(@intFromEnum(new_id));
    }

};

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
pub const wp_presentation_feedback = enum(u32) {
    _,

    pub const NAME = "wp_presentation_feedback";
    pub const VERSION = 2;

    pub const Request = union(enum) {

    };

    pub const Event = union(enum) {
        sync_output: Event.SyncOutput,
        presented: Event.Presented,
        discarded: Event.Discarded,

        /// presentation synchronized to this output
        ///
        /// 
        /// As presentation can be synchronized to only one output at a
        /// time, this event tells which output it was. This event is only
        /// sent prior to the presented event.
        /// 
        /// As clients may bind to the same global wl_output multiple
        /// times, this event is sent for each bound instance that matches
        /// the synchronized output. If a client has not bound to the
        /// right wl_output global at all, this event is not sent.
        /// 
        /// 
        pub const SyncOutput = struct {
            pub const NAME = "sync_output";
            pub const OPCODE = 0;
            pub const SINCE = 0;

            /// presentation output
            output: wayland.wl_output,
        };

        /// the content update was displayed
        ///
        /// 
        /// The associated content update was displayed to the user at the
        /// indicated time (tv_sec_hi/lo, tv_nsec). For the interpretation of
        /// the timestamp, see presentation.clock_id event.
        /// 
        /// The timestamp corresponds to the time when the content update
        /// turned into light the first time on the surface's main output.
        /// Compositors may approximate this from the framebuffer flip
        /// completion events from the system, and the latency of the
        /// physical display path if known.
        /// 
        /// This event is preceded by all related sync_output events
        /// telling which output's refresh cycle the feedback corresponds
        /// to, i.e. the main output for the surface. Compositors are
        /// recommended to choose the output containing the largest part
        /// of the wl_surface, or keeping the output they previously
        /// chose. Having a stable presentation output association helps
        /// clients predict future output refreshes (vblank).
        /// 
        /// The 'refresh' argument gives the compositor's prediction of how
        /// many nanoseconds after tv_sec, tv_nsec the very next output
        /// refresh may occur. This is to further aid clients in
        /// predicting future refreshes, i.e., estimating the timestamps
        /// targeting the next few vblanks. If such prediction cannot
        /// usefully be done, the argument is zero.
        /// 
        /// For version 2 and later, if the output does not have a constant
        /// refresh rate, explicit video mode switches excluded, then the
        /// refresh argument must be either an appropriate rate picked by the
        /// compositor (e.g. fastest rate), or 0 if no such rate exists.
        /// For version 1, if the output does not have a constant refresh rate,
        /// the refresh argument must be zero.
        /// 
        /// The 64-bit value combined from seq_hi and seq_lo is the value
        /// of the output's vertical retrace counter when the content
        /// update was first scanned out to the display. This value must
        /// be compatible with the definition of MSC in
        /// GLX_OML_sync_control specification. Note, that if the display
        /// path has a non-zero latency, the time instant specified by
        /// this counter may differ from the timestamp's.
        /// 
        /// If the output does not have a concept of vertical retrace or a
        /// refresh cycle, or the output device is self-refreshing without
        /// a way to query the refresh count, then the arguments seq_hi
        /// and seq_lo must be zero.
        /// 
        /// 
        pub const Presented = struct {
            pub const NAME = "presented";
            pub const OPCODE = 1;
            pub const SINCE = 0;

            /// high 32 bits of the seconds part of the presentation timestamp
            tv_sec_hi: wire.Uint,
            /// low 32 bits of the seconds part of the presentation timestamp
            tv_sec_lo: wire.Uint,
            /// nanoseconds part of the presentation timestamp
            tv_nsec: wire.Uint,
            /// nanoseconds till next refresh
            refresh: wire.Uint,
            /// high 32 bits of refresh counter
            seq_hi: wire.Uint,
            /// low 32 bits of refresh counter
            seq_lo: wire.Uint,
            /// combination of 'kind' values
            flags: wp_presentation_feedback.Kind,
        };

        /// the content update was not displayed
        ///
        /// 
        /// The content update was never displayed to the user.
        /// 
        /// 
        pub const Discarded = struct {
            pub const NAME = "discarded";
            pub const OPCODE = 2;
            pub const SINCE = 0;
        };

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

};

const wayland = @import("core");
const presentation_time = @This();
