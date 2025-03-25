const std = @import("std");
const Net = std.net;
const GameLib = @import("gamelib.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const address = try Net.Address.parseIp("127.0.0.1", 8080);
    const stream = try Net.tcpConnectToAddress(address);
    var buffer: [1 << 16]u8 = undefined;
    const hello_msg = try stream.reader().readUntilDelimiter(&buffer, '\n');
    std.debug.print("{s}\n", .{hello_msg});
    const obj_json = try stream.reader().readUntilDelimiter(&buffer, '\n');
    const obj = try std.json.parseFromSlice(
        GameLib.Game,
        allocator,
        obj_json,
        .{},
    );
    defer obj.deinit();
    std.debug.print("{}\n", .{obj.value});
    std.debug.print("{}\n", .{try obj.value.check()});
    std.debug.print("{s}\n", .{obj_json});
}
