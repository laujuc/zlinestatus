pub const Database = @import("./scanner/Database.zig");
pub const generate = @import("./scanner/generate.zig");
pub const parse = @import("./scanner/parse.zig");

const log = std.log.scoped(.@"shimizu-scanner");

const HELP = @embedFile("./scanner/HELP");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .stack_trace_frames = 32,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const arguments = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), arguments);

    var db: Database = .empty;
    defer db.deinit(gpa.allocator());

    var options = try parseCommandLineOptions(allocator, arguments, &db);
    defer options.deinit();

    // find which protocol each interface belongs to
    var interface_locations = std.StringHashMapUnmanaged(InterfaceLocation).empty;
    defer interface_locations.deinit(gpa.allocator());

    var to_generate: std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, []const u8) = .empty;
    defer {
        for (to_generate.values()) |output_filename| {
            gpa.allocator().free(output_filename);
        }
        to_generate.deinit(allocator);
    }
    try to_generate.ensureTotalCapacity(gpa.allocator(), options.protocol_xml_filepaths.keys().len);

    var protocol_import_strings: std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, []const u8) = .empty;
    defer {
        for (protocol_import_strings.values()) |output_filename| {
            gpa.allocator().free(output_filename);
        }
        protocol_import_strings.deinit(allocator);
    }
    try protocol_import_strings.ensureTotalCapacity(gpa.allocator(), options.protocol_xml_filepaths.keys().len);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    // read and in source protocol files
    for (options.protocol_xml_filepaths.keys()) |source_filepath| {
        _ = arena.reset(.retain_capacity);

        if (!std.ascii.endsWithIgnoreCase(source_filepath, ".xml")) {
            return error.UnknownFileExtension;
        }
        const xml_filename = std.fs.path.basename(source_filepath);
        // filename without the extension
        const stem = std.fs.path.stem(xml_filename);

        const xml_file = try std.fs.cwd().openFile(source_filepath, .{});
        defer xml_file.close();

        var read_buffer: [4096]u8 = undefined;
        var file_reader = xml_file.reader(read_buffer[0..]);

        var streaming_reader: xml.Reader.Streaming = .init(arena.allocator(), &file_reader.interface, .{});
        defer streaming_reader.deinit();
        const reader = &streaming_reader.interface;

        const protocol = parse.protocol(reader, gpa.allocator(), &db) catch |err| switch (err) {
            error.MalformedXml => {
                const loc = reader.errorLocation();
                log.err("{}:{}: {}", .{ loc.line, loc.column, reader.errorCode() });
                return error.MalformedXml;
            },
            else => |other| return other,
        };

        const output_filename = try std.fmt.allocPrint(gpa.allocator(), "{s}.zig", .{stem});
        try to_generate.putNoClobber(gpa.allocator(), protocol, output_filename);

        const import_string = try std.fmt.allocPrint(gpa.allocator(), "@import(\"{f}\")", .{std.zig.fmtString(output_filename)});
        try protocol_import_strings.putNoClobber(gpa.allocator(), protocol, import_string);
    }

    // read import protocol files
    var to_import: std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, []const u8) = .empty;
    defer to_import.deinit(gpa.allocator());

    for (options.imports.keys(), options.imports.values()) |imported_filepath, import_string| {
        _ = arena.reset(.retain_capacity);

        if (!std.ascii.endsWithIgnoreCase(imported_filepath, ".xml")) {
            return error.UnknownFileExtension;
        }
        const xml_filename = std.fs.path.basename(imported_filepath);
        // filename without the extension
        const stem = std.fs.path.stem(xml_filename);
        _ = stem;

        const xml_file = try std.fs.cwd().openFile(imported_filepath, .{});
        defer xml_file.close();

        var read_buffer: [4096]u8 = undefined;
        var file_reader = xml_file.reader(read_buffer[0..]);

        var streaming_reader: xml.Reader.Streaming = .init(arena.allocator(), &file_reader.interface, .{});
        defer streaming_reader.deinit();
        const reader = &streaming_reader.interface;

        const protocol = parse.protocol(reader, gpa.allocator(), &db) catch |err| switch (err) {
            error.MalformedXml => {
                const loc = reader.errorLocation();
                log.err("{}:{}: {}", .{ loc.line, loc.column, reader.errorCode() });
                return error.MalformedXml;
            },
            else => |other| return other,
        };

        try to_import.putNoClobber(gpa.allocator(), protocol, import_string);

        try protocol_import_strings.putNoClobber(gpa.allocator(), protocol, try gpa.allocator().dupe(u8, import_string));
    }

    var required_imports: std.AutoArrayHashMapUnmanaged(Database.Protocol.Name, void) = .empty;
    defer required_imports.deinit(gpa.allocator());
    try required_imports.ensureTotalCapacity(gpa.allocator(), db.protocols.count());

    // write source protocol files to output directory
    if (options.output) |output_dir_path| {
        var output_directory = try std.fs.cwd().makeOpenPath(output_dir_path, .{});
        defer output_directory.close();

        const root_zig_file = try output_directory.createFile("root.zig", .{});
        defer root_zig_file.close();

        var root_output_buffer: [4096]u8 = undefined;
        var root_out = root_zig_file.writer(&root_output_buffer);

        for (to_generate.keys(), to_generate.values()) |protocol_id, output_filename| {
            const output_file = try output_directory.createFile(output_filename, .{});
            defer output_file.close();

            var protocol_output_buffer: [4096]u8 = undefined;
            var protocol_out = output_file.writer(&protocol_output_buffer);

            required_imports.clearRetainingCapacity();

            try generate.writeProtocolZig(
                .{
                    .db = &db,
                    .writer = &protocol_out.interface,
                    .required_imports = &required_imports,
                },
                protocol_id,
                &options.interface_versions,
                &protocol_import_strings,
            );

            try protocol_out.interface.flush();

            try root_out.interface.print("pub const {f} = @import(\"{f}\");\n", .{
                std.zig.fmtId(db.protocol_names.getString(protocol_id)),
                std.zig.fmtString(output_filename),
            });
        }

        try root_out.interface.writeAll("\n");
        try root_out.interface.flush();
    }

    if (options.compat_output_opt) |compat_output_path| {
        var compat_zig_file = try std.fs.cwd().createFile(compat_output_path, .{});
        defer compat_zig_file.close();

        var compat_zig_buffer: [4096]u8 = undefined;
        var compat_out = compat_zig_file.writer(&compat_zig_buffer);

        try compat_out.interface.writeAll(
            \\const std = @import("std");
            \\const wire = @import("wire");
            \\
            \\const wl_proxy = wire.compat.wl_proxy;
            \\const wl_interface = wire.compat.wl_interface;
            \\const wl_message = wire.compat.wl_message;
            \\const wl_object = wire.compat.wl_object;
            \\const wl_argument = wire.compat.wl_argument;
            \\const MarshalFlags = wire.compat.MarshalFlags;
            \\
            \\extern fn wl_proxy_add_listener(proxy: *wl_proxy, listener: [*]const ?*const fn () callconv(.c) void, data: ?*anyopaque) c_int;
            \\extern fn wl_proxy_get_version(proxy: *wl_proxy) u32;
            \\extern fn wl_proxy_marshal_array_flags(proxy: *wl_proxy, opcode: u32, interface: ?*const wl_interface, version: u32, flags: MarshalFlags, args: ?[*]wl_argument) ?*wl_proxy;
            \\extern fn wl_proxy_destroy(proxy: ?*wl_proxy) void;
            \\
            \\
        );

        for (to_generate.keys()) |protocol_id| {
            const protocol = db.protocols.get(protocol_id).?;
            const interface_names, const interfaces = protocol.interfaces.slice(&db);
            for (interface_names, interfaces) |interface_name, interface| {
                const target_version = options.interface_versions.get(interface_name) orelse interface.version;
                try generate.writeInterfaceCompat(.{
                    .db = &db,
                    .writer = &compat_out.interface,
                    .required_imports = &required_imports,
                }, interface_name, interface, target_version);
            }
        }

        for (required_imports.keys()) |protocol_id| {
            const protocol_name = db.protocol_names.getString(protocol_id);
            try compat_out.interface.print("const {f} = @This();\n", .{std.zig.fmtId(protocol_name)});
            // const import_string = protocol_import_strings.get(protocol_id).?;
            // try writer.print("const {f} = {s};\n", .{ std.zig.fmtId(protocol_name), import_string });
        }

        for (to_import.keys(), to_import.values()) |protocol_id, import_string| {
            const protocol = db.protocols.get(protocol_id).?;
            const interface_ids, _ = protocol.interfaces.slice(&db);
            for (interface_ids) |interface_id| {
                const interface_name = db.interface_names.getString(interface_id);
                try compat_out.interface.print("const {f} = {s}.{f};\n", .{
                    std.zig.fmtId(interface_name),
                    import_string,
                    std.zig.fmtId(interface_name),
                });
            }
        }

        try compat_out.interface.flush();
    }

    if (options.db_output) |db_output_path| {
        var file = try std.fs.cwd().createFile(db_output_path, .{});
        defer file.close();

        var write_buffer: [4096]u8 = undefined;
        var file_writer = file.writer(write_buffer[0..]);

        try db.writeSerializedData(&file_writer.interface);

        try file_writer.interface.flush();
    }
}

