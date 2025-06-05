const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const exe = b.addExecutable(.{
        .name = "clipboard",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 链接 Objective-C 文件 + AppKit 框架
    exe.addCSourceFile(.{ .file = b.path("clipboard.m"), .flags = &.{} });
    exe.linkFramework("AppKit");
    exe.root_module.addImport("args", b.dependency("args", .{ .target = target, .optimize = optimize }).module("args"));
    b.installArtifact(exe);

    // 👇 增加 run 子命令
    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the clipboard program");
    run_step.dependOn(&run_cmd.step);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // test 子命令
    // const test_cmd = b.addTest("main.zig");
    // const run_test_step = b.step("test", "Run test from main.zig");
    // run_test_step.dependOn(test_cmd);
}
