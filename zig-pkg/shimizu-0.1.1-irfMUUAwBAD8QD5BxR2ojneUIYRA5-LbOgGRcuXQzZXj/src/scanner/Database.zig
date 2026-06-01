const Database = @This();

protocol_names: string_table.Indexed(Protocol.Name),
summary_strings: string_table.StringTable(SummaryId),
comment_strings: string_table.StringTable(CommentId),
interface_names: string_table.Indexed(Interface.Name),
message_names: string_table.Indexed(Message.Name),
arg_names: string_table.Indexed(Arg.Name),
enum_names: string_table.Indexed(Enum.Name),
enum_entry_names: string_table.Indexed(EnumEntry.Name),

protocols: std.AutoArrayHashMapUnmanaged(Protocol.Name, Protocol),

interfaces: std.AutoArrayHashMapUnmanaged(Interface.Name, Interface),

interface_requests: std.ArrayList(Message),
interface_events: std.ArrayList(Message),
message_args: std.ArrayList(Arg),

enums: std.AutoArrayHashMapUnmanaged(Enum.Key, Enum),
enum_entries: std.AutoArrayHashMapUnmanaged(EnumEntry.Key, EnumEntry),

pub const empty = Database{
    .protocol_names = .empty,
    .summary_strings = .empty,
    .comment_strings = .empty,
    .interface_names = .empty,
    .message_names = .empty,
    .arg_names = .empty,
    .enum_names = .empty,
    .enum_entry_names = .empty,

    .protocols = .empty,

    .interfaces = .empty,

    .interface_requests = .empty,
    .interface_events = .empty,
    .message_args = .empty,

    .enums = .empty,
    .enum_entries = .empty,
};

pub const SummaryId = enum(u32) { null = std.math.maxInt(u32), _ };
pub const CommentId = enum(usize) { null = std.math.maxInt(u32), _ };

pub const Protocol = struct {
    pub const Name = enum(u32) { _ };

    summary: SummaryId,
    description: CommentId,
    copyright: CommentId,
    interfaces: Interfaces,

    pub const Interfaces = struct {
        start: u32,
        end: u32,

        pub fn slice(this: @This(), db: *const Database) struct { []const Interface.Name, []const Interface } {
            return .{
                db.interfaces.keys()[this.start..this.end],
                db.interfaces.values()[this.start..this.end],
            };
        }
    };
};

pub const Interface = struct {
    pub const Name = enum(u32) { _ };

    protocol: Protocol.Name,
    version: u32,
    summary: SummaryId,
    description: CommentId,
    events: Events,
    requests: Requests,
    enums: Enums,

    pub const Events = struct {
        start: u32,
        end: u32,

        pub const empty = @This(){ .start = 0, .end = 0 };

        pub fn slice(this: @This(), db: *const Database) []const Message {
            return db.interface_events.items[this.start..this.end];
        }
    };

    pub const Requests = struct {
        start: u32,
        end: u32,

        pub const empty = @This(){ .start = 0, .end = 0 };

        pub fn slice(this: @This(), db: *const Database) []const Message {
            return db.interface_requests.items[this.start..this.end];
        }
    };

    pub const Enums = struct {
        start: u32,
        end: u32,

        pub const empty = @This(){ .start = 0, .end = 0 };

        pub fn slice(this: @This(), db: *const Database) struct { []const Enum.Key, []const Enum } {
            return .{
                db.enums.keys()[this.start..this.end],
                db.enums.values()[this.start..this.end],
            };
        }
    };
};

pub const Message = struct {
    name: Name,
    summary: SummaryId,
    description: CommentId,
    since: u32,
    is_destructor: bool,
    args: Args,

    pub const Name = enum(u32) { _ };
    pub const Args = struct {
        start: u32,
        end: u32,

        pub fn slice(this: @This(), db: *const Database) []const Arg {
            return db.message_args.items[this.start..this.end];
        }
    };

    pub const Kind = enum { event, request };
};

pub const Enum = struct {
    pub const Key = struct {
        interface: Interface.Name,
        name: Name,
    };
    pub const Name = enum(u32) { _ };

    interface: Interface.Name,
    kind: Kind,
    summary: SummaryId,
    description: CommentId,
    since: u32,
    entries: Entries,

    pub const Kind = enum {
        @"enum",
        bitfield,
    };

    pub const Entries = struct {
        start: u32,
        end: u32,

        pub const empty = @This(){ .start = 0, .end = 0 };

        pub fn slice(this: @This(), db: *const Database) struct { []const EnumEntry.Key, []const EnumEntry } {
            return .{
                db.enum_entries.keys()[this.start..this.end],
                db.enum_entries.values()[this.start..this.end],
            };
        }
    };
};

