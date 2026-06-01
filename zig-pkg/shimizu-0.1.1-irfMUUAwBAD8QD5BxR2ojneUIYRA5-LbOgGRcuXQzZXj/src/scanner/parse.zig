const log = std.log.scoped(.@"shimizu-scanner");

pub fn protocol(reader: *xml.Reader, gpa: std.mem.Allocator, db: *Database) !Database.Protocol.Name {
    const protocol_name = protocol_name: switch (try reader.read()) {
        .eof => return error.UnexpectedEndOfStream,
        .element_start => {
            const element_name = reader.elementNameNs();
            if (!std.mem.eql(u8, element_name.local, "protocol")) return error.MalformedProtocol;
            const protocol_name = for (0..reader.attributeCount()) |i| {
                const attribute_name = reader.attributeNameNs(i);
                if (!std.mem.eql(u8, attribute_name.local, "name")) continue;
                break try reader.attributeValue(i);
            } else return error.MalformedProtocol;

            break :protocol_name try db.protocol_names.internString(gpa, protocol_name);
        },
        else => continue :protocol_name try reader.read(),
    };

    // It should be safe to hold onto the protocol gop, as protocols should only be added from the top.
    const gop = try db.protocols.getOrPut(gpa, protocol_name);
    if (gop.found_existing) {
        return error.DuplicateProtocol;
    }

    db.protocols.lockPointers();
    defer db.protocols.unlockPointers();

    const interfaces_start = db.interfaces.count();

    var description_opt: ?Description = null;
    var copyright_opt: ?Database.CommentId = null;

    protocol_children: switch (try reader.read()) {
        .eof => return error.MalformedXml,
        .element_end => {},

        .xml_declaration,
        .comment,
        .text,
        => continue :protocol_children try reader.read(),

        .element_start => {
            const element_name = reader.elementNameNs();
            if (std.mem.eql(u8, element_name.local, "interface")) {
                _ = try interface(reader, gpa, db, protocol_name);
            } else if (std.mem.eql(u8, element_name.local, "copyright")) {
                if (copyright_opt != null) return error.MalformedProtocol;

                var allocating_writer = std.Io.Writer.Allocating.init(gpa);
                defer allocating_writer.deinit();
                try lines(reader, &allocating_writer.writer);

                copyright_opt = try db.comment_strings.addString(gpa, allocating_writer.written());
            } else if (std.mem.eql(u8, element_name.local, "description")) {
                if (description_opt != null) return error.MalformedXml;
                description_opt = try Description.parse(reader, gpa, db);
            } else {
                log.err("{}:{}: unexpected protocol child element {f}[{f}]:{f}; expected <interface>, <copyright>, or <description>", .{
                    reader.loc.line,
                    reader.loc.column,
                    std.zig.fmtString(element_name.prefix),
                    std.zig.fmtString(element_name.ns),
                    std.zig.fmtString(element_name.local),
                });
                return error.MalformedProtocol;
            }

            continue :protocol_children try reader.read();
        },

        else => |node| {
            log.err("{}:{}: unexpected node {}", .{
                reader.loc.line,
                reader.loc.column,
                node,
            });
            return error.MalformedProtocol;
        },
    }

    const interfaces_end = db.interfaces.count();

    gop.value_ptr.* = .{
        .summary = if (description_opt) |desc| desc.summary else .null,
        .description = if (description_opt) |desc| desc.lines else .null,
        .copyright = copyright_opt orelse .null,
        .interfaces = .{
            .start = @intCast(interfaces_start),
            .end = @intCast(interfaces_end),
        },
    };

    return protocol_name;
}

