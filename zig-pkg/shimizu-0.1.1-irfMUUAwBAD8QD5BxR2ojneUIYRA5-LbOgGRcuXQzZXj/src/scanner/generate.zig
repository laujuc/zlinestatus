const log = std.log.scoped(.@"shimizu-scanner");

db: *const Database,
writer: *std.Io.Writer,
required_imports: *std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, void),

pub fn writeProtocolZig(
    this: @This(),
    protocol_id: Database.Protocol.Name,
    interface_versions: *const std.AutoArrayHashMapUnmanaged(Database.Interface.Name, u32),
    protocol_import_strings: *const std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, []const u8),
) !void {
    const protocol = this.db.protocols.get(protocol_id).?;

    if (protocol.copyright != .null) {
        const copyright = this.db.comment_strings.getString(protocol.copyright);
        var line_iter = std.mem.splitScalar(u8, copyright, '\n');
        while (line_iter.next()) |line| {
            try this.writer.writeAll("// ");
            try this.writer.writeAll(line);
            try this.writer.writeAll("\n");
        }
        try this.writer.writeAll("\n");
    }

    try this.writer.writeAll(
        \\const wire = @import("wire");
        \\
    );

    const interface_names, const interfaces = protocol.interfaces.slice(this.db);
    for (interface_names, interfaces) |interface_name, interface| {
        const target_version = interface_versions.get(interface_name) orelse interface.version;
        try this.writeInterfaceZig(interface_name, interface, target_version);
    }

    try this.writeProtocolZigImports(protocol_id, protocol_import_strings);
}

pub fn writeProtocolZigImports(
    this: @This(),
    current_protocol_id: Database.Protocol.Name,
    protocol_import_strings: *const std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, []const u8),
) !void {
    const writer = this.writer;
    for (this.required_imports.keys()) |protocol_id| {
        const protocol_name = this.db.protocol_names.getString(protocol_id);
        if (protocol_id == current_protocol_id) {
            try writer.print("const {f} = @This();\n", .{std.zig.fmtId(protocol_name)});
            continue;
        }
        const import_string = protocol_import_strings.get(protocol_id).?;
        try writer.print("const {f} = {s};\n", .{ std.zig.fmtId(protocol_name), import_string });
    }
}

pub fn writeArgType(
    this: @This(),
    arg_kind: Database.Arg.Kind,
    current_interface_id: Database.Interface.Name,
) std.Io.Writer.Error!void {
    const writer = this.writer;
    write_type: switch (arg_kind) {
        .uint => try writer.writeAll("wire.Uint"),
        .int => try writer.writeAll("wire.Int"),
        .fixed => try writer.writeAll("wire.Fixed"),

        .string => try writer.writeAll("wire.String"),
        .string_optional => try writer.writeAll("?wire.String"),
        .array => try writer.writeAll("wire.Array"),
        .array_optional => try writer.writeAll("?wire.Array"),

        .fd => try writer.writeAll("wire.Fd"),

        .object_generic => try writer.writeAll("wire.Object"),
        .object_generic_optional => try writer.writeAll("?wire.Object"),

        .new_id_generic => try writer.writeAll("wire.NewId"),

        .@"enum" => |enum_id| {
            _ = current_interface_id;
            const specified_interface = this.db.interfaces.get(enum_id.interface).?;
            this.required_imports.putAssumeCapacity(specified_interface.protocol, {});

            const interface_name = this.db.interface_names.getString(enum_id.interface);
            const enum_name = this.db.enum_names.getString(enum_id.name);

            try writer.print("{f}.{f}", .{
                std.zig.fmtId(interface_name),
                SnakeToCamelCaseFormatted{ .snake_phrase = enum_name },
            });
        },

        .object_optional => |specified_interface_id| {
            try writer.writeByte('?');
            continue :write_type .{ .object = specified_interface_id };
        },
        .object => |specified_interface_id| {
            const specified_interface_name = this.db.interface_names.getString(specified_interface_id);
            const specified_interface = this.db.interfaces.get(specified_interface_id).?;
            this.required_imports.putAssumeCapacity(specified_interface.protocol, {});
            const protocol = this.db.protocol_names.getString(specified_interface.protocol);
            try writer.print("{f}.", .{std.zig.fmtId(protocol)});
            try writer.writeAll(specified_interface_name);
        },

        .new_id => |specified_interface_id| {
            const specified_interface = this.db.interfaces.get(specified_interface_id).?;
            this.required_imports.putAssumeCapacity(specified_interface.protocol, {});

            try writer.writeAll("wire.NewId.WithInterface(");

            const protocol_name = this.db.protocol_names.getString(specified_interface.protocol);
            try writer.print("{f}.", .{std.zig.fmtId(protocol_name)});

            const specified_interface_name = this.db.interface_names.getString(specified_interface_id);
            try writer.writeAll(specified_interface_name);

            try writer.writeAll(")");
        },
    }
}

pub fn writeInterfaceZig(this: @This(), interface_id: Database.Interface.Name, interface: Database.Interface, target_version: u32) !void {
    const writer = this.writer;

    try this.writeDescriptionIndented(interface.summary, interface.description, "/// ", 0);

    const interface_name = this.db.interface_names.getString(interface_id);
    try printIndented(writer, 0, "pub const {[name]s} = enum(u32) {{\n", .{ .name = interface_name });
    try writeIndented(writer, 1, "_,\n\n");
    try printIndented(writer, 1, "pub const NAME = \"{f}\";\n", .{std.zig.fmtString(interface_name)});
    try printIndented(writer, 1, "pub const VERSION = {};\n", .{target_version});

    try writer.writeByte('\n');

    // Requests enum
    const requests = interface.requests.slice(this.db);
    try writeIndented(writer, 1, "pub const Request = union(enum) {\n");
    for (requests) |req| {
        if (req.since > target_version) break;
        try this.writeMessageUnionField(req, "Request", 2);
    }
    try writer.writeByte('\n');
    for (requests, 0..) |req, opcode| {
        if (req.since > target_version) break;
        try this.writeMessageType(interface_id, @intCast(opcode), req, 2);
    }
    try writeIndented(writer, 1, "};\n\n");

    // print out Events union
    const events = interface.events.slice(this.db);
    try writeIndented(writer, 1, "pub const Event = union(enum) {\n");
    for (events) |event| {
        if (target_version < event.since) break;
        try this.writeMessageUnionField(event, "Event", 2);
    }
    try writer.writeByte('\n');
    for (events, 0..) |event, opcode| {
        if (target_version < event.since) break;
        try this.writeMessageType(interface_id, @intCast(opcode), event, 2);
    }
    try writeIndented(writer, 1, "};\n\n");

    // protocol defined enums
    const enum_keys, const enum_values = interface.enums.slice(this.db);
    for (enum_keys, enum_values) |enum_key, enum_value| {
        if (target_version < enum_value.since) break;
        try this.writeEnumZig(enum_key, enum_value, target_version, 2);
    }

    // output request functions
    for (requests) |request| {
        if (target_version < request.since) break;
        try this.writeSendFn(interface_id, request, 1);
    }

    try writeIndented(writer, 0, "};\n");
    try writer.writeAll("\n");
}