pub const CommandLineOptions = struct {
    arena: std.heap.ArenaAllocator,
    output: ?[]const u8,
    compat_output_opt: ?[]const u8,
    db_output: ?[]const u8,
    protocol_xml_filepaths: std.StringArrayHashMapUnmanaged(void),
    interface_versions: std.AutoArrayHashMapUnmanaged(Database.Interface.Name, u32),
    /// import file path -> zig import string
    imports: std.StringArrayHashMapUnmanaged([]const u8),

    fn deinit(this: *@This()) void {
        this.arena.deinit();
    }
};

fn parseCommandLineOptions(allocator: std.mem.Allocator, arguments: []const [:0]const u8, db: *Database) !CommandLineOptions {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    var output_directory_opt: ?[]const u8 = null;
    var protocol_xml_filepaths = std.StringArrayHashMapUnmanaged(void).empty;
    var interface_versions = std.AutoArrayHashMapUnmanaged(Database.Interface.Name, u32).empty;
    var imports = std.StringArrayHashMapUnmanaged([]const u8).empty;
    var compat_output_opt: ?[]const u8 = null;
    var db_output_opt: ?[]const u8 = null;
    var print_help = false;
    errdefer {
        protocol_xml_filepaths.deinit(arena.allocator());
        interface_versions.deinit(arena.allocator());
        imports.deinit(arena.allocator());
    }

    var arg_parse_failed = false;
    var arg_index: usize = 1;
    while (arg_index < arguments.len) {
        if (arguments[arg_index].len == 0) continue;

        if (arguments[arg_index][0] != '-') {
            // add a filepath to the list of input file paths
            const source_filepath = arguments[arg_index];
            arg_index += 1;

            const gop = try protocol_xml_filepaths.getOrPut(arena.allocator(), source_filepath);
            if (gop.found_existing) {
                arg_parse_failed = true;
                log.err("\"{f}\" specified multiple times", .{std.zig.fmtString(source_filepath)});
                continue;
            }
            gop.key_ptr.* = source_filepath;
            continue;
        }

        // handle flags
        const flag = arguments[arg_index];
        arg_index += 1;
        const flag_args = arguments[arg_index..];
        if (std.mem.eql(u8, flag, "--output") or std.mem.eql(u8, flag, "-o")) {
            if (flag_args.len < 1) {
                arg_parse_failed = true;
                log.err("`--output` flag missing output directory", .{});
                break;
            }
            output_directory_opt = flag_args[0];
            arg_index += 1;
        } else if (std.mem.eql(u8, flag, "--compat-output")) {
            if (flag_args.len < 1) {
                arg_parse_failed = true;
                log.err("`--output` flag missing output directory", .{});
                break;
            }
            compat_output_opt = flag_args[0];
            arg_index += 1;
        } else if (std.mem.eql(u8, flag, "--db-output")) {
            if (flag_args.len < 1) {
                arg_parse_failed = true;
                log.err("`--db-output` flag missing output directory", .{});
                break;
            }
            db_output_opt = flag_args[0];
            arg_index += 1;
        } else if (std.mem.eql(u8, flag, "--interface-version")) {
            if (flag_args.len < 2) {
                arg_parse_failed = true;
                log.err("`--interface-version` requires 2 arguments, <interface name> and <version>", .{});
                break;
            }
            const interface_str = flag_args[0];
            const version_str = flag_args[1];
            arg_index += 2;

            const interface_id = try db.interface_names.internString(allocator, interface_str);
            const version = std.fmt.parseInt(u32, version_str, 10) catch |err| {
                arg_parse_failed = true;
                log.err("failed to parse version string \"{f}\": {}", .{ std.zig.fmtString(version_str), err });
                continue;
            };

            const gop = try interface_versions.getOrPut(arena.allocator(), interface_id);
            if (gop.found_existing) {
                arg_parse_failed = true;
                log.err("\"{f}\" version specified multiple times", .{std.zig.fmtString(interface_str)});
                continue;
            }

            gop.value_ptr.* = version;
        } else if (std.mem.eql(u8, flag, "--import")) {
            if (flag_args.len < 2) {
                arg_parse_failed = true;
                log.err("`--import` requires 2 arguments, <protocol xml file> and <import string>", .{});
                break;
            }
            const protocol_xml_path = flag_args[0];
            const import_str = flag_args[1];
            arg_index += 2;

            if (protocol_xml_filepaths.contains(protocol_xml_path)) {
                log.err("\"{f}\" specified both as an import and as a source file", .{std.zig.fmtString(protocol_xml_path)});
                continue;
            }

            const gop = try imports.getOrPut(arena.allocator(), protocol_xml_path);
            if (gop.found_existing) {
                arg_parse_failed = true;
                log.err("\"{f}\" import specified multiple times", .{std.zig.fmtString(protocol_xml_path)});
                continue;
            }

            gop.key_ptr.* = protocol_xml_path;
            gop.value_ptr.* = import_str;
        } else if (std.mem.eql(u8, flag, "--help")) {
            print_help = true;
        } else {
            log.err("unknown flag \"{f}\"", .{std.zig.fmtString(flag)});
            arg_parse_failed = true;
        }
    }

    if (print_help) {
        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        const stdout = &stdout_writer.interface;
        try stdout.print(HELP, .{
            .command = arguments[0],
        });
        std.process.exit(0);
    }

    if (protocol_xml_filepaths.count() < 1) {
        arg_parse_failed = true;
        log.err("no protocol XML files specified as inputs", .{});
    }

    if (output_directory_opt == null and compat_output_opt == null and db_output_opt == null) {
        arg_parse_failed = true;
        log.err("no output directory specified", .{});
    }

    if (arg_parse_failed) {
        std.process.exit(1);
    }

    return .{
        .arena = arena,
        .output = output_directory_opt,
        .compat_output_opt = compat_output_opt,
        .protocol_xml_filepaths = protocol_xml_filepaths,
        .interface_versions = interface_versions,
        .imports = imports,
        .db_output = db_output_opt,
    };
}

