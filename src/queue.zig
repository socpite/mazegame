const std = @import("std");

pub fn Queue(T: type) type {
    return struct {
        const Self = @This();
        data: []T,
        front: usize = 0,
        back: usize = 0,
        allocator: std.mem.Allocator,
        pub fn init(allocator: std.mem.Allocator, max_len: usize) !Self {
            return Self{
                .allocator = allocator,
                .data = try allocator.alloc(T, max_len),
            };
        }
        pub fn push(self: *Self, value: T) !void {
            if (self.back == self.data.len) {
                return error.QueueExceededMaxSize;
            }
            self.data[self.back] = value;
            self.back += 1;
        }
        pub fn pop(self: *Self) !T {
            if (self.front == self.back) {
                return error.QueueEmpty;
            }
            const value = self.data[self.front];
            self.front += 1;
            return value;
        }
        pub fn peek(self: *Self) !T {
            if (self.front == self.back) {
                return error.QueueEmpty;
            }
            return self.data[self.front];
        }
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
        }
    };
}
