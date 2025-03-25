const std = @import("std");
const Connection = std.net.Server.Connection;

pub const Client = struct {
    const MAX_MESSAGE_LENGTH = 1 << 16;
    stream: std.net.Stream,
    score: u32 = 0,

    pub fn writeMessage(client: Client, message: []const u8) !void {
        _ = try client.stream.write(message);
        _ = try client.stream.write("\n");
    }
    pub fn writeJson(client: Client, value: anytype) !void {
        try std.json.stringify(value, .{}, client.stream.writer());
        _ = try client.stream.write("\n");
    }
    pub fn readMessage(client: Client, allocator: std.mem.Allocator) ![]u8 {
        return try client.stream.reader().readUntilDelimiterAlloc(
            allocator,
            '\n',
            MAX_MESSAGE_LENGTH,
        );
    }
    pub fn readJson(client: Client, allocator: std.mem.Allocator, comptime T: type) !T {
        const message = try client.readMessage(allocator);
        return try std.json.parseFromSliceLeaky(
            T,
            allocator,
            message,
            .{},
        );
    }
};
