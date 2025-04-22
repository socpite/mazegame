const std = @import("std");
const GameLib = @import("gamelib");
const Items = GameLib.ItemLib;
const Self = @This();
const Connection = std.net.Server.Connection;
const Client = GameLib.Client;
const Checker = GameLib.Checker;
const Evaluator = GameLib.Evaluator;
const c = @cImport({
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("time.h");
});

var gpa1 = std.heap.GeneralPurposeAllocator(.{}){};
var gpa2 = std.heap.GeneralPurposeAllocator(.{}){};

const Match = struct {
    game: GameLib.Game,
    mazer_client: *Client,
    gamer_client: *Client,
    allocator: std.mem.Allocator,
    evaluator: Evaluator,

    const MAX_TURN_COUNT = 10000;
    const MatchError = error{
        InvalidMaze,
        MazerTimeout,
        GamerTimeout,
        ServerFailed,
    };
    const MatchResult = enum {
        Error,
        MazerWin,
        GamerWin,
    };

    /// Is called at the end of a match
    fn messageFinished(self: *Match, gamer_score: f32) !void {
        try self.gamer_client.writeMessage("Game finished. Score:");
        try self.mazer_client.writeMessage("Game finished. Score:");
        try self.gamer_client.writeJSON(gamer_score);
        try self.mazer_client.writeJSON(gamer_score);
        self.gamer_client.score += gamer_score;
        try self.logToFile(null);
    }

    /// default file name is time stamp. Overwrites if file exists.
    fn logToFile(self: Match, _file_name: ?[]const u8) !void {
        const file_name = try self.allocator.dupe(
            u8,
            _file_name orelse blk: {
                const current_time = c.time(0);
                const name = std.mem.span(c.asctime(c.localtime(&current_time)));
                break :blk name[0 .. name.len - 1];
            },
        );
        defer self.allocator.free(file_name);

        std.mem.replaceScalar(u8, file_name, ' ', '_');
        const full_name = try std.mem.concat(
            self.allocator,
            u8,
            &.{
                self.mazer_client.name,
                "_vs_",
                self.gamer_client.name,
                "_",
                file_name,
                ".mg25",
            },
        );
        defer self.allocator.free(full_name);
        const log_dir = try std.fs.cwd().makeOpenPath("logs", .{});
        const file = try log_dir.createFile(full_name, .{});
        defer file.close();
        self.evaluator.logToFile(file) catch |err| {
            std.debug.print("Log to file failed: {}\n", .{err});
        };
    }
    fn requestMaze(self: *Match) !void {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();
        try self.mazer_client.writeMessage(Client.REQUEST_MAZE_PROTOCOL);
        try self.mazer_client.writeJSON(try GameLib.getJSONFromGame(
            self.game,
            arena_allocator,
        ));
        const json_game_received = try self.mazer_client.*.getNextJSONTimed(
            arena_allocator,
            GameLib.GameJSON,
            null,
        );
        const new_game = try GameLib.getGameFromJSON(
            json_game_received,
            arena_allocator,
        );
        if (new_game.board.width != self.game.board.width or
            new_game.board.height != self.game.board.height)
        {
            std.debug.print("Invalid maze size\n", .{});
            return MatchError.InvalidMaze;
        }
        const check_result = try Checker.checkEligible(self.game, new_game, .{});
        if (check_result != .Valid) {
            std.debug.print("Maze check failed with status: {}\n", .{check_result});
            return MatchError.InvalidMaze;
        }
        // This ensures that board is still owned by the game arena allocator
        try self.game.applyChanges(new_game);
        std.debug.print("Maze received\n", .{});
    }
    pub fn init(allocator: std.mem.Allocator, mazer_client: *Client, gamer_client: *Client) !Match {
        return Match{
            .allocator = allocator,
            .mazer_client = mazer_client,
            .gamer_client = gamer_client,
            .game = try GameLib.Game.init(
                allocator,
                .{},
                null,
                null,
                try Items.genItemList(&.{"Bomb"}, allocator),
            ),
            .evaluator = undefined, // will be initialized in start
        };
    }

    fn start(self: *Match) !void {
        std.debug.print("Match started with {s}\n", .{self.mazer_client.name});
        self.requestMaze() catch |err| {
            std.debug.print("Request maze failed: {}\n", .{err});
            return self.messageFinished(1.0);
        };
        self.evaluator = try Evaluator.init(
            self.allocator,
            self.game,
        );
        try self.gamer_client.writeMessage(Client.PREPARE_SOLVER_PROTOCOL);
        for (0..MAX_TURN_COUNT) |_| {
            if (self.game.isFinished()) {
                break;
            }
            var limited_vision_game = try GameLib.getGameWithLimitedVision(
                self.game,
                self.allocator,
            );
            defer limited_vision_game.deinit();
            try self.gamer_client.writeMessage(Client.REQUEST_MOVE_PROTOCOL);
            try self.gamer_client.writeJSON(try GameLib.getJSONFromGame(
                limited_vision_game,
                self.allocator,
            ));
            const move_recieved = self.gamer_client.*.getNextJSONTimed(
                self.allocator,
                GameLib.GameTurn,
                null,
            ) catch |err| {
                std.debug.print("Read move failed: {}\n", .{err});
                return self.messageFinished(0.0);
            };
            self.game.doTurn(move_recieved) catch |err| {
                std.debug.print("Move failed: {}\n", .{err});
                return self.messageFinished(0.0);
            };
            try self.evaluator.addTurn(limited_vision_game, move_recieved);
        }
        try self.gamer_client.writeMessage("Game finished");
        try self.mazer_client.writeMessage("Game finished");
        if (self.game.isFinished()) {
            return self.messageFinished(try self.evaluator.calculateScore());
        } else {
            return self.messageFinished(0.0);
        }
    }

    fn deinit(self: *Match) void {
        self.game.deinit();
        self.evaluator.deinit();
    }
};

