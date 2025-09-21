const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "raytracing_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const stb = b.addLibrary(.{
        .name = "stb",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });
    stb.addIncludePath(b.path("libs"));
    stb.addCSourceFile(.{
        .file = b.path("libs/stbi_wrapper.c"),
        .flags = if (b.release_mode == .fast) &[_][]const u8{"-std=c99"} else &[_][]const u8{},
    });
    stb.linkLibC();

    exe.addIncludePath(b.path("libs"));
    exe.linkLibrary(stb);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const test_step = b.step("test", "Run tests");

    // Add unit tests from other source files.
    const vec_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vec.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_vec_tests = b.addRunArtifact(vec_tests);
    test_step.dependOn(&run_vec_tests.step);

    // {
    //     const run_exe_tests = b.addRunArtifact(exe_tests);
    //     test_step.dependOn(&run_exe_tests.step);
    // }
}