test writeInterfaceZig {
    var db: Database = .empty;
    defer db.deinit(std.testing.allocator);

    const interface_id = try db.interface_names.internString(std.testing.allocator, "wl_callback");
    const interface = Database.Interface{
        .protocol = try db.protocol_names.internString(std.testing.allocator, "wayland"),
        .version = 1,
        .summary = .null,
        .description = try db.comment_strings.addString(std.testing.allocator,
            \\Clients can handle the 'done' event to get notified when
            \\the related request is done.
            \\
            \\Note, because wl_callback objects are created from multiple independent
            \\factory interfaces, the wl_callback interface is frozen at version 1.
        ),
        .requests = .empty,
        .events = try db.addEvents(std.testing.allocator, &.{
            Database.Message{
                .name = try db.message_names.internString(std.testing.allocator, "done"),
                .summary = try db.summary_strings.addString(std.testing.allocator,
                    \\done event
                ),
                .description = try db.comment_strings.addString(std.testing.allocator,
                    \\Notify the client when the related request is done.
                ),
                .since = 0,
                .is_destructor = false,
                .args = try db.addArgs(std.testing.allocator, &.{
                    Database.Arg{
                        .name = try db.arg_names.internString(std.testing.allocator, "callback_data"),
                        .summary = try db.summary_strings.addString(std.testing.allocator,
                            \\request-specific data for the callback
                        ),
                        .kind = .uint,
                    },
                }),
            },
        }),
        .enums = .empty,
    };
    try db.interfaces.put(std.testing.allocator, interface_id, interface);

    const expected =
        \\/// Clients can handle the 'done' event to get notified when
        \\/// the related request is done.
        \\/// 
        \\/// Note, because wl_callback objects are created from multiple independent
        \\/// factory interfaces, the wl_callback interface is frozen at version 1.
        \\pub const wl_callback = enum(u32) {
        \\    _,
        \\
        \\    pub const NAME = "wl_callback";
        \\    pub const VERSION = 1;
        \\
        \\    pub const Request = union(enum) {
        \\
        \\    };
        \\
        \\    pub const Event = union(enum) {
        \\        done: Event.Done,
        \\
        \\        /// done event
        \\        ///
        \\        /// Notify the client when the related request is done.
        \\        pub const Done = struct {
        \\            pub const NAME = "done";
        \\            pub const OPCODE = 0;
        \\            pub const SINCE = 0;
        \\
        \\            /// request-specific data for the callback
        \\            callback_data: wire.Uint,
        \\        };
        \\
        \\    };
        \\
        \\};
        \\
        \\
    ;

    var required_imports: std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, void) = .empty;

    var allocating_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer allocating_writer.deinit();

    try writeInterfaceZig(.{
        .db = &db,
        .writer = &allocating_writer.writer,
        .required_imports = &required_imports,
    }, interface_id, interface, 1);

    try std.testing.expectEqualStrings(expected, allocating_writer.written());
}

pub fn writeSendFn(
    this: @This(),
    interface_id: Database.Interface.Name,
    message: Database.Message,
    indent: u32,
) !void {
    const writer = this.writer;

    const message_name = this.db.message_names.getString(message.name);
    const interface_name = this.db.interface_names.getString(interface_id);

    try printIndented(writer, indent + 0, "pub fn {f}(this: {f}, connection: *wire.Connection", .{
        std.zig.fmtId(message_name),
        std.zig.fmtId(interface_name),
    });
    var newid_kind_opt: ?Database.Arg.Kind = null;

    const message_args = message.args.slice(this.db);
    var args_len: usize = message_args.len;

    for (message_args) |arg| {
        switch (arg.kind) {
            .new_id_generic => {
                try writer.writeAll(", interface: [:0]const u8, version: u32");
                newid_kind_opt = .object_generic;
                args_len += 1;
            },
            .new_id => |specified_interface| {
                newid_kind_opt =
                    .{ .object = specified_interface };
            },
            else => {
                try writer.print(", {[name]s}: ", .{ .name = this.db.arg_names.getString(arg.name) });
                try this.writeArgType(arg.kind, interface_id);
                continue;
            },
        }
    }
    try writer.writeAll(") !");
    if (newid_kind_opt) |newid_type| {
        try this.writeArgType(newid_type, interface_id);
    } else {
        try writer.writeAll("void");
    }
    try writer.writeAll(" {\n");

    if (newid_kind_opt) |newid_kind| {
        switch (newid_kind) {
            .object_generic => {
                try writeIndented(writer, indent + 1, "const new_id = try connection.createId(interface, version);\n");
            },
            .object => |specified_interface_id| {
                const specified_interface_name = this.db.interface_names.getString(specified_interface_id);
                const specified_interface = this.db.interfaces.get(specified_interface_id).?;
                this.required_imports.putAssumeCapacity(specified_interface.protocol, {});
                const protocol_name = this.db.protocol_names.getString(specified_interface.protocol);
                try printIndented(writer, indent + 1, "const new_id = try connection.createId({f}.{f}.NAME, {f}.{f}.VERSION);\n", .{
                    std.zig.fmtId(protocol_name),
                    std.zig.fmtId(specified_interface_name),
                    std.zig.fmtId(protocol_name),
                    std.zig.fmtId(specified_interface_name),
                });
            },
            else => unreachable,
        }
        try writeIndented(writer, indent + 1, "errdefer connection.destroyId(new_id);\n");
    }

    const message_name_formatted = SnakeToCamelCaseFormatted{ .snake_phrase = message_name };
    try printIndented(writer, indent + 1, "try connection.begin(@enumFromInt(@intFromEnum(this)), Request.{f}.OPCODE);\n", .{message_name_formatted});
    try printIndented(writer, indent + 1, "try connection.writeStruct(@This().Request.{f}, .{{\n", .{message_name_formatted});
    for (message_args) |arg| {
        const arg_name = this.db.arg_names.getString(arg.name);
        switch (arg.kind) {
            .new_id => {
                try printIndented(writer, indent + 2, ".{f} = @enumFromInt(@intFromEnum(new_id)),\n", .{std.zig.fmtId(arg_name)});
            },
            .new_id_generic => {
                try printIndented(writer, indent + 2, ".{f} = .{{ .interface = interface, .version = version, .object = new_id }}\n", .{std.zig.fmtId(arg_name)});
            },
            else => try printIndented(writer, indent + 2, ".{f} = {f},\n", .{ std.zig.fmtId(arg_name), std.zig.fmtId(arg_name) }),
        }
    }
    try writeIndented(writer, indent + 1, "});\n");
    try writeIndented(writer, indent + 1, "try connection.end();\n");

    // const flags = if (message.is_destructor) ".{ .destroy = true }" else ".{}";
    if (newid_kind_opt != null) {
        try writeIndented(writer, indent + 1, "return @enumFromInt(@intFromEnum(new_id));\n");
    }
    try writeIndented(writer, indent + 0, "}\n\n");
}