/// A series of matches between two clients. Does not need to deinit.
pub const Series = struct {
    allocator: std.mem.Allocator,
    client_1: *Client,
    client_2: *Client,
    const ROUND_COUNT = 3;
    pub fn init(allocator: std.mem.Allocator, client_1: Connection, client_2: Connection) !Series {
        const new_client_1 = try allocator.create(Client);
        const new_client_2 = try allocator.create(Client);
        new_client_1.* = Client.init(
            allocator,
            client_1.stream,
            .{},
            "mazer",
        );
        new_client_2.* = Client.init(
            allocator,
            client_2.stream,
            .{},
            "gamer",
        );
        var new_series = Series{
            .allocator = allocator,
            .client_1 = new_client_1,
            .client_2 = new_client_2,
        };
        try new_series.client_1.start();
        try new_series.client_2.start();
        return new_series;
    }
    pub fn start(self: *Series) !void {
        try self.client_1.writeMessage("Series start");
        try self.client_2.writeMessage("Series start");
        std.debug.print("Series started\n", .{});
        for (0..ROUND_COUNT) |_| {
            var match = try Match.init(
                self.allocator,
                self.client_1,
                self.client_2,
            );
            try match.start();
        }
        for (0..ROUND_COUNT) |_| {
            var match = try Match.init(
                self.allocator,
                self.client_2,
                self.client_1,
            );
            try match.start();
        }
        if (self.client_1.score > self.client_2.score) {
            try self.client_1.writeMessage("Series win");
            try self.client_2.writeMessage("Series lose");
        } else if (self.client_1.score < self.client_2.score) {
            try self.client_1.writeMessage("Series lose");
            try self.client_2.writeMessage("Series win");
        } else {
            try self.client_1.writeMessage("Series draw");
            try self.client_2.writeMessage("Series draw");
        }
    }
    pub fn deinit(self: Series) void {
        self.client_1.deinit() catch |err| {
            std.debug.print("Client 1 deinit failed: {}\n", .{err});
        };
        self.client_2.deinit() catch |err| {
            std.debug.print("Client 2 deinit failed: {}\n", .{err});
        };
        self.allocator.destroy(self.client_1);
        self.allocator.destroy(self.client_2);
    }
};
