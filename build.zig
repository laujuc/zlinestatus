const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shimizu_dep = b.dependency("shimizu", .{});
    const z2d_dep = b.dependency("z2d", .{});

    // zlinestatus executable
    const zlinestatus_exe = b.addExecutable(.{
        .name = "zlinestatus",
        .root_source_file = .{ .path = "src/zlinestatus.zig" },
        .target = target,
        .optimize = optimize,
    });
    zlinestatus_exe.addModule("shimizu", shimizu_dep.module("shimizu"));
    zlinestatus_exe.addModule("z2d", z2d_dep.module("z2d"));
    b.installArtifact(zlinestatus_exe);

    // zsendvalue executable
    const zsendvalue_exe = b.addExecutable(.{
        .name = "zsendvalue",
        .root_source_file = .{ .path = "src/zsendvalue.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(zsendvalue_exe);

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