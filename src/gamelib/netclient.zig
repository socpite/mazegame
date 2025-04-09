const std = @import("std");
const Connection = std.net.Server.Connection;

/// Remember to call start on the client
pub const Client = struct {
    pub const REQUEST_MAZE_PROTOCOL = "Request maze";
    pub const REQUEST_MOVE_PROTOCOL = "Request move";
    const StreamOptions = struct {
        max_timeout_ms: u64 = 10000,
        max_message_length: usize = 1024,
    };

    stream: std.net.Stream,
    score: u32 = 0,
    buffer: std.ArrayList(u8),
    stream_options: StreamOptions,
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    read_position: usize = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        stream: std.net.Stream,
        stream_options: StreamOptions,
    ) Client {
        return Client{
            .stream = stream,
            .buffer = std.ArrayList(u8).init(allocator),
            .stream_options = stream_options,
            .mutex = .{},
            .condition = .{},
        };
    }

    pub fn start(self: *Client) !void {
        const loop_thread = try std.Thread.spawn(.{}, Client.readLoop, .{self});
        loop_thread.detach();
    }

    pub fn writeMessage(self: Client, message: []const u8) !void {
        _ = try self.stream.write(message);
        _ = try self.stream.write("\n");
    }
    pub fn writeJSON(self: Client, value: anytype) !void {
        try std.json.stringify(value, .{}, self.stream.writer());
        _ = try self.stream.write("\n");
    }
    pub fn readMessage(self: Client, allocator: std.mem.Allocator) ![]u8 {
        return try self.stream.reader().readUntilDelimiterAlloc(
            allocator,
            '\n',
            self.stream_options.max_message_length,
        );
    }
    fn addMessage(self: *Client, message: []const u8) !void {
        self.mutex.lock();
        try self.buffer.appendSlice(message);
        try self.buffer.append('\n');
        self.mutex.unlock();
        // Notify any waiting threads that a new message has been added
        self.condition.signal();
    }
    fn readLoop(self: *Client) !void {
        while (true) {
            const message = self.readMessage(self.buffer.allocator) catch |err| {
                if (err == error.EndOfStream) {
                    std.debug.print("End of stream reached, stopping read loop.\n", .{});
                    return;
                }
                std.debug.print("Error reading message: {}\n", .{err});
                continue;
            };
            self.addMessage(message) catch |err| {
                std.debug.print("Error adding message: {}\n", .{err});
                return err;
            };
        }
    }
    pub fn getNextMessage(self: *Client, allocator: std.mem.Allocator) ![]u8 {
        if (self.read_position < self.buffer.items.len) {
            const message_end = std.mem.indexOfScalar(u8, self.buffer.items[self.read_position..], '\n') orelse return error.IncompleteMessage;
            const message = try allocator.dupe(u8, self.buffer.items[self.read_position..message_end]);
            self.read_position += message.len;
            return message;
        }
        return error.NoMessage;
    }
    pub fn getNextMessageTimed(self: *Client, allocator: std.mem.Allocator, timeout_ms: ?u64) ![]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const ns = (timeout_ms orelse self.stream_options.max_timeout_ms) * std.time.ns_per_ms;
        if (self.getNextMessage(allocator)) |message| {
            return message;
        } else |err| {
            if (err == error.NoMessage) {
                self.condition.timedWait(&self.mutex, ns) catch |wait_err| {
                    std.debug.print("Error waiting for message: {}\n", .{wait_err});
                    return wait_err;
                };
                return self.getNextMessage(allocator);
            }
            return err;
        }
    }
    pub fn getNextJSON(self: *Client, allocator: std.mem.Allocator, comptime T: type) !T {
        const message = try self.getNextMessage(allocator);
        return try std.json.parseFromSliceLeaky(
            T,
            allocator,
            message,
            .{},
        );
    }
    pub fn getNextJSONTimed(self: *Client, allocator: std.mem.Allocator, comptime T: type, timeout_ms: ?u64) !T {
        const message = try self.getNextMessageTimed(allocator, timeout_ms);
        return try std.json.parseFromSliceLeaky(
            T,
            allocator,
            message,
            .{},
        );
    }
    pub fn close(self: *Client) !void {
        try self.stream.close();
        self.buffer.deinit();
    }
    pub fn clearBuffer(self: *Client) void {
        self.buffer.clearAndFree();
        self.read_position = 0;
    }
};

fn delay_add(client: *Client, wait_time_ms: u64) !void {
    std.time.sleep(std.time.ns_per_ms * wait_time_ms);
    try client.addMessage("Test message");
}
test "ReadTimeout" {
    var aa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = aa.allocator();
    var client = Client.init(
        allocator,
        std.net.Stream{ .handle = undefined },
        .{},
    );
    const thread = try std.Thread.spawn(.{}, delay_add, .{ &client, 2000 });
    thread.detach();
    const first_message = client.getNextMessageTimed(allocator, 1000);
    try std.testing.expectEqual(first_message, error.Timeout);
    const second_message = try client.getNextMessageTimed(allocator, 2000);
    try std.testing.expect(std.mem.eql(u8, second_message, "Test message"));
}
