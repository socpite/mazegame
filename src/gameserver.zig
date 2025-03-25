const std = @import("std");
const GameLib = @import("gamelib.zig");
const Items = @import("item.zig");
const Self = @This();
const Connection = std.net.Server.Connection;
const Client = @import("netclient.zig").Client;

const Match = struct {
    game: GameLib.Game,
    mazer_client: *Client,
    gamer_client: *Client,
    allocator: std.mem.Allocator,
    const MatchError = error{
        InvalidMaze,
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
        const json_game_received = try self.mazer_client.readJSON(
            arena_allocator,
            GameLib.GameJSON,
        );
        self.game = try GameLib.getGameFromJSON(json_game_received, self.allocator);
        const check_result = try self.game.check();
        if (check_result != .Valid) {
            std.debug.print("Maze check failed with status: {}\n", .{check_result});
            return MatchError.InvalidMaze;
        }
    }
    pub fn init(allocator: std.mem.Allocator, mazer_client: *Client, gamer_client: *Client) !Match {
        return Match{
            .allocator = allocator,
            .mazer_client = mazer_client,
            .gamer_client = gamer_client,
            .game = try GameLib.Game.init(
                allocator,
                .{},
                GameLib.Vec2{ 0, 0 },
                try Items.genItemList(&.{"Bomb"}, allocator),
            ),
        };
    }
    fn start(self: *Match) !void {
        var result = MatchResult.MazerWin;
        self.requestMaze() catch |err| {
            std.debug.print("Request maze failed: {}\n", .{err});
            result = MatchResult.GamerWin;
        };
        return self.messageFinished(result);
    }
    fn deinit(self: *Match) void {
        self.game.deinit();
    }
};

/// A series of matches between two clients. Does not need to deinit.
pub const Series = struct {
    allocator: std.mem.Allocator,
    client_1: Client,
    client_2: Client,
    const ROUND_COUNT = 12;
    pub fn init(allocator: std.mem.Allocator, client_1: Connection, client_2: Connection) !Series {
        return Series{
            .allocator = allocator,
            .client_1 = Client{ .stream = client_1.stream },
            .client_2 = Client{ .stream = client_2.stream },
        };
    }
    pub fn start(self: *Series) !void {
        for (0..ROUND_COUNT) |_| {
            var match = try Match.init(
                self.allocator,
                &self.client_1,
                &self.client_2,
            );
            try match.start();
        }
        for (0..ROUND_COUNT) |_| {
            var match = try Match.init(
                self.allocator,
                &self.client_2,
                &self.client_1,
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
};
