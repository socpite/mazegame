const std = @import("std");
const Net = std.net;
const GameLib = @import("gamelib");
const Client = GameLib.Client;
const PlayerLoader = @import("playerloader.zig");

pub fn main() !void {
    try PlayerLoader.loadLibrary("src/example/mylib.so");
    std.debug.print("Starting client\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var aa = std.heap.ArenaAllocator.init(gpa.allocator());
    defer aa.deinit();
    const allocator = aa.allocator();
    const address = try Net.Address.parseIp("127.0.0.1", 8080);
    const stream = Net.tcpConnectToAddress(address) catch |err| {
        std.debug.print("Failed to connect to server: {}\n", .{err});
        return;
    };
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
            const game_input = try GameLib.getGameFromJSON(
                game_input_json,
                allocator,
            );
            const new_game = try PlayerLoader.getGame(allocator, game_input);
            const game_final_json = try GameLib.getJSONFromGame(
                new_game,
                allocator,
            );
            try client.writeJSON(game_final_json);
            std.debug.print("Sent maze\n", .{});
        } else if (std.mem.eql(u8, message, Client.REQUEST_MOVE_PROTOCOL)) {
            const game_input_json = try client.getNextJSONTimed(allocator, GameLib.GameJSON, null);
            const game_input = try GameLib.getGameFromJSON(
                game_input_json,
                allocator,
            );
            const player_turn = try PlayerLoader.getMove(game_input);
            try client.writeJSON(player_turn);
        } else if (std.mem.eql(u8, message, "Series draw")) {
            try client.deinit();
            break;
        }
    }
}

test "Dynamic linking" {
    var dyn_lib = try std.DynLib.open("src/example/mylib.so");
    var create_game: *const fn (c_int, c_int) callconv(.c) *anyopaque = undefined;
    var set_start_pos: *const fn (*anyopaque, c_int, c_int) callconv(.c) void = undefined;
    var get_start_pos: *const fn (*anyopaque) callconv(.c) [*]c_int = undefined;
    create_game = dyn_lib.lookup(@TypeOf(create_game), "create_game").?;
    set_start_pos = dyn_lib.lookup(@TypeOf(set_start_pos), "set_start_pos").?;
    get_start_pos = dyn_lib.lookup(@TypeOf(get_start_pos), "get_start_pos").?;
    const game = create_game(5, 5);
    const start_pos = get_start_pos(game);
    std.debug.print("Start pos: {d}, {d}\n", .{ start_pos[0], start_pos[1] });
}
