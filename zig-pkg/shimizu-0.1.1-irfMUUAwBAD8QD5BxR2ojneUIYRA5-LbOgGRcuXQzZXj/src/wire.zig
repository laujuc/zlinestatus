//! A list of types that the wire format specifies.
//!
//! References:
//! - ["The Wayland Protocol" by Kristian Høgsberg](https://wayland.freedesktop.org/docs/html/ch04.html#sect-Protocol-Wire-Format)
//! - ["The Wayland Protocol" by Drew DeVault](https://wayland-book.com/protocol-design/wire-protocol.html)

/// The Wayland protocol is defined in terms of 32-bit native-endianess words.
pub const Word = u32;

/// A header sent before each Wayland message. Parsing the message payload
/// requires looking up the `object`'s interface and matching the `opcode`
/// to Request or Event type.
///
/// This data type exactly matches the wire format, so it's underlying bytes may
/// be directly passed to `read` or `write`.
pub const Header = extern struct {
    /// The id of the object that this Wayland message is addressed to.
    object: Object align(4),
    /// To save a bit of typing, see the functions `Header.size()` and `Header.opcode()`.
    size_and_opcode: SizeAndOpcode align(4),

    /// Get the message size from the `size_and_opcode` word. See also `Header.SizeAndOpcode.size`
    pub inline fn size(header: Header) u16 {
        return header.size_and_opcode.size;
    }

    /// Get the message opcode from the `size_and_opcode` word. See also `Header.SizeAndOpcode.opcode`
    pub inline fn opcode(header: Header) u16 {
        return header.size_and_opcode.opcode;
    }

    /// See also the functions `Header.size()` and `Header.opcode()`.
    ///
    /// It would be nice to put the `size` and `opcode` in a flat namespace, but since
    /// Wayland uses 32-bit native-endianess words to encode data, the location of the
    /// `size` and `opcode` fields change their memory position based on the native
    /// endian.
    pub const SizeAndOpcode = packed struct(u32) {
        /// Specifies which Request or Event type the payload corresponds to.
        ///
        /// - For messages sent from client to server, this indicates the Request type.
        /// - For messages sent from server to client, this indicates the Event type.
        opcode: u16,

        /// The size of the Wayland message, including the `Header`.
        size: u16,
    };
};

/// A one Word signed integer.
///
/// This data type exactly matches the wire format, so it's underlying bytes may
/// be directly passed to `read` or `write`.
pub const Int = i32;

/// A one Word unsigned integer.
///
/// This data type exactly matches the wire format, so it's underlying bytes may
/// be directly passed to `read` or `write`.
pub const Uint = u32;

/// A on Word fixed point number with a sign bit, 23 bits of integer
/// precision, and 8 bits of fractional precision.
///
/// This data type exactly matches the wire format, so it's underlying bytes may
/// be directly passed to `read` or `write`.
pub const Fixed = packed struct(u32) {
    fraction: u8,
    integer: i24,

    pub fn fromInt(integer: i24, fraction: u8) @This() {
        return .{
            .integer = integer,
            .fraction = fraction,
        };
    }

    pub fn fromFloat(comptime T: type, float: T) @This() {
        const denominator_t: T = @floatFromInt(std.math.maxInt(u8));

        return .{
            .integer = @intFromFloat(float),
            .fraction = @intFromFloat((float - @floor(float)) * denominator_t),
        };
    }

    pub fn toFloat(this: @This(), comptime T: type) T {
        const fraction_t: T = @floatFromInt(this.fraction);
        const denominator_t: T = @floatFromInt(std.math.maxInt(u8));
        const integer_t: T = @floatFromInt(this.integer);

        return (integer_t * denominator_t + fraction_t) / denominator_t;
    }
};

/// > A string, prefixed with a 32-bit integer specifying its length (in bytes),
/// > followed by the string contents and a NUL terminator, padded to 32 bits
/// > with undefined data. The encoding is not specified, but in practice UTF-8 is
/// > used.
/// - ["The Wayland Protocol" by Drew DeVault](https://wayland-book.com/protocol-design/wire-protocol.html)
///
/// This data type does NOT match the wire format. To read or write this type,
/// you SHOULD use `readString` or `writeString`.
pub const String = [:0]const u8;

/// 32-bit object id. A value of 1 refers to the `core.wl_display` singleton object.
///
/// Most Wayland protocols specify the `Object`'s interface ahead of time, and this
/// is exposed in `shimizu` using `Object.WithInterface(<INTERFACE>)`.
///
/// This data type exactly matches the wire format, so it's underlying bytes may
/// be directly passed to `read` or `write`. HOWEVER! To better integrate with Zig's
/// type system, an `Object` should never be 0, and instead should be wrapped in an
/// Optional type (like so: `?Object`). An optional `Object` DOES NOT match the wire
/// format, and SHOULD be written using `writeOptionalObject` and read using
/// `readOptionalObject`.
pub const Object = enum(Uint) {
    wl_display = 1,
    _,
};