pub fn interface(
    reader: *xml.Reader,
    gpa: std.mem.Allocator,
    db: *Database,
    protocol_name: Database.Protocol.Name,
) !Database.Interface.Name {
    var name_opt: ?Database.Interface.Name = null;
    var version_opt: ?u16 = null;
    for (0..reader.attributeCount()) |i| {
        const attribute_name = reader.attributeNameNs(i);
        if (std.mem.eql(u8, attribute_name.local, "name")) {
            const attr_val = try reader.attributeValue(i);
            name_opt = try db.interface_names.internString(gpa, attr_val);
        } else if (std.mem.eql(u8, attribute_name.local, "version")) {
            const version_str = try reader.attributeValue(i);
            version_opt = try std.fmt.parseInt(u16, version_str, 10);
        }
    }
    const name = name_opt orelse return error.MalformedProtocol;
    const version = version_opt orelse return error.MalformedProtocol;

    const gop = try db.interfaces.getOrPut(gpa, name);
    if (gop.found_existing) {
        log.debug("duplicate interface \"{f}\"; current protocol is \"{f}\", previous is \"{f}\"", .{
            std.zig.fmtString(db.interface_names.getString(name)),
            std.zig.fmtString(db.protocol_names.getString(protocol_name)),
            std.zig.fmtString(db.protocol_names.getString(gop.value_ptr.protocol)),
        });
        return error.DuplicateInterface;
    }
    db.interfaces.lockPointers();
    defer db.interfaces.unlockPointers();

    const requests_start = db.interface_requests.items.len;
    const events_start = db.interface_events.items.len;
    const enums_start = db.enums.count();

    var description_opt: ?Description = null;
    while (true) {
        switch (try reader.read()) {
            .eof => break,
            .xml_declaration,
            .comment,
            .text,
            => {},

            .element_start => {
                const element_name = reader.elementNameNs();
                if (std.mem.eql(u8, element_name.local, "description")) {
                    if (description_opt != null) return error.MalformedXml;
                    description_opt = try Description.parse(reader, gpa, db);
                } else if (std.mem.eql(u8, element_name.local, "request")) {
                    const new_request = try message(reader, gpa, db, name);
                    try db.interface_requests.append(gpa, new_request);
                } else if (std.mem.eql(u8, element_name.local, "event")) {
                    const new_event = try message(reader, gpa, db, name);
                    try db.interface_events.append(gpa, new_event);
                } else if (std.mem.eql(u8, element_name.local, "enum")) {
                    _ = try @"enum"(reader, gpa, db, name);
                } else {
                    log.err("{}:{}: unknown element {f}[{f}]:{f}; expected <description>, <request>, <event>, or <enum>", .{
                        reader.loc.line,
                        reader.loc.column,
                        std.zig.fmtString(element_name.prefix),
                        std.zig.fmtString(element_name.ns),
                        std.zig.fmtString(element_name.local),
                    });
                    return error.MalformedProtocol;
                }
            },

            .element_end => break,

            else => return error.MalformedProtocol,
        }
    }

    const requests_end = db.interface_requests.items.len;
    const events_end = db.interface_events.items.len;
    const enums_end = db.enums.count();

    gop.value_ptr.* = .{
        .protocol = protocol_name,
        .version = version,
        .summary = if (description_opt) |desc| desc.summary else .null,
        .description = if (description_opt) |desc| desc.lines else .null,
        .events = .{
            .start = @intCast(events_start),
            .end = @intCast(events_end),
        },
        .requests = .{
            .start = @intCast(requests_start),
            .end = @intCast(requests_end),
        },
        .enums = .{
            .start = @intCast(enums_start),
            .end = @intCast(enums_end),
        },
    };

    return name;
}

