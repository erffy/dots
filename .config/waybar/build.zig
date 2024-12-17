const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const memory = b.addExecutable(.{
        .name = "memory",
        .root_source_file = b.path("src/memory.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const gpu = b.addExecutable(.{
        .name = "gpu",
        .root_source_file = b.path("src/gpu.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const ping = b.addExecutable(.{
        .name = "ping",
        .root_source_file = b.path("src/ping.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    b.installArtifact(memory);
    b.installArtifact(gpu);
    b.installArtifact(ping);

    const memory_run = b.addRunArtifact(memory);
    memory_run.step.dependOn(b.getInstallStep());

    const gpu_run = b.addRunArtifact(gpu);
    gpu_run.step.dependOn(b.getInstallStep());

    const ping_run = b.addRunArtifact(ping);
    ping_run.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        memory_run.addArgs(args);
        gpu_run.addArgs(args);
        ping_run.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&memory_run.step);
    run_step.dependOn(&ping.step);
    run_step.dependOn(&gpu_run.step);
}