/// A new object id for generic cases where the interface cannot be inferred from
/// the XML. Currently, I know of only one place where this type is used, and
/// that is in `core.wl_registry`'s `bind` request. Everywhere else specifies the
/// interface of the `NewId` ahead of time, and this is exposed in `shimizu`
/// using `NewId.WithInterface(<INTERFACE>)`.
///
/// This data type does NOT match the wire format. To read or write this type,
/// you SHOULD use `readNewId` or `writeNewId`.
pub const NewId = struct {
    interface: String,
    version: u32,
    object: Object,

    /// A 32-bit object id. Unlike `object`, however, this is only used when the id
    /// will be freshly allocated before it is sent over the wire. On the other
    /// side of the connection this tells them what id you will use to refer to the
    /// new object.
    ///
    /// This data type exactly matches the wire format, so it's underlying bytes may
    /// be directly passed to `read` or `write`.
    pub fn WithInterface(I: type) type {
        return enum(Uint) {
            _,

            pub const _IS_TYPED_NEW_ID = true;
            pub const _SPECIFIED_INTERFACE = I;
        };
    }

    /// When writing generic code, it is useful to know if a particular type is a NewID
    pub fn isTypedNewId(T: type) bool {
        return @typeInfo(T) == .@"enum" and @hasDecl(T, "_IS_TYPED_NEW_ID") and T._IS_TYPED_NEW_ID;
    }
};

/// > A blob of arbitrary data, prefixed with a 32-bit integer specifying its
/// > length (in bytes), then the verbatim contents of the array, padded to 32
/// > bits with undefined data.
/// - ["The Wayland Protocol" by Drew DeVault](https://wayland-book.com/protocol-design/wire-protocol.html)
///
/// Wayland XML files don't have a machine-readable way to specify the contents
/// of an array. Thus it falls on you as a Wayland developer to read the
/// protocol documentation and determine how the bytes should be interpreted.
///
/// +------+------------------------------------------------------------------+
/// | word | description                                                      |
/// +------+------------------------------------------------------------------+
/// |    0 | array size in bytes                                              |
/// |    1 | first word of array contents                                     |
/// |  ... | ...                                                              |
/// |    N | word containing last byte(s) of array, and any necessary padding |
/// +------+------------------------------------------------------------------+
///
/// This data type does NOT match the wire format. To read or write this type,
/// you SHOULD use `readArray` or `writeArray`.
pub const Array = []const u8;

/// > The file descriptor is not stored in the message buffer, but in the ancillery
/// > data of the UNIX domain socket message (msg_control).
/// - ["The Wayland Protocol" by Kristian Høgsberg](https://wayland.freedesktop.org/docs/html/ch04.html#sect-Protocol-Wire-Format)
///
/// For `shimizu`, this means that the `fd` is packed into a `cmsg` before being sent
/// in the `control` field of `sendmsg`'s `msgheader`.
///
/// This data type does NOT match the wire format. To read or write this type,
/// you SHOULD use `readFd` or `writeFd`.
pub const Fd = enum(std.posix.fd_t) { _ };

