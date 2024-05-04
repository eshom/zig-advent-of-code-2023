const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const fs = std.fs;
const fmt = std.fmt;
const simd = std.simd;
const posix = std.posix;
const debug = std.debug;

const ArrayList = std.ArrayList;
const Allocator = mem.Allocator;

pub fn inputVecLen(path: []const u8) comptime_int {
    const contents = @embedFile(path);
    var line_it = mem.tokenizeScalar(u8, contents, '\n');
    const line = line_it.next().?;
    var num_it = mem.tokenizeScalar(u8, line, ' ');
    var count = 0;
    while (num_it.next()) |_| {
        count += 1;
    }
    return count;
}

test "comptime count of numbers in input" {
    std.debug.print("\n", .{});
    try testing.expectEqual(21, inputVecLen("inputs/day9.txt"));
}

pub fn readInput(allocator: Allocator, path: []const u8) ![]const u8 {
    const f = try fs.cwd().openFile(path, .{});
    const reader = f.reader();
    const contents = try reader.readAllAlloc(allocator, comptime 1024 * 1024);
    return contents;
}

fn vecFromLine(line: []const u8, vec_len: comptime_int) !@Vector(vec_len, i64) {
    var num_it = mem.tokenizeScalar(u8, line, ' ');
    var arr: [vec_len]i64 = undefined;
    var idx: usize = 0;
    while (num_it.next()) |num| : (idx += 1) {
        arr[idx] = try fmt.parseInt(i64, num, 10);
    }

    const vec: @Vector(vec_len, i64) = arr;
    return vec;
}

test "comptime vector from input" {
    std.debug.print("\n", .{});
    try posix.chdir("src");
    const input_path = "inputs/day9.txt";
    const vec_len = inputVecLen(input_path);
    const contents = try readInput(testing.allocator, input_path);
    defer testing.allocator.free(contents);
    var line_it = mem.tokenizeScalar(u8, contents, '\n');
    const line = line_it.next().?;

    const vec = try vecFromLine(line, vec_len);

    try testing.expectEqual(21, simd.countTrues(vec == @Vector(vec_len, i64){ 4, 7, 14, 17, 8, -3, 40, 284, 1054, 3047, 7774, 18514, 42224, 93097, 198790, 410780, 820904, 1587039, 2972406, 5405827, 9575760 }));
}

test "example input" {
    std.debug.print("\n", .{});
    const input =
        \\0 3 6 9 12 15
        \\1 3 6 10 15 21
        \\10 13 16 21 30 45
    ;

    var line_it = mem.tokenizeScalar(u8, input, '\n');
    const vec0 = try vecFromLine(line_it.next().?, 6);
    const vec1 = try vecFromLine(line_it.next().?, 6);
    const vec2 = try vecFromLine(line_it.next().?, 6);

    try testing.expectEqual(@Vector(6, i64){ 0, 3, 6, 9, 12, 15 }, vec0);
    try testing.expectEqual(@Vector(6, i64){ 1, 3, 6, 10, 15, 21 }, vec1);
    try testing.expectEqual(@Vector(6, i64){ 10, 13, 16, 21, 30, 45 }, vec2);
}

fn diffRight(vec: anytype) @TypeOf(vec) {
    const shift = simd.shiftElementsRight(vec, 1, 0);
    return vec - shift;
}

fn diffLeft(vec: anytype, len: comptime_int) @TypeOf(vec) {
    const shift = simd.shiftElementsLeft(vec, 1, 0);
    const sign_arr = [_]i64{-1} ** len;
    const sign_vec: @TypeOf(vec) = sign_arr;
    return (vec - shift) * sign_vec;
}

test "vector diff" {
    const vec = @Vector(6, i64){ 0, 3, 6, 9, 12, 15 };
    const diff = diffRight(vec);
    const expected = @TypeOf(vec){ 0, 3, 3, 3, 3, 3 };

    try testing.expectEqual(expected, diff);
}

