const std = @import("std");

const StaticHttpFileServer = @import("StaticHttpFileServer");
const Connection = std.net.Server.Connection;
const Items = @import("item.zig");
const Net = std.net;
const Posix = std.posix;
const GameLib = @import("gamelib.zig");
const GameServer = @import("gameserver.zig");

const cwd = std.fs.cwd();
const PORT: u16 = 8080;
const PORT_HTTP: u16 = 8081;
const MAX_BYTES: usize = (1 << 16);

fn matchClients(client_1: Connection, client_2: Connection) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var aa = std.heap.ArenaAllocator.init(gpa.allocator());

    const allocator = aa.allocator();
    var series = try GameServer.Series.init(allocator, client_1, client_2);
    try series.start();
}

fn runGameServer(server: *std.net.Server) !void {
    var queue: ?Connection = null;
    while (true) {
        const connection = server.accept() catch |err| {
            std.debug.print("Error accpeting connection: {}\n", .{err});
            return err;
        };
        std.debug.print("Connected client with address {}\n", .{connection.address});
        if (queue) |client_1| {
            const client_2 = connection;
            const match_thread = try std.Thread.spawn(.{}, matchClients, .{ client_1, client_2 });
            match_thread.detach();
        } else {
            queue = connection;
        }
    }
}

fn runHttpServer(server: *std.net.Server) !void {
    const html_file = std.fs.cwd().openFile(
        "src/index.html",
        .{ .mode = .read_only },
    ) catch |err| {
        std.debug.print("Error opening html file: {}\n", .{err});
        return err;
    };
    defer html_file.close();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const dir = try cwd.openDir("src", .{ .iterate = true });
    var shfs = try StaticHttpFileServer.init(.{ .allocator = allocator, .root_dir = dir });
    defer shfs.deinit(allocator);
    while (true) {
        const connection = try server.accept();
        defer connection.stream.close();
        var buffer: [(1 << 16)]u8 = undefined;
        var http_server = std.http.Server.init(connection, buffer[0..]);
        var request = try http_server.receiveHead();
        std.debug.print("{s}\n", .{request.head.target});
        var headers = request.iterateHeaders();
        std.debug.print("START\n", .{});
        while (headers.next()) |header| {
            std.debug.print("Header: {s} {s}\n", .{ header.name, header.value });
        }
        std.debug.print("END\n", .{});
        try shfs.serve(&request);

        // const html_content = try html_file.readToEndAlloc(allocator, MAX_BYTES);
        // defer allocator.free(html_content);
        // request.respond(html_content, .{}) catch |err| {
        // std.debug.print("Error responding to request: {}\n", .{err});
        // };
    }
}

pub fn main() !void {
    const addr = try Net.Address.parseIp("127.0.0.1", PORT);
    const addr_http = try Net.Address.parseIp("192.168.1.230", PORT_HTTP);
    var server = try Net.Address.listen(addr, .{ .reuse_address = true });
    var http_server = try Net.Address.listen(addr_http, .{ .reuse_address = true });
    defer server.deinit();
    defer http_server.deinit();
    std.debug.print("Server hosted on port {}\n", .{PORT});
    std.debug.print("HTTP Server hosted on port {}\n", .{PORT_HTTP});
    const game_server_thread = try std.Thread.spawn(.{}, runGameServer, .{&server});
    const http_server_thread = try std.Thread.spawn(.{}, runHttpServer, .{&http_server});
    game_server_thread.join();
    http_server_thread.join();
}
