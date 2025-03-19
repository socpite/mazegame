const std = @import("std");
const net = std.net;
const posix = std.posix;
const gamelib = @import("gamelib.zig");

const PORT: u16 = 8080;
const PORT_HTTP: u16 = 8081;
const MAX_BYTES: usize = (1 << 16);

fn process_client(connection: net.Server.Connection) !void {
    std.debug.print("Thread opened with client {}\n", .{connection.address});
    const write_length = connection.stream.write("Hi From Server\n") catch |err| {
        std.debug.print("Unable to write to client {} with error: {}\n", .{ connection.address, err });
        return err;
    };
    if (write_length == 0) {
        std.debug.print("Client {} closed connecton", .{connection.address});
    }
    var game = try gamelib.Game.init(10, 10, null);
    try game.set_horizontal_wall(gamelib.vec2{ 2, 2 }, gamelib.WallType.VisibleWall);
    try game.set_vertical_wall(gamelib.vec2{ 2, 2 }, gamelib.WallType.VisibleWall);

    try std.json.stringify(game, .{}, connection.stream.writer());
    _ = try connection.stream.write("\n");
    connection.stream.close();
}

fn game_server(server: *std.net.Server) !void {
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

fn run_http_server(server: *std.net.Server) !void {
    const html_file = std.fs.cwd().openFile(
        "src/index.html",
        .{ .mode = .read_only },
    ) catch |err| {
        std.debug.print("Error opening html file: {}\n", .{err});
        return err;
    };
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    while (true) {
        const connection = try server.accept();
        var buffer: [(1 << 16)]u8 = undefined;
        var http_server = std.http.Server.init(connection, buffer[0..]);
        var request = try http_server.receiveHead();
        var headers = request.iterateHeaders();
        std.debug.print("START\n", .{});
        while (headers.next()) |header| {
            std.debug.print("Header: {s} {s}\n", .{ header.name, header.value });
        }
        std.debug.print("END\n", .{});
        const html_content = try html_file.readToEndAlloc(allocator, MAX_BYTES);
        defer allocator.free(html_content);
        request.respond(html_content, .{}) catch |err| {
            std.debug.print("Error responding to request: {}\n", .{err});
        };
    }
}

pub fn main() !void {
    const addr = try net.Address.parseIp("127.0.0.1", PORT);
    const addr_http = try net.Address.parseIp("127.0.0.1", PORT_HTTP);
    var server = try net.Address.listen(addr, .{ .reuse_address = true });
    var http_server = try net.Address.listen(addr_http, .{ .reuse_address = true });
    defer server.deinit();
    defer http_server.deinit();
    std.debug.print("Server hosted on port {}\n", .{PORT});
    std.debug.print("HTTP Server hosted on port {}\n", .{PORT_HTTP});
    const game_server_thread = try std.Thread.spawn(.{}, game_server, .{&server});
    const http_server_thread = try std.Thread.spawn(.{}, run_http_server, .{&http_server});
    game_server_thread.join();
    http_server_thread.join();
}
