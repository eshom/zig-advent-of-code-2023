const std = @import("std");

pub fn build(b: *std.Build) void {
    // Setting up options
    const day = b.option(usize, "day", "Which day to build. By default all.") orelse 0;

    const options = b.addOptions();
    options.addOption(usize, "day", day);

    // The executable
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "advent-of-code-2023",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add options to exe
    exe.root_module.addOptions("config", options);

    b.installArtifact(exe);

    // Run section
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test section
    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const day1_tests = b.addTest(
        .{
            .root_source_file = .{ .path = "src/day1.zig" },
            .target = target,
            .optimize = optimize,
        },
    );
    const day2_tests = b.addTest(
        .{
            .root_source_file = .{ .path = "src/day2.zig" },
            .target = target,
            .optimize = optimize,
        },
    );
    const day3_tests = b.addTest(
        .{
            .root_source_file = .{ .path = "src/day3.zig" },
            .target = target,
            .optimize = optimize,
        },
    );
    const day4_tests = b.addTest(
        .{
            .root_source_file = .{ .path = "src/day4.zig" },
            .target = target,
            .optimize = optimize,
        },
    );
    const day5_tests = b.addTest(
        .{
            .root_source_file = .{ .path = "src/day5.zig" },
            .target = target,
            .optimize = optimize,
        },
    );

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&day1_tests.step);
    test_step.dependOn(&day2_tests.step);
    test_step.dependOn(&day3_tests.step);
    test_step.dependOn(&day4_tests.step);
    test_step.dependOn(&day5_tests.step);
}
