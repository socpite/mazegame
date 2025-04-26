const std = @import("std");
const GameLib = @import("gamelib.zig");
const Queue = @import("queue.zig").Queue;
const Game = GameLib.Game;
const Vec2 = GameLib.Vec2;
const Direction = GameLib.Direction;
const Utils = GameLib.Utils;

pub const GameRule = struct {
    predetermined_walls: bool = false,
    predetermined_item_position: bool = false,
    min_item_count: usize = 0,
};

const CheckStatus = enum(usize) {
    Valid = 0,
    SameStartEndPosition,
    InvalidWall,
    CanGoOutside,
    NotConnected,
    StartPositionOutOfBound,
    EndPositionOutOfBound,
    InvalidSize,
    ItemNotFound,
    InvalidItem,
    NotEnoughItem,
};

// Uses the game allocator.
pub fn tryBFS(game: Game) error{OutOfMemory}!CheckStatus {
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

// check for any item not in item list
pub fn checkAllItemExist(game: Game, edited_game: Game) bool {
    for (edited_game.board.item_board) |row| {
        for (row) |item| {
            if (item) |item_name| {
                const item_ptr = game.findItem(item_name);
                if (item_ptr == null) {
                    return false;
                }
            }
        }
    }
    return true;
}

// check if both item board is the same
pub fn checkSameItemBoard(game: Game, edited_game: Game) bool {
    for (edited_game.board.item_board, game.board.item_board) |edited_row, row| {
        for (edited_row, row) |edited_item, item| {
            if (!Utils.optionalStrEql(edited_item, item)) {
                return false;
            }
        }
    }
    return true;
}

// check if there are enough items
pub fn checkEnoughItem(game: Game, edited_game: Game, min_item_count: usize) bool {
    for (game.item_list) |item| {
        var count: usize = 0;
        for (edited_game.board.item_board) |row| {
            for (row) |edited_item| {
                if (Utils.optionalStrEql(edited_item, item.name)) {
                    count += 1;
                }
            }
        }
        if (count < min_item_count) {
            return false;
        }
    }
    return true;
}

pub fn checkEligiblieItemBoard(
    game: Game,
    edited_game: Game,
    game_rule: GameRule,
) CheckStatus {
    if (!checkAllItemExist(game, edited_game)) {
        return .ItemNotFound;
    }
    if (game_rule.predetermined_item_position) {
        if (!checkSameItemBoard(game, edited_game)) {
            std.debug.print("Item board is not the same\n", .{});
            return .InvalidItem;
        }
    }
    if (!checkEnoughItem(
        game,
        edited_game,
        game_rule.min_item_count,
    )) {
        std.debug.print("Not enough item\n", .{});
        return .NotEnoughItem;
    }
    // starting point should not have an item
    if (Utils.getArr2d(?[]const u8, edited_game.board.item_board, edited_game.position) catch unreachable != null) {
        std.debug.print("Starting point has an item\n", .{});
        return .InvalidItem;
    }
    return .Valid;
}

pub fn checkSameWalls(
    game: Game,
    edited_game: Game,
) CheckStatus {
    if (!Utils.checkSameArr2d(
        GameLib.WallType,
        game.board.horizontal_walls,
        edited_game.board.horizontal_walls,
    )) {
        return .InvalidWall;
    }
    if (!Utils.checkSameArr2d(
        GameLib.WallType,
        game.board.vertical_walls,
        edited_game.board.vertical_walls,
    )) {
        return .InvalidWall;
    }
    return .Valid;
}

pub fn checkEligibleWalls(
    game: Game,
    edited_game: Game,
) CheckStatus {
    if (game.rules.predetermined_walls) {
        if (checkSameWalls(game, edited_game) != .Valid) {
            return .InvalidWall;
        }
    }

    for (edited_game.board.horizontal_walls, game.board.horizontal_walls) |edited_row, row| {
        for (edited_row, row) |edited_wall, wall| {
            if (wall == .BorderWall) {
                if (edited_wall != .BorderWall) {
                    return .InvalidWall;
                }
                continue;
            }
            if (edited_wall != .VisibleWall and edited_wall != .NoWall) {
                return .InvalidWall;
            }
        }
    }
    for (edited_game.board.vertical_walls, game.board.vertical_walls) |edited_row, row| {
        for (edited_row, row) |edited_wall, wall| {
            if (wall == .BorderWall) {
                if (edited_wall != .BorderWall) {
                    return .InvalidWall;
                }
                continue;
            }
            if (edited_wall != .VisibleWall and edited_wall != .NoWall) {
                return .InvalidWall;
            }
        }
    }
    return .Valid;
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
    if (edited_game.position[0] == edited_game.end_position[0] and edited_game.position[1] == edited_game.end_position[1]) {
        return .SameStartEndPosition;
    }

    const bfs_check = try tryBFS(edited_game);
    if (bfs_check != .Valid) return bfs_check;

    const item_board_check = checkEligiblieItemBoard(
        game,
        edited_game,
        game_rule,
    );
    if (item_board_check != .Valid) {
        return item_board_check;
    }

    const wall_check = checkEligibleWalls(game, edited_game);
    if (wall_check != .Valid) {
        return wall_check;
    }
    return .Valid;
}

test "simpleChecks" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const game = try Game.init(
        allocator,
        .{ .width = 5, .height = 5 },
        null,
        null,
        &.{},
    );
    var edited_game = try Game.init(
        allocator,
        .{ .width = 5, .height = 5 },
        null,
        null,
        &.{},
    );
    edited_game.setHorizontalWall(.{ 1, 1 }, .VisibleWall) catch unreachable;
    try std.testing.expectEqual(
        try checkEligible(game, edited_game, .{}),
        .Valid,
    );
}