test writeSendFn {
    var db: Database = .empty;
    defer db.deinit(std.testing.allocator);

    const wayland = try db.protocol_names.internString(std.testing.allocator, "wayland");

    const wl_surface = try db.interface_names.internString(std.testing.allocator, "wl_surface");
    try db.interfaces.putNoClobber(std.testing.allocator, wl_surface, .{
        .protocol = wayland,
        .version = 6,
        .summary = .null,
        .description = .null,
        .events = .empty,
        .requests = .empty,
        .enums = .empty,
    });

    const wl_compositor = try db.interface_names.internString(std.testing.allocator, "wl_compositor");
    // const create_surface_opcode = 0;
    const create_surface_message = Database.Message{
        .name = try db.message_names.internString(std.testing.allocator, "create_surface"),
        .summary = try db.summary_strings.addString(std.testing.allocator,
            \\create new surface
        ),
        .description = try db.comment_strings.addString(std.testing.allocator,
            \\Ask the compositor to create a new surface.
        ),
        .args = try db.addArgs(std.testing.allocator, &.{
            Database.Arg{
                .name = try db.arg_names.internString(std.testing.allocator, "id"),
                .summary = try db.summary_strings.addString(std.testing.allocator,
                    \\the new surface
                ),
                .kind = .{ .new_id = wl_surface },
            },
        }),
        .since = 0,
        .is_destructor = false,
    };

    var required_imports: std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, void) = .empty;
    defer required_imports.deinit(std.testing.allocator);
    try required_imports.ensureTotalCapacity(std.testing.allocator, 2);

    var allocating_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer allocating_writer.deinit();

    try writeSendFn(.{
        .db = &db,
        .writer = &allocating_writer.writer,
        .required_imports = &required_imports,
    }, wl_compositor, create_surface_message, 0);

    try std.testing.expectEqualStrings(
        \\pub fn create_surface(this: wl_compositor, connection: *wire.Connection) !wayland.wl_surface {
        \\    const new_id = try connection.createId(wayland.wl_surface.NAME, wayland.wl_surface.VERSION);
        \\    errdefer connection.destroyId(new_id);
        \\    try connection.begin(@enumFromInt(@intFromEnum(this)), Request.CreateSurface.OPCODE);
        \\    try connection.writeStruct(@This().Request.CreateSurface, .{
        \\        .id = @enumFromInt(@intFromEnum(new_id)),
        \\    });
        \\    try connection.end();
        \\    return @enumFromInt(@intFromEnum(new_id));
        \\}
        \\
        \\
    , allocating_writer.written());
}

pub fn writeMessageUnionField(
    this: @This(),
    message: Database.Message,
    message_union_name: []const u8,
    indent: u32,
) !void {
    const message_name = this.db.message_names.getString(message.name);
    try printIndented(this.writer, indent, "{[name]f}: {[union_name]f}.{[type_name]f},\n", .{
        .name = std.zig.fmtId(message_name),
        .union_name = std.zig.fmtId(message_union_name),
        .type_name = SnakeToCamelCaseFormatted{ .snake_phrase = message_name },
    });
}

pub fn writeMessageType(
    this: @This(),
    interface_id: Database.Interface.Name,
    opcode: u16,
    message: Database.Message,
    indent: u32,
) !void {
    const writer = this.writer;
    try this.writeDescriptionIndented(message.summary, message.description, "/// ", indent);

    const message_name = this.db.message_names.getString(message.name);
    try printIndented(writer, indent, "pub const {[name]f} = struct {{\n", .{ .name = SnakeToCamelCaseFormatted{ .snake_phrase = message_name } });
    try printIndented(writer, indent + 1, "pub const NAME = \"{f}\";\n", .{std.zig.fmtString(message_name)});
    try printIndented(writer, indent + 1, "pub const OPCODE = {};\n", .{opcode});
    try printIndented(writer, indent + 1, "pub const SINCE = {};\n", .{message.since});

    // message arg struct
    const message_args = message.args.slice(this.db);
    if (message_args.len > 0) try writer.writeAll("\n");
    for (message_args) |arg| {
        if (arg.summary != .null) {
            const summary = this.db.summary_strings.getString(arg.summary);
            try printIndented(writer, indent + 1, "/// {f}\n", .{stripNewlines(std.mem.trim(u8, summary, " \t\n"))});
        }

        try printIndented(writer, indent + 1, "{[name]s}: ", .{ .name = this.db.arg_names.getString(arg.name) });
        try this.writeArgType(arg.kind, interface_id);
        try writer.writeAll(",\n");
    }

    try writeIndented(writer, indent, "};\n\n");
}

test "writeSendFn for wl_surface.damage_buffer" {
    var db: Database = .empty;
    defer db.deinit(std.testing.allocator);

    const interface_id = try db.interface_names.internString(std.testing.allocator, "wl_surface");
    const damage_buffer_message = Database.Message{
        .name = try db.message_names.internString(std.testing.allocator, "damage_buffer"),
        .summary = try db.summary_strings.addString(std.testing.allocator,
            \\mark part of the surface damaged using buffer coordinates
        ),
        .description = try db.comment_strings.addString(std.testing.allocator,
            \\Mark regions where pending buffer is different from the current surface contents.
            \\
            \\Damage is double-buffered state.
        ),
        .since = 4,
        .is_destructor = false,
        .args = try db.addArgs(std.testing.allocator, &.{
            Database.Arg{
                .name = try db.arg_names.internString(std.testing.allocator, "x"),
                .summary = try db.summary_strings.addString(std.testing.allocator, "buffer-local x coordinate"),
                .kind = .int,
            },
            Database.Arg{
                .name = try db.arg_names.internString(std.testing.allocator, "y"),
                .summary = try db.summary_strings.addString(std.testing.allocator, "buffer-local y coordinate"),
                .kind = .int,
            },
            Database.Arg{
                .name = try db.arg_names.internString(std.testing.allocator, "width"),
                .summary = try db.summary_strings.addString(std.testing.allocator, "width of damage rectangle"),
                .kind = .int,
            },
            Database.Arg{
                .name = try db.arg_names.internString(std.testing.allocator, "height"),
                .summary = try db.summary_strings.addString(std.testing.allocator, "height of damage rectangle"),
                .kind = .int,
            },
        }),
    };

    var required_imports: std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, void) = .empty;
    defer required_imports.deinit(std.testing.allocator);
    try required_imports.ensureTotalCapacity(std.testing.allocator, db.protocols.count());

    var allocating_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer allocating_writer.deinit();

    try writeSendFn(.{
        .db = &db,
        .writer = &allocating_writer.writer,
        .required_imports = &required_imports,
    }, interface_id, damage_buffer_message, 0);

    try std.testing.expectEqualStrings(
        \\pub fn damage_buffer(this: wl_surface, connection: *wire.Connection, x: wire.Int, y: wire.Int, width: wire.Int, height: wire.Int) !void {
        \\    try connection.begin(@enumFromInt(@intFromEnum(this)), Request.DamageBuffer.OPCODE);
        \\    try connection.writeStruct(@This().Request.DamageBuffer, .{
        \\        .x = x,
        \\        .y = y,
        \\        .width = width,
        \\        .height = height,
        \\    });
        \\    try connection.end();
        \\}
        \\
        \\
    , allocating_writer.written());
}