pub fn message(
    reader: *xml.Reader,
    gpa: std.mem.Allocator,
    db: *Database,
    current_interface: Database.Interface.Name,
) !Database.Message {
    var name_opt: ?Database.Message.Name = null;
    var since_opt: ?u16 = null;
    var is_destructor = false;
    for (0..reader.attributeCount()) |i| {
        const attribute_name = reader.attributeNameNs(i);
        if (std.mem.eql(u8, attribute_name.local, "name")) {
            if (name_opt != null) return error.MalformedProtocol;
            const attr_val = try reader.attributeValue(i);
            name_opt = try db.message_names.internString(gpa, attr_val);
        } else if (std.mem.eql(u8, attribute_name.local, "since")) {
            const since_str = try reader.attributeValue(i);
            since_opt = try std.fmt.parseInt(u16, since_str, 10);
        } else if (std.mem.eql(u8, attribute_name.local, "type")) {
            const type_str = try reader.attributeValue(i);
            if (std.mem.eql(u8, type_str, "destructor")) {
                is_destructor = true;
            } else {
                log.err("{}:{}: unexpected type \"{f}\"", .{ reader.loc.line, reader.loc.column, std.zig.fmtString(type_str) });
                return error.MalformedXml;
            }
        }
    }
    const name = name_opt orelse return error.InvalidFormat;

    const args_start = db.message_args.items.len;

    var description_opt: ?Description = null;
    while (true) {
        switch (try reader.read()) {
            .eof => break,
            .xml_declaration,
            .comment,
            .text,
            => {},

            .element_start => {
                const element_name = reader.elementNameNs();
                if (std.mem.eql(u8, element_name.local, "description")) {
                    if (description_opt != null) return error.MalformedProtocol;
                    description_opt = try Description.parse(reader, gpa, db);
                } else if (std.mem.eql(u8, element_name.local, "arg")) {
                    try db.message_args.append(gpa, try arg(reader, gpa, db, current_interface));
                } else {
                    log.err("{}:{}: unknown element {f}[{f}]:{f}", .{
                        reader.loc.line,
                        reader.loc.column,
                        std.zig.fmtString(element_name.prefix),
                        std.zig.fmtString(element_name.ns),
                        std.zig.fmtString(element_name.local),
                    });
                    return error.MalformedProtocol;
                }
            },

            .element_end => break,

            else => return error.MalformedProtocol,
        }
    }

    const args_end = db.message_args.items.len;

    return Database.Message{
        .name = name,
        .summary = if (description_opt) |desc| desc.summary else .null,
        .description = if (description_opt) |desc| desc.lines else .null,
        .since = since_opt orelse 0,
        .is_destructor = is_destructor,
        .args = .{
            .start = @intCast(args_start),
            .end = @intCast(args_end),
        },
    };
}

pub const Primitive = enum {
    uint,
    int,
    fixed,
    new_id,
    object,
    fd,
    string,
    array,
};

