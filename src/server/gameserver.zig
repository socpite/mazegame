const std = @import("std");
const GameLib = @import("gamelib");
const Items = GameLib.ItemLib;
const Self = @This();
const Connection = std.net.Server.Connection;
const Client = GameLib.Client;
const Checker = GameLib.Checker;

var gpa1 = std.heap.GeneralPurposeAllocator(.{}){};
var gpa2 = std.heap.GeneralPurposeAllocator(.{}){};

const Match = struct {
    game: GameLib.Game,
    mazer_client: *Client,
    gamer_client: *Client,
    allocator: std.mem.Allocator,
    const MatchError = error{
        InvalidMaze,
        MazerTimeout,
        GamerTimeout,
    };
    const MatchResult = enum {
        Error,
        MazerWin,
        GamerWin,
    };
    fn messageFinished(self: *Match, result: MatchResult) !void {
        switch (result) {
            MatchResult.MazerWin => {
                try self.gamer_client.writeMessage("Mazer win");
                try self.mazer_client.writeMessage("Mazer win");
                self.mazer_client.score += 1;
            },
            MatchResult.GamerWin => {
                try self.gamer_client.writeMessage("Gamer win");
                try self.mazer_client.writeMessage("Gamer win");
                self.gamer_client.score += 1;
            },
            MatchResult.Error => {
                try self.gamer_client.writeMessage("Error");
                try self.mazer_client.writeMessage("Error");
            },
        }
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
        var new_game = try GameLib.getGameFromJSON(
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
        self.game.board = try new_game.board.deepCopy(self.game.arena.allocator());
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
        };
    }
    fn start(self: *Match) !void {
        std.debug.print("Match started with {s}\n", .{self.mazer_client.name});
        self.requestMaze() catch |err| {
            std.debug.print("Request maze failed: {}\n", .{err});
            return self.messageFinished(MatchResult.GamerWin);
        };
        for (0..100) |_| {
            if (self.game.isFinished()) {
                try self.gamer_client.writeMessage("Game finished");
                try self.mazer_client.writeMessage("Game finished");
                return self.messageFinished(MatchResult.GamerWin);
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
                GameLib.Direction,
                null,
            ) catch |err| {
                std.debug.print("Read move failed: {}\n", .{err});
                return self.messageFinished(MatchResult.MazerWin);
            };
            self.game.move(move_recieved) catch |err| {
                std.debug.print("Move failed: {}\n", .{err});
                return self.messageFinished(MatchResult.MazerWin);
            };
        }
        try self.gamer_client.writeMessage("Game finished");
        try self.mazer_client.writeMessage("Game finished");
        if (self.game.isFinished()) {
            return self.messageFinished(MatchResult.GamerWin);
        } else {
            return self.messageFinished(MatchResult.MazerWin);
        }
    }
    fn deinit(self: *Match) void {
        self.game.deinit();
    }
};

/// A series of matches between two clients. Does not need to deinit.
pub const Series = struct {
    allocator: std.mem.Allocator,
    client_1: *Client,
    client_2: *Client,
    const ROUND_COUNT = 12;
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
    pub fn deinit(self: Series) !void {
        try self.client_1.deinit();
        try self.client_2.deinit();
        self.allocator.destroy(self.client_1);
        self.allocator.destroy(self.client_2);
    }
};