test "writeSendFn for wl_registry.bind" {
    var db: Database = .empty;
    defer db.deinit(std.testing.allocator);

    const interface_id = try db.interface_names.internString(std.testing.allocator, "wl_registry");
    const bind_message = Database.Message{
        .name = try db.message_names.internString(std.testing.allocator, "bind"),
        .summary = .null,
        .description = .null,
        .since = 0,
        .is_destructor = false,
        .args = try db.addArgs(std.testing.allocator, &.{
            Database.Arg{
                .name = try db.arg_names.internString(std.testing.allocator, "name"),
                .summary = .null,
                .kind = .uint,
            },
            Database.Arg{
                .name = try db.arg_names.internString(std.testing.allocator, "id"),
                .summary = .null,
                .kind = .new_id_generic,
            },
        }),
    };

    var required_imports: std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, void) = .empty;
    defer required_imports.deinit(std.testing.allocator);
    try required_imports.ensureTotalCapacity(std.testing.allocator, db.protocols.count());

    var allocating_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer allocating_writer.deinit();

    try writeSendFn(.{
        .db = &db,
        .writer = &allocating_writer.writer,
        .required_imports = &required_imports,
    }, interface_id, bind_message, 0);

    try std.testing.expectEqualStrings(
        \\pub fn bind(this: wl_registry, connection: *wire.Connection, name: wire.Uint, interface: [:0]const u8, version: u32) !wire.Object {
        \\    const new_id = try connection.createId(interface, version);
        \\    errdefer connection.destroyId(new_id);
        \\    try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Bind.OPCODE);
        \\    try connection.writeStruct(@This().Request.Bind, .{
        \\        .name = name,
        \\        .id = .{ .interface = interface, .version = version, .object = new_id }
        \\    });
        \\    try connection.end();
        \\    return @enumFromInt(@intFromEnum(new_id));
        \\}
        \\
        \\
    , allocating_writer.written());
}

test "writeSendFn correctly imports required types" {
    var db: Database = .empty;
    defer db.deinit(std.testing.allocator);

    const wayland = try db.protocol_names.internString(std.testing.allocator, "wayland");
    const presentation_time = try db.protocol_names.internString(std.testing.allocator, "presentation_time");

    const wl_surface = try db.interface_names.internString(std.testing.allocator, "wl_surface");
    try db.interfaces.putNoClobber(std.testing.allocator, wl_surface, .{
        .protocol = wayland,
        .version = 6,
        .summary = .null,
        .description = .null,
        .events = .empty,
        .requests = .empty,
        .enums = .empty,
    });

    const wp_presentation_feedback = try db.interface_names.internString(std.testing.allocator, "wp_presentation_feedback");
    try db.interfaces.putNoClobber(std.testing.allocator, wp_presentation_feedback, .{
        .protocol = presentation_time,
        .version = 6,
        .summary = .null,
        .description = .null,
        .events = .empty,
        .requests = .empty,
        .enums = .empty,
    });

    const wp_presentation = try db.interface_names.internString(std.testing.allocator, "wp_presentation");
    const feedback_message = Database.Message{
        .name = try db.message_names.internString(std.testing.allocator, "feedback"),
        .summary = .null,
        .description = .null,
        .since = 0,
        .is_destructor = false,
        .args = try db.addArgs(std.testing.allocator, &.{
            Database.Arg{
                .name = try db.arg_names.internString(std.testing.allocator, "surface"),
                .summary = .null,
                .kind = .{ .object = wl_surface },
            },
            Database.Arg{
                .name = try db.arg_names.internString(std.testing.allocator, "callback"),
                .summary = .null,
                .kind = .{ .new_id = wp_presentation_feedback },
            },
        }),
    };

    var required_imports: std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, void) = .empty;
    defer required_imports.deinit(std.testing.allocator);
    try required_imports.ensureTotalCapacity(std.testing.allocator, 2);

    var allocating_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer allocating_writer.deinit();

    try writeSendFn(.{
        .db = &db,
        .writer = &allocating_writer.writer,
        .required_imports = &required_imports,
    }, wp_presentation, feedback_message, 0);

    try std.testing.expectEqualStrings(
        \\pub fn feedback(this: wp_presentation, connection: *wire.Connection, surface: wayland.wl_surface) !presentation_time.wp_presentation_feedback {
        \\    const new_id = try connection.createId(presentation_time.wp_presentation_feedback.NAME, presentation_time.wp_presentation_feedback.VERSION);
        \\    errdefer connection.destroyId(new_id);
        \\    try connection.begin(@enumFromInt(@intFromEnum(this)), Request.Feedback.OPCODE);
        \\    try connection.writeStruct(@This().Request.Feedback, .{
        \\        .surface = surface,
        \\        .callback = @enumFromInt(@intFromEnum(new_id)),
        \\    });
        \\    try connection.end();
        \\    return @enumFromInt(@intFromEnum(new_id));
        \\}
        \\
        \\
    , allocating_writer.written());
}

pub fn writeEnumZig(this: @This(), enum_key: Database.Enum.Key, enum_value: Database.Enum, target_version: u32, indent: u32) !void {
    const writer = this.writer;
    if (enum_value.kind == .bitfield) {
        return this.writeBitfieldZig(enum_key, enum_value, target_version, indent);
    }

    const enum_name = this.db.enum_names.getString(enum_key.name);
    try printIndented(writer, indent, "pub const {f}", .{SnakeToCamelCaseFormatted{ .snake_phrase = enum_name }});
    try writer.writeAll(" = enum(wire.Uint) {\n");

    const enum_entry_keys, const enum_entries = enum_value.entries.slice(this.db);
    for (enum_entry_keys, enum_entries) |entry_key, entry_value| {
        if (entry_value.since > target_version) break;

        try this.writeDescriptionIndented(entry_value.summary, entry_value.description, "/// ", indent + 1);

        const entry_name = this.db.enum_entry_names.getString(entry_value.name);

        try writer.splatByteAll(' ', 4 * (indent + 1));
        try std.zig.fmtId(entry_name).format(writer);
        try writer.writeAll(" = ");
        switch (entry_value.radix) {
            2 => {
                try writer.writeAll("0b");
                try writer.printInt(entry_key.value, 2, .lower, .{});
            },
            8 => {
                try writer.writeAll("0o");
                try writer.printInt(entry_key.value, 8, .lower, .{});
            },
            16 => {
                try writer.writeAll("0x");
                try writer.printInt(entry_key.value, 16, .lower, .{});
            },
            else => try writer.printInt(entry_key.value, 10, .lower, .{}),
        }
        try writer.writeAll(",\n");
    }

    try writeIndented(writer, indent, "};\n\n");
}