pub fn arg(
    reader: *xml.Reader,
    gpa: std.mem.Allocator,
    db: *Database,
    current_interface: Database.Interface.Name,
) !Database.Arg {
    var name_opt: ?Database.Arg.Name = null;
    var summary_opt: ?Database.SummaryId = null;
    var interface_name_opt: ?Database.Interface.Name = null;
    var primitive_kind_opt: ?Primitive = null;
    var enum_interface_opt: ?Database.Interface.Name = null;
    var enum_name_opt: ?Database.Enum.Name = null;
    var allow_null = false;
    for (0..reader.attributeCount()) |i| {
        const attribute_name = reader.attributeNameNs(i);
        if (std.mem.eql(u8, attribute_name.local, "name")) {
            if (name_opt != null) return error.MalformedProtocol;
            name_opt = try db.arg_names.internString(gpa, try reader.attributeValue(i));
        } else if (std.mem.eql(u8, attribute_name.local, "summary")) {
            if (summary_opt != null) return error.MalformedProtocol;
            summary_opt = try db.summary_strings.addString(gpa, try reader.attributeValue(i));
        } else if (std.mem.eql(u8, attribute_name.local, "interface")) {
            if (interface_name_opt != null) return error.MalformedProtocol;
            interface_name_opt = try db.interface_names.internString(gpa, try reader.attributeValue(i));
        } else if (std.mem.eql(u8, attribute_name.local, "type")) {
            if (primitive_kind_opt != null) return error.MalformedProtocol;
            const type_str = try reader.attributeValue(i);
            if (std.meta.stringToEnum(Primitive, type_str)) |prim| {
                primitive_kind_opt = prim;
            } else {
                log.err("{}:{}: unexpected type \"{f}\"", .{ reader.loc.line, reader.loc.column, std.zig.fmtString(type_str) });
                return error.MalformedProtocol;
            }
        } else if (std.mem.eql(u8, attribute_name.local, "enum")) {
            if (enum_name_opt != null) return error.MalformedProtocol;
            const attr_text = try reader.attributeValue(i);
            if (std.mem.indexOfScalar(u8, attr_text, '.')) |dot_index| {
                enum_interface_opt = try db.interface_names.internString(gpa, attr_text[0..dot_index]);
                enum_name_opt = try db.enum_names.internString(gpa, attr_text[dot_index + 1 ..]);
            } else {
                enum_interface_opt = current_interface;
                enum_name_opt = try db.enum_names.internString(gpa, attr_text);
            }
        } else if (std.mem.eql(u8, attribute_name.local, "allow-null")) {
            const value_str = try reader.attributeValue(i);
            allow_null = std.mem.eql(u8, value_str, "true");
        } else {
            log.err("{}:{}: unexpected attribute {f}[{f}]:{f}", .{
                reader.loc.line,
                reader.loc.column,
                std.zig.fmtString(attribute_name.prefix),
                std.zig.fmtString(attribute_name.ns),
                std.zig.fmtString(attribute_name.local),
            });
            return error.MalformedXml;
        }
    }
    const name = name_opt orelse return error.MalformedProtocol;
    const primitive_kind = primitive_kind_opt orelse return error.MalformedProtocol;

    while (true) {
        switch (try reader.read()) {
            .eof => break,
            .xml_declaration, .comment, .text => {},

            .element_start => {
                const element_name = reader.elementNameNs();
                log.err("{}:{}: unknown element {f}[{f}]:{f}; unexpected child element in Arg", .{
                    reader.loc.line,
                    reader.loc.column,
                    std.zig.fmtString(element_name.prefix),
                    std.zig.fmtString(element_name.ns),
                    std.zig.fmtString(element_name.local),
                });
                return error.MalformedProtocol;
            },

            .element_end => break,

            else => return error.MalformedProtocol,
        }
    }

    const kind: Database.Arg.Kind = switch (primitive_kind) {
        .uint => blk: {
            if (interface_name_opt != null) return error.MalformedProtocol;
            if (allow_null) return error.MalformedProtocol;
            if (enum_name_opt) |enum_str| {
                break :blk .{ .@"enum" = .{
                    .interface = enum_interface_opt.?,
                    .name = enum_str,
                } };
            }
            break :blk .uint;
        },
        .int => blk: {
            if (interface_name_opt != null) return error.MalformedProtocol;
            if (allow_null) return error.MalformedProtocol;
            if (enum_name_opt) |enum_str| {
                // The core wayland protocol has at least one case where an arg is an int and an enum.
                // Not sure if that was intentional or by mistake.
                break :blk .{ .@"enum" = .{
                    .interface = enum_interface_opt.?,
                    .name = enum_str,
                } };
            }
            break :blk .int;
        },
        .fixed => blk: {
            if (enum_name_opt != null) return error.MalformedProtocol;
            if (interface_name_opt != null) return error.MalformedProtocol;
            if (allow_null) return error.MalformedProtocol;
            break :blk .fixed;
        },
        .new_id => blk: {
            if (enum_name_opt != null) return error.MalformedProtocol;
            if (allow_null) {
                return error.MalformedProtocol;
            }
            break :blk if (interface_name_opt) |interface_name|
                .{ .new_id = interface_name }
            else
                .new_id_generic;
        },
        .object => blk: {
            if (enum_name_opt != null) return error.MalformedProtocol;
            if (interface_name_opt) |interface_name| {
                if (allow_null) {
                    break :blk .{ .object_optional = interface_name };
                } else {
                    break :blk .{ .object = interface_name };
                }
            } else {
                if (allow_null) {
                    break :blk .object_generic_optional;
                } else {
                    break :blk .object_generic;
                }
            }
        },
        .fd => blk: {
            if (enum_name_opt != null) return error.MalformedProtocol;
            if (interface_name_opt != null) return error.MalformedProtocol;
            if (allow_null) return error.MalformedProtocol;
            break :blk .fd;
        },
        .string => blk: {
            if (enum_name_opt != null) return error.MalformedProtocol;
            if (interface_name_opt != null) return error.MalformedProtocol;
            if (allow_null) {
                break :blk .string_optional;
            } else {
                break :blk .string;
            }
        },
        .array => blk: {
            if (enum_name_opt != null) return error.MalformedProtocol;
            if (interface_name_opt != null) return error.MalformedProtocol;
            if (allow_null) {
                break :blk .array_optional;
            } else {
                break :blk .array;
            }
        },
    };

    return Database.Arg{
        .name = name,
        .kind = kind,
        .summary = summary_opt orelse .null,
    };
}