pub const EnumEntry = struct {
    pub const Key = struct {
        interface: Interface.Name,
        name: Enum.Name,
        value: u32,
    };

    name: Name,
    summary: SummaryId,
    description: CommentId,
    since: u32,
    /// * 2 for binary formatting (`0b`)
    /// * 8 for octal formatting
    /// * 10 for decimal formatting
    /// * 16 for hexa-decimal formatting
    /// * Everything else is unspecfied, and any format might be used for printing it
    radix: u8,

    pub const Name = enum(u32) { _ };
};

pub const Arg = struct {
    name: Arg.Name,
    kind: Kind,
    summary: SummaryId,

    pub const Name = enum(u32) { _ };

    pub const Kind = union(Tag) {
        uint,
        int,
        fixed,
        string,
        string_optional,
        array,
        array_optional,
        @"enum": struct { interface: Interface.Name, name: Enum.Name },
        fd,
        new_id: Interface.Name,
        new_id_generic,
        object: Interface.Name,
        object_optional: Interface.Name,
        object_generic,
        object_generic_optional,

        pub const Tag = enum {
            uint,
            int,
            fixed,
            string,
            string_optional,
            array,
            array_optional,
            @"enum",
            fd,
            new_id,
            new_id_generic,
            object,
            object_optional,
            object_generic,
            object_generic_optional,
        };
    };
};

pub fn deinit(this: *@This(), gpa: std.mem.Allocator) void {
    this.protocol_names.deinit(gpa);
    this.summary_strings.deinit(gpa);
    this.comment_strings.deinit(gpa);
    this.interface_names.deinit(gpa);
    this.message_names.deinit(gpa);
    this.arg_names.deinit(gpa);
    this.enum_names.deinit(gpa);
    this.enum_entry_names.deinit(gpa);

    this.protocols.deinit(gpa);

    this.interfaces.deinit(gpa);

    this.interface_requests.deinit(gpa);
    this.interface_events.deinit(gpa);
    this.message_args.deinit(gpa);

    this.enums.deinit(gpa);
    this.enum_entries.deinit(gpa);
}

pub fn addEvents(this: *@This(), gpa: std.mem.Allocator, events: []const Message) !Interface.Events {
    const events_start = this.interface_events.items.len;
    try this.interface_events.appendSlice(gpa, events);
    const events_end = this.interface_events.items.len;
    return .{
        .start = @intCast(events_start),
        .end = @intCast(events_end),
    };
}

pub fn addArgs(this: *@This(), gpa: std.mem.Allocator, args: []const Arg) !Message.Args {
    const args_start = this.message_args.items.len;
    try this.message_args.appendSlice(gpa, args);
    const args_end = this.message_args.items.len;
    return .{
        .start = @intCast(args_start),
        .end = @intCast(args_end),
    };
}

const EnumEntryOptions = struct {
    value: u32,
    name: EnumEntry.Name,
    summary: SummaryId,
    description: CommentId,
    since: u32,
};

pub fn addEnumEntries(this: *@This(), gpa: std.mem.Allocator, enum_key: Enum.Key, enum_entries: []const EnumEntryOptions) !Enum.Entries {
    const entries_start = this.enum_entries.count();
    for (enum_entries) |entry| {
        try this.enum_entries.putNoClobber(gpa, .{
            .interface = enum_key.interface,
            .name = enum_key.name,
            .value = entry.value,
        }, .{
            .name = entry.name,
            .summary = entry.summary,
            .description = entry.description,
            .since = entry.since,
            .radix = 16,
        });
    }
    const entries_end = this.enum_entries.count();
    return .{
        .start = @intCast(entries_start),
        .end = @intCast(entries_end),
    };
}

const SerializedChunk = enum(u32) {
    protocol_names,
    summary_strings,
    comment_strings,
    interface_names,
    message_names,
    arg_names,
    enum_names,
    enum_entry_names,
    protocols,
    interfaces,
    interface_requests,
    interface_events,
    message_args,
    enums,
    enum_entries,
    end_of_database = std.math.maxInt(u32),
};