test writeEnumZig {
    var db: Database = .empty;
    defer db.deinit(std.testing.allocator);

    const wl_data_device_manager = try db.interface_names.internString(std.testing.allocator, "wl_data_device_manager");
    const dnd_action_enum_key = Database.Enum.Key{
        .interface = wl_data_device_manager,
        .name = try db.enum_names.internString(std.testing.allocator, "error"),
    };
    const dnd_action_enum = Database.Enum{
        .interface = wl_data_device_manager,
        .summary = .null,
        .description = .null,
        .since = 0,
        .kind = .@"enum",
        .entries = try db.addEnumEntries(std.testing.allocator, dnd_action_enum_key, &.{
            .{ .name = try db.enum_entry_names.internString(std.testing.allocator, "invalid_finish"), .value = 0, .summary = try db.summary_strings.addString(std.testing.allocator, "finish request was called untimely"), .description = .null, .since = 0 },
            .{ .name = try db.enum_entry_names.internString(std.testing.allocator, "invalid_action_mask"), .value = 1, .summary = try db.summary_strings.addString(std.testing.allocator, "action mask contains invalid values"), .description = .null, .since = 0 },
            .{ .name = try db.enum_entry_names.internString(std.testing.allocator, "invalid_action"), .value = 2, .summary = try db.summary_strings.addString(std.testing.allocator, "action argument has an invalid value"), .description = .null, .since = 0 },
            .{ .name = try db.enum_entry_names.internString(std.testing.allocator, "invalid_offer"), .value = 3, .summary = try db.summary_strings.addString(std.testing.allocator, "offer doesn't accept this request"), .description = .null, .since = 0 },
        }),
    };

    var required_imports: std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, void) = .empty;
    defer required_imports.deinit(std.testing.allocator);
    try required_imports.ensureTotalCapacity(std.testing.allocator, db.protocols.count());

    var allocating_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer allocating_writer.deinit();

    try writeEnumZig(.{
        .db = &db,
        .writer = &allocating_writer.writer,
        .required_imports = &required_imports,
    }, dnd_action_enum_key, dnd_action_enum, 0, 0);

    try std.testing.expectEqualStrings(
        \\pub const Error = enum(wire.Uint) {
        \\    /// finish request was called untimely
        \\    invalid_finish = 0x0,
        \\    /// action mask contains invalid values
        \\    invalid_action_mask = 0x1,
        \\    /// action argument has an invalid value
        \\    invalid_action = 0x2,
        \\    /// offer doesn't accept this request
        \\    invalid_offer = 0x3,
        \\};
        \\
        \\
    , allocating_writer.written());
}

fn writeBitfieldZig(this: @This(), enum_key: Database.Enum.Key, enum_value: Database.Enum, target_version: u32, indent: u32) !void {
    const writer = this.writer;

    const enum_name = this.db.enum_names.getString(enum_key.name);
    try printIndented(this.writer, indent, "pub const {f}", .{SnakeToCamelCaseFormatted{ .snake_phrase = enum_name }});

    // check for duplicate bit fields
    var bits = std.bit_set.IntegerBitSet(32).initEmpty();
    const entry_keys, const entry_values = enum_value.entries.slice(this.db);
    for (entry_keys, entry_values) |entry_key, entry_value| {
        const entry_name = this.db.enum_entry_names.getString(entry_value.name);
        errdefer log.debug("entry name = {s}.{s}", .{ enum_name, entry_name });

        if (entry_value.since > target_version) continue;

        const entry_int = entry_key.value;

        if (entry_int == 0) continue;
        if (@popCount(entry_int) > 1) {
            continue;
        }

        const bit_index = std.math.log2(entry_int);
        if (bits.isSet(bit_index)) return error.DuplicateBitField;
        bits.set(bit_index);
    }

    try writer.writeAll(" = packed struct(wire.Uint) {\n");

    // write out field names
    var bit_iter = bits.iterator(.{});
    var prev_index: usize = 0;
    var padding_number: usize = 1;
    while (bit_iter.next()) |bit_index| {
        if (bit_index - prev_index > 1) {
            try printIndented(writer, indent + 1, "padding_{}: u{} = 0,\n", .{ padding_number, bit_index - prev_index });
            padding_number += 1;
        }
        for (entry_keys, entry_values) |entry_key, entry_value| {
            if (entry_value.since > target_version) break;

            const entry_int = entry_key.value;

            if (entry_int == 0) continue;
            if (@popCount(entry_int) > 1) {
                continue;
            }

            const value_bit_index = std.math.log2(entry_int);
            if (value_bit_index != bit_index) continue;

            const entry_name = this.db.enum_entry_names.getString(entry_value.name);
            try this.writeDescriptionIndented(entry_value.summary, entry_value.description, "/// ", indent + 1);
            try printIndented(writer, indent + 1, "{[name]f}: bool,\n", .{ .name = std.zig.fmtId(entry_name) });
        }

        prev_index = bit_index;
    }
    if (prev_index != 31) {
        try printIndented(writer, indent + 1, "padding_{}: u{} = 0,\n", .{ padding_number, 31 - prev_index });
    }

    // write out multi bit values as declarations
    for (entry_keys, entry_values) |entry_key, entry_value| {
        const entry_name = this.db.enum_entry_names.getString(entry_value.name);
        errdefer log.debug("entry name = {s}.{s}", .{ enum_name, entry_name });

        if (entry_value.since > target_version) continue;

        const entry_int = entry_key.value;
        if (@popCount(entry_int) == 1) {
            continue;
        }

        try printIndented(writer, indent + 1, "pub const {f}: @This() = @bitCast(@as(u32, 0b{b}));\n", .{ std.zig.fmtId(entry_name), entry_key.value });
    }

    try writeIndented(writer, indent, "};\n\n");

    return;
}

test writeBitfieldZig {
    var db: Database = .empty;
    defer db.deinit(std.testing.allocator);

    const wl_data_device_manager = try db.interface_names.internString(std.testing.allocator, "wl_data_device_manager");
    const dnd_action_enum_key = Database.Enum.Key{
        .interface = wl_data_device_manager,
        .name = try db.enum_names.internString(std.testing.allocator, "dnd_action"),
    };
    const dnd_action_enum = Database.Enum{
        .interface = wl_data_device_manager,
        .kind = .bitfield,
        .summary = .null,
        .description = .null,
        .since = 0,
        .entries = try db.addEnumEntries(std.testing.allocator, dnd_action_enum_key, &.{
            .{ .name = try db.enum_entry_names.internString(std.testing.allocator, "none"), .value = 0, .summary = try db.summary_strings.addString(std.testing.allocator, "ask action"), .description = .null, .since = 0 },
            .{ .name = try db.enum_entry_names.internString(std.testing.allocator, "copy"), .value = 1, .summary = try db.summary_strings.addString(std.testing.allocator, "copy action"), .description = .null, .since = 0 },
            .{ .name = try db.enum_entry_names.internString(std.testing.allocator, "move"), .value = 2, .summary = try db.summary_strings.addString(std.testing.allocator, "move action"), .description = .null, .since = 0 },
            .{ .name = try db.enum_entry_names.internString(std.testing.allocator, "ask"), .value = 4, .summary = try db.summary_strings.addString(std.testing.allocator, "ask action"), .description = .null, .since = 0 },
        }),
    };

    var required_imports: std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, void) = .empty;
    defer required_imports.deinit(std.testing.allocator);
    try required_imports.ensureTotalCapacity(std.testing.allocator, db.protocols.count());

    var allocating_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer allocating_writer.deinit();

    try writeBitfieldZig(.{
        .db = &db,
        .writer = &allocating_writer.writer,
        .required_imports = &required_imports,
    }, dnd_action_enum_key, dnd_action_enum, 0, 0);

    try std.testing.expectEqualStrings(
        \\pub const DndAction = packed struct(wire.Uint) {
        \\    /// copy action
        \\    copy: bool,
        \\    /// move action
        \\    move: bool,
        \\    /// ask action
        \\    ask: bool,
        \\    padding_1: u29 = 0,
        \\    pub const none: @This() = @bitCast(@as(u32, 0b0));
        \\};
        \\
        \\
    , allocating_writer.written());
}