pub fn @"enum"(
    reader: *xml.Reader,
    gpa: std.mem.Allocator,
    db: *Database,
    interface_name: Database.Interface.Name,
) !Database.Enum.Name {
    var name_opt: ?Database.Enum.Name = null;
    var since_opt: ?u16 = null;
    var bitfield: bool = false;
    for (0..reader.attributeCount()) |i| {
        const attribute_name = reader.attributeNameNs(i);
        if (std.mem.eql(u8, attribute_name.local, "name")) {
            if (name_opt != null) return error.MalformedProtocol;
            name_opt = try db.enum_names.internString(gpa, try reader.attributeValue(i));
        } else if (std.mem.eql(u8, attribute_name.local, "bitfield")) {
            const bool_str = try reader.attributeValue(i);
            bitfield = std.mem.eql(u8, bool_str, "true");
        } else if (std.mem.eql(u8, attribute_name.local, "since")) {
            const since_str = try reader.attributeValue(i);
            since_opt = try std.fmt.parseInt(u16, since_str, 10);
        } else {
            @panic("TODO: error message");
        }
    }
    const name = name_opt orelse return error.InvalidFormat;

    const enum_key = Database.Enum.Key{
        .interface = interface_name,
        .name = name,
    };

    const gop = try db.enums.getOrPut(gpa, enum_key);
    errdefer _ = db.enums.swapRemove(enum_key);
    if (gop.found_existing) {
        return error.DuplicateEnum;
    }

    db.enums.lockPointers();
    defer db.enums.unlockPointers();

    const entries_start = db.enum_entries.count();

    var description_opt: ?Description = null;
    while (true) {
        switch (try reader.read()) {
            .eof => break,
            .xml_declaration,
            .comment,
            => {},

            .element_start => {
                const element_name = reader.elementNameNs();
                if (std.mem.eql(u8, element_name.local, "description")) {
                    if (description_opt != null) return error.MalformedXml;
                    description_opt = try Description.parse(reader, gpa, db);
                } else if (std.mem.eql(u8, element_name.local, "entry")) {
                    try enumEntry(reader, gpa, db, enum_key);
                } else {
                    log.err("{}:{}: unknown element {f}[{f}]:{f}; expected <description>, <request>, <event>, or <enum>", .{
                        reader.loc.line,
                        reader.loc.column,
                        std.zig.fmtString(element_name.prefix),
                        std.zig.fmtString(element_name.ns),
                        std.zig.fmtString(element_name.local),
                    });
                    return error.MalformedXml;
                }
            },

            .element_end => break,

            .text => {
                const text = try reader.text();
                if (std.mem.trim(u8, text, " \t\n").len != 0) {
                    std.log.warn("Unexpected text: \"{f}\"", .{std.zig.fmtString(text)});
                    return error.MalformedXml;
                }
            },

            .pi,
            .cdata,
            .entity_reference,
            .character_reference,
            => return error.MalformedXml,
        }
    }

    const entries_end = db.enum_entries.count();

    gop.value_ptr.* = .{
        .interface = interface_name,
        .summary = if (description_opt) |desc| desc.summary else .null,
        .description = if (description_opt) |desc| desc.lines else .null,
        .kind = switch (bitfield) {
            true => .bitfield,
            false => .@"enum",
        },
        .since = since_opt orelse 0,
        .entries = .{
            .start = @intCast(entries_start),
            .end = @intCast(entries_end),
        },
    };

    return name;
}

