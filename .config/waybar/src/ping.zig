// This module is currently Work In Progress
// This module is currently Work In Progress
// This module is currently Work In Progress
// This module is currently Work In Progress
// This module is currently Work In Progress

const std = @import("std");

const TARGET = "8.8.8.8";
const PACKET_SIZE = 64;
const TIMEOUT_MS = 5000;

fn checksum(data: []const u8) u16 {
    var sum: u32 = 0;
    var i: usize = 0;

    // Process 16-bit chunks
    while (i + 1 < data.len) : (i += 2) sum += @as(u16, data[i]) << 8 | data[i + 1];

    if (i < data.len) sum += @as(u16, data[i]) << 8;

    sum = (sum >> 16) + (sum & 0xFFFF);
    sum += (sum >> 16);
    return ~@as(u16, @truncate(sum));
}

fn getTimeMs() i64 {
    return std.time.timestamp() * 1000 + @as(i64, @intCast(std.time.milliTimestamp()));
}

fn ping(ip_address: []const u8) !i64 {
    const addr = try std.net.Address.parseIp(ip_address, 0);
    const socket = try std.posix.socket(2, 3, 1);
    defer std.posix.close(socket);

    var packet = [_]u8{0} ** PACKET_SIZE;
    packet[0] = 8;
    packet[1] = 0;

    const cs = checksum(&packet);
    packet[2] = @as(u8, @truncate(cs >> 8));
    packet[3] = @as(u8, @truncate(cs & 0xFF));

    const start_time = getTimeMs();

    const timeout = std.posix.timeval{ .tv_sec = @intCast(TIMEOUT_MS / 1000), .tv_usec = @intCast((TIMEOUT_MS % 1000) * 1000) };
    try std.posix.setsockopt(socket, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout));

    _ = try std.posix.sendto(socket, &packet, 0, &addr.any, addr.getOsSockLen());

    var recv_buffer = [_]u8{0} ** PACKET_SIZE;
    _ = try std.posix.recvfrom(socket, &recv_buffer, 0, null, null);

    const latency = getTimeMs() - start_time;

    if (recv_buffer[0] == 0 and recv_buffer[1] == 0) {
        return latency;
    }

    return -1;
}

pub fn main() !void {
    const latency = try ping(TARGET);

    if (latency < 0 or latency > TIMEOUT_MS) {
        std.debug.print("{{\"text\":\"\", \"tooltip\":\"\", \"class\":\"hidden\"}}\n", .{});
    } else {
        std.debug.print("{{\"text\":\"   {}ms\", \"tooltip\":\"Target: {s}\"}}\n", .{ latency, TARGET });
    }
}
