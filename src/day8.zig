// modules
const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const atomic = std.atomic;
const time = std.time;

// function aliases
const assert = std.debug.assert;

// type aliases
const Allocator = mem.Allocator;
const StringArrayHashMap = std.StringArrayHashMap;
const Thread = std.Thread;

const LR = struct {
    left: []const u8,
    right: []const u8,
};

const NetworkMap = struct {
    map: StringArrayHashMap(LR),
    instructions: *Instructions,
    visit_count: usize = 0,
    visit_count_atomic: atomic.Value(usize) = atomic.Value(usize).init(0),
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
        defer self.visit_count += 1;
        defer _ = self.visit_count_atomic.fetchAdd(1, .monotonic);
        errdefer self.visit_count -= 1;
        errdefer _ = self.visit_count_atomic.fetchSub(1, .monotonic);
        const dir = self.instructions.next();
        switch (dir) {
            .L => if (self.map.get(key)) |entry| return entry.left else return error.LeftNotfound,
            .R => if (self.map.get(key)) |entry| return entry.right else return error.RightNotfound,
        }
    }

    fn reset(self: *Self) void {
        self.visit_count = 0;
        self.visit_count_atomic.store(0, .monotonic);
        self.instructions.inst_idx = 0;
    }

    fn travelSteps(self: *Self, from: []const u8, to: []const u8) !u64 {
        var key = from;
        while (true) {
            if (mem.eql(u8, key, to)) break;
            key = try self.visit(key);
        }

        return @as(u64, self.visit_count);
    }

    // Get slice of all nodes that end with some letter
    // Caller owns memory of return value
    fn nodesEndWith(self: *const Self, allocator: Allocator, ends_with: u8) ![]const []const u8 {
        const keys = self.map.keys();

        const found = try allocator.alloc([]const u8, keys.len);
        defer allocator.free(found);

        var count: usize = 0;
        for (keys) |k| {
            assert(count < keys.len);
            assert(k.len == 3);
            if (k[2] == ends_with) {
                found[count] = k;
                count += 1;
            }
        }

        const nodes = try allocator.alloc([]const u8, count);
        errdefer allocator.free(nodes);

        @memcpy(nodes, found[0..count]);

        return nodes;
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

    try testing.expectEqual(6, try map.travelSteps(start, end));
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

    return map.travelSteps(start, end);
}

test "get starting nodes" {
    std.debug.print("\n", .{});
    const input =
        \\LR
        \\
        \\11A = (11B, XXX)
        \\11B = (XXX, 11Z)
        \\11Z = (11B, XXX)
        \\22A = (22B, XXX)
        \\22B = (22C, 22C)
        \\22C = (22Z, 22Z)
        \\22Z = (22B, 22B)
        \\XXX = (XXX, XXX)
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

    const result = try map.nodesEndWith(testing.allocator, 'A');
    defer testing.allocator.free(result);

    const expected = [_][]const u8{ "11A", "22A" };
    for (expected, result) |exp, res| {
        try testing.expectEqualSlices(u8, exp, res);
    }
}

pub fn part2(input: []const u8) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const map = try NetworkMap.init(allocator, input);
    defer map.deinit();

    const start_keys = try map.nodesEndWith(allocator, 'A');
    defer allocator.free(start_keys);

    const map_arr = try allocator.alloc(*NetworkMap, start_keys.len);
    defer allocator.free(map_arr);
    for (map_arr) |*m| {
        m.* = try NetworkMap.init(allocator, input);
    }
    defer {
        for (map_arr) |m| {
            m.deinit();
        }
    }

    const threads_end = try allocator.alloc(atomic.Value(bool), start_keys.len);
    defer allocator.free(threads_end);
    for (threads_end) |*thren| {
        thren.store(false, .monotonic);
    }

    const stop_signal = try allocator.alloc(atomic.Value(bool), start_keys.len);
    defer allocator.free(stop_signal);
    for (stop_signal) |*stop| {
        stop.store(true, .monotonic);
    }

    const exit_signal = try allocator.alloc(atomic.Value(bool), start_keys.len);
    defer allocator.free(exit_signal);
    for (exit_signal) |*exit| {
        exit.store(false, .monotonic);
    }

    const n_threads = comptime 7;
    assert(n_threads >= map_arr.len);

    // const threads = [n_threads]Thread;
    const threads = try allocator.alloc(Thread, start_keys.len);
    defer allocator.free(threads);

    var mutex = Thread.Mutex{};

    for (threads, 0..) |*th, idx| {
        th.* = Thread.spawn(.{}, travelStepsThread, .{
            idx,
            map_arr[idx],
            start_keys[idx],
            'Z',
            &threads_end[idx],
            &stop_signal[idx],
            &exit_signal[idx],
            &mutex,
        }) catch |err| {
            std.debug.panic("error spawning thread {d}: {any}\n", .{ idx, err });
        };
    }

    outer: while (true) {
        time.sleep(10);

        // threads should wait while main makes decisions
        mutex.lock();
        defer mutex.unlock();

        var max_step: usize = 0;
        for (map_arr) |m| {
            max_step = @max(max_step, m.visit_count_atomic.load(.monotonic));
        }

        for (map_arr, stop_signal) |m, *stp| {
            if (m.visit_count_atomic.load(.monotonic) < max_step) {
                stp.store(false, .monotonic);
            } else {
                stp.store(true, .monotonic);
            }
        }

        // std.debug.print("Main: threads end: {any}\n", .{threads_end});
        // all on end point and same step?
        for (map_arr) |m| {
            // checking if all in same step
            if (m.visit_count_atomic.load(.monotonic) != max_step) break;
        } else {
            // same step branch
            var all_end = true;
            for (threads_end) |end| {
                all_end = all_end and end.load(.monotonic);
            }
            if (all_end) {
                // same end point branch
                for (exit_signal) |*exit| {
                    exit.store(true, .monotonic);
                }
                break :outer;
            } else {
                // different end points branch
                for (stop_signal) |*stp| {
                    stp.store(false, .monotonic);
                }
            }
        }
    }

    for (threads) |t| {
        t.join();
    }

    const answer: u64 = map_arr[0].visit_count_atomic.load(.monotonic);
    for (1..map_arr.len) |idx| {
        if (answer != map_arr[idx].visit_count_atomic.load(.monotonic)) {
            return error.AnswerNotSynced;
        }
    } else {
        return answer;
    }
}

