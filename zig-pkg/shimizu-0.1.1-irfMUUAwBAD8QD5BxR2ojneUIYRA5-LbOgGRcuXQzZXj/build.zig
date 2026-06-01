const std = @import("std");

pub fn build(b: *std.Build) void {
    const run_step = b.step("run", "Run the shimizu tool");
    const test_step = b.step("test", "Run unit tests");
    const check_step = b.step("check", "check that everything compiles, while avoiding LLVM emit output");
    const docs_step = b.step("docs", "build the documentation");
    const run_trace_step = b.step("run:trace", "Run the shimizu-trace tool");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const use_llvm_lld = b.option(bool, "use-llvm", "force use (or non-use) of llvm and lld backends for scanner, tests, and examples");

    // scanner used for building
    const host_xml_dep = b.dependency("xml", .{
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const host_scanner_module = b.createModule(.{
        .root_source_file = b.path("src/scanner.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "xml", .module = host_xml_dep.module("xml") },
        },
    });

    // scanner as an independent module
    const lib_xml_dep = b.dependency("xml", .{
        .target = target,
        .optimize = optimize,
    });
    const lib_scanner_module = b.addModule("scanner", .{
        .root_source_file = b.path("src/scanner.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "xml", .module = lib_xml_dep.module("xml") },
        },
    });

    // wire module; self contained, defines types that are used for serializing messages
    const wire_module = b.addModule("wire", .{
        .root_source_file = b.path("src/wire.zig"),
        .target = target,
        .optimize = optimize,
    });

    const wayland_dep = b.dependency("wayland", .{});
    const wayland_protocols_dep = b.dependency("wayland-protocols", .{});

    // Wayland XML files -> zig files
    const shimizu_scanner_exe = b.addExecutable(.{
        .name = "shimizu-scanner",
        .root_module = host_scanner_module,
        .use_llvm = use_llvm_lld,
        .use_lld = use_llvm_lld,
    });
    b.installArtifact(shimizu_scanner_exe);

    // run `shimizu` tool from the build script
    const run_cmd = b.addRunArtifact(shimizu_scanner_exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    run_step.dependOn(&run_cmd.step);

    // generate xdg-shell.zig
    // run `shimizu` tool from the build script
    const wayland_core_generate_result = generateProtocolZig(b, shimizu_scanner_exe, .{
        .output_directory_name = "core",
        .compat_output_name = "core-compat.zig",
        .source_files = &.{
            wayland_dep.path("protocol/wayland.xml"),
        },
        .interface_versions = &[_]GenerateProtocolZigOptions.InterfaceVersion{
            // lowest common denominators as of 2024-01-05 https://wayland.app/protocols/xdg-shell#compositor-support
            .{ .interface = "wl_compositor", .version = 4 },
            .{ .interface = "wl_shm", .version = 1 },
            .{ .interface = "wl_data_device_manager", .version = 3 },
            .{ .interface = "wl_seat", .version = 7 },
            .{ .interface = "wl_output", .version = 4 },
            .{ .interface = "wl_subcompositor", .version = 1 },
        },
        .imports = &.{},
    });

    const wayland_core_module = b.addModule("core", .{
        .root_source_file = wayland_core_generate_result.output_directory.?.path(b, "wayland.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "wire", .module = wire_module }},
    });

    const wayland_core_compat_module = b.addModule("core-compat", .{
        .root_source_file = wayland_core_generate_result.compat_output_file.?,
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "wire", .module = wire_module }},
    });

    // shimizu module; depends on the generator to generate the core protocol
    const shimizu_module = b.addModule("shimizu", .{
        .root_source_file = b.path("src/shimizu.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "wire", .module = wire_module },
            .{ .name = "core", .module = wayland_core_module },
            .{ .name = "core-compat", .module = wayland_core_compat_module },
            .{ .name = "scanner", .module = lib_scanner_module },
        },
    });

    // proxies a wayland server/client and logs the messages that are sent
    const trace_embedded_wayland_protocols_generate_result = generateProtocolZig(b, shimizu_scanner_exe, .{
        .output_directory_name = null,
        .db_output_name = "protocols.bin",
        .imports = &.{},
        .source_files = &.{
            wayland_dep.path("protocol/wayland.xml"),

            wayland_protocols_dep.path("stable/presentation-time/presentation-time.xml"),
            wayland_protocols_dep.path("stable/viewporter/viewporter.xml"),
            wayland_protocols_dep.path("stable/xdg-shell/xdg-shell.xml"),
            wayland_protocols_dep.path("stable/linux-dmabuf/linux-dmabuf-v1.xml"),
            wayland_protocols_dep.path("stable/tablet/tablet-v2.xml"),

            wayland_protocols_dep.path("staging/alpha-modifier/alpha-modifier-v1.xml"),
            wayland_protocols_dep.path("staging/color-management/color-management-v1.xml"),
            wayland_protocols_dep.path("staging/commit-timing/commit-timing-v1.xml"),
            wayland_protocols_dep.path("staging/content-type/content-type-v1.xml"),
            wayland_protocols_dep.path("staging/cursor-shape/cursor-shape-v1.xml"),
            wayland_protocols_dep.path("staging/drm-lease/drm-lease-v1.xml"),
            wayland_protocols_dep.path("staging/ext-data-control/ext-data-control-v1.xml"),
            wayland_protocols_dep.path("staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1.xml"),
            wayland_protocols_dep.path("staging/ext-idle-notify/ext-idle-notify-v1.xml"),
            wayland_protocols_dep.path("staging/ext-image-capture-source/ext-image-capture-source-v1.xml"),
            wayland_protocols_dep.path("staging/ext-image-copy-capture/ext-image-copy-capture-v1.xml"),
            wayland_protocols_dep.path("staging/ext-session-lock/ext-session-lock-v1.xml"),
            wayland_protocols_dep.path("staging/ext-transient-seat/ext-transient-seat-v1.xml"),
            wayland_protocols_dep.path("staging/ext-workspace/ext-workspace-v1.xml"),
            wayland_protocols_dep.path("staging/fifo/fifo-v1.xml"),
            wayland_protocols_dep.path("staging/fractional-scale/fractional-scale-v1.xml"),
            wayland_protocols_dep.path("staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml"),
            wayland_protocols_dep.path("staging/security-context/security-context-v1.xml"),
            wayland_protocols_dep.path("staging/single-pixel-buffer/single-pixel-buffer-v1.xml"),
            wayland_protocols_dep.path("staging/tearing-control/tearing-control-v1.xml"),
            wayland_protocols_dep.path("staging/xdg-activation/xdg-activation-v1.xml"),
            wayland_protocols_dep.path("staging/xdg-dialog/xdg-dialog-v1.xml"),
            wayland_protocols_dep.path("staging/xdg-system-bell/xdg-system-bell-v1.xml"),
            wayland_protocols_dep.path("staging/xdg-toplevel-drag/xdg-toplevel-drag-v1.xml"),
            wayland_protocols_dep.path("staging/xdg-toplevel-icon/xdg-toplevel-icon-v1.xml"),
            wayland_protocols_dep.path("staging/xwayland-shell/xwayland-shell-v1.xml"),

            wayland_protocols_dep.path("unstable/fullscreen-shell/fullscreen-shell-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/idle-inhibit/idle-inhibit-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/input-method/input-method-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/input-timestamps/input-timestamps-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/linux-explicit-synchronization/linux-explicit-synchronization-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/pointer-constraints/pointer-constraints-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/pointer-gestures/pointer-gestures-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/primary-selection/primary-selection-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/relative-pointer/relative-pointer-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/text-input/text-input-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/text-input/text-input-unstable-v3.xml"),
            wayland_protocols_dep.path("unstable/xdg-decoration/xdg-decoration-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/xdg-foreign/xdg-foreign-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/xdg-foreign/xdg-foreign-unstable-v2.xml"),
            wayland_protocols_dep.path("unstable/xdg-output/xdg-output-unstable-v1.xml"),
            wayland_protocols_dep.path("unstable/xwayland-keyboard-grab/xwayland-keyboard-grab-unstable-v1.xml"),
        },
    });

    const trace_module = b.addModule("trace", .{
        .root_source_file = b.path("src/trace.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "shimizu", .module = shimizu_module },
            .{ .name = "xml", .module = lib_xml_dep.module("xml") },
        },
    });
    trace_module.addAnonymousImport("embedded_protocols", .{
        .root_source_file = trace_embedded_wayland_protocols_generate_result.db_output_file.?,
    });
    const shimizu_trace_exe = b.addExecutable(.{
        .name = "shimizu-trace",
        .root_module = trace_module,
        .use_llvm = use_llvm_lld,
        .use_lld = use_llvm_lld,
    });
    b.installArtifact(shimizu_trace_exe);
    const run_trace_cmd = b.addRunArtifact(shimizu_trace_exe);
    if (b.args) |args| {
        run_trace_cmd.addArgs(args);
    }
    run_trace_step.dependOn(&run_trace_cmd.step);

    // tests
    const lib_unit_tests = b.addTest(.{
        .root_module = shimizu_module,
        .use_llvm = use_llvm_lld,
        .use_lld = use_llvm_lld,
    });
    lib_unit_tests.root_module.addImport("wire", wire_module);
    lib_unit_tests.root_module.addImport("core", wayland_core_module);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{ .root_module = lib_scanner_module });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    // generate wayland-protol zig files
    const wayland_protocols_generate_result = generateProtocolZig(b, shimizu_scanner_exe, .{
        .output_directory_name = "wayland-protocols",
        .compat_output_name = "wayland-protocols-compat.zig",
        .source_files = &.{
            wayland_protocols_dep.path("stable/presentation-time/presentation-time.xml"),
            wayland_protocols_dep.path("stable/viewporter/viewporter.xml"),
            wayland_protocols_dep.path("stable/xdg-shell/xdg-shell.xml"),
            wayland_protocols_dep.path("stable/linux-dmabuf/linux-dmabuf-v1.xml"),
            wayland_protocols_dep.path("stable/tablet/tablet-v2.xml"),
        },
        .interface_versions = &.{
            // lowest common denominators as of 2024-01-05 https://wayland.app/protocols/xdg-shell#compositor-support
            .{ .interface = "wl_compositor", .version = 4 },
            .{ .interface = "wl_shm", .version = 1 },
            .{ .interface = "wl_data_device_manager", .version = 3 },
            .{ .interface = "wl_seat", .version = 7 },
            .{ .interface = "wl_output", .version = 4 },
            .{ .interface = "wl_subcompositor", .version = 1 },

            .{ .interface = "wp_presentation", .version = 1 },
            .{ .interface = "wp_viewporter", .version = 1 },
            .{ .interface = "xdg_wm_base", .version = 2 },
            .{ .interface = "zwp_linux_dmabuf_v1", .version = 3 },
            .{ .interface = "zwp_tablet_manager_v2", .version = 1 },
        },
        .imports = &.{
            .{ .file = wayland_dep.path("protocol/wayland.xml"), .import_string = "@import(\"core\")" },
        },
    });

    const wayland_protocols_module = b.addModule("wayland-protocols", .{
        .root_source_file = wayland_protocols_generate_result.output_directory.?.path(b, "root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "wire", .module = wire_module },
            .{ .name = "core", .module = wayland_core_module },
        },
    });

    const wayland_protocols_compat_module = b.addModule("compat", .{
        .root_source_file = wayland_protocols_generate_result.compat_output_file.?,
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "wire", .module = wire_module },
            .{ .name = "core", .module = wayland_core_compat_module },
        },
    });

    // examples
    const example_options = ExampleOptions{
        .shimizu = shimizu_module,
        .wayland_protocols = wayland_protocols_module,
        .install_examples = b.option(bool, "install-examples", "(default: false)") orelse false,
        .target = target,
        .optimize = optimize,
        .use_llvm_lld = use_llvm_lld,
    };
    _ = addExample(b, "00_list_globals", example_options);
    _ = addExample(b, "01_black_square", example_options);
    _ = addExample(b, "02_gradient", example_options);
    _ = addExample(b, "03_input", example_options);
    _ = addExample(b, "10_subcompositor", example_options);

    const example_03_libwayland_compat = addExample(b, "20_libwayland_compat", ExampleOptions{
        .shimizu = shimizu_module,
        .wayland_protocols = wayland_protocols_compat_module,
        .install_examples = example_options.install_examples,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .use_llvm_lld = true,
    });
    example_03_libwayland_compat.root_module.addImport("wayland", wayland_core_compat_module);

    // check step for in editor error messages
    check_step.dependOn(&lib_unit_tests.step);

    const check_example_options = ExampleOptions{
        .shimizu = shimizu_module,
        .wayland_protocols = wayland_protocols_module,
        .install_examples = false,
        .target = target,
        .optimize = .Debug,
        .run_step = false,
        .use_llvm_lld = use_llvm_lld,
    };
    check_step.dependOn(&addExample(b, "00_list_globals", check_example_options).step);
    check_step.dependOn(&addExample(b, "01_black_square", check_example_options).step);
    check_step.dependOn(&addExample(b, "02_gradient", check_example_options).step);
    check_step.dependOn(&addExample(b, "03_gradient", check_example_options).step);

    // emit documentation
    const shimizu_docs_dummy = b.addLibrary(.{
        .name = "shimizu",
        .root_module = shimizu_module,
    });

    const shimizu_install_docs = b.addInstallDirectory(.{
        .source_dir = shimizu_docs_dummy.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/shimizu",
    });

    const wayland_protocols_docs_dummy = b.addLibrary(.{
        .name = "wayland-procotols",
        .root_module = wayland_protocols_module,
    });

    const wayland_protocols_install_docs = b.addInstallDirectory(.{
        .source_dir = wayland_protocols_docs_dummy.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs/wayland-protocols",
    });

    docs_step.dependOn(&shimizu_install_docs.step);
    docs_step.dependOn(&wayland_protocols_install_docs.step);
}

