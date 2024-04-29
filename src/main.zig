const config = @import("config");
const std = @import("std");
const fs = std.fs;
const heap = std.heap;
const io = std.io;

const GlobalConfig = .{
    .fmt_answer_spacing = "10",
};

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer if (gpa.deinit() != .ok) @panic("Memoery leak detected");

    const stdout = io.getStdOut().writer();
    try stdout.writeByte('\n');

    // day 1
    if (config.day == 1 or config.day == 0) {
        const day1 = @import("day1.zig");

        const day1_input_file = try fs.cwd().openFile("src/inputs/day1.txt", .{});
        defer day1_input_file.close();

        const day1_input = try day1_input_file.readToEndAlloc(allocator, comptime 1024 * 1024);
        defer allocator.free(day1_input);

        // part 1
        const day1_part1_answer = day1.part1(day1_input);
        try stdout.print("Day1 Part1:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d}\n", .{ ' ', day1_part1_answer });

        // part 2
        const day1_part2_answer = day1.part2(day1_input);
        try stdout.print("Day1 Part2:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d}\n", .{ ' ', day1_part2_answer });

        try stdout.print("\n", .{});
    }

    // day 2
    if (config.day == 2 or config.day == 0) {
        const day2 = @import("day3.zig");

        const day2_input_file = try fs.cwd().openFile("src/inputs/day2.txt", .{});
        defer day2_input_file.close();

        const day2_input = try day2_input_file.readToEndAlloc(allocator, comptime 1024 * 1024);
        defer allocator.free(day2_input);

        // part 1
        const day2_part1_answer = try day2.part1(day2_input);
        try stdout.print("Day2 Part1:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d}\n", .{ ' ', day2_part1_answer });

        // part 2
        const day2_part2_answer = try day2.part2(day2_input);
        try stdout.print("Day2 Part2:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d}\n", .{ ' ', day2_part2_answer });

        try stdout.print("\n", .{});
    }

    // day 3
    if (config.day == 3 or config.day == 0) {
        const day3 = @import("day3.zig");

        const day3_input_file = try fs.cwd().openFile("src/inputs/day3.txt", .{});
        defer day3_input_file.close();

        const day3_input = try day3_input_file.readToEndAlloc(allocator, comptime 1024 * 1024);
        defer allocator.free(day3_input);

        // part 1
        const day3_part1_answer = try day3.part1(day3_input);
        try stdout.print("Day3 Part1:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d}\n", .{ ' ', day3_part1_answer });

        // part 2
        const day3_part2_answer = try day3.part2(day3_input);
        try stdout.print("Day3 Part2:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d} (wrong)\n", .{ ' ', day3_part2_answer });

        try stdout.print("\n", .{});
    }

    // day 4
    if (config.day == 4 or config.day == 0) {
        const day4 = @import("day4.zig");

        const day4_input_file = try fs.cwd().openFile("src/inputs/day4.txt", .{});
        defer day4_input_file.close();

        const day4_input = try day4_input_file.readToEndAlloc(allocator, comptime 1024 * 1024);
        defer allocator.free(day4_input);

        // part 1
        const day4_part1_answer = day4.part1(day4_input);
        try stdout.print("Day4 Part1:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d}\n", .{ ' ', day4_part1_answer });

        // part 2
        const day4_part2_answer = try day4.part2(day4_input, day4.max_cards);
        try stdout.print("Day4 Part2:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d}\n", .{ ' ', day4_part2_answer });

        try stdout.print("\n", .{});
    }

    // day 5
    if (config.day == 5 or config.day == 0) {
        const day5 = @import("day5.zig");

        const day5_input_file = try fs.cwd().openFile("src/inputs/day5.txt", .{});
        defer day5_input_file.close();

        const day5_input = try day5_input_file.readToEndAlloc(allocator, comptime 1024 * 1024);
        defer allocator.free(day5_input);

        // part 1
        const day5_part1_answer = try day5.part1(day5_input);
        try stdout.print("Day5 Part1:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d}\n", .{ ' ', day5_part1_answer });

        // part 2
        // NOTE: got the correct answer, but it's very inefficient.
        // Should have taken bottom up approch:
        // 1. Start with locations, not seeds
        // 2. First locations is 0, then count up
        // 3. Traverse the graph backwards
        // 4. If the seed is valid (in range) then you are done. It's the minimal possible location :-)

        // const day5_part2_answer = try day5.part2(day5_input);
        const day5_part2_answer = 56931769;
        // try stdout.print("Day5 Part2:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d}\n", .{ ' ', day5_part2_answer });
        try stdout.print("Day5 Part2:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d} (cached)\n", .{ ' ', day5_part2_answer });

        try stdout.print("\n", .{});
    }

    // day 6
    if (config.day == 6 or config.day == 0) {
        const day6 = @import("day6.zig");

        //const day6_input_file = try fs.cwd().openFile("src/inputs/day6.txt", .{});
        //defer day6_input_file.close();

        //const day6_input = try day6_input_file.readToEndAlloc(allocator, comptime 1024 * 1024);
        //defer allocator.free(day6_input);

        const times = [_]u64{ 47, 84, 74, 67 };
        const dists = [_]u64{ 207, 1394, 1209, 1014 };

        // part 1
        const day6_part1_answer = day6.part1(&times, &dists);
        try stdout.print("Day6 Part1:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d}\n", .{ ' ', day6_part1_answer });

        // part 2
        const time: u64 = 47_847_467;
        const dist: u64 = 207_139_412_091_014;
        const day6_part2_answer = day6.part2(time, dist);
        try stdout.print("Day6 Part2:{c:<" ++ GlobalConfig.fmt_answer_spacing ++ "}{d}\n", .{ ' ', day6_part2_answer });

        try stdout.print("\n", .{});
    }
}
