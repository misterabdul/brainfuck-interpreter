const std = @import("std");

pub fn build(builder: *std.Build) void {
    const target: std.Build.ResolvedTarget = builder.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = builder.standardOptimizeOption(.{});

    // Main executable
    const exe_mod: *std.Build.Module = builder.createModule(.{
        .root_source_file = builder.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe: *std.Build.Step.Compile = builder.addExecutable(.{
        .name = "bfi",
        .root_module = exe_mod,
    });
    builder.installArtifact(exe);

    // Run script
    const run_cmd: *std.Build.Step.Run = builder.addRunArtifact(exe);
    run_cmd.step.dependOn(builder.getInstallStep());
    if (builder.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step: *std.Build.Step = builder.step("run", "Run the executable");
    run_step.dependOn(&run_cmd.step);

    // Test script
    const exe_unit_tests: *std.Build.Step.Compile = builder.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_unit_tests: *std.Build.Step.Run = builder.addRunArtifact(exe_unit_tests);
    const test_step: *std.Build.Step = builder.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
