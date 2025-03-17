const std = @import("std");

const sustype = struct {
    var x: i32 = 0;
    fn inc() void {
        x += 1;
    }
};

const a = sustype;
const b = sustype;

pub fn main() !void {
    a.inc();
    a.inc();
    b.inc();
    std.debug.print("a.x = {}, b.x = {}\n", .{ a.x, b.x });
}
