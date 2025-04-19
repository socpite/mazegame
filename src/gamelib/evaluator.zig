const Gamelib = @import("gamelib.zig");
const Utils = @import("utils.zig");
const Checker = @import("checker.zig");
const std = @import("std");

const Evaluator = struct {
    optimal_path_length: i32,
    turn_list: std.ArrayList(Gamelib.GameTurn),
    original_game_json_string: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, original_game: Gamelib.Game) Evaluator {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const temp_allocator = arena.allocator();
        Checker.tryBFS(original_game);
        const optimal_path_length = original_game.board.getBufferValue(original_game.end_position);
        const original_game_json = Gamelib.getJSONFromGame(
            original_game,
            temp_allocator,
        );
        return Evaluator{
            .allocator = allocator,
            .original_game_json_string = std.json.stringifyAlloc(
                allocator,
                original_game_json,
                .{},
            ),
            .optimal_path_length = optimal_path_length,
            .turn_list = std.ArrayList(Gamelib.GameTurn).init(allocator),
        };
    }

    pub fn addTurn(self: *Evaluator, turn: Gamelib.GameTurn) !void {
        try self.turn_list.append(turn);
    }

    pub fn calculateScore(self: Evaluator) !f32 {
        return @as(f32, self.optimal_path_length) / @as(f32, self.turn_list.length);
    }

    pub fn logToFile(self: Evaluator, file: *std.fs.File) !void {
        const writer = file.writer();
        try writer.write(self.original_game_json_string);
    }
};
