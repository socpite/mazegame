const std = @import("std");
const Gamelib = @import("gamelib");
const CGame = anyopaque;
const CMove = anyopaque;

var c_create_game: *const fn (c_int, c_int) callconv(.c) *CGame = undefined;
var c_set_start_pos: *const fn (*anyopaque, c_int, c_int) callconv(.c) void = undefined;
var c_add_item_type: *const fn (*CGame, [*:0]const u8) callconv(.c) void = undefined;
var c_set_horizontal_wall: *const fn (*CGame, c_int, c_int, bool) callconv(.c) void = undefined;
var c_set_vertical_wall: *const fn (*CGame, c_int, c_int, bool) callconv(.c) void = undefined;
var c_set_item: *const fn (*CGame, c_int, c_int, [*:0]const u8) callconv(.c) void = undefined;
var c_set_end_pos: *const fn (*CGame, c_int, c_int) callconv(.c) void = undefined;

var c_get_width: *const fn (*CGame) callconv(.c) c_int = undefined;
var c_get_height: *const fn (*CGame) callconv(.c) c_int = undefined;
var c_get_end_pos: *const fn (*CGame) callconv(.c) [*]c_int = undefined;
var c_get_item: *const fn (*CGame, c_int, c_int) callconv(.c) [*:0]const u8 = undefined;
var c_get_item_name: *const fn (*CMove) callconv(.c) [*:0]const u8 = undefined;
var c_get_move_type: *const fn (*CMove) callconv(.c) [*:0]u8 = undefined;
var c_get_move: *const fn (*CGame) callconv(.c) *CMove = undefined;
var c_get_maze: *const fn (*CGame) callconv(.c) *CGame = undefined;
var c_get_start_pos: *const fn (*CGame) callconv(.c) [*]c_int = undefined;
var c_get_horizontal_wall: *const fn (*CGame, c_int, c_int) callconv(.c) bool = undefined;
var c_get_vertical_wall: *const fn (*CGame, c_int, c_int) callconv(.c) bool = undefined;

fn loadSymbol(
    comptime T: type,
    lib: *std.DynLib,
    name: [:0]const u8,
) !T {
    const sym = lib.lookup(T, name) orelse {
        std.debug.print("Failed to load symbol: {s}\n", .{name});
        return error.SymbolNotFound;
    };
    return sym;
}

pub fn loadLibrary(filename: []const u8) !void {
    var lib = try std.DynLib.open(filename);
    defer lib.close();

    c_create_game = try loadSymbol(@TypeOf(c_create_game), &lib, "create_game");
    c_set_start_pos = try loadSymbol(@TypeOf(c_set_start_pos), &lib, "set_start_pos");
    c_add_item_type = try loadSymbol(@TypeOf(c_add_item_type), &lib, "add_item_type");
    c_set_horizontal_wall = try loadSymbol(@TypeOf(c_set_horizontal_wall), &lib, "set_horizontal_wall");
    c_set_vertical_wall = try loadSymbol(@TypeOf(c_set_vertical_wall), &lib, "set_vertical_wall");
    c_set_item = try loadSymbol(@TypeOf(c_set_item), &lib, "set_item");
    c_set_end_pos = try loadSymbol(@TypeOf(c_set_end_pos), &lib, "set_end_pos");

    c_get_width = try loadSymbol(@TypeOf(c_get_width), &lib, "get_width");
    c_get_height = try loadSymbol(@TypeOf(c_get_height), &lib, "get_height");
    c_get_end_pos = try loadSymbol(@TypeOf(c_get_end_pos), &lib, "get_end_pos");
    c_get_item = try loadSymbol(@TypeOf(c_get_item), &lib, "get_item");
    c_get_item_name = try loadSymbol(@TypeOf(c_get_item_name), &lib, "get_item_name");
    c_get_move_type = try loadSymbol(@TypeOf(c_get_move_type), &lib, "get_move_type");
    c_get_move = try loadSymbol(@TypeOf(c_get_move), &lib, "get_move");
    c_get_maze = try loadSymbol(@TypeOf(c_get_maze), &lib, "get_maze");
    c_get_start_pos = try loadSymbol(@TypeOf(c_get_start_pos), &lib, "get_start_pos");
    c_get_horizontal_wall = try loadSymbol(@TypeOf(c_get_horizontal_wall), &lib, "get_horizontal_wall");
    c_get_vertical_wall = try loadSymbol(@TypeOf(c_get_vertical_wall), &lib, "get_vertical_wall");
}

