const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shimizu_dep = b.dependency("shimizu", .{});
    const wlr_layer_shell_mod = b.createModule(.{
        .root_source_file = b.path("src/generated/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "wire", .module = shimizu_dep.module("wire") },
        },
    });

    const zlinestatus_mod = b.createModule(.{
        .root_source_file = b.path("src/zlinestatus.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "shimizu", .module = shimizu_dep.module("shimizu") },
            .{ .name = "wlr-layer-shell", .module = wlr_layer_shell_mod },
        },
    });
    const zlinestatus_exe = b.addExecutable(.{
        .name = "zlinestatus",
        .root_module = zlinestatus_mod,
    });
    b.installArtifact(zlinestatus_exe);

    // zsendvalue executable
    const zsendvalue_mod = b.createModule(.{
        .root_source_file = b.path("src/zsendvalue.zig"),
        .target = target,
        .optimize = optimize,
    });
    const zsendvalue_exe = b.addExecutable(.{
        .name = "zsendvalue",
        .root_module = zsendvalue_mod,
    });
    b.installArtifact(zsendvalue_exe);

    const zlinestatus_tests = b.addTest(.{
        .root_module = zlinestatus_mod,
    });
    const zsendvalue_tests = b.addTest(.{
        .root_module = zsendvalue_mod,
    });
    const run_zlinestatus_tests = b.addRunArtifact(zlinestatus_tests);
    const run_zsendvalue_tests = b.addRunArtifact(zsendvalue_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_zlinestatus_tests.step);
    test_step.dependOn(&run_zsendvalue_tests.step);

    // Run steps
    const zlinestatus_run_cmd = b.addRunArtifact(zlinestatus_exe);
    zlinestatus_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| zlinestatus_run_cmd.addArgs(args);

    const zsendvalue_run_cmd = b.addRunArtifact(zsendvalue_exe);
    zsendvalue_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| zsendvalue_run_cmd.addArgs(args);

    const zlinestatus_run_step = b.step("run-zlinestatus", "Run zlinestatus");
    zlinestatus_run_step.dependOn(&zlinestatus_run_cmd.step);

    const zsendvalue_run_step = b.step("run-zsendvalue", "Run zsendvalue");
    zsendvalue_run_step.dependOn(&zsendvalue_run_cmd.step);
}
