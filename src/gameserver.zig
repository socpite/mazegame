const std = @import("std");
const GameLib = @import("gamelib.zig");
const Items = @import("item.zig");
const Self = @This();
const Connection = std.net.Server.Connection;
const Client = @import("netclient.zig").Client;

pub fn genItemList(name_list: []const []const u8, allocator: std.mem.Allocator) ![]GameLib.Item {
    var array = std.ArrayList(GameLib.Item).init(allocator);
    for (name_list) |name| {
        try array.append(try Items.strToItem(name, allocator));
    }
    return try array.toOwnedSlice();
}

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
        try self.mazer_client.writeMessage("Request maze");
        try self.mazer_client.writeJson(try self.game.getGameJSON());
        const json_game_received = try self.mazer_client.readJson(self.allocator, GameLib.GameJSON);
        self.game = try json_game_received.getGame(self.allocator);
        if (!try self.game.check()) {
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
                try genItemList(&.{"Bomb"}, allocator),
            ),
        };
    }
    fn start(self: *Match) !void {
        var result = MatchResult.Error;
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
