const std = @import("std");
const Net = std.net;
const GameLib = @import("gamelib");
const Client = GameLib.Client;

pub fn main() !void {
    std.debug.print("Starting client\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var aa = std.heap.ArenaAllocator.init(gpa.allocator());
    defer aa.deinit();
    const allocator = aa.allocator();
    const address = try Net.Address.parseIp("127.0.0.1", 8080);
    const stream = try Net.tcpConnectToAddress(address);
    var client = Client.init(
        allocator,
        stream,
        .{},
        "my_name",
    );
    try client.start();
    while (true) {
        const message = client.getNextMessageTimed(allocator, null) catch {
            stream.close();
            break;
        };
        std.debug.print("Received message: {s}\n", .{message});
        if (std.mem.eql(u8, message, Client.REQUEST_MAZE_PROTOCOL)) {
            const game_input_json = try client.getNextJSONTimed(allocator, GameLib.GameJSON, null);
            var game_input = try GameLib.getGameFromJSON(
                game_input_json,
                allocator,
            );
            try game_input.setHorizontalWall(.{ 1, 1 }, .VisibleWall);
            const game_final_json = try GameLib.getJSONFromGame(
                game_input,
                allocator,
            );
            try client.writeJSON(game_final_json);
            std.debug.print("Sent maze\n", .{});
        } else if (std.mem.eql(u8, message, Client.REQUEST_MOVE_PROTOCOL)) {
            const game_input_json = try client.getNextJSONTimed(allocator, GameLib.GameJSON, null);
            var game_input = try GameLib.getGameFromJSON(
                game_input_json,
                allocator,
            );
            for (GameLib.Direction.list) |direction| {
                if (game_input.isMoveValid(direction)) {
                    try client.writeJSON(direction);
                    break;
                }
            }
        } else {
            std.debug.print("Unknown message: {s}\n", .{message});
        }
    }
}
