// This module is currently Work In Progress
// This module is currently Work In Progress
// This module is currently Work In Progress
// This module is currently Work In Progress
// This module is currently Work In Progress

const std = @import("std");
const mem = std.mem;
const process = std.process;
const time = std.time;
const heap = std.heap;
const io = std.io;
const sort = std.sort;

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
    const escape_replacements = &[_]u8{ '"', '\\', 'b', 'f', 'n', 'r', 't' };
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

fn parseLine(line: []const u8, pkg: []u8, local_ver: []u8, new_ver: []u8) bool {
    var token_iter = mem.tokenize(u8, line, " ");

    const package_name = token_iter.next() orelse return false;
    @memcpy(pkg[0..package_name.len], package_name);
    pkg[package_name.len] = 0;

    const current_ver = token_iter.next() orelse return false;
    if (!mem.eql(u8, current_ver, "->")) return false;

    const local_version = token_iter.next() orelse return false;
    @memcpy(local_ver[0..local_version.len], local_version);
    local_ver[local_version.len] = 0;

    const new_version = token_iter.next() orelse return false;
    @memcpy(new_ver[0..new_version.len], new_version);
    new_ver[new_version.len] = 0;

    return true;
}

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var child = process.Child.init(&.{ "/usr/bin/checkupdates", "--nocolor" }, allocator);

    child.stdout_behavior = .Pipe;
    try child.spawn();

    const stdout = child.stdout orelse return error.NoStdout;
    const reader = stdout.reader();
    var line_buf: [BUFFER_SIZE]u8 = undefined;
    var updates = [_]UpdateInfo{mem.zeroes(UpdateInfo)} ** MAX_UPDATES;
    var updates_count: usize = 0;

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        if (updates_count >= MAX_UPDATES) break;

        var pkg: [BUFFER_SIZE]u8 = undefined;
        var local_ver: [MAX_VERSION_LENGTH + 1]u8 = undefined;
        var new_ver: [MAX_VERSION_LENGTH + 1]u8 = undefined;

        if (parseLine(line, &pkg, &local_ver, &new_ver)) {
            @memcpy(&updates[updates_count].pkg_name, &pkg);
            @memcpy(&updates[updates_count].local_version, &local_ver);
            @memcpy(&updates[updates_count].new_version, &new_ver);
            updates_count += 1;
        }
    }

    _ = try child.wait();

    sort.insertion(UpdateInfo, &updates, {}, compareUpdates);

    var updates_str = std.ArrayList(u8).init(allocator);
    defer updates_str.deinit();

    for (0..updates_count) |i| {
        try updates_str.writer().print("{s:<25} {s} -> {s}\n", .{ mem.sliceTo(&updates[i].pkg_name, 0), mem.sliceTo(&updates[i].local_version, 0), mem.sliceTo(&updates[i].new_version, 0) });
    }

    if (updates_str.items.len > 0 and updates_str.items[updates_str.items.len - 1] == '\n') {
        _ = updates_str.pop();
    }

    var pkg_list_escaped = [_]u8{0} ** (BUFFER_SIZE * 10);
    escapeJson(updates_str.items, &pkg_list_escaped);

    var bw = io.bufferedWriter(io.getStdOut().writer());

    if (updates_count > 0) {
        try bw.writer().print("{{\"text\":\"{d}\",\"tooltip\":\"{d} updates available.\\n\\n{s}\"}}\n", .{ updates_count, updates_count, &pkg_list_escaped });
    } else {
        try bw.writer().print("{{\"text\":\"\",\"tooltip\":\"You're up to date!\"}}\n", .{});
    }

    try bw.flush();
}