pub const Connection = struct {
    vtable: *const VTable,
    message_writer: std.Io.Writer,
    message_start: ?usize = null,
    control_buffer: []u8,
    control_end: usize = 0,

    pub const VTable = struct {
        create_id_fn: *const fn (*Connection, name: [:0]const u8, version: Uint) Error!Object,
        destroy_id_fn: *const fn (*Connection, object_id: Object) void,
        set_object_message_callback_fn: *const fn (
            *Connection,
            object: Object,
            msg_callback: ?MessageCallback,
            userdata: usize,
        ) Error!void,
    };

    pub const Error = error{OutOfMemory} || std.Io.Writer.Error;
    pub const MessageCallback = *const fn (
        userdata: usize,
        connection: *Connection,
        object: Object,
        message_buffer: []const u8,
        message_index: *usize,
        control_buffer: []const u8,
        control_index: *usize,
    ) anyerror!void;

    pub fn createId(this: *@This(), name: [:0]const u8, version: Uint) Error!Object {
        return this.vtable.create_id_fn(this, name, version);
    }

    pub fn destroyId(this: *@This(), object_id: Object) void {
        return this.vtable.destroy_id_fn(this, object_id);
    }

    pub fn begin(this: *@This(), object_id: Object, opcode: u16) Error!void {
        std.debug.assert(this.message_start == null); // previous message must be closed before writing
        this.message_start = this.message_writer.end;
        try this.message_writer.writeStruct(Header{
            .object = object_id,
            .size_and_opcode = .{
                .opcode = opcode,
                .size = undefined,
            },
        }, builtin.cpu.arch.endian());
    }

    pub fn writeControlMessage(this: *@This(), bytes: []const u8) Error!void {
        if (this.control_end + bytes.len > this.control_buffer.len) {
            @branchHint(.unlikely);
            try this.message_writer.flush();
            if (this.control_end + bytes.len > this.control_buffer.len) {
                return error.WriteFailed;
            }
        }
        @memcpy(this.control_buffer[this.control_end..][0..bytes.len], bytes);
        this.control_end += bytes.len;
    }

    pub fn end(this: *@This()) Error!void {
        std.debug.assert(this.message_start != null); // a message must be started before it is ended

        const header_start = this.message_start.?;
        std.debug.assert(header_start % 4 == 0);

        const header_end = header_start + @sizeOf(Header);
        std.debug.assert(header_end <= this.message_writer.end);

        const header: *Header = @ptrCast(@alignCast(this.message_writer.buffer[header_start..header_end]));
        header.size_and_opcode.size = @intCast(this.message_writer.end - header_start);

        this.message_start = null;
    }

    pub fn setObjectMessageCallback(this: *@This(), object_id: Object, msg_callback: ?MessageCallback, userdata: usize) Error!void {
        return this.vtable.set_object_message_callback_fn(this, object_id, msg_callback, userdata);
    }

    pub fn writeUint(this: *@This(), uint: Uint) !void {
        try this.message_writer.writeAll(std.mem.asBytes(&uint));
    }

    pub fn writeInt(this: *@This(), int: Int) !void {
        try this.writeUint(@bitCast(int));
    }

    pub fn writeObject(this: *@This(), object: Object) !void {
        try this.writeUint(@intFromEnum(object));
    }

    pub fn writeString(this: *@This(), string: String) !void {
        try this.writeUint(@intCast(string.len + 1));

        try this.message_writer.writeAll(string);

        const aligned_len = std.mem.alignForward(usize, string.len + 1, @sizeOf(Word));
        try this.message_writer.splatByteAll(0, aligned_len - string.len);
    }

    pub fn writeArray(this: @This(), array: Array) !void {
        try this.writeUint(@intCast(array.len));
        try this.write(array);

        const aligned_len = std.mem.alignForward(usize, array.len + 1, @sizeOf(Word));
        try this.message_writer.splatByteAll(0, aligned_len - array.len);
    }

    pub fn writeOptionalObject(this: @This(), optional_object: ?Object) !void {
        if (optional_object) |object| {
            try this.writeObject(object);
        } else {
            try this.writeUint(0);
        }
    }

    pub fn writeOptionalString(this: @This(), optional_string: ?String) !void {
        if (optional_string) |string| {
            try this.writeString(string);
        } else {
            try this.writeUint(0);
        }
    }

    pub fn writeOptionalArray(this: @This(), optional_array: ?Array) !void {
        if (optional_array) |array| {
            try this.writeArray(array);
        } else {
            try this.writeUint(0);
        }
    }

    pub fn writeFd(this: *@This(), fd: Fd) !void {
        const scm_rights_msg: cmsg(std.posix.fd_t) = .{
            .level = std.posix.SOL.SOCKET,
            .type = SCM.RIGHTS,
            .data = @intFromEnum(fd),
        };
        try this.writeControlMessage(std.mem.asBytes(&scm_rights_msg));
    }

    pub fn writeStruct(msg_writer: *Connection, comptime Signature: type, message: Signature) Connection.Error!void {
        if (Signature == void) return;
        if (@typeInfo(Signature) != .@"struct") @compileError("Unexpected type" ++ @typeName(Signature) ++ ", expected Struct found " ++ @tagName(@typeInfo(Signature)));
        inline for (std.meta.fields(Signature)) |field| {
            const field_compile_error_prefix = @typeName(Signature) ++ "." ++ field.name ++ ": " ++ @typeName(field.type);

            switch (field.type) {
                Uint,
                Int,
                Fixed,
                Object,
                => try msg_writer.writeUint(@bitCast(@field(message, field.name))),

                ?Object => try msg_writer.writeOptionalObject(@field(message, field.name)),

                String => try msg_writer.writeString(@field(message, field.name)),
                Array => try msg_writer.writeArray(@field(message, field.name)),
                ?String => try msg_writer.writeOptionalString(@field(message, field.name)),
                ?Array => try msg_writer.writeOptionalArray(@field(message, field.name)),

                Fd => try msg_writer.writeFd(@field(message, field.name)),

                NewId => {
                    const new_id: NewId = @field(message, field.name);
                    try msg_writer.writeString(new_id.interface);
                    try msg_writer.writeUint(new_id.version);
                    try msg_writer.writeUint(@intFromEnum(new_id.object));
                },

                else => switch (@typeInfo(field.type)) {
                    .@"enum" => |enum_info| {
                        if (@bitSizeOf(enum_info.tag_type) != 32) @compileError(field_compile_error_prefix ++ ": enums must have a 32-bit backing integer");
                        try msg_writer.writeUint(@bitCast(@intFromEnum(@field(message, field.name))));
                    },
                    .@"struct" => |struct_info| {
                        if (struct_info.layout != .@"packed") @compileError(field_compile_error_prefix ++ ": only 32-bit packed structs have a defined format");
                        if (@bitSizeOf(struct_info.backing_integer.?) != 32) @compileError(field_compile_error_prefix ++ ": only 32-bit packed structs have a defined format");
                        try msg_writer.writeUint(@bitCast(@field(message, field.name)));
                    },
                    .optional => |optional_info| {
                        // we should only be here when a message contains an `?Object.WithInterface(T)` type.
                        if (@typeInfo(optional_info.child) != .@"enum") @compileError(field_compile_error_prefix ++ ": only `Object` enums may be null");
                        if (@bitSizeOf(@typeInfo(optional_info.child).@"enum".tag_type) != 32) @compileError(field_compile_error_prefix ++ ": enums must have a 32-bit backing integer");
                        const value: u32 = if (@field(message, field.name)) |v|
                            @bitCast(@intFromEnum(v))
                        else
                            0;
                        try msg_writer.writeUint(value);
                    },
                    else => @compileError(field_compile_error_prefix ++ ": unsupported type"),
                },
            }
        }
    }

    pub fn setEventListener(
        connection: *Connection,
        obj: anytype,
        Userdata: type,
        comptime callback: *const fn (Userdata, *Connection, @TypeOf(obj), @TypeOf(obj).Event) anyerror!void,
        userdata: Userdata,
    ) Error!void {
        const ObjectI = @TypeOf(obj);

        const Wrapper = struct {
            fn onMessageReceived(
                userdata_wrapper: usize,
                connection_wrapper: *Connection,
                object: Object,
                message_buffer: []const u8,
                message_index: *usize,
                control_buffer: []const u8,
                control_index: *usize,
            ) anyerror!void {
                const event = try deserialize(ObjectI.Event, message_buffer, message_index, control_buffer, control_index);

                const user_value: Userdata = switch (@typeInfo(Userdata)) {
                    .pointer => |ptr_info| switch (ptr_info.size) {
                        .many => @compileError("Unsupported userdata type: " ++ @typeName(Userdata)),
                        else => @ptrFromInt(userdata_wrapper),
                    },
                    .void => {},
                    else => @compileError("Unsupported userdata type: " ++ @typeName(Userdata)),
                };

                try callback(user_value, connection_wrapper, @enumFromInt(@intFromEnum(object)), event);
            }
        };

        const user_int: usize = switch (@typeInfo(Userdata)) {
            .pointer => |ptr_info| switch (ptr_info.size) {
                .many => @compileError("Unsupported userdata type: " ++ @typeName(Userdata)),
                else => @intFromPtr(userdata),
            },
            .void => 0,
            else => @compileError("Unsupported userdata type: " ++ @typeName(Userdata)),
        };

        return connection.setObjectMessageCallback(@enumFromInt(@intFromEnum(obj)), Wrapper.onMessageReceived, user_int);
    }
};

