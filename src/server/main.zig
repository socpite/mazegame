const std = @import("std");

const Connection = std.net.Server.Connection;
const Net = std.net;
const Posix = std.posix;
const GameServer = @import("gameserver.zig");

const PORT: u16 = 8080;
const PORT_HTTP: u16 = 8081;
const MAX_BYTES: usize = (1 << 16);

fn matchClients(client_1: *Connection, client_2: *Connection) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var series = try GameServer.Series.init(allocator, client_1, client_2);
    try series.start();
    defer series.deinit();
}

fn runGameServer(server: *std.net.Server) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var queue: ?*Connection = null;
    while (true) {
        const connection = try allocator.create(Connection);
        connection.* = server.accept() catch |err| {
            std.debug.print("Error accpeting connection: {any}\n", .{err});
            return err;
        };
        std.debug.print("Connected client with address {any}\n", .{connection.address});
        if (queue) |client_1| {
            const client_2 = connection;
            const match_thread = try std.Thread.spawn(.{}, matchClients, .{ client_1, client_2 });
            match_thread.detach();
            queue = null;
        } else {
            queue = connection;
        }
    }
}

pub fn main() !void {
    const addr = try Net.Address.parseIp("0.0.0.0", PORT);
    const addr_http = try Net.Address.parseIp("127.0.0.1", PORT_HTTP);
    var server = try Net.Address.listen(addr, .{ .reuse_address = true });
    var http_server = try Net.Address.listen(addr_http, .{ .reuse_address = true });
    defer server.deinit();
    defer http_server.deinit();
    std.debug.print("Server hosted on port {any}\n", .{PORT});
    std.debug.print("HTTP Server hosted on port {any}\n", .{PORT_HTTP});
    const game_server_thread = try std.Thread.spawn(.{}, runGameServer, .{&server});
    game_server_thread.join();
}
