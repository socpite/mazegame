const std = @import("std");
const vec2 = @Vector(2, usize);
const Direction = enum(vec2) {
    Up = .{ -1, 0 },
    Down = .{ 1, 0 },
    Left = .{ 0, -1 },
    Right = .{ 0, 1 },
};
pub const WallType = enum {
    VisibleWall,
    NoWall,
    NotVisivle,
};
pub const MazeBoard = struct {
    height: usize,
    width: usize,
    vertical_walls: [][]WallType,
    horizontal_walls: [][]WallType,
    /// Default maze has border wall only
    pub fn init(arena_allocator: *std.heap.ArenaAllocator, height: usize, width: usize) !MazeBoard {
        const allocator = arena_allocator.allocator();
        const vertical_walls = try allocator.alloc([]WallType, height);
        const horizontal_walls = try allocator.alloc([]WallType, height + 1);
        for (vertical_walls) |*rows| {
            rows.* = try allocator.alloc(WallType, width + 1);
            @memset(rows.*, WallType.NoWall);
            rows.*[0] = WallType.VisibleWall;
            rows.*[width] = WallType.VisibleWall;
        }
        for (horizontal_walls) |*rows| {
            rows.* = try allocator.alloc(WallType, width);
            @memset(rows.*, WallType.NoWall);
        }
        @memset(horizontal_walls[0], WallType.VisibleWall);
        @memset(horizontal_walls[height], WallType.VisibleWall);
        return MazeBoard{
            .height = height,
            .width = width,
            .vertical_walls = vertical_walls,
            .horizontal_walls = horizontal_walls,
        };
    }
    fn check_inbound(mazeboard: MazeBoard, position: vec2) bool {
        return 0 <= position[0] and position[0] < mazeboard.height and 0 <= position[1] and position[1] < mazeboard.width;
    }
    fn check_inbound_vertical_wall(mazeboard: MazeBoard, position: vec2) bool {
        return 0 <= position[0] and position[0] < mazeboard.height and 0 <= position[1] and position[1] <= mazeboard.width;
    }
    fn check_inbound_horizontal_wall(mazeboard: MazeBoard, position: vec2) bool {
        return 0 <= position[0] and position[0] <= mazeboard.height and 0 <= position[1] and position[1] < mazeboard.width;
    }
};
pub const Game = struct {
    board: MazeBoard,
    position: vec2,
    pub fn init(arena_allocator: *std.heap.ArenaAllocator, height: usize, width: usize, start_position: ?vec2) !Game {
        const new_board = try MazeBoard.init(arena_allocator, height, width);
        const new_position = start_position orelse vec2{ 0, 0 };
        if (!new_board.check_inbound(new_position)) {
            return error.StartPositionOutOfBound;
        }
        return Game{
            .board = new_board,
            .position = new_position,
        };
    }
    pub fn set_position(game: *Game, position: vec2) !void {
        if (!game.board.check_inbound(position)) {
            return error.PositionOutOfBound;
        }
        game.position = position;
    }
    pub fn move(game: *Game, direction: Direction) !void {
        try game.set_position(game.position + direction);
    }
    pub fn set_vertical_wall(game: *Game, position: vec2, wall_value: WallType) !void {
        if (!game.board.check_inbound_vertical_wall(position)) {
            return error.OutOfBound;
        }
        game.board.vertical_walls[position[0]][position[1]] = wall_value;
    }
    pub fn set_horizontal_wall(game: *Game, position: vec2, wall_value: WallType) !void {
        if (!game.board.check_inbound_horizontal_wall(position)) {
            return error.OutOfBound;
        }
        game.board.horizontal_walls[position[0]][position[1]] = wall_value;
    }
    pub fn check(game: *Game) {
        var vis = 
    }
    fn bfs(game: *Game, start_position: vec2) [game.height][game.width]i32 {

    }
};
