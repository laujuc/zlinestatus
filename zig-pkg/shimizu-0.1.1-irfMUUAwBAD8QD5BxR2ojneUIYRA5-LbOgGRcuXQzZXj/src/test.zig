test "serialize Registry.Event.Global" {
    var message_buffer: [24]u8 = undefined;

    var fixed_connection = shimizu.wire.FixedBufferConnection.init(message_buffer[0..], &.{});
    try fixed_connection.connection.writeStruct(shimizu.core.wl_registry.Event.Global, .{
        .name = 1,
        .interface = "wl_shm",
        .version = 3,
    });

    try std.testing.expectEqualSlices(
        u8,
        std.mem.sliceAsBytes(&[_]u32{
            1,
            7,
            @bitCast(@as([4]u8, "wl_s".*)),
            @bitCast(@as([4]u8, "hm\x00\x00".*)),
            3,
        }),
        fixed_connection.connection.message_writer.buffered(),
    );
}

test "deserialize Registry.Event.Global" {
    const words = [_]u32{
        1,
        7,
        @bitCast(@as([4]u8, "wl_s".*)),
        @bitCast(@as([4]u8, "hm\x00\x00".*)),
        3,
    };
    var words_index: usize = 0;
    const control = [_]u8{};
    var control_index: usize = 0;

    const parsed = try shimizu.wire.deserializeArguments(
        std.meta.TagPayload(shimizu.core.wl_registry.Event, .global),
        std.mem.sliceAsBytes(&words),
        &words_index,
        &control,
        &control_index,
    );
    try std.testing.expectEqualDeep(std.meta.TagPayload(shimizu.core.wl_registry.Event, .global){
        .name = 1,
        .interface = "wl_shm",
        .version = 3,
    }, parsed);
}

test "deserialize Registry.Event" {
    const header = shimizu.Header{
        .object = @enumFromInt(123),
        .size_and_opcode = .{
            .size = 28,
            .opcode = @intFromEnum(std.meta.Tag(shimizu.core.wl_registry.Event).global),
        },
    };
    const words = @as([2]u32, @bitCast(header)) ++ [_]u32{
        1,
        7,
        @bitCast(@as([4]u8, "wl_s".*)),
        @bitCast(@as([4]u8, "hm\x00\x00".*)),
        3,
    };
    var words_index: usize = 0;
    var control_buffer = [_]u8{};
    var control_index: usize = 0;

    const parsed = try shimizu.wire.deserialize(shimizu.core.wl_registry.Event, std.mem.sliceAsBytes(&words), &words_index, &control_buffer, &control_index);
    try std.testing.expectEqualDeep(
        shimizu.core.wl_registry.Event{ .global = .{
            .name = 1,
            .interface = "wl_shm",
            .version = 3,
        } },
        parsed,
    );

    const payload2 = [_]u32{
        1,
        15,
        40,
        @bitCast(@as([4]u8, "inva".*)),
        @bitCast(@as([4]u8, "lid ".*)),
        @bitCast(@as([4]u8, "argu".*)),
        @bitCast(@as([4]u8, "ment".*)),
        @bitCast(@as([4]u8, "s to".*)),
        @bitCast(@as([4]u8, " wl_".*)),
        @bitCast(@as([4]u8, "regi".*)),
        @bitCast(@as([4]u8, "stry".*)),
        @bitCast(@as([4]u8, "@2.b".*)),
        @bitCast(@as([4]u8, "ind\x00".*)),
    };
    const header2 = shimizu.Header{
        .object = .wl_display,
        .size_and_opcode = .{
            .size = payload2.len * @sizeOf(u32) + @sizeOf(shimizu.Header),
            .opcode = @intFromEnum(std.meta.Tag(shimizu.core.wl_display.Event).@"error"),
        },
    };
    const words2 = @as([2]u32, @bitCast(header2)) ++ payload2;
    control_buffer = [0]u8{};

    words_index = 0;
    control_index = 0;

    const parsed2 = try shimizu.wire.deserialize(
        shimizu.core.wl_display.Event,
        std.mem.sliceAsBytes(&words2),
        &words_index,
        &control_buffer,
        &control_index,
    );
    try std.testing.expectEqualDeep(
        shimizu.core.wl_display.Event{ .@"error" = .{
            .object_id = .wl_display,
            .code = 15,
            .message = "invalid arguments to wl_registry@2.bind",
        } },
        parsed2,
    );
}

const shimizu = @import("./shimizu.zig");
const std = @import("std");
