pub const Vec2 = @Vector(2, isize);
const std = @import("std");

pub const Direction = enum {
    Up,
    Down,
    Left,
    Right,
    pub const list = [_]Direction{ Direction.Up, Direction.Down, Direction.Left, Direction.Right };
    pub fn getVec2(direction: Direction) Vec2 {
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
    NotVisible,
    BorderWall,

    pub fn isWall(wall: WallType) bool {
        return switch (wall) {
            WallType.VisibleWall => true,
            WallType.NoWall => false,
            WallType.NotVisible => false,
            WallType.BorderWall => true,
        };
    }
};

// Caller owns the new array
pub fn copyArr2d(
    comptime T: type,
    arr: []const []const T,
    allocator: std.mem.Allocator,
) ![][]T {
    const new_arr = try allocator.alloc([]T, arr.len);
    for (arr, new_arr) |row, *new_row| {
        new_row.* = try allocator.dupe(T, row);
    }
    return new_arr;
}

pub fn copyItemBoard(arr: []const []const ?[]const u8, allocator: std.mem.Allocator) ![][]?[]const u8 {
    const new_arr = try allocator.alloc([]?[]const u8, arr.len);
    for (arr, new_arr) |row, *new_row| {
        new_row.* = try allocator.alloc(?[]const u8, row.len);
        for (row, new_row.*) |item, *new_item| {
            if (item == null) {
                new_item.* = null;
            } else {
                new_item.* = try allocator.dupe(u8, item.?);
            }
        }
    }
    return new_arr;
}

pub fn checkSameArr2d(comptime T: type, arr1: [][]T, arr2: [][]T) bool {
    if (arr1.len != arr2.len) {
        return false;
    }
    for (arr1, arr2) |row1, row2| {
        if (row1.len != row2.len) {
            return false;
        }
        for (row1, row2) |cell1, cell2| {
            if (cell1 != cell2) {
                return false;
            }
        }
    }
    return true;
}

pub fn checkInboundArr2d(comptime T: type, arr: [][]T, position: Vec2) bool {
    return 0 <= position[0] and position[0] < arr.len and 0 <= position[1] and position[1] < arr[0].len;
}

pub fn setArr2d(comptime T: type, arr: [][]T, value: T, position: Vec2) !void {
    if (!checkInboundArr2d(T, arr, position)) {
        return error.OutOfBound;
    }
    arr[@intCast(position[0])][@intCast(position[1])] = value;
}

pub fn setAllArr2d(comptime T: type, arr: [][]T, value: T) void {
    for (arr) |*rows| {
        for (rows.*) |*cell| {
            cell.* = value;
        }
    }
}

pub fn getArr2d(comptime T: type, arr: [][]T, position: Vec2) !T {
    if (!checkInboundArr2d(T, arr, position)) {
        return error.OutOfBound;
    }
    return arr[@intCast(position[0])][@intCast(position[1])];
}

pub fn optionalStrEql(str1: ?[]const u8, str2: ?[]const u8) bool {
    if (str1 == null and str2 == null) {
        return true;
    }
    if (str1 == null or str2 == null) {
        return false;
    }
    return std.mem.eql(u8, str1.?, str2.?);
}
