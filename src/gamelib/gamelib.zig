const std = @import("std");
const Queue = @import("queue.zig").Queue;
const expect = std.testing.expect;

pub const ItemLib = @import("item.zig");
pub const MazeBoard = @import("mazeboard.zig").MazeBoard;
pub const Utils = @import("utils.zig");
pub const WallType = Utils.WallType;
pub const Vec2 = Utils.Vec2;
pub const Direction = Utils.Direction;
pub const Client = @import("netclient.zig").Client;

const GameRule = struct {
    item_min_count: usize = 0,
    predetermined_item_position: bool = false,
};

const CheckStatus = enum {
    Valid,
    CanGoOutside,
    NotConnected,
    StartPositionOutOfBound,
    EndPositionOutOfBound,
    InvalidSize,
    ItemNotFound,
    InvalidItem,
    NotEnoughItem,
};

pub const Game = struct {
    board: MazeBoard,
    position: Vec2,
    end_position: Vec2,
    item_list: []Item,
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    /// Default height and width is 10
    const MazeOptions = struct {
        height: usize = 10,
        width: usize = 10,
        board: ?MazeBoard = null,
    };
    /// item_list and board is copied
    pub fn init(
        allocator: std.mem.Allocator,
        maze_options: MazeOptions,
        start_position: ?Vec2,
        end_position: ?Vec2,
        item_list: []const Item,
    ) !Game {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const temp_allocator = arena.allocator();
        const new_board = blk: {
            if (maze_options.board) |board| {
                break :blk try board.deepCopy(temp_allocator);
            }
            break :blk try MazeBoard.init(
                temp_allocator,
                maze_options.height,
                maze_options.width,
            );
        };
        const new_game = Game{
            .arena = arena,
            .allocator = allocator,
            .board = new_board,
            .position = start_position orelse Vec2{ 0, 0 },
            .end_position = end_position orelse Vec2{
                @intCast(new_board.height - 1),
                @intCast(new_board.width - 1),
            },
            .item_list = try allocator.dupe(Item, item_list),
        };
        if (!new_game.board.checkInbound(new_game.position)) {
            return error.StartPositionOutOfBound;
        }
        if (!new_game.board.checkInbound(new_game.end_position)) {
            return error.EndPositionOutOfBound;
        }
        return new_game;
    }
    pub fn setPosition(game: *Game, position: Vec2) !void {
        if (!game.board.checkInbound(position)) {
            return error.PositionOutOfBound;
        }
        game.position = position;
    }
    /// Get wall type in the direction relative to the position
    pub fn getWallRelTile(game: Game, position: Vec2, direction: Direction) WallType {
        const next_position = position + direction.getVec2();
        return switch (direction) {
            .Up => game.board.getHorizontalWall(position) catch unreachable,
            .Down => game.board.getHorizontalWall(next_position) catch unreachable,
            .Left => game.board.getVerticalWall(position) catch unreachable,
            .Right => game.board.getVerticalWall(next_position) catch unreachable,
        };
    }
    pub fn isMoveValid(game: Game, direction: Direction) bool {
        return game.getWallRelTile(game.position, direction).isWall() == false;
    }
    pub fn move(game: *Game, direction: Direction) !void {
        if (!game.isMoveValid(direction)) {
            return error.InvalidMove;
        }
        try game.setPosition(game.position + direction.getVec2());
    }
    pub fn setVerticalWall(game: *Game, position: Vec2, wall_value: WallType) !void {
        try game.board.setVerticalWall(position, wall_value);
    }
    pub fn setHorizontalWall(game: *Game, position: Vec2, wall_value: WallType) !void {
        try game.board.setHorizontalWall(position, wall_value);
    }
    /// All border must be wall
    /// All tiles should be connected
    pub fn check(game: Game) error{OutOfMemory}!CheckStatus {
        var queue = try Queue(Vec2).init(
            game.allocator,
            game.board.height * game.board.width,
        );
        defer queue.deinit();
        game.board.setAllBuffer(-1);
        queue.push(game.position) catch unreachable;
        game.board.setBufferValue(game.position, 0) catch unreachable;
        while (queue.front < queue.back) {
            const current_position = queue.pop() catch unreachable;
            const current_value = game.board.getBufferValue(current_position) catch unreachable;
            for (Direction.list) |direction| {
                const next_position = current_position + direction.getVec2();
                const wall = game.getWallRelTile(current_position, direction);
                if (wall.isWall()) {
                    continue;
                }
                if (!game.board.checkInbound(next_position)) {
                    return .CanGoOutside;
                }
                if (game.board.getBufferValue(next_position) catch unreachable != -1) {
                    continue;
                }
                game.board.setBufferValue(next_position, current_value + 1) catch unreachable;
                queue.push(next_position) catch unreachable;
            }
        }
        if (queue.back == game.board.height * game.board.width) {
            return .Valid;
        } else {
            return .NotConnected;
        }
    }
    pub fn isFinished(game: Game) bool {
        return game.position[0] == game.end_position[0] and game.position[1] == game.end_position[1];
    }
    pub fn findItem(game: Game, item_name: []const u8) ?Item {
        for (game.item_list) |item| {
            if (std.mem.eql(u8, item.name, item_name)) {
                return item;
            }
        }
        return null;
    }
    pub fn checkEligible(game: Game, edited_game: Game, game_rule: GameRule) !CheckStatus {
        if (game.board.height != edited_game.board.height or
            game.board.width != edited_game.board.width)
        {
            return .InvalidSize;
        }
        if (!edited_game.board.checkConsistentSize()) {
            return .InvalidSize;
        }
        if (edited_game.board.checkInbound(edited_game.position) == false) {
            return .StartPositionOutOfBound;
        }
        if (edited_game.board.checkInbound(edited_game.end_position) == false) {
            return .EndPositionOutOfBound;
        }
        const bfs_check = try edited_game.check();
        if (bfs_check != .Valid) {
            return bfs_check;
        }
        // check for any item not in item list
        for (edited_game.board.item_board) |row| {
            for (row) |item| {
                if (item) |item_name| {
                    const item_ptr = game.findItem(item_name);
                    if (item_ptr == null) {
                        return .ItemNotFound;
                    }
                }
            }
        }
        // check if any item was edited
        if (game_rule.predetermined_item_position) {
            for (edited_game.board.item_board, game.board.item_board) |edited_row, row| {
                for (edited_row, row) |edited_item, item| {
                    if (!Utils.optionalStrEql(edited_item, item)) {
                        return .InvalidItem;
                    }
                }
            }
        }
        // check if there are enough items
        for (game.item_list) |item| {
            var count: usize = 0;
            for (edited_game.board.item_board) |row| {
                for (row) |edited_item| {
                    if (Utils.optionalStrEql(edited_item, item.name)) {
                        count += 1;
                    }
                }
            }
            if (count < game_rule.item_min_count) {
                return .NotEnoughItem;
            }
        }
        return .Valid;
    }
    pub fn deinit(self: *Game) void {
        self.arena.deinit();
        self.allocator.free(self.item_list);
    }
};

