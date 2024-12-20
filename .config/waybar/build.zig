const std = @import("std");

const Executable = struct {
    name: []const u8,
    source: []const u8,
    run_args: ?[]const []const u8 = null,
};

const executables = [_]Executable{
    .{ .name = "memory", .source = "src/memory.zig" },
    .{ .name = "gpu", .source = "src/gpu.zig" },
    .{ .name = "ping", .source = "src/ping.zig" },
    .{ .name = "updates", .source = "src/updates.zig" },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    for (executables) |exe| {
        const exe_obj = b.addExecutable(.{
            .name = exe.name,
            .root_source_file = b.path(exe.source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        const install_exe = b.addInstallArtifact(exe_obj, .{});
        b.getInstallStep().dependOn(&install_exe.step);

        const run_cmd = b.addRunArtifact(exe_obj);
        if (b.args) |args| run_cmd.addArgs(args);
        if (exe.run_args) |args| run_cmd.addArgs(args);

        const run_step = b.step(b.fmt("run-{s}", .{exe.name}), b.fmt("Run the {s} executable", .{exe.name}));
        run_step.dependOn(&run_cmd.step);
    }

    const fmt_step = b.step("fmt", "Check source formatting");
    const fmt_cmd = b.addSystemCommand(&[_][]const u8{ "zig", "fmt", "--check", "src" });
    fmt_step.dependOn(&fmt_cmd.step);

    const clean_step = b.step("clean", "Clean build artifacts");
    const clean_cmd = b.addSystemCommand(&[_][]const u8{
        "rm",
        "-rf",
        "zig-cache",
        "zig-out",
    });
    clean_step.dependOn(&clean_cmd.step);
}
