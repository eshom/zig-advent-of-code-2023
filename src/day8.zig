// modules
const std = @import("std");
const mem = std.mem;
const testing = std.testing;

// function aliases
const assert = std.debug.assert;

// type aliases
const Allocator = mem.Allocator;
const StringArrayHashMap = std.StringArrayHashMap;

const LR = struct {
    left: []const u8,
    right: []const u8,
};

const NetworkMap = struct {
    map: StringArrayHashMap(LR),
    instructions: *Instructions,
    visit_count: usize = 0,
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator, input: []const u8) !*Self {
        var map = StringArrayHashMap(LR).init(allocator);
        errdefer map.deinit();

        var section_iter = mem.tokenizeSequence(u8, input, "\n\n");
        _ = section_iter.next();

        var node_iter = mem.tokenizeScalar(u8, section_iter.next().?, '\n');

        while (node_iter.next()) |node_line| {
            var src_dest_iter = mem.tokenizeSequence(u8, node_line, " = ");
            const src = src_dest_iter.next().?;

            var left_right_iter = mem.tokenizeSequence(u8, mem.trim(u8, src_dest_iter.next().?, "()"), ", ");
            const left = left_right_iter.next().?;
            const right = left_right_iter.next().?;

            try map.putNoClobber(src, LR{ .left = left, .right = right });
        }

        const insts = try Instructions.init(allocator, input);
        errdefer insts.deinit();

        const out = try allocator.create(Self);
        out.* = Self{ .map = map, .instructions = insts, .allocator = allocator };

        return out;
    }

    fn deinit(self: *Self) void {
        self.map.deinit();
        self.instructions.deinit();
        self.allocator.destroy(self);
    }

    // Goes to next node according to current instructions
    // returns key of next left/right node
    fn visit(self: *Self, key: []const u8) ![]const u8 {
        defer self.visit_count += 1; // In error case visit count is invalid
        const dir = self.instructions.next();
        switch (dir) {
            .L => if (self.map.get(key)) |entry| return entry.left else return error.LeftNotfound,
            .R => if (self.map.get(key)) |entry| return entry.right else return error.RightNotfound,
        }
    }

    fn reset(self: *Self) void {
        self.visit_count = 0;
        self.instructions.inst_idx = 0;
    }
};

test "Parse NetworkMap" {
    std.debug.print("\n", .{});
    const input =
        \\RL
        \\
        \\AAA = (BBB, CCC)
        \\BBB = (DDD, EEE)
        \\CCC = (ZZZ, GGG)
        \\DDD = (DDD, DDD)
        \\EEE = (EEE, EEE)
        \\GGG = (GGG, GGG)
        \\ZZZ = (ZZZ, ZZZ)
    ;

    const map = try NetworkMap.init(testing.allocator, input);
    defer map.deinit();

    errdefer {
        var map_iter = map.map.iterator();
        std.debug.print("Network: \n", .{});
        while (map_iter.next()) |entry| {
            std.debug.print("{s} -> ({s}, {s})\n", .{
                entry.key_ptr.*,
                entry.value_ptr.left,
                entry.value_ptr.right,
            });
        }
    }

    const key = comptime [_][]const u8{ "AAA", "BBB", "CCC", "DDD", "EEE", "GGG", "ZZZ" };
    const left = comptime [_][]const u8{ "BBB", "DDD", "ZZZ", "DDD", "EEE", "GGG", "ZZZ" };
    const right = comptime [_][]const u8{ "CCC", "EEE", "GGG", "DDD", "EEE", "GGG", "ZZZ" };

    inline for (key, left, right) |k, l, r| {
        try testing.expectEqualStrings(l, map.map.get(k).?.left);
        try testing.expectEqualStrings(r, map.map.get(k).?.right);
    }
}

const Direction = enum(u8) {
    L = 'L',
    R = 'R',
};

