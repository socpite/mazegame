const std = @import("std");
const Queue = @import("queue.zig").Queue;
pub const vec2 = @Vector(2, isize);
const Direction = enum {
    Up,
    Down,
    Left,
    Right,
    const list = [_]Direction{ Direction.Up, Direction.Down, Direction.Left, Direction.Right };
    fn get_vec2(direction: Direction) vec2 {
        return switch (direction) {
            Direction.Up => vec2{ -1, 0 },
            Direction.Down => vec2{ 1, 0 },
            Direction.Left => vec2{ 0, -1 },
            Direction.Right => vec2{ 0, 1 },
        };
    }
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
    buffer_board: [][]i32,
    /// Default maze has border wall only
    pub fn init(arena_allocator: *std.heap.ArenaAllocator, height: usize, width: usize) !MazeBoard {
        const allocator = arena_allocator.allocator();
        const vertical_walls = try allocator.alloc([]WallType, height);
        const horizontal_walls = try allocator.alloc([]WallType, height + 1);
        const buffer_board = try allocator.alloc([]i32, height);
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
        for (buffer_board) |*rows| {
            rows.* = try allocator.alloc(i32, width);
            @memset(rows.*, 0);
        }
        return MazeBoard{
            .height = height,
            .width = width,
            .vertical_walls = vertical_walls,
            .horizontal_walls = horizontal_walls,
            .buffer_board = buffer_board,
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
    fn set_all_buffer(mazeboard: MazeBoard, value: i32) void {
        for (mazeboard.buffer_board) |*rows| {
            for (rows.*) |*cell| {
                cell.* = value;
            }
        }
    }
    fn set_vertical_wall(mazeboard: MazeBoard, position: vec2, wall_value: WallType) !void {
        if (!mazeboard.check_inbound_vertical_wall(position)) {
            return error.OutOfBound;
        }
        mazeboard.vertical_walls[@intCast(position[0])][@intCast(position[1])] = wall_value;
    }
    fn get_vertical_wall(mazeboard: MazeBoard, position: vec2) !WallType {
        if (!mazeboard.check_inbound_vertical_wall(position)) {
            return error.OutOfBound;
        }
        return mazeboard.vertical_walls[@intCast(position[0])][@intCast(position[1])];
    }
    fn set_horizontal_wall(mazeboard: MazeBoard, position: vec2, wall_value: WallType) !void {
        if (!mazeboard.check_inbound_horizontal_wall(position)) {
            return error.OutOfBound;
        }
        mazeboard.horizontal_walls[@intCast(position[0])][@intCast(position[1])] = wall_value;
    }
    fn get_horizontal_wall(mazeboard: MazeBoard, position: vec2) !WallType {
        if (!mazeboard.check_inbound_horizontal_wall(position)) {
            return error.OutOfBound;
        }
        return mazeboard.horizontal_walls[@intCast(position[0])][@intCast(position[1])];
    }
    fn set_buffer_value(mazeboard: MazeBoard, position: vec2, value: i32) !void {
        if (!mazeboard.check_inbound(position)) {
            return error.OutOfBound;
        }
        mazeboard.buffer_board[@intCast(position[0])][@intCast(position[1])] = value;
    }
    fn get_buffer_value(mazeboard: MazeBoard, position: vec2) !i32 {
        if (!mazeboard.check_inbound(position)) {
            return error.OutOfBound;
        }
        return mazeboard.buffer_board[@intCast(position[0])][@intCast(position[1])];
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
        try game.set_position(game.position + direction.get_vec2());
    }
    pub fn set_vertical_wall(game: *Game, position: vec2, wall_value: WallType) !void {
        if (!game.board.check_inbound_vertical_wall(position)) {
            return error.OutOfBound;
        }
        try game.board.set_vertical_wall(position, wall_value);
    }
    pub fn set_horizontal_wall(game: *Game, position: vec2, wall_value: WallType) !void {
        if (!game.board.check_inbound_horizontal_wall(position)) {
            return error.OutOfBound;
        }
        try game.board.set_horizontal_wall(position, wall_value);
    }
    pub fn check(game: Game, allocator: std.mem.Allocator) !bool {
        var queue = try Queue(vec2).init(allocator, game.board.height * game.board.width);
        defer queue.deinit();
        game.board.set_all_buffer(-1);
        try queue.push(game.position);
        try game.board.set_buffer_value(game.position, 0);
        while (queue.front < queue.back) {
            const current_position = try queue.pop();
            const current_value = try game.board.get_buffer_value(current_position);
            for (Direction.list) |direction| {
                const next_position = current_position + direction.get_vec2();
                if (!game.board.check_inbound(next_position)) {
                    continue;
                }
                if (try game.board.get_buffer_value(next_position) != -1) {
                    continue;
                }
                if (WallType.VisibleWall == switch (direction) {
                    Direction.Up => try game.board.get_horizontal_wall(current_position),
                    Direction.Down => try game.board.get_horizontal_wall(next_position),
                    Direction.Left => try game.board.get_vertical_wall(current_position),
                    Direction.Right => try game.board.get_vertical_wall(next_position),
                }) {
                    continue;
                }
                try game.board.set_buffer_value(next_position, current_value + 1);
                try queue.push(next_position);
            }
        }
        return queue.back == game.board.height * game.board.width;
    }
};