pub fn writeInterfaceCompat(this: @This(), interface_id: Database.Interface.Name, interface: Database.Interface, target_version: u32) !void {
    const writer = this.writer;

    try this.writeDescriptionIndented(interface.summary, interface.description, "/// ", 0);

    const interface_name = this.db.interface_names.getString(interface_id);
    try printIndented(writer, 0, "pub const {[name]s} = opaque {{\n", .{ .name = interface_name });
    try printIndented(writer, 1, "pub const NAME = \"{f}\";\n", .{std.zig.fmtString(interface_name)});
    try printIndented(writer, 1, "pub const VERSION = {};\n", .{target_version});

    try writer.writeByte('\n');

    try writeIndented(writer, 1, "comptime {\n");
    try printIndented(writer, 2, "@export(INTERFACE, .{{ .name = \"{f}_interface\" }});\n", .{
        std.zig.fmtString(interface_name),
    });
    try writeIndented(writer, 1, "}\n");

    try writer.writeByte('\n');

    try writeIndented(writer, 1, "pub const INTERFACE: *const wl_interface = &.{\n");
    try printIndented(writer, 2, ".name = \"{f}\",\n", .{std.zig.fmtString(interface_name)});
    try printIndented(writer, 2, ".version = {},\n", .{interface.version});
    try printIndented(writer, 2, ".requests = &{f}.REQUESTS,\n", .{std.zig.fmtId(interface_name)});
    try printIndented(writer, 2, ".request_count = {f}.REQUESTS.len,\n", .{std.zig.fmtId(interface_name)});
    try printIndented(writer, 2, ".events = &{f}.EVENTS,\n", .{std.zig.fmtId(interface_name)});
    try printIndented(writer, 2, ".event_count = {f}.EVENTS.len,\n", .{std.zig.fmtId(interface_name)});
    try writeIndented(writer, 1, "};\n");

    try writer.writeByte('\n');

    // Requests enum
    const requests = interface.requests.slice(this.db);
    try writeIndented(writer, 1, "pub const REQUESTS = [_]wl_message{\n");
    for (requests) |req| {
        if (req.since > target_version) break;
        try this.writeMessageStructCompat(req, 2);
    }
    try writeIndented(writer, 1, "};\n\n");

    // print out Events union
    const events = interface.events.slice(this.db);
    try writeIndented(writer, 1, "pub const EVENTS = [_]wl_message{\n");
    for (events) |event| {
        if (target_version < event.since) break;
        try this.writeMessageStructCompat(event, 2);
    }
    try writeIndented(writer, 1, "};\n\n");

    // protocol defined enums
    const enum_keys, const enum_values = interface.enums.slice(this.db);
    for (enum_keys, enum_values) |enum_key, enum_value| {
        if (target_version < enum_value.since) break;
        try this.writeEnumZig(enum_key, enum_value, target_version, 2);
    }

    try writeIndented(writer, 1, "pub const EventListener = extern struct {\n");
    for (events) |event| {
        if (target_version < event.since) break;
        const event_name = this.db.message_names.getString(event.name);
        try printIndented(writer, 2, "{f}: *const ", .{std.zig.fmtId(event_name)});
        try this.writeMessageListenerFnCompat(interface_id, event);
        try writer.writeAll(",\n");
    }
    try writeIndented(writer, 1, "};\n\n");

    try writeIndented(writer, 1,
        \\pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        \\    if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
        \\}
        \\
        \\
    );

    // output request functions
    for (requests, 0..) |request, opcode| {
        if (target_version < request.since) break;
        try this.writeMessageSendFnCompat(interface_id, @intCast(opcode), request, 1);
    }

    try writeIndented(writer, 0, "};\n");
    try writer.writeAll("\n");
    try printIndented(writer, 0, "comptime {{ _ = {f}.INTERFACE; }}\n", .{std.zig.fmtId(interface_name)});
}

pub fn writeMessageListenerFnCompat(this: @This(), current_interface: Database.Interface.Name, message: Database.Message) !void {
    // COMPAT_LISTENER_FN
    const writer = this.writer;
    const current_interface_name = this.db.interface_names.getString(current_interface);
    const message_args = message.args.slice(this.db);

    try writer.print("fn(?*anyopaque, *{f}", .{std.zig.fmtId(current_interface_name)});
    for (message_args) |arg| {
        switch (arg.kind) {
            .new_id_generic => try writer.writeAll(", name: u32, interface: *const wl_interface, version: u32"),
            .new_id => |specified_interface| {
                const specified_interface_name = this.db.interface_names.getString(specified_interface);
                try writer.print(", *{f}", .{std.zig.fmtId(specified_interface_name)});
            },
            else => {
                try writer.print(", {[name]s}: ", .{ .name = this.db.arg_names.getString(arg.name) });
                try this.writeArgTypeCompat(current_interface, arg.kind);
                continue;
            },
        }
    }
    try writer.writeAll(") callconv(.c) void");
}

