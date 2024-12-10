const std = @import("std");

const KILO: u64 = 1024;
const MEGA: u64 = KILO * KILO;
const GIGA: u64 = KILO * MEGA;

const MemoryInfo = struct {
    mem_total: u64 = 0,
    mem_used: u64 = 0,
    mem_free: u64 = 0,
    mem_shared: u64 = 0,
    mem_buff_cache: u64 = 0,
    mem_available: u64 = 0,
    swap_total: u64 = 0,
    swap_used: u64 = 0,
    swap_free: u64 = 0,
};

fn format(size: u64, output: []u8) []const u8 {
    const scaled_size = size * KILO;

    return if (scaled_size >= GIGA)
        std.fmt.bufPrint(output, "{d:.2}G", .{@as(f64, @floatFromInt(scaled_size)) / GIGA}) catch ""
    else if (scaled_size >= MEGA)
        std.fmt.bufPrint(output, "{d:.2}M", .{@as(f64, @floatFromInt(scaled_size)) / MEGA}) catch ""
    else if (scaled_size >= KILO)
        std.fmt.bufPrint(output, "{d:.2}K", .{@as(f64, @floatFromInt(scaled_size)) / KILO}) catch ""
    else
        std.fmt.bufPrint(output, "{}B", .{scaled_size}) catch "";
}

fn parseLine(line: []const u8, prefix: []const u8) ?u64 {
    if (!std.mem.startsWith(u8, line, prefix)) return null;

    const value_start = std.mem.trimLeft(u8, line[prefix.len..], " ");
    const end_index = std.mem.indexOfScalar(u8, value_start, ' ') orelse value_start.len;

    return std.fmt.parseInt(u64, value_start[0..end_index], 10) catch null;
}

fn parse() !MemoryInfo {
    const file = try std.fs.cwd().openFile("/proc/meminfo", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var result = MemoryInfo{};
    var line_buf: [256]u8 = undefined;
    var buffers: u64 = 0;
    var cached: u64 = 0;

    while (try in_stream.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        if (parseLine(line, "MemTotal:")) |val| result.mem_total = val;
        if (parseLine(line, "MemFree:")) |val| result.mem_free = val;
        if (parseLine(line, "MemAvailable:")) |val| result.mem_available = val;
        if (parseLine(line, "Buffers:")) |val| buffers = val;
        if (parseLine(line, "Cached:")) |val| cached = val;
        if (parseLine(line, "Shmem:")) |val| result.mem_shared = val;
        if (parseLine(line, "SwapTotal:")) |val| result.swap_total = val;
        if (parseLine(line, "SwapFree:")) |val| result.swap_free = val;
    }

    result.mem_buff_cache = buffers + cached;
    result.mem_used = result.mem_total - result.mem_available;
    result.swap_used = result.swap_total - result.swap_free;

    return result;
}

pub fn main() !void {
    const mem_info = try parse();

    var mem_total_str: [16]u8 = undefined;
    var mem_used_str: [16]u8 = undefined;
    var mem_free_str: [16]u8 = undefined;
    var mem_available_str: [16]u8 = undefined;
    var mem_shared_str: [16]u8 = undefined;
    var mem_cache_str: [16]u8 = undefined;
    var swap_total_str: [16]u8 = undefined;
    var swap_free_str: [16]u8 = undefined;
    var swap_used_str: [16]u8 = undefined;
    var total_usage_str: [16]u8 = undefined;

    const total_usage = mem_info.mem_used + mem_info.swap_used;
    const formatted_total_usage = format(total_usage, &total_usage_str);

    const total_percentage = @as(f64, @floatFromInt(total_usage)) /
        @as(f64, @floatFromInt(mem_info.mem_total + mem_info.swap_total)) * 100;

    try std.io.getStdOut().writer().print("{{\"text\":\"  {s} · {d:.0}%\",\"tooltip\":\"Total · {s}\\nUsed · {s}\\nFree · {s}\\nAvailable · {s}\\nShared · {s}\\nBuffer / Cache · {s}\\n\\nSwap Total · {s}\\nSwap Free · {s}\\nSwap Used · {s}\"}}", .{ formatted_total_usage, total_percentage, format(mem_info.mem_total, &mem_total_str), format(mem_info.mem_used, &mem_used_str), format(mem_info.mem_free, &mem_free_str), format(mem_info.mem_available, &mem_available_str), format(mem_info.mem_shared, &mem_shared_str), format(mem_info.mem_buff_cache, &mem_cache_str), format(mem_info.swap_total, &swap_total_str), format(mem_info.swap_free, &swap_free_str), format(mem_info.swap_used, &swap_used_str) });
}