/// Reads serialized a Database file into memory.
///
/// Intended for shipping a database of Wayland protocols with an application.
///
/// It is not intended to be compatible between versions, or used for transfer between applications.
pub fn readSerializedData(gpa: std.mem.Allocator, reader: *std.Io.Reader) !Database {
    var result: Database = .empty;
    errdefer result.deinit(gpa);

    while (true) {
        const chunk_size = try reader.takeInt(u32, .little);
        const chunk_name = try reader.takeEnum(SerializedChunk, .little);

        switch (chunk_name) {
            inline .summary_strings,
            .comment_strings,
            => |tag| {
                if (@field(result, @tagName(tag)).bytes.items.len > 0) {
                    return error.DuplicateChunk;
                }
                @field(result, @tagName(tag)) = try .fromReader(gpa, reader, chunk_size);
            },
            inline .protocol_names,
            .interface_names,
            .message_names,
            .arg_names,
            .enum_names,
            .enum_entry_names,
            => |tag| {
                if (@field(result, @tagName(tag)).table.bytes.items.len > 0) {
                    return error.DuplicateChunk;
                }
                @field(result, @tagName(tag)) = try .fromReader(gpa, reader, chunk_size);
            },
            .interface_requests => {
                if (result.interface_requests.items.len > 0) {
                    return error.DuplicateChunk;
                }
                if (chunk_size % @sizeOf(Message) != 0) {
                    return error.InvalidData;
                }
                const count = @divExact(chunk_size, @sizeOf(Message));
                try result.interface_requests.resize(gpa, count);
                try reader.readSliceEndian(Message, result.interface_requests.items, .little);
            },
            .interface_events => {
                if (result.interface_events.items.len > 0) {
                    return error.DuplicateChunk;
                }
                if (chunk_size % @sizeOf(Message) != 0) {
                    return error.InvalidData;
                }
                const count = @divExact(chunk_size, @sizeOf(Message));
                try result.interface_events.resize(gpa, count);
                try reader.readSliceEndian(Message, result.interface_events.items, .little);
            },
            .message_args => {
                if (result.message_args.items.len > 0) {
                    return error.DuplicateChunk;
                }
                if (chunk_size % @sizeOf(Arg) != 0) {
                    return error.InvalidData;
                }
                const count = @divExact(chunk_size, @sizeOf(Arg));
                try result.message_args.resize(gpa, count);
                try reader.readSliceEndian(Arg, result.message_args.items, .little);
            },
            .protocols => {
                if (result.protocols.count() > 0) {
                    return error.DuplicateChunk;
                }
                result.protocols = try readAutoHashmap(Protocol.Name, Protocol, gpa, reader, chunk_size);
            },
            .interfaces => {
                if (result.interfaces.count() > 0) {
                    return error.DuplicateChunk;
                }
                result.interfaces = try readAutoHashmap(Interface.Name, Interface, gpa, reader, chunk_size);
            },
            .enums => {
                if (result.enums.count() > 0) {
                    return error.DuplicateChunk;
                }
                result.enums = try readAutoHashmap(Enum.Key, Enum, gpa, reader, chunk_size);
            },
            .enum_entries => {
                if (result.enum_entries.count() > 0) {
                    return error.DuplicateChunk;
                }
                result.enum_entries = try readAutoHashmap(EnumEntry.Key, EnumEntry, gpa, reader, chunk_size);
            },
            .end_of_database => {
                if (chunk_size != 0) return error.InvalidData;
                break;
            },
        }
    }

    return result;
}

fn readAutoHashmap(comptime K: type, comptime V: type, gpa: std.mem.Allocator, reader: *std.Io.Reader, num_bytes: usize) !std.AutoArrayHashMapUnmanaged(K, V) {
    if (num_bytes % (@sizeOf(K) + @sizeOf(V)) != 0) {
        return error.InvalidData;
    }
    const count = @divExact(num_bytes, @sizeOf(K) + @sizeOf(V));

    var result: std.AutoArrayHashMapUnmanaged(K, V) = .empty;
    try result.entries.resize(gpa, count);
    const slice = result.entries.slice();

    try reader.readSliceEndian(K, slice.items(.key), .little);
    try reader.readSliceEndian(V, slice.items(.value), .little);
    try result.reIndex(gpa);

    return result;
}

