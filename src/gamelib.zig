const std = @import("std");
const ItemLib = @import("item.zig");
const Queue = @import("queue.zig").Queue;
pub const Vec2 = @Vector(2, isize);
const expect = std.testing.expect;

const Direction = enum {
    Up,
    Down,
    Left,
    Right,
    const list = [_]Direction{ Direction.Up, Direction.Down, Direction.Left, Direction.Right };
    fn getVec2(direction: Direction) Vec2 {
        return switch (direction) {
            Direction.Up => Vec2{ -1, 0 },
            Direction.Down => Vec2{ 1, 0 },
            Direction.Left => Vec2{ 0, -1 },
            Direction.Right => Vec2{ 0, 1 },
        };
    }
};
pub const WallType = enum {
    VisibleWall,
    NoWall,
    NotVisivle,
    LuminatedWall,
    BorderWall,

    pub fn isWall(wall: WallType) bool {
        return switch (wall) {
            WallType.VisibleWall => true,
            WallType.NoWall => false,
            WallType.NotVisivle => false,
            WallType.LuminatedWall => true,
            WallType.BorderWall => true,
        };
    }
};

fn checkInboundArr2d(comptime T: type, arr: [][]T, position: Vec2) bool {
    return 0 <= position[0] and position[0] < arr.len and 0 <= position[1] and position[1] < arr[0].len;
}

fn setArr2d(comptime T: type, arr: [][]T, value: T, position: Vec2) !void {
    if (!checkInboundArr2d(T, arr, position)) {
        return error.OutOfBound;
    }
    arr[@intCast(position[0])][@intCast(position[1])] = value;
}

fn getArr2d(comptime T: type, arr: [][]T, position: Vec2) !T {
    if (!checkInboundArr2d(T, arr, position)) {
        return error.OutOfBound;
    }
    return arr[@intCast(position[0])][@intCast(position[1])];
}

pub const MazeBoard = struct {
    height: usize,
    width: usize,
    vertical_walls: [][]WallType,
    horizontal_walls: [][]WallType,
    buffer_board: [][]i32,
    item_board: [][]?[]const u8,
    /// Default maze has border wall only
    pub fn init(arena: std.mem.Allocator, height: usize, width: usize) !MazeBoard {
        const vertical_walls = try arena.alloc([]WallType, height);
        for (vertical_walls) |*rows| {
            rows.* = try arena.alloc(WallType, width + 1);
            @memset(rows.*, WallType.NoWall);
            rows.*[0] = WallType.BorderWall;
            rows.*[width] = WallType.BorderWall;
        }

        const horizontal_walls = try arena.alloc([]WallType, height + 1);
        for (horizontal_walls) |*rows| {
            rows.* = try arena.alloc(WallType, width);
            @memset(rows.*, WallType.NoWall);
        }
        @memset(horizontal_walls[0], WallType.BorderWall);
        @memset(horizontal_walls[height], WallType.BorderWall);

        const buffer_board = try arena.alloc([]i32, height);
        for (buffer_board) |*rows| {
            rows.* = try arena.alloc(i32, width);
            @memset(rows.*, 0);
        }

        const item_board = try arena.alloc([]?[]const u8, height);
        for (item_board) |*rows| {
            rows.* = try arena.alloc(?[]const u8, width);
            @memset(rows.*, null);
        }

        return MazeBoard{
            .height = height,
            .width = width,
            .vertical_walls = vertical_walls,
            .horizontal_walls = horizontal_walls,
            .buffer_board = buffer_board,
            .item_board = item_board,
        };
    }

    pub fn checkInbound(mazeboard: MazeBoard, position: Vec2) bool {
        return checkInboundArr2d(i32, mazeboard.buffer_board, position);
    }
    pub fn checkInboundVerticalWall(mazeboard: MazeBoard, position: Vec2) bool {
        return checkInboundArr2d(WallType, mazeboard.vertical_walls, position);
    }
    pub fn checkInboundHorizontalWall(mazeboard: MazeBoard, position: Vec2) bool {
        return checkInboundArr2d(WallType, mazeboard.horizontal_walls, position);
    }

    fn setAllBuffer(mazeboard: MazeBoard, value: i32) void {
        for (mazeboard.buffer_board) |*rows| {
            for (rows.*) |*cell| {
                cell.* = value;
            }
        }
    }

    pub fn setVerticalWall(mazeboard: MazeBoard, position: Vec2, wall_value: WallType) !void {
        return setArr2d(WallType, mazeboard.vertical_walls, wall_value, position);
    }
    pub fn getVerticalWall(mazeboard: MazeBoard, position: Vec2) !WallType {
        return getArr2d(WallType, mazeboard.vertical_walls, position);
    }
    pub fn setHorizontalWall(mazeboard: MazeBoard, position: Vec2, wall_value: WallType) !void {
        return setArr2d(WallType, mazeboard.horizontal_walls, wall_value, position);
    }
    pub fn getHorizontalWall(mazeboard: MazeBoard, position: Vec2) !WallType {
        return getArr2d(WallType, mazeboard.horizontal_walls, position);
    }
    pub fn setBufferValue(mazeboard: MazeBoard, position: Vec2, value: i32) !void {
        return setArr2d(i32, mazeboard.buffer_board, value, position);
    }
    pub fn getBufferValue(mazeboard: MazeBoard, position: Vec2) !i32 {
        return getArr2d(i32, mazeboard.buffer_board, position);
    }
};

pub const Game = struct {
    board: MazeBoard,
    position: Vec2,
    item_list: []Item,
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    /// Default height and width is 10
    const MazeOptions = struct {
        height: usize = 10,
        width: usize = 10,
        board: ?MazeBoard = null,
    };
    /// item_list is copied
    pub fn init(
        allocator: std.mem.Allocator,
        maze_options: MazeOptions,
        start_position: ?Vec2,
        item_list: []const Item,
    ) !Game {
        const new_board = maze_options.board orelse try MazeBoard.init(
            allocator,
            maze_options.height,
            maze_options.width,
        );
        const new_position = start_position orelse Vec2{ 0, 0 };
        if (!new_board.checkInbound(new_position)) {
            return error.StartPositionOutOfBound;
        }
        return Game{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .allocator = allocator,
            .board = new_board,
            .position = new_position,
            .item_list = try allocator.dupe(Item, item_list),
        };
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
        return game.getWallRelTile(game.current_position, direction).isWall() == false;
    }
    pub fn move(game: *Game, direction: Direction) !void {
        try game.setPosition(game.position + direction.getVec2());
    }
    pub fn setVerticalWall(game: *Game, position: Vec2, wall_value: WallType) !void {
        try game.board.setVerticalWall(position, wall_value);
    }
    pub fn setHorizontalWall(game: *Game, position: Vec2, wall_value: WallType) !void {
        try game.board.setHorizontalWall(position, wall_value);
    }

    const CheckStatus = enum {
        Valid,
        CanGoOutside,
        NotConnected,
    };
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
    pub fn deit(self: *Game) void {
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
        item_list,
    );
}
pub const GameJSON = struct {
    board: MazeBoard,
    position: Vec2,
    item_list: [][]u8,
};

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
