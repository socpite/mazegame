const std = @import("std");
const Net = std.net;
const GameLib = @import("gamelib.zig");
const Client = @import("netclient.zig").Client;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const address = try Net.Address.parseIp("127.0.0.1", 8080);
    const stream = try Net.tcpConnectToAddress(address);
    const client = Client{ .stream = stream };
    const first_message = try client.readMessage(allocator);
    std.debug.print("First message: {s}\n", .{first_message});
}