pub fn serialize(comptime Union: type, msg_writer: Connection, object_id: Object, message: Union) Connection.Error!void {
    if (@typeInfo(Union).Union.fields.len == 0) @compileError(@typeName(Union) ++ " has no valid messages!");

    try msg_writer.begin(object_id, @intFromEnum(std.meta.activeTag(message)));

    switch (message) {
        inline else => |payload| try msg_writer.writeStruct(@TypeOf(payload), payload),
    }

    try msg_writer.end();
}

pub const FixedBufferConnection = struct {
    connection: Connection,
    next_id: u32,

    pub fn init(message_buffer: []u8, control_buffer: []u8) @This() {
        return .{
            .connection = .{
                .vtable = CONNECTION_VTABLE,
                .message_writer = std.Io.Writer.fixed(message_buffer),
                .control_buffer = control_buffer,
            },
            .next_id = 2,
        };
    }

    const CONNECTION_VTABLE = &Connection.VTable{
        .create_id_fn = connectionCreateId,
        .destroy_id_fn = connectionDestroyId,
        .set_object_message_callback_fn = connectionSetObjectMessageCallback,
    };

    fn connectionCreateId(connection: *Connection, name: [:0]const u8, version: Uint) Connection.Error!Object {
        const this: *@This() = @fieldParentPtr("connection", connection);

        _ = name;
        _ = version;

        defer this.next_id += 1;
        return @enumFromInt(this.next_id);
    }

    fn connectionDestroyId(connection: *Connection, object_id: Object) void {
        const this: *@This() = @fieldParentPtr("connection", connection);

        _ = this;
        _ = object_id;
    }

    fn connectionSetObjectMessageCallback(connection: *Connection, _: Object, _: ?Connection.MessageCallback, _: usize) Connection.Error!void {
        const this: *@This() = @fieldParentPtr("connection", connection);
        _ = this;
    }
};