pub const InterfaceLocation = struct {
    protocol: []const u8,
    import: []const u8,
};

test parseCommandLineOptions {
    const test_args = [_][:0]const u8{
        "shimizu-scanner",
        "presentation-time.xml",
        "viewporter.xml",
        "xdg-shell.xml",
        "linux-dmabuf-v1.xml",
        "tablet-v2.xml",
        "--interface-version",
        "wl_compositor",
        "4",
        "--interface-version",
        "wl_shm",
        "1",
        "--interface-version",
        "wl_data_device_manager",
        "3",
        "--interface-version",
        "wl_seat",
        "7",
        "--interface-version",
        "wl_output",
        "4",
        "--interface-version",
        "wl_subcompositor",
        "1",
        "--interface-version",
        "wp_presentation",
        "1",
        "--interface-version",
        "wp_viewporter",
        "1",
        "--interface-version",
        "xdg_wm_base",
        "2",
        "--interface-version",
        "zwp_linux_dmabuf_v1",
        "3",
        "--interface-version",
        "zwp_tablet_manager_v2",
        "1",
        "--import",
        "wayland.xml",
        "@import(\"core\")",
        "--output",
        "wayland-protocols",
        "--compat-output",
        "wayland-protocols-compat.zig",
    };

    var db: Database = .empty;
    defer db.deinit(std.testing.allocator);

    var options = try parseCommandLineOptions(std.testing.allocator, &test_args, &db);
    defer options.deinit();

    try std.testing.expect(options.imports.contains("wayland.xml"));
    try std.testing.expectEqualStrings("@import(\"core\")", options.imports.get("wayland.xml").?);
}

comptime {
    if (@import("builtin").is_test) {
        _ = Database;
        _ = generate;
        _ = parse;
    }
}

const std = @import("std");
const xml = @import("xml");