pub fn enumEntry(reader: *xml.Reader, gpa: std.mem.Allocator, db: *Database, enum_key: Database.Enum.Key) !void {
    var name_opt: ?Database.EnumEntry.Name = null;
    var value_opt: ?u32 = null;
    var summary_opt: ?Database.SummaryId = null;
    var since_opt: ?u16 = null;
    var radix: u8 = 0;
    for (0..reader.attributeCount()) |i| {
        const attribute_name = reader.attributeNameNs(i);
        if (std.mem.eql(u8, attribute_name.local, "name")) {
            if (name_opt != null) return error.MalformedProtocol;
            const attr_text = try reader.attributeValue(i);
            name_opt = try db.enum_entry_names.internString(gpa, attr_text);
        } else if (std.mem.eql(u8, attribute_name.local, "value")) {
            if (value_opt != null) return error.MalformedProtocol;
            const attr_text = try reader.attributeValue(i);
            if (std.mem.startsWith(u8, attr_text, "0x")) {
                value_opt = try std.fmt.parseInt(u32, attr_text[2..], 16);
                radix = 16;
            } else if (std.mem.startsWith(u8, attr_text, "0o")) {
                value_opt = try std.fmt.parseInt(u32, attr_text[2..], 8);
                radix = 8;
            } else if (std.mem.startsWith(u8, attr_text, "0b")) {
                value_opt = try std.fmt.parseInt(u32, attr_text[2..], 2);
                radix = 2;
            } else {
                value_opt = std.fmt.parseInt(u32, attr_text, 10) catch |err| {
                    std.log.warn("{s}:{} \"{s}\": {}", .{ @src().file, @src().line, attr_text, err });
                    return err;
                };
                radix = 10;
            }
        } else if (std.mem.eql(u8, attribute_name.local, "summary")) {
            if (summary_opt != null) return error.MalformedProtocol;
            const attr_text = try reader.attributeValue(i);
            summary_opt = try db.summary_strings.addString(gpa, attr_text);
        } else if (std.mem.eql(u8, attribute_name.local, "since")) {
            if (since_opt != null) return error.MalformedProtocol;
            const attr_text = try reader.attributeValue(i);
            since_opt = try std.fmt.parseInt(u16, attr_text, 10);
        } else {
            @panic("TODO: error message");
        }
    }
    const name = name_opt orelse return error.MalformedProtocol;
    const value = value_opt orelse return error.MalformedProtocol;

    const enum_entry_key = Database.EnumEntry.Key{
        .interface = enum_key.interface,
        .name = enum_key.name,
        .value = value,
    };
    const gop = try db.enum_entries.getOrPut(gpa, enum_entry_key);
    errdefer _ = db.enum_entries.swapRemove(enum_entry_key);
    if (gop.found_existing) {
        return error.DuplicateEnumEntry;
    }

    db.enum_entries.lockPointers();
    defer db.enum_entries.unlockPointers();

    var description_opt: ?Description = null;
    while (true) {
        switch (try reader.read()) {
            .eof => break,
            .xml_declaration, .comment, .text => {},

            .element_start => {
                const element_name = reader.elementNameNs();
                if (std.mem.eql(u8, element_name.local, "description")) {
                    if (description_opt != null) return error.MalformedProtocol;
                    description_opt = try Description.parse(reader, gpa, db);
                } else {
                    log.err("{}:{}: unknown element {f}[{f}]:{f} in Enum.Entry; expected <description>", .{
                        reader.loc.line,
                        reader.loc.column,
                        std.zig.fmtString(element_name.prefix),
                        std.zig.fmtString(element_name.ns),
                        std.zig.fmtString(element_name.local),
                    });
                    return error.MalformedProtocol;
                }
            },

            .element_end => break,

            else => return error.MalformedProtocol,
        }
    }

    gop.value_ptr.* = .{
        .name = name,
        .summary = if (description_opt) |desc| desc.summary else .null,
        .description = if (description_opt) |desc| desc.lines else .null,
        .since = since_opt orelse 0,
        .radix = radix,
    };
}

fn lines(reader: *xml.Reader, writer: *std.Io.Writer) !void {
    while (true) {
        switch (try reader.read()) {
            .comment => {},

            .eof,
            .xml_declaration,
            .element_start,
            => return error.MalformedXml,

            .element_end => break,
            .text => {
                var line_iter = std.mem.splitScalar(u8, try reader.text(), '\n');
                while (line_iter.next()) |line| {
                    try writer.writeAll(std.mem.trim(u8, line, " \t"));
                    try writer.writeByte('\n');
                }
            },

            .character_reference => {
                const c = reader.characterReferenceChar();
                const n = try std.unicode.utf8Encode(c, try writer.writableSlice(4));
                writer.advance(n);
            },

            .entity_reference => {
                const ref = reader.entityReferenceName();
                if (std.mem.eql(u8, ref, "amp")) {
                    try writer.writeByte('&');
                } else if (std.mem.eql(u8, ref, "lt")) {
                    try writer.writeByte('<');
                } else if (std.mem.eql(u8, ref, "gt")) {
                    try writer.writeByte('>');
                } else if (std.mem.eql(u8, ref, "apos")) {
                    try writer.writeByte('\'');
                } else if (std.mem.eql(u8, ref, "quot")) {
                    try writer.writeByte('"');
                }
            },

            .pi, .cdata => @panic("unhandled"),
        }
    }
}

