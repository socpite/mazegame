const std = @import("std");
const Connection = std.net.Server.Connection;
/// Remember to call start on the client
pub const Client = struct {
    pub const REQUEST_MAZE_PROTOCOL = "Request maze";
    pub const REQUEST_MOVE_PROTOCOL = "Request move";
    const StreamOptions = struct {
        // By default, timeout if infinite
        max_timeout_ms: u64 = std.math.maxInt(u64) / std.time.ns_per_ms,
        max_message_length: usize = 1 << 16,
    };

    stream: std.net.Stream,
    score: u32 = 0,
    buffer: std.ArrayList(u8),
    stream_options: StreamOptions,
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    read_position: usize = 0,
    is_closed: bool = false,
    name: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        stream: std.net.Stream,
        stream_options: StreamOptions,
        name: []const u8,
    ) Client {
        return Client{
            .stream = stream,
            .buffer = std.ArrayList(u8).init(allocator),
            .stream_options = stream_options,
            .mutex = .{},
            .condition = .{},
            .name = name,
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
        std.time.sleep(std.time.ns_per_ms * 20);
        if (self.is_closed) {
            return error.EndOfStream;
        }
        return self.stream.reader().readUntilDelimiterAlloc(
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
    pub fn debugPrint(self: Client, comptime fmt: []const u8, args: anytype) void {
        std.debug.print("Client: {s}, ", .{self.name});
        std.debug.print(fmt, args);
        std.debug.print("\n", .{});
    }
    fn readLoop(self: *Client) !void {
        while (true) {
            const message = self.readMessage(self.buffer.allocator) catch |err| {
                if (err == error.EndOfStream) {
                    self.debugPrint("End of stream reached, stopping read loop.", .{});
                    return;
                }
                self.debugPrint("Unexpected error", .{});
                return err;
            };
            self.addMessage(message) catch |err| {
                self.debugPrint("Error adding message: {}", .{err});
                return err;
            };
            self.buffer.allocator.free(message);
        }
    }
    pub fn checkNewMessage(self: *Client) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.read_position < self.buffer.items.len) {
            return true;
        }
        return false;
    }
    pub fn getNextMessage(self: *Client, allocator: std.mem.Allocator) ![]u8 {
        if (!self.checkNewMessage()) {
            return error.NoMessage;
        }
        self.mutex.lock();
        defer self.mutex.unlock();
        const message_end = std.mem.indexOfScalarPos(
            u8,
            self.buffer.items,
            self.read_position,
            '\n',
        ) orelse return error.IncompleteMessage;
        const message = try allocator.dupe(u8, self.buffer.items[self.read_position..message_end]);
        self.read_position = message_end + 1;
        return message;
    }
    pub fn getNextMessageTimed(self: *Client, allocator: std.mem.Allocator, timeout_ms: ?u64) ![]u8 {
        const ns = (timeout_ms orelse self.stream_options.max_timeout_ms) * std.time.ns_per_ms;
        if (self.checkNewMessage()) {
            return try self.getNextMessage(allocator);
        }
        {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.condition.timedWait(&self.mutex, ns) catch |err| {
                std.debug.assert(err == error.Timeout);
            };
        }
        if (self.checkNewMessage()) {
            return try self.getNextMessage(allocator);
        }
        return error.Timeout;
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
    pub fn deinit(self: *Client) !void {
        try std.posix.shutdown(self.stream.handle, .both);
        self.debugPrint("Deinitializing client\n", .{});
        self.is_closed = true;
        // Wait for the read loop to finish
        std.time.sleep(std.time.ns_per_ms * 1000);
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
        "TestClient",
    );
    const thread = try std.Thread.spawn(.{}, delay_add, .{ &client, 2000 });
    thread.detach();
    const first_message = client.getNextMessageTimed(allocator, 1000);
    try std.testing.expectEqual(first_message, error.Timeout);
    const second_message = try client.getNextMessageTimed(allocator, 2000);
    try std.testing.expect(std.mem.eql(u8, second_message, "Test message"));
}
