const std = @import("std");

const KILO: u64 = 1024;
const MEGA: u64 = KILO * KILO;
const GIGA: u64 = KILO * MEGA;

const FmtSize = struct {
    size: u64,

    pub fn format(self: FmtSize, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        const scaled_size = self.size * KILO;
        return if (scaled_size >= GIGA) {
            try std.fmt.formatType(@as(f64, @floatFromInt(scaled_size)) / GIGA, fmt, options, writer, 0);
            try writer.writeByte('G');
        } else if (scaled_size >= MEGA) {
            try std.fmt.formatType(@as(f64, @floatFromInt(scaled_size)) / MEGA, fmt, options, writer, 0);
            try writer.writeByte('M');
        } else if (scaled_size >= KILO) {
            try std.fmt.formatType(@as(f64, @floatFromInt(scaled_size)) / KILO, fmt, options, writer, 0);
            try writer.writeByte('K');
        } else {
            try std.fmt.formatType(scaled_size, fmt, options, writer, 0);
            try writer.writeByte('B');
        };
    }
};

fn fmtSize(size: u64) FmtSize {
    return .{ .size = size };
}

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

    active: u64 = 0,
    inactive: u64 = 0,
    anon_pages: u64 = 0,
    mapped: u64 = 0,
    dirty: u64 = 0,
    writeback: u64 = 0,
    kernel_stack: u64 = 0,
    page_tables: u64 = 0,
    slab: u64 = 0,

    pub fn format(mem_info: MemoryInfo, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        const total_usage = mem_info.mem_used + mem_info.swap_used;
        const total_percentage = @as(f64, @floatFromInt(total_usage)) / @as(f64, @floatFromInt(mem_info.mem_total + mem_info.swap_total)) * 100;

        try writer.print(
            "{{\"text\":\"  {d:.2} · {d:.0}%\",\"tooltip\":\"Total · {d:.2}\\nUsed · {d:.2}\\nFree · {d:.2}\\nAvailable · {d:.2}\\nShared · {d:.2}\\nBuffer / Cache · {d:.2}\\n\\nActive · {d:.2}\\nInactive · {d:.2}\\nAnon Pages · {d:.2}\\nMapped · {d:.2}\\nDirty · {d:.2}\\nWriteback · {d:.2}\\nKernel Stack · {d:.2}\\nPage Tables · {d:.2}\\nSlab · {d:.2}\\n\\nSwap Total · {d:.2}\\nSwap Free · {d:.2}\\nSwap Used · {d:.2}\"}}",
            .{
                fmtSize(total_usage),
                total_percentage,
                fmtSize(mem_info.mem_total),
                fmtSize(mem_info.mem_used),
                fmtSize(mem_info.mem_free),
                fmtSize(mem_info.mem_available),
                fmtSize(mem_info.mem_shared),
                fmtSize(mem_info.mem_buff_cache),
                fmtSize(mem_info.active),
                fmtSize(mem_info.inactive),
                fmtSize(mem_info.anon_pages),
                fmtSize(mem_info.mapped),
                fmtSize(mem_info.dirty),
                fmtSize(mem_info.writeback),
                fmtSize(mem_info.kernel_stack),
                fmtSize(mem_info.page_tables),
                fmtSize(mem_info.slab),
                fmtSize(mem_info.swap_total),
                fmtSize(mem_info.swap_free),
                fmtSize(mem_info.swap_used),
            },
        );
    }
};

fn asInt(s: []const u8) u128 {
    var buf = [1]u8{0} ** 16;
    if (s.len <= buf.len) @memcpy(buf[0..s.len], s);
    return @bitCast(buf);
}

fn parse() !MemoryInfo {
    const file = try std.fs.cwd().openFile("/proc/meminfo", .{});
    defer file.close();
    var br = std.io.bufferedReader(file.reader());
    const reader = br.reader();

    var result = MemoryInfo{};
    var buffers: u64 = 0;
    var cached: u64 = 0;

    while (true) {
        var name_int: u128 = 0;
        const name_buf = std.mem.asBytes(&name_int);
        _ = (reader.readUntilDelimiterOrEof(name_buf, ':') catch name_buf) orelse break;
        const ptr: ?*u64 = switch (name_int) {
            asInt("MemTotal:") => &result.mem_total,
            asInt("MemFree:") => &result.mem_free,
            asInt("MemAvailable:") => &result.mem_available,
            asInt("Buffers:") => &buffers,
            asInt("Cached:") => &cached,
            asInt("Shmem:") => &result.mem_shared,
            asInt("SwapTotal:") => &result.swap_total,
            asInt("SwapFree:") => &result.swap_free,
            asInt("Active:") => &result.active,
            asInt("Inactive:") => &result.inactive,
            asInt("AnonPages:") => &result.anon_pages,
            asInt("Mapped:") => &result.mapped,
            asInt("Dirty:") => &result.dirty,
            asInt("Writeback:") => &result.writeback,
            asInt("KernelStack:") => &result.kernel_stack,
            asInt("PageTables:") => &result.page_tables,
            asInt("Slab:") => &result.slab,
            else => null,
        };
        var line_buf: [256 - @sizeOf(@TypeOf(name_int))]u8 = undefined;
        const line = reader.readUntilDelimiterOrEof(&line_buf, '\n') catch &line_buf orelse break;
        if (ptr) |p| {
            const value_start = std.mem.trimLeft(u8, line, " ");
            const end_index = std.mem.indexOfScalar(u8, value_start, ' ') orelse value_start.len;
            p.* = try std.fmt.parseUnsigned(u64, value_start[0..end_index], 10);
        }
    }

    result.mem_buff_cache = buffers + cached;
    result.mem_used = result.mem_total - result.mem_available;
    result.swap_used = result.swap_total - result.swap_free;
    return result;
}

pub fn main() !void {
    const mem_info = try parse();
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    try bw.writer().print("{}", .{mem_info});
    try bw.flush();
}
