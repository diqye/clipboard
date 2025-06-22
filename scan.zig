const std = @import("std");
const net = std.net;
const time = std.time;

fn printTime(start: std.time.Instant) !void {
    const now = try std.time.Instant.now();
    const diff = now.since(start);
    std.debug.print("Total time = {d:.2}s\n", .{@as(f64, @floatFromInt(diff)) / @as(f64, @floatFromInt(std.time.ns_per_s))});
}
pub fn main() !void {
    const start_time = try std.time.Instant.now();
    defer {
        printTime(start_time) catch {};
    }
    const allocator_1 = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator_1);
    const allocator = arena.allocator();
    defer arena.deinit();
    var list = std.ArrayList(std.Thread).init(allocator);
    defer list.deinit();
    for (0..255) |i| {
        const ip_str = try std.fmt.allocPrint(allocator, "10.4.208.{}", .{i});
        const thread = try std.Thread.spawn(.{}, struct {
            pub fn call(ip: []const u8) !void {
                _ = try scan(ip, 22);
            }
        }.call, .{ip_str});
        try list.append(thread);
        if (list.items.len >= 200) {
            // std.debug.print("join threads {}\n", .{list.items.len});
            for (list.items) |t| {
                t.join();
            }
            list.clearAndFree();
        }
    }
    for (list.items) |t| {
        t.join();
    }
}
test scan {
    _ = try scan("10.4.208.206", 22);
}
fn scan(ip: []const u8, port: u16) !bool {
    const address = try net.Address.parseIp4(ip, port);
    const sockfd = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM | std.posix.SOCK.NONBLOCK, 0);
    defer std.posix.close(sockfd);
    var addr: std.posix.sockaddr.in = address.in.sa;
    const last_time = try std.time.Instant.now();
    while (true) {
        switch (std.posix.errno(std.posix.system.connect(sockfd, @ptrCast(&addr), addr.len))) {
            .SUCCESS => {
                std.debug.print("Success {s}:{}\n", .{ ip, port });
                return true;
            },
            .ISCONN => {
                std.debug.print("ISCONN {s}:{}\n", .{ ip, port });
                return true;
            },
            .ALREADY, .AGAIN, .INPROGRESS => {
                const now = try std.time.Instant.now();
                const diff = now.since(last_time);
                if (diff > std.time.ns_per_ms * 800) {
                    // std.debug.print("超时 {s}\n", .{ip});
                    return false;
                }
                continue;
            },
            else => |err| {
                _ = err;
                // std.debug.print("err={}\n", .{err});
                return false;
            },
        }
    }
}