const Instructions = struct {
    go: []Direction,
    inst_idx: usize = 0,
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator, input: []const u8) !*Self {
        var section_iter = mem.tokenizeSequence(u8, input, "\n\n");
        const insts = section_iter.next().?;
        const insts_copy = try allocator.dupe(u8, insts);
        errdefer allocator.free(insts_copy);
        const out = try allocator.create(Instructions);
        errdefer allocator.free(out);
        out.* = Self{ .go = @ptrCast(insts_copy), .allocator = allocator };
        return out;
    }

    fn deinit(self: *Self) void {
        self.allocator.free(self.go);
        self.allocator.destroy(self);
    }

    fn next(self: *Self) Direction {
        const out = self.go[self.inst_idx];
        self.inst_idx = (self.inst_idx + 1) % self.go.len;
        return out;
    }
};

test "instructions recycle" {
    std.debug.print("\n", .{});
    const input =
        \\LLR
        \\
        \\AAA = (BBB, BBB)
        \\BBB = (AAA, ZZZ)
        \\ZZZ = (ZZZ, ZZZ)
    ;

    const map = try NetworkMap.init(testing.allocator, input);
    defer map.deinit();

    const expected_insts = comptime [_]Direction{ .L, .L, .R } ** 50;
    inline for (expected_insts) |inst| {
        try testing.expectEqual(inst, map.instructions.next());
    }
}

test "part 1 example 1" {
    std.debug.print("\n", .{});
    const input =
        \\RL
        \\
        \\AAA = (BBB, CCC)
        \\BBB = (DDD, EEE)
        \\CCC = (ZZZ, GGG)
        \\DDD = (DDD, DDD)
        \\EEE = (EEE, EEE)
        \\GGG = (GGG, GGG)
        \\ZZZ = (ZZZ, ZZZ)
    ;

    const map = try NetworkMap.init(testing.allocator, input);
    defer map.deinit();

    errdefer {
        var map_iter = map.map.iterator();
        std.debug.print("Network: \n", .{});
        while (map_iter.next()) |entry| {
            std.debug.print("{s} -> ({s}, {s})\n", .{
                entry.key_ptr.*,
                entry.value_ptr.left,
                entry.value_ptr.right,
            });
        }
    }

    const start: []const u8 = "AAA";
    const end: []const u8 = "ZZZ";

    var key = start;
    while (true) {
        if (mem.eql(u8, key, end)) break;
        key = try map.visit(key);
    }

    try testing.expectEqual(2, map.visit_count);
}

test "part 1 example 2" {
    std.debug.print("\n", .{});
    const input =
        \\LLR
        \\
        \\AAA = (BBB, BBB)
        \\BBB = (AAA, ZZZ)
        \\ZZZ = (ZZZ, ZZZ)
    ;

    const map = try NetworkMap.init(testing.allocator, input);
    defer map.deinit();

    errdefer {
        var map_iter = map.map.iterator();
        std.debug.print("Network: \n", .{});
        while (map_iter.next()) |entry| {
            std.debug.print("{s} -> ({s}, {s})\n", .{
                entry.key_ptr.*,
                entry.value_ptr.left,
                entry.value_ptr.right,
            });
        }
    }

    const start: []const u8 = "AAA";
    const end: []const u8 = "ZZZ";

    var key = start;
    while (true) {
        if (mem.eql(u8, key, end)) break;
        key = try map.visit(key);
    }

    try testing.expectEqual(6, map.visit_count);
}

pub fn part1(input: []const u8) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        if (gpa.deinit() != .ok) std.debug.panic("allocator reports memory leak!\n", .{});
    }

    const map = try NetworkMap.init(allocator, input);
    defer map.deinit();

    const start: []const u8 = "AAA";
    const end: []const u8 = "ZZZ";

    var key = start;
    while (true) {
        if (mem.eql(u8, key, end)) break;
        key = try map.visit(key);
    }

    return @as(u64, map.visit_count);
}
