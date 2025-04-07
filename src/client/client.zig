const std = @import("std");
const Net = std.net;
const GameLib = @import("gamelib");
const Client = GameLib.Client;

pub fn main() !void {
    std.debug.print("Starting client\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var aa = std.heap.ArenaAllocator.init(gpa.allocator());
    const allocator = aa.allocator();
    const address = try Net.Address.parseIp("127.0.0.1", 8080);
    const stream = try Net.tcpConnectToAddress(address);
    const client = Client{ .stream = stream };
    while (true) {
        const message = client.readMessage(allocator) catch {
            stream.close();
            break;
        };
        if (std.mem.eql(u8, message, Client.REQUEST_MAZE_PROTOCOL)) {
            const game_input_json = try client.readJSON(allocator, GameLib.GameJSON);
            var game_input = try GameLib.getGameFromJSON(
                game_input_json,
                allocator,
            );
            try game_input.setHorizontalWall(.{ 1, 1 }, .BorderWall);
            const game_final_json = try GameLib.getJSONFromGame(
                game_input,
                allocator,
            );
            try client.writeJSON(game_final_json);
        } else {
            std.debug.print("Invalid protocol: {s}\n", .{message});
        }
    }
}