pub fn writeMessageSendFnCompat(this: @This(), current_interface_id: Database.Interface.Name, opcode: u16, message: Database.Message, indent: u32) !void {
    const writer = this.writer;
    const message_name = this.db.message_names.getString(message.name);
    const message_args = message.args.slice(this.db);

    try printIndented(writer, indent + 0, "pub fn {f}(this: *@This()", .{std.zig.fmtId(message_name)});
    var newid_kind_opt: ?Database.Arg.Kind = null;
    var args_len: usize = message_args.len;
    for (message_args) |arg| {
        switch (arg.kind) {
            .new_id_generic => {
                try writer.writeAll(", interface: *const wl_interface, version: u32");
                newid_kind_opt = .object_generic;
                args_len += 1;
            },
            .new_id => |specified_interface| {
                newid_kind_opt = .{ .object = specified_interface };
            },
            else => {
                try writer.print(", {[name]s}: ", .{ .name = this.db.arg_names.getString(arg.name) });
                try this.writeArgTypeCompat(current_interface_id, arg.kind);
                continue;
            },
        }
    }
    try writer.writeAll(")");
    if (newid_kind_opt) |newid_kind| {
        try writer.writeAll(" error{Failure}!*");
        const newid_text = switch (newid_kind) {
            .object => |specified_interface| this.db.interface_names.getString(specified_interface),
            .object_generic => "wl_proxy",
            else => unreachable,
        };
        try writer.writeAll(newid_text);
    } else {
        try writer.writeAll("void");
    }
    try writer.writeAll(" {\n");

    try printIndented(writer, indent + 1, "var args: [{}]wl_argument = .{{", .{args_len});
    for (message_args) |arg| {
        const arg_name = this.db.arg_names.getString(arg.name);
        switch (arg.kind) {
            .new_id => {
                // |specified_interface| {
                // const specified_interface_name = this.db.interface_names.getString(specified_interface);
                try writeIndented(writer, indent + 2, ".{ .object = null },\n");
            },
            .new_id_generic => {
                try writeIndented(writer, indent + 2, ".{ .string = interface.name },\n");
                try writeIndented(writer, indent + 2, ".{ .uint = version },\n");
            },
            .@"enum" => {
                try printIndented(writer, indent + 2, ".{{ .uint = @intFromEnum({f}) }},\n", .{std.zig.fmtId(arg_name)});
            },
            .uint => try printIndented(writer, indent + 2, ".{{ .uint = {f} }},\n", .{std.zig.fmtId(arg_name)}),
            .int => try printIndented(writer, indent + 2, ".{{ .int = {f} }},\n", .{std.zig.fmtId(arg_name)}),
            .fixed => try printIndented(writer, indent + 2, ".{{ .fixed = {f} }},\n", .{std.zig.fmtId(arg_name)}),

            .object,
            .object_optional,
            => try printIndented(writer, indent + 2, ".{{ .object = @ptrCast({f}) }},\n", .{std.zig.fmtId(arg_name)}),
            .object_generic,
            .object_generic_optional,
            => try printIndented(writer, indent + 2, ".{{ .object = {f} }},\n", .{std.zig.fmtId(arg_name)}),

            .fd => try printIndented(writer, indent + 2, ".{{ .fd = @intFromEnum({f}) }},\n", .{std.zig.fmtId(arg_name)}),

            .string,
            .string_optional,
            => try printIndented(writer, indent + 2, ".{{ .string = {f} }},\n", .{std.zig.fmtId(arg_name)}),

            .array,
            .array_optional,
            => try printIndented(writer, indent + 2, ".{{ .array = {f} }},\n", .{std.zig.fmtId(arg_name)}),
        }
    }
    try writeIndented(writer, indent + 1, "};\n\n");

    const flags = if (message.is_destructor) ".{ .destroy = true }" else ".{}";
    if (newid_kind_opt) |newid_kind| {
        switch (newid_kind) {
            .object => |specified_interface| {
                const specified_name = this.db.interface_names.getString(specified_interface);
                try printIndented(writer, indent + 1, "return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), {}, {s}.INTERFACE, wl_proxy_get_version(@ptrCast(this)), {s}, &args", .{ opcode, specified_name, flags });
            },
            .object_generic => {
                try printIndented(writer, indent + 1, "return @ptrCast(wl_proxy_marshal_array_flags(@ptrCast(this), {}, interface, wl_proxy_get_version(@ptrCast(this)), {s}, &args", .{ opcode, flags });
            },
            else => unreachable,
        }
        try writeIndented(writer, indent + 1, ") orelse return error.Failure);\n");
    } else {
        try printIndented(writer, indent + 1, "_ = wl_proxy_marshal_array_flags(@ptrCast(this), {}, null, wl_proxy_get_version(@ptrCast(this)), {s}, &args", .{ opcode, flags });
        try writeIndented(writer, indent + 1, ");\n");
    }
    try writeIndented(writer, indent + 0, "}\n\n");
}

pub fn writeMessageStructCompat(this: @This(), message: Database.Message, indent: u32) !void {
    const writer = this.writer;
    const message_name = this.db.message_names.getString(message.name);
    const message_args = message.args.slice(this.db);

    try writeIndented(writer, indent + 0, "wl_message{\n");
    try printIndented(writer, indent + 1, ".name = \"{f}\",\n", .{std.zig.fmtString(message_name)});
    try writeIndented(writer, indent + 1, ".signature = \"");
    if (message.since > 0) try writer.print("{d}", .{message.since});
    for (message_args) |arg| {
        try this.writeArgCompatSignature(arg.kind);
    }
    try writer.writeAll("\",\n");

    if (message_args.len > 0) {
        try writeIndented(writer, indent + 1, ".types = &.{\n");
        for (message_args) |arg| {
            switch (arg.kind) {
                .object,
                .object_optional,
                .new_id,
                => |interface| {
                    const interface_name = this.db.interface_names.getString(interface);
                    try printIndented(writer, indent + 2, "@extern(?*const wl_interface, .{{ .name = \"{f}_interface\" }}),\n", .{std.zig.fmtString(interface_name)});
                },

                .uint,
                .int,
                .fixed,
                .string,
                .string_optional,
                .array,
                .array_optional,
                .@"enum",
                .fd,
                .object_generic,
                .object_generic_optional,
                .new_id_generic,
                => try writeIndented(writer, indent + 2, "null,\n"),
            }
        }
        try writeIndented(writer, indent + 1, "},\n");
    } else {
        try writeIndented(writer, indent + 1, ".types = &[0]?*const wl_interface{},\n");
    }
    try writeIndented(writer, indent + 0, "},\n");
}

pub fn writeArgTypeCompat(this: @This(), current_interface_id: Database.Interface.Name, arg_kind: Database.Arg.Kind) std.Io.Writer.Error!void {
    const writer = this.writer;
    write_type: switch (arg_kind) {
        .uint => try writer.writeAll("u32"),
        .int => try writer.writeAll("i32"),
        .fixed => try writer.writeAll("wire.Fixed"),

        .string => try writer.writeAll("[*:0]const u8"),
        .string_optional => try writer.writeAll("?[*:0]const u8"),
        .array => try writer.writeAll("wire.Array"),
        .array_optional => try writer.writeAll("?wire.Array"),

        .fd => try writer.writeAll("wire.Fd"),

        .object_generic => try writer.writeAll("*wl_object"),
        .object_generic_optional => try writer.writeAll("?*wl_object"),

        .new_id,
        .new_id_generic,
        => std.debug.panic("NewId should be handled as a return type", .{}),

        .@"enum" => |enum_id| {
            _ = current_interface_id;
            const specified_interface = this.db.interfaces.get(enum_id.interface).?;
            this.required_imports.putAssumeCapacity(specified_interface.protocol, {});

            const interface_name = this.db.interface_names.getString(enum_id.interface);
            const enum_name = this.db.enum_names.getString(enum_id.name);

            try writer.print("{f}.{f}", .{
                std.zig.fmtId(interface_name),
                SnakeToCamelCaseFormatted{ .snake_phrase = enum_name },
            });
        },

        .object_optional => |specified_interface_id| {
            try writer.writeByte('?');
            continue :write_type .{ .object = specified_interface_id };
        },
        .object => |specified_interface_id| {
            const specified_interface_name = this.db.interface_names.getString(specified_interface_id);
            const specified_interface = this.db.interfaces.get(specified_interface_id).?;
            const protocol = this.db.protocol_names.getString(specified_interface.protocol);
            try writer.writeByte('*');
            try writer.print("{f}.", .{std.zig.fmtId(protocol)});
            try writer.writeAll(specified_interface_name);
        },
    }
}

