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
    var file_buf: [1024]u8 = undefined;
    var content = try std.fs.cwd().readFile("/proc/meminfo", &file_buf);

    var result = MemoryInfo{};
    var buffers: u64 = 0;
    var cached: u64 = 0;
    var pos: usize = 0;
    while (std.mem.indexOfScalarPos(u8, content, pos, ':')) |idx| {
        const label = content[pos..idx];
        var name_int: u128 = 0;
        const name_buf = std.mem.asBytes(&name_int);
        @memcpy(name_buf[0..label.len], label);
        const line_start = idx + 1;
        pos = (std.mem.indexOfScalarPos(u8, content, line_start, '\n') orelse break) + 1;

        const value_start = std.mem.trimLeft(u8, content[line_start..pos], " ");
        const end_index = std.mem.indexOfScalar(u8, value_start, ' ') orelse value_start.len;
        const value_str = value_start[0..end_index];
        switch (name_int) {
            asInt("MemTotal") => result.mem_total = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("MemFree") => result.mem_free = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("MemAvailable") => result.mem_available = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("Buffers") => buffers = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("Cached") => cached = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("Shmem") => result.mem_shared = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("SwapTotal") => result.swap_total = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("SwapFree") => result.swap_free = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("Active") => result.active = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("Inactive") => result.inactive = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("AnonPages") => result.anon_pages = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("Mapped") => result.mapped = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("Dirty") => result.dirty = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("Writeback") => result.writeback = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("KernelStack") => result.kernel_stack = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("PageTables") => result.page_tables = try std.fmt.parseUnsigned(u64, value_str, 10),
            asInt("Slab") => result.slab = try std.fmt.parseUnsigned(u64, value_str, 10),
            else => {},
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
