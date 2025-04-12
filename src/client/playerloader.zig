const std = @import("std");
const Gamelib = @import("gamelib");

const CGame = opaque {};
const CMove = opaque {};

var c_create_game: *const fn (c_int, c_int) callconv(.c) *CGame = undefined;
var c_set_start_pos: *const fn (*CGame, c_int, c_int) callconv(.c) void = undefined;
var c_add_item_type: *const fn (*CGame, [*:0]const u8) callconv(.c) void = undefined;
var c_set_horizontal_wall: *const fn (*CGame, c_int, c_int) callconv(.c) void = undefined;
var c_set_vertical_wall: *const fn (*CGame, c_int, c_int) callconv(.c) void = undefined;
var c_set_item: *const fn (*CGame, c_int, c_int, [*:0]const u8) callconv(.c) void = undefined;
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
    c_get_item = try loadSymbol(@TypeOf(c_get_item), &lib, "get_item");
    c_get_item_name = try loadSymbol(@TypeOf(c_get_item_name), &lib, "get_item_name");
    c_get_move_type = try loadSymbol(@TypeOf(c_get_move_type), &lib, "get_move_type");
    c_get_move = try loadSymbol(@TypeOf(c_get_move), &lib, "get_move");
    c_get_maze = try loadSymbol(@TypeOf(c_get_maze), &lib, "get_maze");
    c_get_start_pos = try loadSymbol(@TypeOf(c_get_start_pos), &lib, "get_start_pos");
    c_get_horizontal_wall = try loadSymbol(@TypeOf(c_get_horizontal_wall), &lib, "get_horizontal_wall");
    c_get_vertical_wall = try loadSymbol(@TypeOf(c_get_vertical_wall), &lib, "get_vertical_wall");
}