pub fn writeArgCompatSignature(this: @This(), arg_kind: Database.Arg.Kind) std.Io.Writer.Error!void {
    const writer = this.writer;
    switch (arg_kind) {
        .uint => try writer.writeAll("u"),
        .int => try writer.writeAll("i"),
        .fixed => try writer.writeAll("f"),
        .new_id => try writer.writeAll("n"),
        .new_id_generic => try writer.writeAll("sun"),
        .fd => try writer.writeAll("h"),
        .string => try writer.writeAll("s"),
        .string_optional => try writer.writeAll("?s"),
        .array => try writer.writeAll("a"),
        .array_optional => try writer.writeAll("?a"),
        .@"enum" => try writer.writeAll("u"), // enums are just uint

        .object,
        .object_generic,
        => try writer.writeAll("o"),

        .object_optional,
        .object_generic_optional,
        => try writer.writeAll("?o"),
    }
}

test writeInterfaceCompat {
    var db: Database = .empty;
    defer db.deinit(std.testing.allocator);

    const interface_id = try db.interface_names.internString(std.testing.allocator, "wl_callback");
    const interface = Database.Interface{
        .protocol = try db.protocol_names.internString(std.testing.allocator, "wayland"),
        .version = 1,
        .summary = .null,
        .description = try db.comment_strings.addString(std.testing.allocator,
            \\Clients can handle the 'done' event to get notified when
            \\the related request is done.
            \\
            \\Note, because wl_callback objects are created from multiple independent
            \\factory interfaces, the wl_callback interface is frozen at version 1.
        ),
        .requests = .empty,
        .events = try db.addEvents(std.testing.allocator, &.{
            Database.Message{
                .name = try db.message_names.internString(std.testing.allocator, "done"),
                .summary = try db.summary_strings.addString(std.testing.allocator,
                    \\done event
                ),
                .description = try db.comment_strings.addString(std.testing.allocator,
                    \\Notify the client when the related request is done.
                ),
                .since = 0,
                .is_destructor = false,
                .args = try db.addArgs(std.testing.allocator, &.{
                    Database.Arg{
                        .name = try db.arg_names.internString(std.testing.allocator, "callback_data"),
                        .summary = try db.summary_strings.addString(std.testing.allocator,
                            \\request-specific data for the callback
                        ),
                        .kind = .uint,
                    },
                }),
            },
        }),
        .enums = .empty,
    };
    try db.interfaces.put(std.testing.allocator, interface_id, interface);

    const expected =
        \\/// Clients can handle the 'done' event to get notified when
        \\/// the related request is done.
        \\/// 
        \\/// Note, because wl_callback objects are created from multiple independent
        \\/// factory interfaces, the wl_callback interface is frozen at version 1.
        \\pub const wl_callback = opaque {
        \\    pub const NAME = "wl_callback";
        \\    pub const VERSION = 1;
        \\
        \\    comptime {
        \\        @export(INTERFACE, .{ .name = "wl_callback_interface" });
        \\    }
        \\
        \\    pub const INTERFACE: *const wl_interface = &.{
        \\        .name = "wl_callback",
        \\        .version = 1,
        \\        .requests = &wl_callback.REQUESTS,
        \\        .request_count = wl_callback.REQUESTS.len,
        \\        .events = &wl_callback.EVENTS,
        \\        .event_count = wl_callback.EVENTS.len,
        \\    };
        \\
        \\    pub const REQUESTS = [_]wl_message{
        \\    };
        \\
        \\    pub const EVENTS = [_]wl_message{
        \\        wl_message{
        \\            .name = "done",
        \\            .signature = "u",
        \\            .types = &.{
        \\                null,
        \\            },
        \\        },
        \\    };
        \\
        \\    pub const EventListener = extern struct {
        \\        done: *const fn(?*anyopaque, *wl_callback, callback_data: u32) callconv(.c) void,
        \\    };
        \\
        \\    pub fn addEventListener(this: *@This(), listener: *const EventListener, userdata: ?*anyopaque) error{AlreadySet}!void {
        \\        if (wl_proxy_add_listener(@ptrCast(this), @ptrCast(listener), userdata) == -1) return error.AlreadySet;
        \\    }
        \\
        \\};
        \\
        \\comptime { _ = wl_callback.INTERFACE; }
        \\
    ;

    var required_imports: std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, void) = .empty;
    defer required_imports.deinit(std.testing.allocator);
    try required_imports.ensureTotalCapacity(std.testing.allocator, db.protocols.count());

    var allocating_writer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer allocating_writer.deinit();

    try writeInterfaceCompat(.{
        .db = &db,
        .required_imports = &required_imports,
        .writer = &allocating_writer.writer,
    }, interface_id, interface, 1);

    try std.testing.expectEqualStrings(expected, allocating_writer.written());
}

pub fn writeDescriptionIndented(this: @This(), summary_id: Database.SummaryId, description_id: Database.CommentId, comment_prefix: []const u8, indent: u32) !void {
    const writer = this.writer;
    if (summary_id != .null) {
        const summary = this.db.summary_strings.getString(summary_id);
        var line_iter = std.mem.splitScalar(u8, summary, '\n');
        while (line_iter.next()) |line| {
            try writeIndented(writer, indent, comment_prefix);
            try writer.writeAll(std.mem.trim(u8, line, " \t"));
            try writer.writeByte('\n');
        }
    }

    if (summary_id != .null and description_id != .null) {
        try printIndented(writer, indent, "{s}\n", .{std.mem.trimRight(u8, comment_prefix, " ")});
    }

    if (description_id != .null) {
        const description = this.db.comment_strings.getString(description_id);
        var line_iter = std.mem.splitScalar(u8, description, '\n');
        while (line_iter.next()) |line| {
            try writeIndented(writer, indent, comment_prefix);
            try writer.writeAll(std.mem.trim(u8, line, " \t"));
            try writer.writeByte('\n');
        }
    }
}

pub const SnakeToCamelCaseFormatted = struct {
    snake_phrase: []const u8,

    pub fn format(this: @This(), writer: *std.Io.Writer) !void {
        var word_iter = std.mem.splitScalar(u8, this.snake_phrase, '_');
        while (word_iter.next()) |word| {
            if (word.len == 0) continue;
            try writer.writeByte(std.ascii.toUpper(word[0]));
            try writer.writeAll(word[1..]);
        }
    }
};

fn stripNewlines(text: []const u8) StripNewlineFormatter {
    return .{ .text = text };
}

const StripNewlineFormatter = struct {
    text: []const u8,

    pub fn format(this: @This(), writer: *std.Io.Writer) !void {
        var line_iter = std.mem.tokenizeScalar(u8, this.text, '\n');
        while (line_iter.next()) |line| {
            try writer.writeAll(line);
        }
    }
};

pub fn writeIndented(writer: *std.Io.Writer, indent: u32, bytes: []const u8) !void {
    var line_iter = std.mem.splitScalar(u8, bytes, '\n');
    var first = true;
    while (line_iter.next()) |line| {
        if (line.len == 0) {
            try writer.writeByte('\n');
            continue;
        }
        if (!first) {
            try writer.writeByte('\n');
        }
        _ = try writer.writeSplat(&.{" "}, indent * 4);
        try writer.writeAll(line);

        first = false;
    }
}

pub fn printIndented(writer: *std.Io.Writer, indent: u32, comptime template_string: []const u8, args: anytype) !void {
    _ = try writer.writeSplat(&.{" "}, indent * 4);
    try writer.print(template_string, args);
}

const Database = @import("Database.zig");
const std = @import("std");