pub const GenerateProtocolZigOptions = struct {
    output_directory_name: ?[]const u8,
    compat_output_name: ?[]const u8 = null,
    db_output_name: ?[]const u8 = null,

    source_files: []const std.Build.LazyPath,
    interface_versions: []const InterfaceVersion = &.{},
    imports: []const Import,

    pub const InterfaceVersion = struct {
        interface: []const u8,
        version: u32,
    };

    pub const Import = struct {
        file: std.Build.LazyPath,
        import_string: []const u8,
    };
};

pub const GenerateProtocolZigResult = struct {
    output_directory: ?std.Build.LazyPath,
    compat_output_file: ?std.Build.LazyPath,
    db_output_file: ?std.Build.LazyPath,
};

pub fn generateProtocolZig(b: *std.Build, shimizu_scanner_exe: *std.Build.Step.Compile, options: GenerateProtocolZigOptions) GenerateProtocolZigResult {
    const generate_zig_cmd = b.addRunArtifact(shimizu_scanner_exe);

    for (options.source_files) |source_file| {
        generate_zig_cmd.addFileArg(source_file);
    }

    for (options.interface_versions) |interface_version| {
        generate_zig_cmd.addArgs(&.{
            "--interface-version",
            interface_version.interface,
            b.fmt("{d}", .{interface_version.version}),
        });
    }

    for (options.imports) |import| {
        generate_zig_cmd.addArg("--import");
        generate_zig_cmd.addFileArg(import.file);
        generate_zig_cmd.addArg(import.import_string);
    }

    var result: GenerateProtocolZigResult = .{
        .output_directory = null,
        .compat_output_file = null,
        .db_output_file = null,
    };

    if (options.output_directory_name) |dir_name| {
        generate_zig_cmd.addArg("--output");
        result.output_directory = generate_zig_cmd.addOutputDirectoryArg(dir_name);
    }

    if (options.compat_output_name) |file_name| {
        generate_zig_cmd.addArg("--compat-output");
        result.compat_output_file = generate_zig_cmd.addOutputFileArg(file_name);
    }

    if (options.db_output_name) |db_name| {
        generate_zig_cmd.addArg("--db-output");
        result.db_output_file = generate_zig_cmd.addOutputFileArg(db_name);
    }

    return result;
}

