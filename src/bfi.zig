const std: type = @import("std");

const LoopStack: type = struct {
    begin_counter: usize,
    skip: bool,
    prev: ?*LoopStack,

    pub fn push(allocator: std.mem.Allocator, begin_counter: usize, skip: bool, prev: ?*LoopStack) std.mem.Allocator.Error!*LoopStack {
        const new_loop_stack: *LoopStack = try allocator.create(LoopStack);
        new_loop_stack.* = LoopStack{
            .begin_counter = begin_counter,
            .skip = skip,
            .prev = prev,
        };

        return new_loop_stack;
    }

    pub fn pop(self: *LoopStack, allocator: std.mem.Allocator) ?*LoopStack {
        const prev_loop_stack: ?*LoopStack = self.prev;
        allocator.destroy(self);
        return prev_loop_stack;
    }
};

const Operator: type = enum {
    Skip,
    PointerNext,
    PointerPrev,
    ValueIncrease,
    ValueDecrease,
    ValueInput,
    ValueOutput,
    LoopStart,
    LoopEnd,
};

pub const InterpreterError: type = error{
    UnclosedLoopStart,
    UnexpectedLoopEnd,
};

pub const BrainfuckInterpreter: type = struct {
    allocator: std.mem.Allocator,
    loop_stack: ?*LoopStack,
    reader: std.io.AnyReader,
    writer: std.io.AnyWriter,
    memory: []u8,

    pub fn create(
        allocator: std.mem.Allocator,
        memory_width: usize,
        reader: std.io.AnyReader,
        writer: std.io.AnyWriter,
    ) std.mem.Allocator.Error!*BrainfuckInterpreter {
        const interpreter: *BrainfuckInterpreter = try allocator.create(BrainfuckInterpreter);
        interpreter.* = BrainfuckInterpreter{
            .allocator = allocator,
            .loop_stack = null,
            .reader = reader,
            .writer = writer,
            .memory = try allocator.alloc(u8, memory_width),
        };

        return interpreter;
    }

    pub fn destroy(self: *BrainfuckInterpreter) void {
        self.allocator.free(self.memory);
        self.allocator.destroy(self);
    }

    pub fn interpret(self: *BrainfuckInterpreter, program: [*:0]const u8) anyerror!void {
        @memset(self.memory, 0);

        const program_length: usize = std.mem.len(program);
        var program_counter: usize = 0;
        var current_address: usize = 0;

        while (program_counter < program_length) : (program_counter += 1) {
            const current_operator: Operator = parse(program[program_counter]);
            const loop_skip: bool = if (self.loop_stack) |loop_stack| loop_stack.skip else false;
            if (loop_skip and (current_operator != Operator.LoopStart and current_operator != Operator.LoopEnd)) {
                continue;
            }

            switch (current_operator) {
                Operator.Skip => {},
                Operator.PointerNext => current_address += 1,
                Operator.PointerPrev => current_address -= 1,
                Operator.ValueIncrease => self.memory[current_address] +%= 1,
                Operator.ValueDecrease => self.memory[current_address] -%= 1,
                Operator.ValueInput => self.memory[current_address] = self.reader.readByte() catch 0,
                Operator.ValueOutput => try self.writer.writeByte(self.memory[current_address]),
                Operator.LoopStart => self.loop_stack = try LoopStack.push(
                    self.allocator,
                    program_counter,
                    self.memory[current_address] == 0,
                    self.loop_stack,
                ),
                Operator.LoopEnd => if (self.loop_stack) |loop_stack| {
                    if (!loop_stack.skip and self.memory[current_address] != 0) {
                        program_counter = loop_stack.begin_counter;
                    } else {
                        self.loop_stack = loop_stack.pop(self.allocator);
                    }
                } else return InterpreterError.UnexpectedLoopEnd,
            }
        }

        if (self.loop_stack) |_| {
            while (self.loop_stack != null) {
                self.loop_stack = if (self.loop_stack) |loop_stack| loop_stack.pop(self.allocator) else null;
            }
            return InterpreterError.UnclosedLoopStart;
        }
    }

    fn parse(c: u8) Operator {
        return switch (c) {
            '>' => Operator.PointerNext,
            '<' => Operator.PointerPrev,
            '+' => Operator.ValueIncrease,
            '-' => Operator.ValueDecrease,
            ',' => Operator.ValueInput,
            '.' => Operator.ValueOutput,
            '[' => Operator.LoopStart,
            ']' => Operator.LoopEnd,
            else => Operator.Skip,
        };
    }
};
