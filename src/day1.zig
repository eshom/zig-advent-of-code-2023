const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const t = std.testing;
const debug = std.debug;

const DigitStr = enum(u8) {
    one = 1,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
};

// const DigitStrReverse = enum(u8) {
//     eno = 1,
//     owt,
//     eerht,
//     ruof,
//     evif,
//     xis,
//     neves,
//     thgie,
//     enie,
// };

// return first digit in line, and last digit in line
fn findDigits(input: []const u8) error{EmptyLine}!struct { u8, u8 } {
    if (input.len == 0) return error.EmptyLine;
    // check input is one line as expected here
    assert(input.len > 0);
    assert(mem.count(u8, input, "\n") <= 1);

    const ind1 = mem.indexOfAny(u8, input, "123456789").?;
    const ind2 = mem.lastIndexOfAny(u8, input, "123456789").?;

    return .{ input[ind1] - '0', input[ind2] - '0' };
}

fn findDigits2(input: []const u8) error{EmptyLine}!struct { u8, u8 } {
    if (input.len == 0) return error.EmptyLine;
    // check input is one line as expected here
    assert(input.len > 0);
    assert(mem.count(u8, input, "\n") <= 1);

    const ind1 = mem.indexOfAny(u8, input, "123456789") orelse std.math.maxInt(usize);
    const ind2 = mem.lastIndexOfAny(u8, input, "123456789") orelse 0;

    var str_ind1: usize = std.math.maxInt(usize);
    var str_val1: u8 = 0;
    var str_ind2: usize = 0;
    var str_val2: u8 = 0;
    inline for (std.meta.fields(DigitStr)) |field| {
        const tmp_ind1 = mem.indexOf(u8, input, field.name);
        if (tmp_ind1 != null and tmp_ind1.? < str_ind1) {
            str_val1 = field.value;
            str_ind1 = tmp_ind1.?;
        }

        const tmp_ind2 = mem.lastIndexOf(u8, input, field.name);
        if (tmp_ind2 != null and tmp_ind2.? >= str_ind2) {
            str_val2 = field.value;
            str_ind2 = tmp_ind2.?;
        }
    }

    const out1: u8 = if (ind1 < str_ind1) input[ind1] - '0' else str_val1;
    const out2: u8 = if (ind2 > str_ind2) input[ind2] - '0' else str_val2;

    return .{ out1, out2 };
}

fn caliVal(digits: struct { u8, u8 }) u8 {
    return digits[0] * 10 + digits[1];
}

pub fn part1(input: []const u8) u64 {
    var line_iter = mem.splitScalar(u8, input, '\n');
    var sum: u64 = 0;

    var idx: usize = 0;
    while (line_iter.next()) |line| : (idx += 1) {
        const cali = caliVal(findDigits(line) catch continue);
        sum += cali;
    }

    return sum;
}

pub fn part2(input: []const u8) u64 {
    var line_iter = mem.splitScalar(u8, input, '\n');
    var sum: u64 = 0;

    var idx: usize = 0;
    while (line_iter.next()) |line| : (idx += 1) {
        const cali = caliVal(findDigits2(line) catch continue);
        sum += cali;
    }

    return sum;
}

test "example 1 parsing" {
    debug.print("\n", .{});

    const input =
        \\1abc2
        \\pqr3stu8vwx
        \\a1b2c3d4e5f
        \\treb7uchet
    ;

    const expected = [_]u8{ 12, 38, 15, 77 };
    var actual: [4]u8 = undefined;

    var line_iter = mem.splitScalar(u8, input, '\n');

    while (line_iter.next()) |line| {
        debug.print("{s}\n", .{line});
    }

    line_iter.reset();

    while (line_iter.next()) |line| {
        debug.print("{any}\n", .{findDigits(line) catch continue});
    }

    line_iter.reset();

    var idx: usize = 0;
    while (line_iter.next()) |line| : (idx += 1) {
        const cali = caliVal(findDigits(line) catch continue);
        actual[idx] = cali;
    }

    try t.expectEqualSlices(u8, &expected, &actual);
}

test "example 1" {
    const input =
        \\1abc2
        \\pqr3stu8vwx
        \\a1b2c3d4e5f
        \\treb7uchet
    ;

    const expected = 142;
    const actual = part1(input);

    try t.expectEqual(expected, actual);
}

test "example 2" {
    const input =
        \\two1nine
        \\eightwothree
        \\abcone2threexyz
        \\xtwone3four
        \\4nineeightseven2
        \\zoneight234
        \\7pqrstsixteenV
    ;

    const expected = 281;
    const actual = part2(input);

    try t.expectEqual(expected, actual);
}
