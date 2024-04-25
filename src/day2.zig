const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const t = std.testing;
const debug = std.debug;
const fs = std.fs;
const fmt = std.fmt;

const Globals = struct {
    max_draws: comptime_int,
    max_games: comptime_int,
    max_cubes: CubeSet = .{ .red = 12, .green = 13, .blue = 14 },
};

pub const globals = getInputMaxGamesDraws();

fn getInputMaxGamesDraws() Globals {
    comptime var max_draws = 0;
    comptime var max_games = 0;

    @setEvalBranchQuota(100000);
    defer @setEvalBranchQuota(1000);
    const input = @embedFile("inputs/day2.txt");
    var iter = mem.splitScalar(u8, input, '\n');

    while (iter.next()) |line| : (max_games += 1) {
        const sm_count = mem.count(u8, line, ";");
        max_draws = @max(sm_count, max_draws);
    }

    max_games -= 1;
    max_draws += 1;
    return .{ .max_draws = max_draws, .max_games = max_games };
}

const CubeSet = struct {
    red: usize = 0,
    green: usize = 0,
    blue: usize = 0,

    fn power(self: *const CubeSet) u64 {
        return @as(u64, self.red) * @as(u64, self.green) * @as(u64, self.blue);
    }
};

const Game = struct {
    id: usize,
    draws: usize = 0,
    cubes: [globals.max_draws]CubeSet,

    fn possibleGame(self: *const Game) bool {
        const colors = comptime [_][]const u8{ "red", "green", "blue" };

        inline for (colors) |col| {
            for (self.cubes) |set| {
                const possible = @field(set, col) <= @field(globals.max_cubes, col);
                if (possible) continue else return false;
            }
        }

        return true;
    }

    fn minCubeSet(self: *const Game) CubeSet {
        const colors = comptime [_][]const u8{ "red", "green", "blue" };
        var max = CubeSet{};

        inline for (colors) |col| {
            for (self.cubes) |set| {
                @field(max, col) = @max(@field(max, col), @field(set, col));
            }
        }

        return max;
    }
};

pub fn part1(input: []const u8) !u64 {
    var lineit = mem.splitScalar(u8, input, '\n');
    var game_buf: [globals.max_games]Game = undefined;

    var game_count: usize = 0;
    while (lineit.next()) |line| : (game_count += 1) {
        if (line.len == 0) continue;
        game_buf[game_count] = try parseGame(line);
    }
    game_count -= 1;

    const games = game_buf[0..game_count];
    var sum: u64 = 0;
    for (games) |game| {
        sum += if (game.possibleGame()) game.id else 0;
    }

    return sum;
}

pub fn part2(input: []const u8) !u64 {
    var lineit = mem.splitScalar(u8, input, '\n');
    var game_buf: [globals.max_games]Game = undefined;

    var game_count: usize = 0;
    while (lineit.next()) |line| : (game_count += 1) {
        if (line.len == 0) continue;
        game_buf[game_count] = try parseGame(line);
    }
    game_count -= 1;

    const games = game_buf[0..game_count];
    var sum: u64 = 0;
    for (games) |game| {
        sum += game.minCubeSet().power();
    }

    return sum;
}

fn parseGame(game_line: []const u8) !Game {
    // std.debug.print("~~GAME START~~\n", .{});
    assert(game_line.len > 0);

    var gameit = mem.splitScalar(u8, game_line, ':');

    var idit = mem.splitScalar(u8, gameit.first(), ' ');
    _ = idit.next();
    const id = try fmt.parseInt(usize, idit.next().?, 10);

    var drawit = mem.splitScalar(u8, gameit.next().?, ';');

    var out = Game{
        .id = id,
        .draws = 0,
        .cubes = [_]CubeSet{.{ .red = 0, .green = 0, .blue = 0 }} ** globals.max_draws,
    };

    while (drawit.next()) |draw| {
        // std.debug.print("~~DRAW~~\n", .{});
        defer out.draws += 1;
        var cubit = mem.splitScalar(u8, draw, ',');
        while (cubit.next()) |cube| {
            const red = mem.indexOf(u8, cube, "red");
            if (red != null) {
                out.cubes[out.draws].red = try fmt.parseInt(usize, std.mem.trim(u8, cube[0..red.?], " "), 10);
                continue;
            }
            const green = mem.indexOf(u8, cube, "green");
            if (green != null) {
                out.cubes[out.draws].green = try fmt.parseInt(usize, std.mem.trim(u8, cube[0..green.?], " "), 10);
                continue;
            }
            const blue = mem.indexOf(u8, cube, "blue");
            if (blue != null) {
                out.cubes[out.draws].blue = try fmt.parseInt(usize, std.mem.trim(u8, cube[0..blue.?], " "), 10);
                continue;
            }
        }
    }

    return out;
}

test "parsing input" {
    std.debug.print("\n", .{});

    const input =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
    ;

    const expected = [2]Game{
        .{
            .id = 1,
            .draws = 3,
            .cubes = [globals.max_draws]CubeSet{
                .{ .blue = 3, .red = 4 },
                .{ .red = 1, .green = 2, .blue = 6 },
                .{ .green = 2 },
                .{},
                .{},
                .{},
            },
        },
        .{
            .id = 2,
            .draws = 3,
            .cubes = [globals.max_draws]CubeSet{
                .{ .blue = 1, .green = 2 },
                .{ .green = 3, .blue = 4, .red = 1 },
                .{ .green = 1, .blue = 1 },
                .{},
                .{},
                .{},
            },
        },
    };

    var actual: [2]Game = undefined;

    var iter = mem.splitScalar(u8, input, '\n');
    actual[0] = try parseGame(iter.next().?);
    actual[1] = try parseGame(iter.next().?);

    try t.expectEqualDeep(expected, actual);
}

test "example reuslt correct" {
    const input =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    const expected = 8;
    const actual = try part1(input);

    try t.expectEqual(expected, actual);
}

// test "comptime max size from input" {
//     comptime var max_count = 0;
//
//     comptime {
//         @setEvalBranchQuota(100000);
//         defer @setEvalBranchQuota(1000);
//         const input = @embedFile("inputs/day2.txt");
//         var iter = mem.splitScalar(u8, input, '\n');
//
//         while (iter.next()) |line| {
//             // @compileLog("-----\n");
//             // @compileLog(line);
//             const sm_count = mem.count(u8, line, ";");
//             max_count = if (max_count < sm_count) sm_count else max_count;
//         }
//
//         max_count += 1;
//     }
//
//     const res = try t.allocator.alloc(usize, max_count);
//     defer t.allocator.free(res);
//     @memset(res, max_count);
//
//     std.debug.print("Max draws: {any}\n", .{res});
// }
