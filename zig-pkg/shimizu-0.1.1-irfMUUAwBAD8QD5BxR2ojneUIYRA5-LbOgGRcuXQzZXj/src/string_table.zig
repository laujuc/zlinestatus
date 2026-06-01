pub fn StringTable(StringIndex: type) type {
    std.debug.assert(@typeInfo(StringIndex) == .@"enum");
    return struct {
        bytes: std.ArrayListUnmanaged(u8),

        pub const empty = @This(){
            .bytes = .empty,
        };

        pub fn deinit(this: *@This(), gpa: std.mem.Allocator) void {
            this.bytes.deinit(gpa);
        }

        pub fn fromReader(gpa: std.mem.Allocator, reader: *std.Io.Reader, table_size: usize) !@This() {
            var result: @This() = .empty;
            errdefer result.deinit(gpa);

            try result.bytes.ensureUnusedCapacity(gpa, table_size);
            const read_buf = result.bytes.unusedCapacitySlice();
            try reader.readSliceAll(read_buf[0..table_size]);

            return result;
        }

        pub fn addString(this: *@This(), gpa: std.mem.Allocator, string: []const u8) !StringIndex {
            try this.ensureUnusedCapacity(gpa, 1, string.len);
            return this.addStringAssumeCapacity(string);
        }

        pub fn ensureUnusedCapacity(this: *@This(), gpa: std.mem.Allocator, strings: usize, bytes: usize) !void {
            try this.bytes.ensureUnusedCapacity(gpa, bytes + strings);
        }

        pub fn addStringAssumeCapacity(this: *@This(), string: []const u8) StringIndex {
            std.debug.assert(std.mem.indexOfScalar(u8, string, 0) == null);
            const index: StringIndex = @enumFromInt(this.bytes.items.len);
            this.bytes.appendSliceAssumeCapacity(string);
            this.bytes.appendAssumeCapacity(0);
            return index;
        }

        pub fn getString(this: *const @This(), string_index: StringIndex) [:0]const u8 {
            const end = std.mem.indexOfScalarPos(u8, this.bytes.items, @intFromEnum(string_index), 0).?;
            return this.bytes.items[@intFromEnum(string_index)..end :0];
        }

        pub fn iterateStrings(this: *const @This()) StringIterator {
            return StringIterator{
                .bytes = this.bytes.items,
                .pos = 0,
            };
        }

        pub fn find(this: @This(), lookup: HashMap(void), text: []const u8) ?StringIndex {
            return lookup.getKeyAdapted(text, this.hashMapAdapter());
        }

        pub fn internString(this: *@This(), gpa: std.mem.Allocator, lookup: *HashMap(void), text: []const u8) !StringIndex {
            try this.bytes.ensureUnusedCapacity(gpa, text.len + 1);
            try lookup.ensureUnusedCapacityContext(gpa, 1, this.hashMapContext());

            const gop = lookup.getOrPutAssumeCapacityAdapted(text, this.hashMapAdapter());
            if (gop.found_existing) {
                return gop.key_ptr.*;
            }

            gop.key_ptr.* = this.addStringAssumeCapacity(text);
            return gop.key_ptr.*;
        }

        pub const StringIterator = struct {
            bytes: []const u8,
            pos: usize,

            pub const Item = struct {
                index: StringIndex,
                string: []const u8,
            };

            pub fn next(this: *@This()) ?Item {
                if (this.bytes.len - this.pos == 0) {
                    return null;
                }
                const index: StringIndex = @enumFromInt(this.pos);
                const end_of_string = std.mem.indexOfScalarPos(u8, this.bytes, this.pos, 0).?;
                const string = this.bytes[this.pos..end_of_string];
                this.pos = end_of_string + 1;
                return .{
                    .index = index,
                    .string = string,
                };
            }
        };

        pub fn HashMap(V: type) type {
            return std.ArrayHashMapUnmanaged(StringIndex, V, HashMapContext, true);
        }

        pub fn hashMapAdapter(this: *const @This()) HashMapAdapter {
            return HashMapAdapter{ .strings = this };
        }

        pub fn hashMapContext(this: *const @This()) HashMapContext {
            return HashMapContext{ .strings = this };
        }

        const ThisStringTable = @This();

        pub const HashMapContext = struct {
            strings: *const ThisStringTable,

            pub fn hash(this: @This(), i: StringIndex) u32 {
                const string = this.strings.getString(i);
                return @as(u32, @truncate(std.hash.Wyhash.hash(0, string)));
            }

            pub fn eql(this: @This(), a: StringIndex, b: StringIndex, b_index: usize) bool {
                _ = b_index;

                const a_string = this.strings.getString(a);
                const b_string = this.strings.getString(b);

                return std.mem.eql(u8, a_string, b_string);
            }
        };

        pub const HashMapAdapter = struct {
            strings: *const ThisStringTable,

            pub fn hash(this: @This(), string: []const u8) u32 {
                _ = this;
                return @as(u32, @truncate(std.hash.Wyhash.hash(0, string)));
            }

            pub fn eql(this: @This(), a: []const u8, b: StringIndex, b_index: usize) bool {
                _ = b_index;
                const b_string = this.strings.getString(b);
                return std.mem.eql(u8, a, b_string);
            }
        };
    };
}

pub fn Indexed(StringIndex: type) type {
    std.debug.assert(@typeInfo(StringIndex) == .@"enum");
    return struct {
        table: StringTable(StringIndex),
        lookup: StringTable(StringIndex).HashMap(void),

        pub const empty = @This(){
            .table = .empty,
            .lookup = .empty,
        };

        pub fn deinit(this: *@This(), gpa: std.mem.Allocator) void {
            this.table.deinit(gpa);
            this.lookup.deinit(gpa);
        }

        pub fn fromReader(gpa: std.mem.Allocator, reader: *std.Io.Reader, table_size: usize) !@This() {
            var result: @This() = .empty;
            errdefer result.deinit(gpa);

            try result.table.bytes.resize(gpa, table_size);
            try reader.readSliceAll(result.table.bytes.items);

            const table = result.table.bytes.items;

            var start_pos: usize = 0;
            while (std.mem.indexOfScalarPos(u8, table, start_pos, 0)) |nul_offset| : (start_pos = std.mem.indexOfNonePos(u8, table, nul_offset + 1, &.{0}) orelse nul_offset + 1) {
                const string = table[start_pos..nul_offset];
                const gop = try result.lookup.getOrPutContextAdapted(
                    gpa,
                    string,
                    result.table.hashMapAdapter(),
                    result.table.hashMapContext(),
                );
                std.debug.assert(!gop.found_existing);
                gop.key_ptr.* = @enumFromInt(start_pos);
            }

            return result;
        }

        pub fn ensureUnusedCapacity(this: *@This(), gpa: std.mem.Allocator, strings: usize, bytes: usize) !void {
            try this.table.ensureUnusedCapacity(gpa, strings, bytes);
            try this.lookup.ensureUnusedCapacity(gpa, strings);
        }

        pub fn find(this: @This(), text: []const u8) ?StringIndex {
            return this.table.find(this.lookup, text);
        }

        pub fn getString(this: *const @This(), string_index: StringIndex) [:0]const u8 {
            return this.table.getString(string_index);
        }

        pub fn iterateStrings(this: *const @This()) StringTable(StringIndex).StringIterator {
            return this.table.iterateStrings();
        }

        pub fn internString(this: *@This(), gpa: std.mem.Allocator, text: []const u8) !StringIndex {
            return this.table.internString(gpa, &this.lookup, text);
        }
    };
}

const std = @import("std");
