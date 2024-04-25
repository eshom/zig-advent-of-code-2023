const day1 = @import("day1.zig");
const day2 = @import("day2.zig");

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

    // day 1
    {
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
    }

    // day 2
    {
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
    }
}
