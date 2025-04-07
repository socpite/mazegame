const Utils = @import("utils.zig");
const std = @import("std");
const WallType = Utils.WallType;
const Vec2 = Utils.Vec2;

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
        return Utils.checkInboundArr2d(i32, mazeboard.buffer_board, position);
    }
    pub fn checkInboundVerticalWall(mazeboard: MazeBoard, position: Vec2) bool {
        return Utils.checkInboundArr2d(WallType, mazeboard.vertical_walls, position);
    }
    pub fn checkInboundHorizontalWall(mazeboard: MazeBoard, position: Vec2) bool {
        return Utils.checkInboundArr2d(WallType, mazeboard.horizontal_walls, position);
    }

    pub fn setAllBuffer(mazeboard: MazeBoard, value: i32) void {
        for (mazeboard.buffer_board) |*rows| {
            for (rows.*) |*cell| {
                cell.* = value;
            }
        }
    }

    pub fn setVerticalWall(mazeboard: MazeBoard, position: Vec2, wall_value: WallType) !void {
        return Utils.setArr2d(WallType, mazeboard.vertical_walls, wall_value, position);
    }
    pub fn getVerticalWall(mazeboard: MazeBoard, position: Vec2) !WallType {
        return Utils.getArr2d(WallType, mazeboard.vertical_walls, position);
    }
    pub fn setHorizontalWall(mazeboard: MazeBoard, position: Vec2, wall_value: WallType) !void {
        return Utils.setArr2d(WallType, mazeboard.horizontal_walls, wall_value, position);
    }
    pub fn getHorizontalWall(mazeboard: MazeBoard, position: Vec2) !WallType {
        return Utils.getArr2d(WallType, mazeboard.horizontal_walls, position);
    }
    pub fn setBufferValue(mazeboard: MazeBoard, position: Vec2, value: i32) !void {
        return Utils.setArr2d(i32, mazeboard.buffer_board, value, position);
    }
    pub fn getBufferValue(mazeboard: MazeBoard, position: Vec2) !i32 {
        return Utils.getArr2d(i32, mazeboard.buffer_board, position);
    }

    pub fn limitVision(mazeboard: MazeBoard, position: Vec2) void {
        var is_visible = true;
        const px: usize = @intCast(position[0]);
        const py: usize = @intCast(position[1]);
        for (0..px) |x| {
            const rowid = px - x - 1;
            if (!is_visible) {
                mazeboard.horizontal_walls[rowid + 1][py] = .NotVisivle;
            }
            if (mazeboard.horizontal_walls[rowid + 1][py].isWall()) {
                is_visible = false;
            }
            for (mazeboard.vertical_walls[rowid], 0..) |*wall, y| {
                if (wall.* == .BorderWall) {
                    continue;
                }
                if (!is_visible or (y != py and y != py + 1)) {
                    wall.* = .NotVisivle;
                }
            }
        }
        is_visible = true;
        for (px + 1..mazeboard.height) |rowid| {
            if (!is_visible) {
                mazeboard.horizontal_walls[rowid][py] = .NotVisivle;
            }
            if (mazeboard.horizontal_walls[rowid][py].isWall()) {
                is_visible = false;
            }
            for (mazeboard.vertical_walls[rowid], 0..) |*wall, y| {
                if (wall.* == .BorderWall) {
                    continue;
                }
                if (!is_visible or (y != py and y != py + 1)) {
                    wall.* = .NotVisivle;
                }
            }
        }
        is_visible = true;
        for (0..py) |y| {
            const colid = py - y - 1;
            if (!is_visible) {
                mazeboard.vertical_walls[px][colid + 1] = .NotVisivle;
            }
            if (mazeboard.vertical_walls[px][colid + 1].isWall()) {
                is_visible = false;
            }
            for (0..mazeboard.width) |x| {
                if (mazeboard.horizontal_walls[x][colid] == .BorderWall) {
                    continue;
                }
                if (!is_visible or (x != px and x != px + 1)) {
                    mazeboard.horizontal_walls[x][colid] = .NotVisivle;
                }
            }
        }
        is_visible = true;
        for (py + 1..mazeboard.width) |colid| {
            if (!is_visible) {
                mazeboard.vertical_walls[px][colid] = .NotVisivle;
            }
            if (mazeboard.vertical_walls[px][colid].isWall()) {
                is_visible = false;
            }
            for (0..mazeboard.height) |x| {
                if (mazeboard.horizontal_walls[x][colid] == .BorderWall) {
                    continue;
                }
                if (!is_visible or (x != px and x != px + 1)) {
                    mazeboard.horizontal_walls[x][colid] = .NotVisivle;
                }
            }
        }
    }
    pub fn deepCopy(self: MazeBoard, allocator: std.mem.Allocator) !MazeBoard {
        return MazeBoard{
            .height = self.height,
            .width = self.width,
            .vertical_walls = try Utils.copyArr2d(WallType, self.vertical_walls, allocator),
            .horizontal_walls = try Utils.copyArr2d(WallType, self.horizontal_walls, allocator),
            .buffer_board = try Utils.copyArr2d(i32, self.buffer_board, allocator),
            .item_board = try Utils.copyArr2d(?[]const u8, self.item_board, allocator),
        };
    }
    pub fn checkConsistentSize(self: MazeBoard) bool {
        if (self.vertical_walls.len != self.height) {
            return false;
        }
        if (self.horizontal_walls.len != self.height + 1) {
            return false;
        }
        if (self.buffer_board.len != self.height) {
            return false;
        }
        if (self.item_board.len != self.height) {
            return false;
        }
        for (self.vertical_walls) |*rows| {
            if (rows.*.len != self.width + 1) {
                return false;
            }
        }
        for (self.horizontal_walls) |*rows| {
            if (rows.*.len != self.width) {
                return false;
            }
        }
        for (self.buffer_board) |*rows| {
            if (rows.*.len != self.width) {
                return false;
            }
        }
        for (self.item_board) |*rows| {
            if (rows.*.len != self.width) {
                return false;
            }
        }
        return true;
    }
};
