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

    const map = try NetworkMap.init(testing.allocator, input);
    defer map.deinit();

    const start_keys = try map.nodesEndWith(testing.allocator, 'A');
    defer testing.allocator.free(start_keys);

    const map_arr = try testing.allocator.alloc(*NetworkMap, start_keys.len);
    defer testing.allocator.free(map_arr);
    for (map_arr) |*m| {
        m.* = try NetworkMap.init(testing.allocator, input);
    }
    defer {
        for (map_arr) |m| {
            m.deinit();
        }
    }

    const threads_done = try testing.allocator.alloc(atomic.Value(bool), start_keys.len);
    defer testing.allocator.free(threads_done);
    for (threads_done) |*td| {
        td.store(false, .monotonic);
    }

    const threads_end = try testing.allocator.alloc(atomic.Value(bool), start_keys.len);
    defer testing.allocator.free(threads_end);
    for (threads_done) |*thren| {
        thren.store(false, .monotonic);
    }

    const threads_error = try testing.allocator.alloc(atomic.Value(bool), start_keys.len);
    defer testing.allocator.free(threads_error);
    for (threads_error) |*te| {
        te.store(false, .monotonic);
    }

    var all_done = atomic.Value(bool).init(false);
    var all_on_same_step = atomic.Value(bool).init(false);
    var force_exit = atomic.Value(bool).init(false);

    const n_threads = comptime 7;
    assert(n_threads >= map_arr.len);

    // const threads = [n_threads]Thread;
    const threads = try testing.allocator.alloc(Thread, start_keys.len);
    defer testing.allocator.free(threads);

    //TODO: Try atomic visit count
    for (threads, 0.., map_arr) |*th, idx, m| {
        th.* = Thread.spawn(.{}, travelStepsThread, .{
            idx,
            m,
            start_keys[idx],
            'Z',
            &threads_done[idx],
            &threads_end[idx],
            &threads_error[idx],
            &all_done,
            &all_on_same_step,
            &force_exit,
        }) catch {
            force_exit.store(true, .monotonic);
            break;
        };
    }

    // update shared memory
    var all_done_check = false;
    var all_on_same_step_check = false;
    while (true) {
        //     for (map_arr, 0..) |m, id| {
        //         std.debug.print("Thread {d}: visit count: {d}, local_done? {any}, global_done? {any}\n", .{
        //             id,
        //             m.visit_count,
        //             all_done.load(.monotonic),
        //             all_on_same_step.load(.monotonic),
        //         });
        //     }

        // std.debug.print("main: addr local done: {*}\n", .{&all_done});
        time.sleep(500 * time.ns_per_ms); // NOTE: Adjust for performance

        // Check for thread error
        for (threads_error) |err| {
            if (err.load(.monotonic)) {
                force_exit.store(true, .monotonic);
                break;
            }
        }

        // are all threads on local end point?
        all_done_check = true;
        for (threads_done) |done| {
            all_done_check = all_done_check and done.load(.monotonic);
        }

        if (all_done_check) {
            // are all threads on the same step? (end condition)
            // all_on_same_step_check = true;
            // var prev_t_step: usize = map_arr[0].visit_count;
            // for (map_arr[1..]) |m| {
            //     const vc = m.visit_count;
            //     all_on_same_step_check = all_on_same_step_check and prev_t_step == vc;
            //     prev_t_step = vc;
            // }

            all_on_same_step_check = true;
            for (threads_end) |end| {
                all_on_same_step_check = all_on_same_step_check and end.load(.monotonic);
                std.debug.print("Main: On end per thread?  {any}\n", .{end.load(.monotonic)});
            }

            // if this is true we can signal threads to stop
            if (all_on_same_step_check) {
                all_on_same_step.store(true, .monotonic);
                all_done.store(true, .monotonic);
                break; // All that's left is to wait for threads to finish
            } else {
                // After this threads should continue to next step
                all_done.store(true, .monotonic);
            }
        }
    }

    for (threads) |t| {
        t.join();
    }

    for (map_arr, 0..) |m, id| {
        std.debug.print("Thread {d}: visit count: {d}\n", .{ id, m.visit_count });
    }
}

// Thread related params:
// `step` - Thread updates the step it is on. Main initializes to 0.
// `done` - Thread updates when it found local end point
// `error_signal` - Thread signals if it encounters some error
// `all_done` - Main thread updates when all threads are sleeping on local end point
// `all_on_same_step` - Main thread updates when all threads are done on the same step
// This is the condition for thread to finish execution
// `force_exit` - Main thread signals if thread must exit early
fn travelStepsThread(
    id: usize,
    nmap: *NetworkMap, // visit_count gets updated, it's not thread safe but worst case main will wait a bit longer
    from: []const u8,
    to_char: u8,
    done: *atomic.Value(bool),
    on_end_point: *atomic.Value(bool),
    error_signal: *atomic.Value(bool),
    all_done: *const atomic.Value(bool),
    all_on_same_step: *const atomic.Value(bool),
    force_exit: *const atomic.Value(bool),
) void {
    var key = from;
    while (true) {
        std.debug.print("Thread {d}: On step? {d}, done? {any}, on end? {any}\n", .{
            id,
            nmap.visit_count,
            done.load(.monotonic),
            on_end_point.load(.monotonic),
        });
        time.sleep(500 * time.ns_per_ms); // slow down for debug
        // std.debug.print("thread: addr local done: {*}\n", .{all_done});
        key = nmap.visit(key) catch {
            error_signal.store(true, .monotonic);
            return;
        };

        // signal thread is done with step
        if (key[2] == to_char) {
            on_end_point.store(true, .monotonic);
        } else {
            on_end_point.store(false, .monotonic);
        }
        done.store(true, .monotonic);

        // Wait for others to finish with step
        while (!all_done.load(.monotonic)) {
            std.debug.print("Thread {d}: waiting at step {d}\n", .{ id, nmap.visit_count });
            time.sleep(500 * time.ns_per_ms); //NOTE: adjust for performance
            if (force_exit.load(.monotonic)) return;
        }

        // At this point we are done, are all on their end points?
        // return condition
        if (all_on_same_step.load(.monotonic)) {
            return;
        }
    }
}
