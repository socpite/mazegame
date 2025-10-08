const std = @import("std");
const Connection = std.net.Server.Connection;
/// Remember to call start on the client
pub const Client = struct {
    pub const REQUEST_MAZE_PROTOCOL = "Request maze";
    pub const REQUEST_MOVE_PROTOCOL = "Request move";
    pub const PREPARE_SOLVER_PROTOCOL = "Prepare solver";
    const BUFFER_LENGTH = 1 << 16;
    const StreamOptions = struct {
        // By default, timeout if infinite
        max_timeout_ms: u64 = std.math.maxInt(u64) / std.time.ns_per_ms,
        max_message_length: usize = 1 << 30,
    };

    stream: std.net.Stream,
    reader: std.net.Stream.Reader,
    writer: std.net.Stream.Writer,
    score: f32 = 0,
    buffer: std.array_list.Aligned(u8, null),
    allocator: std.mem.Allocator,
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
    ) !Client {
        return Client{
            .stream = stream,
            .allocator = allocator,
            .buffer = std.array_list.Aligned(u8, null).empty,
            .reader = stream.reader(try allocator.alloc(u8, BUFFER_LENGTH)),
            .writer = stream.writer(&.{}),
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

    pub fn writeMessage(self: *Client, message: []const u8) !void {
        _ = try self.writer.interface.write(message);
        _ = try self.writer.interface.write("\n");
        self.debugPrint("{s} wrote: {s}", .{ self.name, message });
    }
    pub fn writeJSON(self: *Client, value: anytype) !void {
        try std.json.Stringify.value(value, .{}, &self.writer.interface);
        _ = try self.writer.interface.write("\n");
    }
    pub fn readMessage(self: *Client) ![]u8 {
        if (self.is_closed) {
            return error.EndOfStream;
        }
        const message = try self.reader.interface().takeDelimiterExclusive('\n');
        self.debugPrint("{s} read: {s}", .{ self.name, message });
        return message;
    }
    pub fn readJSON(
        self: *Client,
        allocator: std.mem.Allocator,
        comptime T: type,
    ) !T {
        const message = try self.readMessage();
        return try std.json.parseFromSliceLeaky(
            T,
            allocator,
            message,
            .{},
        );
    }
    fn addMessage(self: *Client, message: []const u8) !void {
        self.mutex.lock();
        try self.buffer.appendSlice(self.allocator, message);
        try self.buffer.append(self.allocator, '\n');
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
            const message = self.readMessage() catch |err| {
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
        self.is_closed = true;
        try std.posix.shutdown(self.stream.handle, .both);
        self.debugPrint("Deinitializing client\n", .{});
        // Wait for the read loop to finish
        std.posix.nanosleep(1, 0);
        self.allocator.free(self.reader.interface().buffer);
        self.buffer.deinit(self.allocator);
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