pub const DeserializeError = error{ InvalidOpcode, InvalidEnumTag, UnexpectedNullString, UnexpectedNullArray, UnexpectedEndOfMessage, UnexpectedEndOfControlMessage };

/// Deserialize a given Event or Request Union. `index` and `control_index` will be set to point to the end of this message if the
/// desirialization succeeds.
pub fn deserialize(comptime Union: type, buffer: []const u8, index: *usize, control_buffer: []const u8, control_index: *usize) DeserializeError!Union {
    if (std.meta.fields(Union).len == 0) std.debug.panic(@typeName(Union) ++ " event has no tags!", .{});

    const header: *const Header = @ptrCast(@alignCast(buffer[index.*..][0..@sizeOf(Header)]));

    if (header.size() > buffer[index.*..].len) {
        return error.UnexpectedEndOfMessage;
    }

    const op = std.meta.intToEnum(std.meta.Tag(Union), header.opcode()) catch return error.InvalidOpcode;

    var sub_index = index.* + @sizeOf(Header);
    var sub_control_index = control_index.*;
    switch (op) {
        inline else => |f| {
            const Payload = std.meta.TagPayload(Union, f);
            const payload = try deserializeArguments(Payload, buffer, &sub_index, control_buffer, &sub_control_index);

            index.* = sub_index;
            control_index.* = sub_control_index;

            return @unionInit(Union, @tagName(f), payload);
        },
    }
}

pub fn deserializeArguments(comptime Signature: type, buffer: []const u8, index: *usize, control_buffer: []const u8, control_index: *usize) DeserializeError!Signature {
    if (Signature == void) return {};
    if (@typeInfo(Signature) != .@"struct") @compileError("Unexpected type" ++ @typeName(Signature) ++ ", expected Struct found " ++ @tagName(@typeInfo(Signature)));

    var sub_index = index.*;
    var sub_control_index = control_index.*;

    var result: Signature = undefined;
    inline for (std.meta.fields(Signature)) |field| {
        const field_compile_error_prefix = @typeName(Signature) ++ "." ++ field.name ++ ": " ++ @typeName(field.type);

        switch (field.type) {
            Uint,
            Int,
            Fixed,
            => @field(result, field.name) = @bitCast(try readUint(buffer, &sub_index)),

            Object,
            => @field(result, field.name) = @enumFromInt(try readUint(buffer, &sub_index)),

            ?Object => @field(result, field.name) = try readOptionalObject(buffer, &sub_index),

            String => @field(result, field.name) = (try readString(buffer, &sub_index)) orelse return error.UnexpectedNullString,
            Array => @field(result, field.name) = try readArray(buffer, &sub_index),
            ?String => @field(result, field.name) = try readString(buffer, &sub_index),

            Fd => @field(result, field.name) = try readFd(control_buffer, &sub_control_index),

            NewId => {
                @field(result, field.name) = NewId{
                    .interface = (try readString(buffer, &sub_index)) orelse return error.UnexpectedNullString,
                    .version = try readUint(buffer, &sub_index),
                    .object = try readUint(buffer, &sub_index),
                };
            },

            else => switch (@typeInfo(field.type)) {
                .@"enum" => |enum_info| {
                    if (@bitSizeOf(enum_info.tag_type) != 32) @compileError(field_compile_error_prefix ++ ": enums must have a 32-bit backing integer");
                    @field(result, field.name) = @enumFromInt(try readUint(buffer, &sub_index));
                },
                .@"struct" => |struct_info| {
                    if (struct_info.layout != .@"packed") @compileError(field_compile_error_prefix ++ ": only 32-bit packed structs have a defined format");
                    if (@bitSizeOf(struct_info.backing_integer.?) != 32) @compileError(field_compile_error_prefix ++ ": only 32-bit packed structs have a defined format");
                    @field(result, field.name) = @bitCast(try readUint(buffer, &sub_index));
                },
                .optional => |optional_info| {
                    if (@typeInfo(optional_info.child) != .@"enum") @compileError(field_compile_error_prefix ++ ": only `Object` enums may be null");
                    if (@bitSizeOf(@typeInfo(optional_info.child).@"enum".tag_type) != 32) @compileError(field_compile_error_prefix ++ ": enums must have a 32-bit backing integer");

                    const uint = try readUint(buffer, &sub_index);
                    if (uint == 0) {
                        @field(result, field.name) = null;
                    } else {
                        @field(result, field.name) = @enumFromInt(uint);
                    }
                },
                else => @compileError(field_compile_error_prefix ++ ": unsupported type"),
            },
        }
    }

    index.* = sub_index;
    control_index.* = sub_control_index;

    return result;
}

