const std: type = @import("std");
const bfi: type = @import("bfi.zig");

const default_memory_width: comptime_int = 30000;

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();

    const allocator: std.mem.Allocator = debug_allocator.allocator();
    const reader: std.io.AnyReader = std.io.getStdIn().reader().any();
    const writer: std.io.AnyWriter = std.io.getStdOut().writer().any();

    const interpreter: *bfi.BrainfuckInterpreter = try bfi.BrainfuckInterpreter.create(
        allocator,
        default_memory_width,
        reader,
        writer,
    );
    defer interpreter.destroy();

    const program: []u8 = try get_program(allocator);
    defer allocator.free(program);

    try interpreter.interpret(program[0 .. program.len - 1 :0]);
}

fn get_program(allocator: std.mem.Allocator) anyerror![]u8 {
    var args: std.ArrayList(u8) = std.ArrayList(u8).init(allocator);
    defer args.deinit();

    var raw_args: std.process.ArgIterator = try std.process.argsWithAllocator(allocator);
    defer raw_args.deinit();

    _ = raw_args.next();
    while (raw_args.next()) |raw_arg| {
        try args.appendSlice(raw_arg);
    }
    try args.append(0);

    const proper_arg: []u8 = try allocator.alloc(u8, args.items.len);
    @memcpy(proper_arg, args.items);

    return proper_arg;
}

test "test hello world" {
    var debug_allocator: std.heap.DebugAllocator(.{}) = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();

    var io_buffer: [100]u8 = undefined;
    var stream: std.io.FixedBufferStream(u8) = std.io.fixedBufferStream(&io_buffer);

    const program = ">>+<--[[<++>->-->+++>+<<<]-->++++]<<.<<-.<<..+++.>.<<-.>.+++.------.>>-.<+.>>.";
    const allocator: std.mem.Allocator = debug_allocator.allocator();
    const reader: std.io.AnyReader = std.io.getStdIn().reader().any();
    const writer: std.io.AnyWriter = stream.writer().any();

    const interpreter: *bfi.BrainfuckInterpreter = try bfi.BrainfuckInterpreter.create(
        allocator,
        30000,
        reader,
        writer,
    );
    defer interpreter.destroy();

    try interpreter.interpret(program);

    try std.testing.expectEqualStrings("Hello World!", io_buffer[0..12]);
}