fn GameToCGame(game: Gamelib.Game) !*CGame {
    const c_game = c_create_game(@intCast(game.board.height), @intCast(game.board.width));
    c_set_start_pos(c_game, @intCast(game.position[0]), @intCast(game.position[1]));
    c_set_end_pos(c_game, @intCast(game.end_position[0]), @intCast(game.end_position[1]));
    var arena = std.heap.ArenaAllocator.init(game.allocator);
    const temp_allocator = arena.allocator();
    defer arena.deinit();

    for (game.item_list) |item| {
        c_add_item_type(c_game, try temp_allocator.dupeZ(u8, item.name));
    }

    for (game.board.horizontal_walls[1..game.board.height], 0..) |row, i| {
        for (row, 0..) |wall, j| {
            c_set_horizontal_wall(c_game, @intCast(i), @intCast(j), wall.isWall());
        }
    }

    for (game.board.vertical_walls, 0..) |row, i| {
        for (row[1..game.board.width], 0..) |wall, j| {
            c_set_vertical_wall(c_game, @intCast(i), @intCast(j), wall.isWall());
        }
    }

    for (game.board.item_board, 0..) |row, i| {
        for (row, 0..) |item, j| {
            if (item != null) {
                c_set_item(c_game, @intCast(i), @intCast(j), try temp_allocator.dupeZ(u8, item.?));
            }
        }
    }

    return c_game;
}

// Item list should not be modified. Therefore it is irrelevant what the CGame item list is.
fn CGameToGame(allocator: std.mem.Allocator, c_game: *CGame, item_list: []Gamelib.Item) !Gamelib.Game {
    const start_pos = c_get_start_pos(c_game);
    const end_pos = c_get_end_pos(c_game);
    const width: usize = @intCast(c_get_width(c_game));
    const height: usize = @intCast(c_get_height(c_game));
    var game = try Gamelib.Game.init(
        allocator,
        .{ .width = @intCast(width), .height = @intCast(height) },
        Gamelib.Vec2{ start_pos[0], start_pos[1] },
        Gamelib.Vec2{ end_pos[0], end_pos[1] },
        item_list,
    );

    for (0..height) |i| {
        for (1..width - 1) |j| {
            if (c_get_vertical_wall(c_game, @intCast(i), @intCast(j - 1))) {
                game.setVerticalWall(.{ @intCast(i), @intCast(j) }, .VisibleWall) catch unreachable;
            }
        }
    }
    for (1..height - 1) |i| {
        for (0..width) |j| {
            if (c_get_horizontal_wall(c_game, @intCast(i - 1), @intCast(j))) {
                game.setHorizontalWall(.{ @intCast(i), @intCast(j) }, .VisibleWall) catch unreachable;
            }
        }
    }
    for (0..height) |i| {
        for (0..width) |j| {
            const item_name = std.mem.span(c_get_item(c_game, @intCast(i), @intCast(j)));
            if (item_name.len > 0) {
                try game.setItem(item_name, .{ @intCast(i), @intCast(j) });
            }
        }
    }
    return game;
}

pub fn getGame(allocator: std.mem.Allocator, game: Gamelib.Game) !Gamelib.Game {
    const c_game = try GameToCGame(game);
    const c_game_new = c_get_maze(c_game);
    return try CGameToGame(
        allocator,
        c_game_new,
        game.item_list,
    );
}

pub fn CGameMoveToGameTurn(c_move: *CMove) Gamelib.GameTurn {
    const move_type = std.mem.span(c_get_move_type(c_move));
    if (std.mem.eql(u8, move_type, "item")) {
        return .{ .item_name = std.mem.span(c_get_item_name(c_move)) };
    }
    return .{ .direction = std.meta.stringToEnum(Gamelib.Direction, move_type).? };
}

pub fn getMove(game: Gamelib.Game) !Gamelib.GameTurn {
    const c_game = try GameToCGame(game);
    const c_move = c_get_move(c_game);
    return CGameMoveToGameTurn(c_move);
}

test "Convert Game to CGame" {
    const allocator = std.testing.allocator;
    try loadLibrary("src/example/mylib.so");
    var game = try Gamelib.Game.init(
        allocator,
        .{ .width = 5, .height = 5 },
        Gamelib.Vec2{ 1, 1 },
        Gamelib.Vec2{ 3, 3 },
        &.{},
    );
    defer game.deinit();
    game.setHorizontalWall(.{ 1, 1 }, .VisibleWall) catch unreachable;
    const c_game = try GameToCGame(game);
    try std.testing.expect(c_get_horizontal_wall(c_game, 0, 1));

    var new_game = try CGameToGame(allocator, c_game, game.item_list);
    defer new_game.deinit();
    try std.testing.expect(try new_game.board.getHorizontalWall(.{ 1, 1 }) == .VisibleWall);
}

test "Get a move" {
    const allocator = std.testing.allocator;
    try loadLibrary("src/example/mylib.so");
    var game = try Gamelib.Game.init(
        allocator,
        .{ .width = 5, .height = 5 },
        Gamelib.Vec2{ 1, 1 },
        Gamelib.Vec2{ 3, 3 },
        &.{},
    );
    defer game.deinit();
    game.setHorizontalWall(.{ 1, 1 }, .VisibleWall) catch unreachable;
    const move = try getMove(game);
    try std.testing.expect(move.direction == Gamelib.Direction.Down);
}