fn diffSeries(allocator: Allocator, vec: anytype, len: comptime_int) !ArrayList(@TypeOf(vec)) {
    var list = ArrayList(@TypeOf(vec)).init(allocator);
    try list.append(vec);

    var diff_count: usize = 1;
    while (true) : (diff_count += 1) {
        debug.assert(diff_count < len);
        const diff = diffRight(list.getLast());
        try list.append(diff);
        const arr: [len]i64 = diff;
        const zero_check: []const i64 = arr[diff_count..len];
        for (zero_check) |zero| {
            if (zero != 0) break;
        } else {
            break;
        }
    }

    return list;
}

test "diff series" {
    std.debug.print("\n", .{});
    const vec = @Vector(6, i64){ 0, 3, 6, 9, 12, 15 };
    var list = try diffSeries(testing.allocator, vec, 6);
    defer list.deinit();
    try testing.expectEqual(@Vector(6, i64){ 0, 3, 6, 9, 12, 15 }, list.items[0]);
    try testing.expectEqual(@Vector(6, i64){ 0, 3, 3, 3, 3, 3 }, list.items[1]);
    try testing.expectEqual(@Vector(6, i64){ 0, 3, 0, 0, 0, 0 }, list.items[2]);
}

fn predict(list: anytype) i64 {
    var sum: i64 = 0;
    for (list.items) |vec| {
        const cev = simd.reverseOrder(vec);
        sum += cev[0];
    }

    return sum;
}

pub fn part1(input: []const u8, line_len: comptime_int, vec_len: comptime_int) !i64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var line_it = mem.tokenizeScalar(u8, input, '\n');
    var list_arr: [line_len]ArrayList(@Vector(vec_len, i64)) = undefined;
    var idx: usize = 0;
    while (line_it.next()) |line| : (idx += 1) {
        list_arr[idx] = try diffSeries(allocator, try vecFromLine(line, vec_len), vec_len);
    }

    defer {
        for (list_arr) |list| {
            list.deinit();
        }
    }

    var sum: i64 = 0;
    for (list_arr) |list| {
        sum += predict(list);
    }

    return sum;
}

test "example part 1" {
    std.debug.print("\n", .{});
    const input =
        \\0 3 6 9 12 15
        \\1 3 6 10 15 21
        \\10 13 16 21 30 45
    ;

    const answer = part1(input, 3, 6);
    try testing.expectEqual(114, answer);
}

fn predict2(list: anytype) i64 {
    var sum: i64 = 0;
    var items_rev = mem.reverseIterator(list.items);
    _ = items_rev.next(); // discard zero vec because sum is initalized to 0
    while (items_rev.next()) |vec| {
        sum = vec[0] - sum;
    }

    return sum;
}

fn diffSeries2(allocator: Allocator, vec: anytype, len: comptime_int) !ArrayList(@TypeOf(vec)) {
    var list = ArrayList(@TypeOf(vec)).init(allocator);
    try list.append(vec);

    var diff_count: usize = 1;
    while (true) : (diff_count += 1) {
        debug.assert(diff_count < len);
        const diff = diffLeft(list.getLast(), len);
        try list.append(diff);
        const arr: [len]i64 = diff;
        const zero_check: []const i64 = arr[0 .. len - diff_count];
        for (zero_check) |zero| {
            if (zero != 0) break;
        } else {
            break;
        }
    }

    return list;
}

pub fn part2(input: []const u8, line_len: comptime_int, vec_len: comptime_int) !i64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var line_it = mem.tokenizeScalar(u8, input, '\n');
    var list_arr: [line_len]ArrayList(@Vector(vec_len, i64)) = undefined;
    var idx: usize = 0;
    while (line_it.next()) |line| : (idx += 1) {
        list_arr[idx] = try diffSeries2(allocator, try vecFromLine(line, vec_len), vec_len);
    }

    defer {
        for (list_arr) |list| {
            list.deinit();
        }
    }

    var sum: i64 = 0;
    for (list_arr) |list| {
        sum += predict2(list);
    }

    return sum;
}

test "example part 2" {
    std.debug.print("\n", .{});
    const input =
        \\0 3 6 9 12 15
        \\1 3 6 10 15 21
        \\10 13 16 21 30 45
    ;

    const answer = part2(input, 3, 6);
    try testing.expectEqual(2, answer);
}
