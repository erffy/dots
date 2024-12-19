const std = @import("std");
const mem = std.mem;
const process = std.process;
const heap = std.heap;
const io = std.io;
const sort = std.sort;
const ascii = std.ascii;

const BUFFER_SIZE = 4096;
const MAX_VERSION_LENGTH = 20;
const MAX_UPDATES = 75;

const UpdateInfo = struct {
    pkg_name: [BUFFER_SIZE]u8,
    local_version: [MAX_VERSION_LENGTH + 1]u8,
    new_version: [MAX_VERSION_LENGTH + 1]u8,
};

fn escapeJson(input: []const u8, output: []u8) void {
    const escape_chars = &[_]u8{ '"', '\\', '\n', '\r', '\t' };
    const escape_replacements = &[_]u8{ '"', '\\', 'n', 'r', 't' };
    var j: usize = 0;

    for (input) |char| {
        if (j >= output.len - 1) break;

        if (mem.indexOfScalar(u8, escape_chars, char)) |esc_index| {
            if (j + 2 >= output.len) break;
            output[j] = '\\';
            j += 1;
            output[j] = escape_replacements[esc_index];
        } else {
            output[j] = char;
        }
        j += 1;
    }
    output[j] = 0;
}

fn compareUpdates(context: void, a: UpdateInfo, b: UpdateInfo) bool {
    _ = context;
    return mem.lessThan(u8, &a.pkg_name, &b.pkg_name);
}

fn parseLine(line: []const u8, info: *UpdateInfo) bool {
    const trimmed = mem.trim(u8, line, &ascii.whitespace);
    if (trimmed.len == 0) return false;

    var parts = mem.split(u8, trimmed, "->");
    const left_part = mem.trim(u8, parts.first(), &ascii.whitespace);
    const new_version = mem.trim(u8, parts.rest(), &ascii.whitespace);
    if (new_version.len == 0) return false;

    const last_space = mem.lastIndexOf(u8, left_part, " ") orelse return false;
    const pkg_name = left_part[0..last_space];
    const local_ver = left_part[last_space + 1 ..];

    if (pkg_name.len >= info.pkg_name.len or
        local_ver.len >= info.local_version.len or
        new_version.len >= info.new_version.len) return false;

    @memset(&info.pkg_name, 0);
    @memset(&info.local_version, 0);
    @memset(&info.new_version, 0);

    @memcpy(info.pkg_name[0..pkg_name.len], pkg_name);
    @memcpy(info.local_version[0..local_ver.len], local_ver);
    @memcpy(info.new_version[0..new_version.len], new_version);

    return true;
}

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var child = process.Child.init(&[_][]const u8{ "/usr/bin/checkupdates", "--nocolor" }, allocator);
    child.stdout_behavior = .Pipe;
    try child.spawn();

    const stdout = child.stdout orelse return error.NoStdout;
    var buf_reader = io.bufferedReader(stdout.reader());
    var line_buf: [BUFFER_SIZE]u8 = undefined;
    var updates = [_]UpdateInfo{mem.zeroes(UpdateInfo)} ** MAX_UPDATES;
    var updates_count: usize = 0;

    while (try buf_reader.reader().readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        if (updates_count >= MAX_UPDATES) break;
        if (line.len == 0) continue;

        if (parseLine(line, &updates[updates_count])) updates_count += 1;
    }

    _ = try child.wait();

    sort.insertion(UpdateInfo, updates[0..updates_count], {}, compareUpdates);

    var updates_str = std.ArrayList(u8).init(allocator);
    defer updates_str.deinit();

    for (updates[0..updates_count], 0..) |update, i| {
        try updates_str.writer().print("{s:<25} {s} -> {s}\n", .{
            mem.sliceTo(&update.pkg_name, 0),
            mem.sliceTo(&update.local_version, 0),
            mem.sliceTo(&update.new_version, 0),
        });

        if (i == MAX_UPDATES - 1 and updates_count >= MAX_UPDATES) {
            try updates_str.writer().writeAll("...");
            break;
        }
    }

    if (updates_str.items.len > 0 and updates_str.items[updates_str.items.len - 1] == '\n') _ = updates_str.pop();

    var pkg_list_escaped = [_]u8{0} ** (BUFFER_SIZE * 10);
    escapeJson(updates_str.items, &pkg_list_escaped);

    var bw = io.bufferedWriter(io.getStdOut().writer());
    const writer = bw.writer();

    if (updates_count > 0) {
        try writer.print("{{\"text\":\"\",\"tooltip\":\"{d} updates available.\\n\\n{s}{s}\"}}", .{
            updates_count,
            mem.sliceTo(&pkg_list_escaped, 0),
            if (updates_count >= MAX_UPDATES) "\\n...and more updates." else "",
        });
    } else {
        try writer.print("{{\"text\":\"\",\"tooltip\":\"You're up to date!\"}}", .{});
    }

    try bw.flush();
}
