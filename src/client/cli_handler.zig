const std = @import("std");
const builtin = @import("builtin");

var args: [][:0]u8 = undefined;
var has_read: bool = false;
var bot_name: [:0]const u8 = undefined;
pub var server_ip: [:0]const u8 = "127.0.0.1";

// Must be called before any other function.
pub fn init(allocator: std.mem.Allocator) !void {
    if (has_read) {
        return;
    }
    has_read = true;
    args = try std.process.argsAlloc(allocator);
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--ip")) {
            if (i + 1 >= args.len) {
                return error.MissingValue;
            }
            server_ip = args[i + 1];
            i += 1; // skip the value
        } else if (std.mem.eql(u8, arg, "--name")) {
            if (i + 1 >= args.len) {
                return error.MissingValue;
            }
            bot_name = args[i + 1];
            i += 1; // skip the value
        } else {
            std.debug.print("Unknown argument: {s}\n", .{arg});
        }
    }
}

pub fn deinit(allocator: std.mem.Allocator) void {
    if (has_read) {
        std.process.argsFree(allocator, args);
    }
}

pub fn getBotPath(allocator: std.mem.Allocator) ![]const u8 {
    const bot_dir = try std.fs.cwd().openDirZ(bot_name, .{});
    if (builtin.os.tag == .windows) {
        return bot_dir.realpathAlloc(allocator, "bot.dll");
    } else {
        return bot_dir.realpathAlloc(allocator, "bot.so");
    }
}
