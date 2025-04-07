const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const check = b.step("check", "Check if foo compiles");

    const gamelib_module = b.addModule("mazegame", .{
        .root_source_file = b.path("src/gamelib/gamelib.zig"),
        .target = target,
        .optimize = optimize,
    });
    //----------------------------------------------------------------------
    // Server
    // ---------------------------------------------------------------------

    const server_module = b.addModule("mazegame", .{
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const server = b.addExecutable(.{
        .name = "server",
        .root_module = server_module,
    });

    const file_server = b.dependency("StaticHttpFileServer", .{
        .target = target,
        .optimize = optimize,
    });
    const file_server_module = file_server.module("StaticHttpFileServer");
    server.root_module.addImport("StaticHttpFileServer", file_server_module);
    server.root_module.addImport("gamelib", gamelib_module);
    b.installArtifact(server);

    const server_run_exe = b.addRunArtifact(server);

    const server_check = b.addExecutable(.{
        .name = "mazegame",
        .root_module = server_module,
    });
    server_check.root_module.addImport("StaticHttpFileServer", file_server_module);
    check.dependOn(&server_check.step);
    server_run_exe.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        server_run_exe.addArgs(args);
    }

    const run_server_step = b.step("server", "Start the server");
    run_server_step.dependOn(&server_run_exe.step);

    //----------------------------------------------------------------------
    // Client
    // ---------------------------------------------------------------------

    const client_module = b.addModule("mazegame", .{
        .root_source_file = b.path("src/client/client.zig"),
        .target = target,
        .optimize = optimize,
    });
    const client = b.addExecutable(.{
        .name = "client",
        .root_module = client_module,
    });
    client.root_module.addImport("gamelib", gamelib_module);
    b.installArtifact(client);
    const client_run_exe = b.addRunArtifact(client);
    client_run_exe.step.dependOn(b.getInstallStep());

    const client_check = b.addExecutable(.{
        .name = "mazegame",
        .root_module = client_module,
    });
    check.dependOn(&client_check.step);

    if (b.args) |args| {
        client_run_exe.addArgs(args);
    }

    const run_client_step = b.step("client", "Start the client");
    run_client_step.dependOn(&client_run_exe.step);
    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