pub fn readUint(buffer: []const u8, parent_pos: *usize) !Uint {
    var pos = parent_pos.*;
    if (pos + @sizeOf(Word) > buffer.len) return error.UnexpectedEndOfMessage;

    const uint = std.mem.bytesToValue(Uint, buffer[pos..][0..4]);
    pos += @sizeOf(Uint);

    parent_pos.* = pos;
    return uint;
}

pub fn readInt(buffer: []const u8, pos: *usize) !Int {
    const uint = try readUint(buffer, pos);
    return @bitCast(uint);
}

pub fn readString(buffer: []const u8, parent_pos: *usize) !?String {
    var pos = parent_pos.*;

    const len = try readUint(buffer, &pos);
    if (len == 0) {
        parent_pos.* = pos;
        return null;
    }
    const aligned_size = std.mem.alignForward(usize, len, @sizeOf(Word));

    if (pos + aligned_size > buffer.len) return error.UnexpectedEndOfMessage;
    const string = buffer[pos..][0 .. len - 1 :0];
    pos += aligned_size;

    parent_pos.* = pos;
    return string;
}

pub fn readArray(buffer: []const u8, parent_pos: *usize) !Array {
    var pos = parent_pos.*;

    const byte_size = try readUint(buffer, &pos);
    const aligned_size = std.mem.alignForward(usize, byte_size, @sizeOf(Word));

    if (aligned_size > buffer[pos..].len) {
        return error.UnexpectedEndOfMessage;
    }

    const array = buffer[pos..][0..byte_size];
    pos += aligned_size;

    parent_pos.* = pos;
    return array;
}

pub fn readObject(buffer: []const u8, pos: *usize) !Object {
    return @enumFromInt(try readUint(buffer, pos));
}

pub fn readOptionalObject(buffer: []const u8, pos: *usize) !?Object {
    const uint = try readUint(buffer, pos, 0);
    if (uint == 0) return null;
    return @enumFromInt(uint);
}

pub fn readFd(control_buffer: []const u8, control_pos: *usize) !Fd {
    const MSG_SIZE = @sizeOf(cmsg(std.posix.fd_t));

    while (true) {
        if (control_pos.* + MSG_SIZE > control_buffer.len) {
            return error.UnexpectedEndOfControlMessage;
        }

        const scm_rights_msg: *align(1) const cmsg(std.posix.fd_t) = @ptrCast(control_buffer[control_pos.*..][0..MSG_SIZE]);
        control_pos.* += MSG_SIZE;

        if (scm_rights_msg.level != std.posix.SOL.SOCKET or scm_rights_msg.type != SCM.RIGHTS) {
            continue;
        }

        return @enumFromInt(scm_rights_msg.data);
    }
}

pub const MessageSize = struct {
    // The number of 32-bit words required to serialize the payload.
    payload_words: u14,
    // The number of bytes required for the control message.
    control_message_bytes: u32,
};

const MessageSizeEstimate = struct {
    min_message_size: u16,
    /// How many dynamic elements (strings and arrays) are in this message signature.
    dynamic_element_count: u32,
    /// The exact number of bytes needed to send the control message.
    /// Possible to know because the fd message are not variably sized.
    control_message_bytes: u32,
};