test "part 2 example" {
    std.debug.print("\n", .{});
    const input =
        \\LR
        \\
        \\11A = (11B, XXX)
        \\11B = (XXX, 11Z)
        \\11Z = (11B, XXX)
        \\22A = (22B, XXX)
        \\22B = (22C, 22C)
        \\22C = (22Z, 22Z)
        \\22Z = (22B, 22B)
        \\XXX = (XXX, XXX)
    ;

    try testing.expectEqual(6, try part2(input));
}

fn travelStepsThread(
    id: usize,
    map: *NetworkMap,
    from: []const u8,
    to_char: u8,
    end: *atomic.Value(bool),
    stop: *const atomic.Value(bool),
    exit: *const atomic.Value(bool),
    mutex: *Thread.Mutex,
) void {
    // defer std.debug.print("Thread {d}: exit\n", .{id});
    var key = from;

    while (true) {
        defer time.sleep(10);
        // std.debug.print("Thread {d}: starting step {d}\n", .{ id, map.visit_count_atomic.load(.monotonic) });
        // defer std.debug.print("Thread {d}: done and on step {d}\n", .{ id, map.visit_count_atomic.load(.monotonic) });

        // Did main signal thread to continue?
        while (stop.load(.monotonic)) {
            time.sleep(10);
            if (exit.load(.monotonic)) return;
        }

        mutex.lock();
        defer mutex.unlock();

        // Did main signal thread to exit?
        if (exit.load(.monotonic)) break;

        // Update step
        // std.debug.print("Thread {d}: {s} -> ", .{ id, key });
        key = map.visit(key) catch {
            std.debug.print("Thread {d}: error while visiting next location from {s}\n", .{ id, from });
            return;
        };
        // std.debug.print("{s}\n", .{key});

        // Update if on end point
        if (key[2] == to_char) end.store(true, .monotonic) else end.store(false, .monotonic);
        // std.debug.print("Thread {d}: end point {any}\n", .{ id, end });
    }
}

test "part 2 example but more threads" {
    std.debug.print("\n", .{});
    const input =
        \\LR
        \\
        \\11A = (11B, XXX)
        \\11B = (XXX, 11Z)
        \\11Z = (11B, XXX)
        \\22A = (22B, XXX)
        \\22B = (22C, 22C)
        \\22C = (22Z, 22Z)
        \\22Z = (22B, 22B)
        \\XXX = (XXX, XXX)
        \\33A = (33B, XXX)
        \\33B = (33C, 33C)
        \\33C = (33Z, 33Z)
        \\33Z = (33B, 33B)
        \\44A = (44B, XXX)
        \\44B = (44C, 44C)
        \\44C = (44Z, 44Z)
        \\44Z = (44B, 44B)
        \\55A = (55B, XXX)
        \\55B = (55C, 55C)
        \\55C = (55Z, 55Z)
        \\55Z = (55B, 55B)
        \\66A = (66B, XXX)
        \\66B = (66C, 66C)
        \\66C = (66Z, 66Z)
        \\66Z = (66B, 66B)
    ;

    try testing.expectEqual(6, try part2(input));
}