/// Caller owns the game_json
pub fn getJSONFromGame(game: Game, arena: std.mem.Allocator) !GameJSON {
    const item_list = try arena.alloc([]u8, game.item_list.len);
    for (item_list, game.item_list) |*item_json, item| {
        item_json.* = try item.jsonStringify(arena);
    }
    return GameJSON{
        .board = game.board,
        .position = game.position,
        .end_position = game.end_position,
        .item_list = item_list,
    };
}

/// Caller owns the game
pub fn getGameFromJSON(game_json: GameJSON, allocator: std.mem.Allocator) !Game {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    const item_list = try allocator.alloc(Item, game_json.item_list.len);
    for (item_list, game_json.item_list) |*item, item_json| {
        item.* = try ItemLib.jsonToItem(item_json, arena_allocator);
    }
    return try Game.init(
        allocator,
        Game.MazeOptions{ .board = game_json.board },
        game_json.position,
        game_json.end_position,
        item_list,
    );
}
pub const GameJSON = struct {
    board: MazeBoard,
    position: Vec2,
    end_position: Vec2,
    item_list: [][]u8,
};

/// Caller owns the game
pub fn getGameWithLimitedVision(
    game: Game,
    allocator: std.mem.Allocator,
) !Game {
    const new_game = try Game.init(
        allocator,
        .{ .board = game.board },
        game.position,
        game.end_position,
        game.item_list,
    );
    new_game.board.limitVision(game.position);
    return new_game;
}

pub const Item = struct {
    ptr: *anyopaque,
    name: []const u8,
    impl: *const Impl,
    pub const ItemError = error{
        FailedApply,
    };
    pub const Impl = struct {
        pick_up: *const fn (*anyopaque) void,
        apply: *const fn (*anyopaque, *Game) void,
        json_stringify: *const fn (*anyopaque, std.mem.Allocator) error{OutOfMemory}![]u8,
    };
    pub fn pickUp(self: Item) void {
        self.impl.pick_up(self.ptr);
    }
    pub fn apply(self: Item, game: *Game) void {
        self.impl.apply(self.ptr, game);
    }
    pub fn jsonStringify(self: Item, allocator: std.mem.Allocator) error{OutOfMemory}![]u8 {
        return self.impl.json_stringify(self.ptr, allocator);
    }
};

test "ConvertGameToJson" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();
    var game = try Game.init(
        allocator,
        Game.MazeOptions{ .height = 10, .width = 10 },
        null,
        null,
        &.{try ItemLib.Bomb.newItem(allocator)},
    );
    try game.setHorizontalWall(.{ 1, 1 }, .BorderWall);
    try expect(game.item_list.len == 1);
    try expect(std.mem.eql(u8, game.item_list[0].name, "Bomb"));
    const game_json = try getJSONFromGame(game, allocator);
    const new_game = try getGameFromJSON(game_json, allocator);
    try expect(new_game.board.height == 10);
    try expect(new_game.board.width == 10);
    try expect(try new_game.board.getHorizontalWall(.{ 1, 1 }) == WallType.BorderWall);
    try expect(try new_game.check() == .Valid);
}

test "LimitVision" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();
    var game = try Game.init(
        allocator,
        .{ .height = 3, .width = 3 },
        .{ 1, 1 },
        null,
        &.{},
    );
    try game.setVerticalWall(.{ 0, 1 }, .VisibleWall);
    try game.setVerticalWall(.{ 2, 1 }, .VisibleWall);
    try game.setVerticalWall(.{ 0, 2 }, .VisibleWall);
    try game.setVerticalWall(.{ 2, 2 }, .VisibleWall);
    try game.setHorizontalWall(.{ 1, 1 }, .VisibleWall);
    var limited_vision_game = try getGameWithLimitedVision(game, allocator);
    try expect(try limited_vision_game.board.getVerticalWall(.{ 0, 1 }) == WallType.NotVisivle);
    try expect(try limited_vision_game.board.getVerticalWall(.{ 2, 1 }) == WallType.VisibleWall);
    try expect(try limited_vision_game.board.getHorizontalWall(.{ 1, 1 }) == WallType.VisibleWall);
    try game.setHorizontalWall(.{ 1, 1 }, .NoWall);
    limited_vision_game = try getGameWithLimitedVision(game, allocator);
    try expect(try limited_vision_game.board.getVerticalWall(.{ 0, 1 }) == WallType.VisibleWall);
}
