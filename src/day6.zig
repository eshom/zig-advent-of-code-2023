const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;

fn possibleWins(time: u64, dist: u64) u64 {
    // std.debug.print("\n", .{});
    var out: u64 = 0;
    var fwd: u64 = 0;
    var bwd: u64 = time;
    while (fwd < time) : ({
        fwd += 1;
        bwd -= 1;
    }) {
        // std.debug.print("fwd: {d}, bwd: {d}, fwd*bwd: {d}, abs(bwd-fwd): {d}, win: {any}\n", .{ fwd, bwd, fwd * bwd, if (bwd >= fwd) bwd - fwd else fwd - bwd, (bwd * fwd) > dist });
        out += if ((fwd * bwd) > dist) 1 else 0;
    }
    return out;
}

pub fn part1(time: []const u64, dist: []const u64) u64 {
    assert(time.len == dist.len);
    var answer: u64 = 1;
    for (time, dist) |t, d| {
        answer *= possibleWins(t, d);
    }
    return answer;
}

test "part 1 example" {
    std.debug.print("\n", .{});
    const race1 = possibleWins(7, 9);
    const race2 = possibleWins(15, 40);
    const race3 = possibleWins(30, 200);
    try testing.expectEqual(4, race1);
    try testing.expectEqual(8, race2);
    try testing.expectEqual(9, race3);
    try testing.expectEqual(288, part1(&[_]u64{ 7, 15, 30 }, &[_]u64{ 9, 40, 200 }));
}

// mid point is always a win, so we can go backwards and forwards from there
fn possibleWins2(time: u64, dist: u64) u64 {
    // std.debug.print("\n", .{});
    const mid: u64 = time >> 1;
    var out: u64 = 0;
    var fwd: u64 = mid + 1;
    var bwd: u64 = if (time % 2 == 0) mid - 1 else mid;
    // var done: bool = false;
    while (fwd < time) : ({
        fwd += 1;
        bwd -= 1;
    }) {
        // std.debug.print("mid: {d}, fwd: {d}, bwd: {d}, fwd*bwd: {d}, abs(bwd-fwd): {d}, win: {any}\n", .{ mid, fwd, bwd, fwd * bwd, if (bwd >= fwd) bwd - fwd else fwd - bwd, (bwd * fwd) > dist });
        if (fwd * bwd > dist) {
            out += 1;
        } else {
            return if (mid * 2 == time) out * 2 + 1 else out * 2;
        }
    }
    return out;
}

pub fn part2(time: u64, dist: u64) u64 {
    return possibleWins2(time, dist);
}

test "part 1+2 example" {
    std.debug.print("\n", .{});
    const race1 = possibleWins2(7, 9);
    const race2 = possibleWins2(15, 40);
    const race3 = possibleWins2(30, 200);
    const race4 = possibleWins2(71530, 940200);
    try testing.expectEqual(4, race1);
    try testing.expectEqual(8, race2);
    try testing.expectEqual(9, race3);
    try testing.expectEqual(71503, race4);
    try testing.expectEqual(71503, part2(71530, 940200));
}