/// Estimates the space required to serialize a given message
pub fn EstimateSerializedSize(comptime Signature: type) MessageSizeEstimate {
    var estimate = MessageSizeEstimate{
        .min_message_size = @sizeOf(Header),
        .dynamic_element_count = 0,
        .control_message_bytes = 0,
    };
    inline for (std.meta.fields(Signature)) |field| {
        switch (field.type) {
            Uint,
            Int,
            Fixed,
            Object,
            ?Object,
            => estimate.min_message_size += @sizeOf(Word),

            String,
            ?String,
            Array,
            ?Array,
            => {
                // add 1 for the string length prefix word
                estimate.min_message_size += @sizeOf(Word);
                estimate.dynamic_element_count += 1;
            },

            Fd => estimate.control_message_bytes += @sizeOf(cmsg(std.posix.fd_t)),

            NewId => {
                const new_id_estimate = EstimateSerializedSize(NewId);
                estimate.min_message_size += new_id_estimate.min_message_size;
                estimate.dynamic_element_count += new_id_estimate.dynamic_element_count;
                estimate.control_message_bytes += new_id_estimate.control_message_bytes;
            },

            else => switch (@typeInfo(field.type)) {
                .@"enum" => |enum_info| {
                    if (@bitSizeOf(enum_info.tag_type) != 32) @compileError("Unsupported type " ++ @typeName(field.type) ++ " in " ++ @typeName(Signature) ++ " (field " ++ field.name ++ "): enums must have a 32-bit backing integer");
                    estimate.min_message_size += @sizeOf(Word);
                },
                .@"struct" => |struct_info| {
                    if (struct_info.layout != .@"packed") @compileError("Unsupported type " ++ @typeName(field.type) ++ " in " ++ @typeName(Signature) ++ " (field " ++ field.name ++ "): only packed structs are allowed");
                    if (@bitSizeOf(struct_info.backing_integer.?) != 32) @compileError("Unsupported type " ++ @typeName(field.type) ++ " in " ++ @typeName(Signature) ++ " (field " ++ field.name ++ "): packed structs must have a 32 bit backing integer");
                    estimate.min_message_size += @sizeOf(Word);
                },
                .optional => |optional_info| {
                    // we should only be here when a message contains an `?Object.WithInterface(T)` type.
                    if (@typeInfo(optional_info.child) != .@"enum") @compileError("Unsupported type " ++ @typeName(field.type) ++ " in " ++ @typeName(Signature) ++ " (field " ++ field.name ++ "): only `Object` enums may be null");
                    if (@bitSizeOf(@typeInfo(optional_info.child).@"enum".tag_type) != 32) @compileError("Unsupported type " ++ @typeName(field.type) ++ " in " ++ @typeName(Signature) ++ " (field " ++ field.name ++ "): enum must have a 32-bit backing integer");
                    estimate.min_message_size += @sizeOf(Word);
                },
                else => @compileError("Unsupported type " ++ @typeName(field.type) ++ " in " ++ @typeName(Signature) ++ " (field " ++ field.name ++ ")"),
            },
        }
    }
    return estimate;
}

/// Returns the length of the serialized message in `u32` words.
pub fn calculateSerializedWordLen(comptime Signature: type, message: Signature) MessageSize {
    var message_size = MessageSize{
        .payload_words = 0,
        .control_message_bytes = 0,
    };
    inline for (std.meta.fields(Signature)) |field| {
        switch (field.type) {
            Uint,
            Int,
            Fixed,
            Object,
            ?Object,
            => message_size.payload_words += 1,

            String => {
                // add 1 for the string length prefix word
                message_size.payload_words += 1;
                // add 1 to the string length for the null byte
                const byte_size = @field(message, field.name).len + 1;
                message_size.payload_words += std.mem.alignForward(usize, byte_size, @sizeOf(u32)) / @sizeOf(u32);
            },
            ?String => {
                // add 1 for the string length prefix word
                message_size.payload_words += 1;
                if (@field(message, field.name)) |string| {
                    // add 1 to the string length for the null byte
                    const byte_size = string.len + 1;
                    message_size.payload_words += std.mem.alignForward(usize, byte_size, @sizeOf(u32)) / @sizeOf(u32);
                }
            },
            Array => {
                // add 1 for the array length prefix word
                message_size.payload_words += 1;
                const byte_size = @field(message, field.name).len;
                message_size.payload_words += std.mem.alignForward(usize, byte_size, @sizeOf(u32)) / @sizeOf(u32);
            },
            ?Array => {
                // add 1 for the array length prefix word
                message_size.payload_words += 1;
                if (@field(message, field.name)) |array| {
                    const byte_size = array.len;
                    message_size.payload_words += std.mem.alignForward(usize, byte_size, @sizeOf(u32)) / @sizeOf(u32);
                }
            },

            Fd => message_size.control_message_bytes += @sizeOf(cmsg(std.posix.fd_t)),

            NewId => {
                const new_id_size = calculateSerializedWordLen(NewId, @field(message, field.name));
                message_size.payload_words += new_id_size.payload_words;
                message_size.control_message_bytes += new_id_size.control_message_bytes;
            },

            else => switch (@typeInfo(field.type)) {
                .@"enum" => |enum_info| {
                    if (@bitSizeOf(enum_info.tag_type) != 32) @compileError("Unsupported type " ++ @typeName(field.type) ++ " in " ++ @typeName(Signature) ++ " (field " ++ field.name ++ "): enums must have a 32-bit backing integer");
                    message_size.payload_words += 1;
                },
                .@"struct" => |struct_info| {
                    if (struct_info.layout != .@"packed") @compileError("Unsupported type " ++ @typeName(field.type) ++ " in " ++ @typeName(Signature) ++ " (field " ++ field.name ++ "): only packed structs are allowed");
                    if (@bitSizeOf(struct_info.backing_integer.?) != 32) @compileError("Unsupported type " ++ @typeName(field.type) ++ " in " ++ @typeName(Signature) ++ " (field " ++ field.name ++ "): packed structs must have a 32 bit backing integer");
                    message_size.payload_words += 1;
                },
                .optional => |optional_info| {
                    // we should only be here when a message contains an `?Object.WithInterface(T)` type.
                    if (@typeInfo(optional_info.child) != .@"enum") @compileError("Unsupported type " ++ @typeName(field.type) ++ " in " ++ @typeName(Signature) ++ " (field " ++ field.name ++ "): only `Object` enums may be null");
                    if (@bitSizeOf(@typeInfo(optional_info.child).@"enum".tag_type) != 32) @compileError("Unsupported type " ++ @typeName(field.type) ++ " in " ++ @typeName(Signature) ++ " (field " ++ field.name ++ "): enum must have a 32-bit backing integer");
                    message_size.payload_words += 1;
                },
                else => @compileError("Unsupported type " ++ @typeName(field.type) ++ " in " ++ @typeName(Signature) ++ " (field " ++ field.name ++ ")"),
            },
        }
    }
    return message_size;
}

