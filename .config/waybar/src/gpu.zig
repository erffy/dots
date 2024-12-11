const std = @import("std");

const KILO: u64 = 1024;
const MEGA: u64 = KILO * KILO;
const GIGA: u64 = KILO * MEGA;

const GPUInfo = struct {
    memory_total: u64,
    memory_used: u64,
    memory_free: u64,
    temperature: f64,
    gpu_busy_percent: u64,
    memory_busy_percent: u64,
};

fn readSysFile(path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buffer: [4096]u8 = undefined;
    const bytes_read = try file.read(&buffer);
    const content = buffer[0..bytes_read];

    return std.mem.trim(u8, content, " \n");
}

fn parseNumber(content: []const u8) u64 {
    return std.fmt.parseInt(u64, content, 10) catch |err| blk: {
        std.debug.print("Number parsing error: {}\n", .{err});
        break :blk 0;
    };
}

fn parseFloat(content: []const u8) f64 {
    return std.fmt.parseFloat(f64, content) catch |err| blk: {
        std.debug.print("Float parsing error: {}\n", .{err});
        break :blk 0.0;
    };
}

fn findPath(base_paths: []const []const u8) ![]const u8 {
    for (base_paths) |path| {
        const file = std.fs.cwd().openFile(path, .{}) catch continue;
        defer file.close();
        return try std.heap.page_allocator.dupe(u8, path);
    }
    return error.PathNotFound;
}

fn getGPUInfo(allocator: std.mem.Allocator) !GPUInfo {
    const base_device = "/sys/class/hwmon/hwmon2/device";
    const base_hwmon = "/sys/class/hwmon/hwmon2";

    const syspaths = struct {
        mem_total: []const u8 = "mem_info_vram_total",
        mem_used: []const u8 = "mem_info_vram_used",
        gpu_busy: []const u8 = "gpu_busy_percent",
        mem_busy: []const u8 = "mem_busy_percent",
    }{};

    const mem_total_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_device, syspaths.mem_total });
    defer allocator.free(mem_total_path);
    const memory_total_raw = try readSysFile(mem_total_path);
    const memory_total = parseNumber(memory_total_raw);

    const mem_used_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_device, syspaths.mem_used });
    defer allocator.free(mem_used_path);
    const memory_used_raw = try readSysFile(mem_used_path);
    const memory_used = parseNumber(memory_used_raw);

    const temperature_path = try std.fmt.allocPrint(allocator, "{s}/temp1_input", .{base_hwmon});
    defer allocator.free(temperature_path);
    const temperature_raw = try readSysFile(temperature_path);
    const temperature = parseFloat(temperature_raw) / 1000.0;

    const gpu_busy_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_device, syspaths.gpu_busy });
    defer allocator.free(gpu_busy_path);

    const gpu_busy_raw = try readSysFile(gpu_busy_path);
    const gpu_busy_percent = parseNumber(gpu_busy_raw);

    const mem_busy_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_device, syspaths.mem_busy });
    defer allocator.free(mem_busy_path);

    const mem_busy_raw = try readSysFile(mem_busy_path);
    const memory_busy_percent = parseNumber(mem_busy_raw);

    return GPUInfo{
        .memory_total = memory_total,
        .memory_used = memory_used,
        .memory_free = memory_total - memory_used,
        .temperature = temperature,
        .gpu_busy_percent = gpu_busy_percent,
        .memory_busy_percent = memory_busy_percent,
    };
}

fn formatMemory(size: u64, output: []u8) []const u8 {
    return if (size >= GIGA)
        std.fmt.bufPrint(output, "{d:.2}G", .{@as(f64, @floatFromInt(size)) / GIGA}) catch ""
    else if (size >= MEGA)
        std.fmt.bufPrint(output, "{d:.2}M", .{@as(f64, @floatFromInt(size)) / MEGA}) catch ""
    else if (size >= KILO)
        std.fmt.bufPrint(output, "{d:.2}K", .{@as(f64, @floatFromInt(size)) / KILO}) catch ""
    else
        std.fmt.bufPrint(output, "{}B", .{size}) catch "";
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const gpu_info = getGPUInfo(allocator) catch |err| {
        std.debug.print("Failed to get GPU info: {}\n", .{err});
        return;
    };

    var total_mem_str: [16]u8 = undefined;
    var used_mem_str: [16]u8 = undefined;
    var free_mem_str: [16]u8 = undefined;

    try std.io.getStdOut().writer().print(
        "{{\"text\":\"  {d}% · {d}°C\",\"tooltip\":\"Memory Total · {s}\\nMemory Used · {s}\\nMemory Free · {s}\"}}",
        .{
            gpu_info.gpu_busy_percent,
            gpu_info.temperature,
            formatMemory(gpu_info.memory_total, &total_mem_str),
            formatMemory(gpu_info.memory_used, &used_mem_str),
            formatMemory(gpu_info.memory_free, &free_mem_str),
        },
    );
}