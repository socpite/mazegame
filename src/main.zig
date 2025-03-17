const std = @import("std");
const net = std.net;
const posix = std.posix;
const gamelib = @import("gamelib.zig");

const PORT: u16 = 8080;

fn process_client(connection: net.Server.Connection) !void {
    std.debug.print("Thread opened with client {}\n", .{connection.address});
    const write_length = connection.stream.write("Hi From Server\n") catch |err| {
        std.debug.print("Unable to write to client {} with error: {}\n", .{ connection.address, err });
        return err;
    };
    if (write_length == 0) {
        std.debug.print("Client {} closed connecton", .{connection.address});
    }
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var game = try gamelib.Game.init(&arena, 10, 10, null);
    try game.set_horizontal_wall(gamelib.vec2{ 2, 2 }, gamelib.WallType.VisibleWall);
    try game.set_vertical_wall(gamelib.vec2{ 2, 2 }, gamelib.WallType.VisibleWall);

    try std.json.stringify(game, .{}, connection.stream.writer());
    _ = try connection.stream.write("\n");
    connection.stream.close();
}

pub fn main() !void {
    const addr = try net.Address.parseIp("127.0.0.1", PORT);
    var server = try net.Address.listen(addr, .{ .reuse_address = true });
    defer server.deinit();
    std.debug.print("Server hosted on port {}\n", .{PORT});
    while (true) {
        const connection = server.accept() catch |err| {
            std.debug.print("Error accpeting connection: {}\n", .{err});
            return err;
        };
        std.debug.print("Connected client with address {}\n", .{connection.address});
        const new_thread = std.Thread.spawn(.{}, process_client, .{connection}) catch |err| {
            std.debug.print("Error opening thead: {}\n", .{err});
            return err;
        };
        new_thread.detach();
    }
}
