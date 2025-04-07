const GameLib = @import("gamelib.zig");
const Utils = @import("utils.zig");
const std = @import("std");
const WallType = Utils.WallType;
const Vec2 = Utils.Vec2;
const Item = GameLib.Item;
const Game = GameLib.Game;

pub const Bomb = struct {
    const name = "Bomb";
    count: usize = 0,
    range: usize = 1,
    pub fn init(count: usize, range: usize) Bomb {
        return Bomb{ .count = count, .range = range };
    }
    fn pickUp(ctx: *anyopaque) void {
        const self: *Bomb = @ptrCast(@alignCast(ctx));
        self.count += 1;
    }
    fn apply(ctx: *anyopaque, game: *Game) void {
        const self: *Bomb = @ptrCast(@alignCast(ctx));
        const center = game.position;
        for (0..self.range * 2 - 1) |x| {
            for (0..self.range * 2) |y| {
                const position = center - Vec2{ @intCast(self.range), @intCast(self.range) } + Vec2{ @intCast(x), @intCast(y) };
                if (game.board.checkInboundVerticalWall(position) and game.board.getVerticalWall(position) catch unreachable != .BorderWall) {
                    game.board.setVerticalWall(position, .NoWall) catch unreachable;
                }
            }
        }
        for (0..self.range * 2 - 1) |y| {
            for (0..self.range * 2) |x| {
                const position = center - Vec2{ @intCast(self.range), @intCast(self.range) } + Vec2{ @intCast(x), @intCast(y) };
                if (game.board.checkInboundHorizontalWall(position) and game.board.getHorizontalWall(position) catch unreachable != .BorderWall) {
                    game.board.setHorizontalWall(position, .NoWall) catch unreachable;
                }
            }
        }
    }
    fn jsonStringify(ctx: *anyopaque, allocator: std.mem.Allocator) error{OutOfMemory}![]u8 {
        const self: *Bomb = @ptrCast(@alignCast(ctx));
        const obj_json = try std.json.stringifyAlloc(allocator, self.*, .{});
        return std.mem.concat(allocator, u8, &.{ name, ";", obj_json });
    }
    pub fn newItem(allocator: std.mem.Allocator) !Item {
        var bomb = try allocator.create(Bomb);
        bomb.* = Bomb{};
        return bomb.asItem();
    }
    pub fn asItem(self: *Bomb) Item {
        return Item{
            .ptr = self,
            .name = name,
            .impl = &.{
                .pick_up = Bomb.pickUp,
                .apply = Bomb.apply,
                .json_stringify = Bomb.jsonStringify,
            },
        };
    }
};

const AllItemType = enum {
    Bomb,
};

/// Caller owns the item
pub fn strToItem(name: []const u8, allocator: std.mem.Allocator) !Item {
    const item_type = std.meta.stringToEnum(AllItemType, name).?;
    return switch (item_type) {
        .Bomb => try Bomb.newItem(allocator),
    };
}

pub fn jsonToItem(json: []const u8, arena: std.mem.Allocator) !Item {
    const typename_end = std.mem.indexOfScalar(u8, json, ';') orelse {
        return error.WrongItemFormat;
    };
    const item_type = std.meta.stringToEnum(AllItemType, json[0..typename_end]) orelse {
        return error.ItemTypeNotFound;
    };
    const item_content = json[typename_end + 1 ..];
    return switch (item_type) {
        .Bomb => {
            var bomb = try std.json.parseFromSliceLeaky(Bomb, arena, item_content, .{});
            return bomb.asItem();
        },
    };
}

pub fn genItemList(name_list: []const []const u8, allocator: std.mem.Allocator) ![]GameLib.Item {
    var array = std.ArrayList(GameLib.Item).init(allocator);
    for (name_list) |name| {
        try array.append(try strToItem(name, allocator));
    }
    return try array.toOwnedSlice();
}