pub const Description = struct {
    summary: Database.SummaryId,
    lines: Database.CommentId,

    pub fn parse(reader: *xml.Reader, gpa: std.mem.Allocator, db: *Database) !@This() {
        var summary_opt: Database.SummaryId = .null;
        for (0..reader.attributeCount()) |i| {
            const attribute_name = reader.attributeNameNs(i);
            if (std.mem.eql(u8, attribute_name.local, "summary")) {
                const attr_val = try reader.attributeValue(i);
                summary_opt = try db.summary_strings.addString(gpa, std.mem.trim(u8, attr_val, " \t\n"));
            }
        }

        var allocating_writer = std.Io.Writer.Allocating.init(gpa);
        defer allocating_writer.deinit();
        try lines(reader, &allocating_writer.writer);

        return .{
            .summary = summary_opt,
            .lines = if (allocating_writer.written().len == 0)
                .null
            else
                try db.comment_strings.addString(gpa, allocating_writer.written()),
        };
    }
};

test "parse enum field" {
    const input_xml =
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<protocol name="wayland">
        \\  <interface name="wl_shm_pool" version="2">
        \\    <request name="create_buffer">
        \\      <arg name="id" type="new_id" interface="wl_buffer"/>
        \\      <arg name="offset" type="int" />
        \\      <arg name="width" type="int" />
        \\      <arg name="height" type="int" />
        \\      <arg name="stride" type="int" />
        \\      <arg name="format" type="uint" enum="wl_shm.format" />
        \\    </request>
        \\  </interface>
        \\</protocol>
    ;

    var db: Database = .empty;
    defer db.deinit(std.testing.allocator);

    var buffer_reader = std.Io.Reader.fixed(input_xml);

    var streaming_reader: xml.Reader.Streaming = .init(std.testing.allocator, &buffer_reader, .{});
    defer streaming_reader.deinit();
    const reader = &streaming_reader.interface;

    const actual_protocol_name = protocol(reader, std.testing.allocator, &db) catch |err| switch (err) {
        error.MalformedXml => {
            const loc = reader.errorLocation();
            log.err("{}:{}: {}", .{ loc.line, loc.column, reader.errorCode() });
            return error.MalformedXml;
        },
        else => |other| return other,
    };
    try std.testing.expectEqualStrings("wayland", db.protocol_names.getString(actual_protocol_name));

    const actual_protocol = db.protocols.get(actual_protocol_name) orelse return error.TestExpectedNotNull;

    const actual_interface_ids, const actual_interfaces = actual_protocol.interfaces.slice(&db);
    try std.testing.expectEqualStrings("wl_shm_pool", db.interface_names.getString(actual_interface_ids[0]));
    try std.testing.expectEqual(@as(u32, 2), actual_interfaces[0].version);

    const actual_requests = actual_interfaces[0].requests.slice(&db);
    try std.testing.expectEqualStrings("create_buffer", db.message_names.getString(actual_requests[0].name));

    const actual_args = actual_requests[0].args.slice(&db);
    try std.testing.expectEqualStrings("format", db.arg_names.getString(actual_args[5].name));
    try std.testing.expectEqual(Database.Arg.Kind.Tag.@"enum", @as(Database.Arg.Kind.Tag, actual_args[5].kind));
    try std.testing.expectEqualStrings("wl_shm", db.interface_names.getString(actual_args[5].kind.@"enum".interface));
    try std.testing.expectEqualStrings("format", db.enum_names.getString(actual_args[5].kind.@"enum".name));
}

const Database = @import("./Database.zig");
const std = @import("std");
const xml = @import("xml");
