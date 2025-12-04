const std: type = @import("std");
const bfi: type = @import("bfi.zig");

const interpreter_memory_size: comptime_int = 30000;
const stdin_buffer_size: comptime_int = 1024;
const stdout_buffer_size: comptime_int = 1024;

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const interpreter: *bfi.BrainfuckInterpreter = try bfi.BrainfuckInterpreter.create(
        debug_allocator.allocator(),
        interpreter_memory_size,
    );
    defer interpreter.destroy();

    var stdin_buffer: [stdin_buffer_size]u8 = undefined;
    var stdout_buffer: [stdout_buffer_size]u8 = undefined;
    var stdin: std.fs.File.Reader = std.fs.File.stdin().reader(&stdin_buffer);
    var stdout: std.fs.File.Writer = std.fs.File.stdout().writer(&stdout_buffer);

    const program: [:0]const u8 = try get_program(debug_allocator.allocator());
    defer debug_allocator.allocator().free(program);

    try interpreter.interpret(&stdin.interface, &stdout.interface, program);
}

fn get_program(allocator: std.mem.Allocator) ![:0]const u8 {
    var args: std.process.ArgIterator = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next(); // skip the executable name

    var program: std.ArrayList(u8) = .empty;

    while (args.next()) |arg| {
        try program.appendSlice(allocator, arg);
    }

    return program.toOwnedSliceSentinel(allocator, 0);
}

test "test hello world" {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();

    const interpreter: *bfi.BrainfuckInterpreter = try bfi.BrainfuckInterpreter.create(
        debug_allocator.allocator(),
        30000,
    );
    defer interpreter.destroy();

    const read_buffer: [0]u8 = undefined;
    var write_buffer: [100]u8 = undefined;
    var reader: std.Io.Reader = std.Io.Reader.fixed(&read_buffer);
    var writer: std.Io.Writer = std.Io.Writer.fixed(&write_buffer);

    const program = ">>+<--[[<++>->-->+++>+<<<]-->++++]<<.<<-.<<..+++.>.<<-.>.+++.------.>>-.<+.>>.";

    try interpreter.interpret(
        &reader,
        &writer,
        program,
    );

    try std.testing.expectEqualStrings("Hello World!", write_buffer[0..12]);
}
