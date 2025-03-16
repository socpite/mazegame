const std = @import("std");
const net = std.net;
const gamelib = @import("gamelib.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const address = try net.Address.parseIp("127.0.0.1", 8080);
    const stream = try net.tcpConnectToAddress(address);
    var buffer: [1 << 16]u8 = undefined;
    const hello_msg = try stream.reader().readUntilDelimiter(&buffer, '\n');
    std.debug.print("{s}\n", .{hello_msg});
    const obj_json = try stream.reader().readUntilDelimiter(&buffer, '\n');
    const obj = try std.json.parseFromSlice(
        gamelib.MazeBoard,
        allocator,
        obj_json,
        .{},
    );
    obj.deinit();
    // std.debug.print("{}", .{obj.value.arr});
    std.debug.print("{s}\n", .{obj_json});
}
