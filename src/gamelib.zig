const std = @import("std");
const Direction = enum {
    Up,
    Down,
    Left,
    Right,
};
pub const MazeBoard = struct {
    height: u32,
    width: u32,
    vertical_walls: [][]bool,
    horizontal_walls: [][]bool,
    pub fn init(arena_allocator: *std.heap.ArenaAllocator, height: u32, width: u32) !MazeBoard {
        const allocator = arena_allocator.allocator();
        const vertical_walls = try allocator.alloc([]bool, height);
        const horizontal_walls = try allocator.alloc([]bool, height + 1);
        for (vertical_walls) |*rows| {
            rows.* = try allocator.alloc(bool, width + 1);
        }
        for (horizontal_walls) |*rows| {
            rows.* = try allocator.alloc(bool, width);
        }
        return MazeBoard{
            .height = height,
            .width = width,
            .vertical_walls = vertical_walls,
            .horizontal_walls = horizontal_walls,
        };
    }
};