const ExampleOptions = struct {
    shimizu: *std.Build.Module,
    wayland_protocols: *std.Build.Module,
    install_examples: bool,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    run_step: bool = true,
    link_libc: bool = false,
    use_llvm_lld: ?bool,
};
fn addExample(b: *std.Build, comptime name: []const u8, options: ExampleOptions) *std.Build.Step.Compile {
    const example_module = b.createModule(.{
        .root_source_file = b.path("examples/" ++ name ++ ".zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "shimizu", .module = options.shimizu },
            .{ .name = "wayland-protocols", .module = options.wayland_protocols },
        },
    });
    const exe = b.addExecutable(.{
        .name = "shimizu_example_" ++ name,
        .root_module = example_module,
    });
    exe.root_module.addImport("shimizu", options.shimizu);
    exe.root_module.addImport("wayland-protocols", options.wayland_protocols);

    exe.use_llvm = options.use_llvm_lld;
    exe.use_lld = options.use_llvm_lld;

    if (options.link_libc) {
        exe.linkLibC();
    }

    const install_exe = b.addInstallArtifact(exe, .{});
    if (options.install_examples) {
        b.getInstallStep().dependOn(&install_exe.step);
    }

    if (options.run_step) {
        const install_step = b.step("install:" ++ name, "Install the " ++ name ++ " example.");
        install_step.dependOn(&install_exe.step);

        const run_cmd = b.addRunArtifact(exe);

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run:" ++ name, "Run the " ++ name ++ " example");
        run_step.dependOn(&run_cmd.step);

        const run_step_deprecated = b.step("run-" ++ name, "Run the " ++ name ++ " example (deprecated, use run:" ++ name ++ " instead)");
        run_step_deprecated.dependOn(run_step);
    }

    return exe;
}