/// Writes a Database into a serialized file.
///
/// Intended for shipping a database of Wayland protocols with an application.
///
/// It is not intended to be compatible between versions, or used for transfer between applications.
pub fn writeSerializedData(this: *const @This(), w: *std.Io.Writer) !void {
    // protocol_names,
    try w.writeInt(u32, @intCast(this.protocol_names.table.bytes.items.len), .little);
    try w.writeInt(u32, @intFromEnum(SerializedChunk.protocol_names), .little);
    try w.writeAll(this.protocol_names.table.bytes.items);

    // summary_strings,
    try w.writeInt(u32, @intCast(this.summary_strings.bytes.items.len), .little);
    try w.writeInt(u32, @intFromEnum(SerializedChunk.summary_strings), .little);
    try w.writeAll(this.summary_strings.bytes.items);

    // comment_strings,
    try w.writeInt(u32, @intCast(this.comment_strings.bytes.items.len), .little);
    try w.writeInt(u32, @intFromEnum(SerializedChunk.comment_strings), .little);
    try w.writeAll(this.comment_strings.bytes.items);

    // interface_names,
    try w.writeInt(u32, @intCast(this.interface_names.table.bytes.items.len), .little);
    try w.writeInt(u32, @intFromEnum(SerializedChunk.interface_names), .little);
    try w.writeAll(this.interface_names.table.bytes.items);

    // message_names,
    try w.writeInt(u32, @intCast(this.message_names.table.bytes.items.len), .little);
    try w.writeInt(u32, @intFromEnum(SerializedChunk.message_names), .little);
    try w.writeAll(this.message_names.table.bytes.items);

    // arg_names,
    try w.writeInt(u32, @intCast(this.arg_names.table.bytes.items.len), .little);
    try w.writeInt(u32, @intFromEnum(SerializedChunk.arg_names), .little);
    try w.writeAll(this.arg_names.table.bytes.items);

    // enum_names,
    try w.writeInt(u32, @intCast(this.enum_names.table.bytes.items.len), .little);
    try w.writeInt(u32, @intFromEnum(SerializedChunk.enum_names), .little);
    try w.writeAll(this.enum_names.table.bytes.items);

    // enum_entry_names,
    try w.writeInt(u32, @intCast(this.enum_entry_names.table.bytes.items.len), .little);
    try w.writeInt(u32, @intFromEnum(SerializedChunk.enum_entry_names), .little);
    try w.writeAll(this.enum_entry_names.table.bytes.items);

    // hashmaps
    try writeAutoHashmap(.protocols, Protocol.Name, Protocol, &this.protocols, w);
    try writeAutoHashmap(.interfaces, Interface.Name, Interface, &this.interfaces, w);
    try writeAutoHashmap(.enums, Enum.Key, Enum, &this.enums, w);
    try writeAutoHashmap(.enum_entries, EnumEntry.Key, EnumEntry, &this.enum_entries, w);

    // interface_requests,
    {
        const size: u32 = @intCast(this.interface_requests.items.len * @sizeOf(Message));
        try w.writeInt(u32, size, .little);
        try w.writeInt(u32, @intFromEnum(SerializedChunk.interface_requests), .little);
        try w.writeSliceEndian(Message, this.interface_requests.items, .little);
    }

    // interface_events,
    {
        const size: u32 = @intCast(this.interface_events.items.len * @sizeOf(Message));
        try w.writeInt(u32, size, .little);
        try w.writeInt(u32, @intFromEnum(SerializedChunk.interface_events), .little);
        try w.writeSliceEndian(Message, this.interface_events.items, .little);
    }

    // message_args,
    {
        const size: u32 = @intCast(this.message_args.items.len * @sizeOf(Arg));
        try w.writeInt(u32, size, .little);
        try w.writeInt(u32, @intFromEnum(SerializedChunk.message_args), .little);
        try w.writeSliceEndian(Arg, this.message_args.items, .little);
    }

    // end of database chunk to signal end of file
    try w.writeInt(u32, 0, .little);
    try w.writeInt(u32, @intFromEnum(SerializedChunk.end_of_database), .little);
}

fn writeAutoHashmap(chunk_label: SerializedChunk, comptime K: type, comptime V: type, hashmap: *const std.AutoArrayHashMapUnmanaged(K, V), w: *std.Io.Writer) !void {
    const num_bytes: u32 = @intCast((@sizeOf(K) + @sizeOf(V)) * hashmap.count());

    try w.writeInt(u32, num_bytes, .little);
    try w.writeInt(u32, @intFromEnum(chunk_label), .little);

    const slice = hashmap.entries.slice();
    try w.writeSliceEndian(K, slice.items(.key), .little);
    try w.writeSliceEndian(V, slice.items(.value), .little);
}

const string_table = @import("../string_table.zig");
const std = @import("std");
const xml = @import("xml");
