const Gamelib = @import("gamelib.zig");
const Utils = @import("utils.zig");
const Checker = @import("checker.zig");
const std = @import("std");

pub const Evaluator = struct {
    const FullTurnInfo = struct {
        maze_sent_json: []const u8,
        gamer_turn_json: []const u8,
    };

    const FullMatchInfo = struct {
        original_game_json: []const u8,
        turn_info_list: std.ArrayList(FullTurnInfo),
        optimal_path_length: i32,
        fn getScore(self: FullMatchInfo) f32 {
            return @as(f32, @floatFromInt(self.optimal_path_length)) /
                @as(f32, @floatFromInt(self.turn_info_list.items.len));
        }
    };

    /// Data only for JSON serialization
    const FullMatchInfoJSON = struct {
        original_game_json: []const u8,
        turn_info_list: []FullTurnInfo,
        optimal_path_length: i32,
    };

    match_info: FullMatchInfo,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, original_game: Gamelib.Game) !Evaluator {
        std.debug.assert(try Checker.tryBFS(original_game) == .Valid);
        const optimal_path_length = try original_game.board.getBufferValue(original_game.end_position);
        return Evaluator{
            .allocator = allocator,
            .match_info = .{
                .original_game_json = try Gamelib.getGameAsJsonString(
                    original_game,
                    allocator,
                ),
                .optimal_path_length = optimal_path_length,
                .turn_info_list = std.ArrayList(FullTurnInfo).init(allocator),
            },
        };
    }

    pub fn addTurn(self: *Evaluator, maze_sent: Gamelib.Game, turn: Gamelib.GameTurn) !void {
        try self.match_info.turn_info_list.append(.{
            .maze_sent_json = try Gamelib.getGameAsJsonString(
                maze_sent,
                self.allocator,
            ),
            .gamer_turn_json = try std.json.stringifyAlloc(
                self.allocator,
                turn,
                .{},
            ),
        });
    }

    pub fn calculateScore(self: Evaluator) !f32 {
        if (self.match_info.turn_info_list.items.len == 0) {
            return error.NoTurns;
        }
        return self.match_info.getScore();
    }

    pub fn logToFile(self: Evaluator, file: std.fs.File) !void {
        const writer = file.writer();
        try std.json.stringify(
            FullMatchInfoJSON{
                .original_game_json = self.match_info.original_game_json,
                .turn_info_list = self.match_info.turn_info_list.items,
                .optimal_path_length = self.match_info.optimal_path_length,
            },
            .{},
            writer,
        );
    }
    pub fn deinit(self: Evaluator) void {
        self.allocator.free(self.match_info.original_game_json);
        for (self.match_info.turn_info_list.items) |*turn_info| {
            self.allocator.free(turn_info.maze_sent_json);
            self.allocator.free(turn_info.gamer_turn_json);
        }
        self.match_info.turn_info_list.deinit();
    }
};