/// - TODO: find location where this is defined
const SCM = struct {
    /// - TODO: find location where this is defined
    /// - TODO: verify that this is the correct value for more than just Linux
    const RIGHTS = 0x01;
};

/// We define a generic `cmsg` type here for reading and writing control messages.
/// In C, this is accomplished using macros.
fn cmsg(comptime T: type) type {
    const raw_struct_size = @sizeOf(c_ulong) + @sizeOf(c_int) + @sizeOf(c_int) + @sizeOf(T);
    const padded_struct_size = std.mem.alignForward(usize, @sizeOf(c_ulong) + @sizeOf(c_int) + @sizeOf(c_int) + @sizeOf(T), @alignOf(c_long));
    const padding_size = padded_struct_size - raw_struct_size;
    return extern struct {
        len: c_ulong = raw_struct_size,
        level: c_int,
        type: c_int,
        data: T,
        _padding: [padding_size]u8 align(1) = [_]u8{0} ** padding_size,

        // Calculate the size of the message if padding is included. This function was made for reading potentially unknown control messages,
        // using `cmsg(void)`.
        pub fn size(this: @This()) usize {
            return std.mem.alignForward(usize, this.len, @alignOf(c_long));
        }
    };
}

test "[]u32 from header" {
    try std.testing.expectEqualSlices(
        u32,
        &[_]u32{
            1,
            (@as(u32, 12) << 16) | (4),
        },
        &@as([2]u32, @bitCast(Header{
            .object_id = 1,
            .size_and_opcode = .{
                .size = 12,
                .opcode = 4,
            },
        })),
    );
}

test "header from []u32" {
    try std.testing.expectEqualDeep(
        Header{
            .object_id = 1,
            .size_and_opcode = .{
                .size = 12,
                .opcode = 4,
            },
        },
        @as(Header, @bitCast([2]u32{
            1,
            (@as(u32, 12) << 16) | (4),
        })),
    );
}

/// structs and functions for interfacing with libwayland
pub const compat = struct {
    pub const wl_message = extern struct {
        name: [*:0]const u8,
        signature: [*:0]const u8,
        types: [*]const ?*const wl_interface,
    };

    pub const wl_interface = extern struct {
        name: [*:0]const u8,
        version: c_int,
        request_count: c_int,
        requests: ?[*]const wl_message,
        event_count: c_int,
        events: ?[*]const wl_message,
    };

    pub const wl_array = extern struct {
        size: usize,
        capacity: usize,
        data: ?*anyopaque,
    };

    pub const wl_fixed = Fixed;

    pub const wl_argument = extern union {
        int: i32,
        uint: u32,
        fixed: wl_fixed,
        string: ?[*:0]const u8,
        object: ?*wl_object,
        new_id: u32,
        array: *wl_array,
        fd: std.posix.fd_t,
    };

    pub const wl_object = opaque {};
    pub const wl_proxy = opaque {};

    pub const MarshalFlags = packed struct(u32) {
        /// destroy proxy after marshalling
        destroy: bool = false,
        _: u31 = 0,
    };
};

const builtin = @import("builtin");
const std = @import("std");
