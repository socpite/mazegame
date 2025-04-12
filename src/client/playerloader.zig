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

pub fn loadLibrary(allocator: std.mem.Allocator, filename: []const u8) !*std.DynLib {
    const lib = try allocator.create(std.DynLib);
    lib.* = try std.DynLib.open(filename);

    c_create_game = try loadSymbol(@TypeOf(c_create_game), lib, "create_game");
    c_set_start_pos = try loadSymbol(@TypeOf(c_set_start_pos), lib, "set_start_pos");
    c_add_item_type = try loadSymbol(@TypeOf(c_add_item_type), lib, "add_item_type");
    c_set_horizontal_wall = try loadSymbol(@TypeOf(c_set_horizontal_wall), lib, "set_horizontal_wall");
    c_set_vertical_wall = try loadSymbol(@TypeOf(c_set_vertical_wall), lib, "set_vertical_wall");
    c_set_item = try loadSymbol(@TypeOf(c_set_item), lib, "set_item");
    c_set_end_pos = try loadSymbol(@TypeOf(c_set_end_pos), lib, "set_end_pos");

    c_get_end_pos = try loadSymbol(@TypeOf(c_get_end_pos), lib, "get_end_pos");
    c_get_item = try loadSymbol(@TypeOf(c_get_item), lib, "get_item");
    c_get_item_name = try loadSymbol(@TypeOf(c_get_item_name), lib, "get_item_name");
    c_get_move_type = try loadSymbol(@TypeOf(c_get_move_type), lib, "get_move_type");
    c_get_move = try loadSymbol(@TypeOf(c_get_move), lib, "get_move");
    c_get_maze = try loadSymbol(@TypeOf(c_get_maze), lib, "get_maze");
    c_get_start_pos = try loadSymbol(@TypeOf(c_get_start_pos), lib, "get_start_pos");
    c_get_horizontal_wall = try loadSymbol(@TypeOf(c_get_horizontal_wall), lib, "get_horizontal_wall");
    c_get_vertical_wall = try loadSymbol(@TypeOf(c_get_vertical_wall), lib, "get_vertical_wall");
    return lib;
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

test "Convert Game to CGame" {
    const allocator = std.testing.allocator;
    const lib = try loadLibrary(allocator, "src/example/mylib.so");
    defer allocator.destroy(lib);
    defer lib.close();
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
}
