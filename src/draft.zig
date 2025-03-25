const std = @import("std");

const TestStruct = struct {
    var x: i32 = 0;
    fn increment() void {
        x += 1;
    }
};

const a = TestStruct;
const b = TestStruct;

pub fn main() !void {
    a.increment();
    a.increment();
    b.increment();
    std.debug.print("a.x = {}, b.x = {}\n", .{ a.x, b.x });
}
