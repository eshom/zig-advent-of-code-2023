const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const t = std.testing;
const debug = std.debug;
const fs = std.fs;
const fmt = std.fmt;
const log = std.log;
const ascii = std.ascii;
const math = std.math;

const Schematic = struct {
    allocator: mem.Allocator,
    nrow: usize,
    ncol: usize,
    parts: ?[]Part,
    layout: []const u8,

    fn init(allocator: mem.Allocator, input: []const u8) !Schematic {
        assert(input.len > 0);
        const input_clean = mem.trim(u8, input, "\n ");

        const nrow = mem.count(u8, input_clean, "\n") + 1;
        assert(nrow > 1);
        const ncol = mem.indexOf(u8, input_clean, "\n") orelse 0;
        assert(ncol > 0);

        const layout = try allocator.alloc(u8, nrow * ncol);

        var idx: usize = 0;
        for (input_clean) |in| {
            if (in != '\n') {
                layout[idx] = in;
                idx += 1;
            }
        }

        return Schematic{
            .allocator = allocator,
            .nrow = nrow,
            .ncol = ncol,
            .parts = null,
            .layout = layout,
        };
    }

    fn initParts(self: *Schematic, allocator: mem.Allocator) !void {
        const part_count = Part.countPartsFromString(self.layout);

        var partit = PartNumIterator{ .input = self.layout };

        const parts = try allocator.alloc(Part, part_count);
        var init_count: usize = 0;

        errdefer {
            for (0..init_count) |idx| {
                allocator.free(parts[idx].indice);
            }
            allocator.free(parts);
        }

        for (parts) |*part| {
            const num, const start, const end = try partit.next() orelse {
                log.err("Could not find next part number", .{});
                break;
            };
            const seq = try seqAlloc(allocator, start, end);
            init_count += 1;

            part.schema = self;
            part.part = num;
            part.indice = seq;
        }

        assert(init_count == parts.len);
        self.parts = parts;
    }

    fn deinit(self: *Schematic) void {
        if (self.parts) |par| {
            for (par) |p| {
                self.allocator.free(p.indice);
            }
            self.allocator.free(par);
        }
        self.allocator.free(self.layout);
    }

    fn get(self: *const Schematic, row: usize, col: usize) !u8 {
        if (row >= self.nrow or col >= self.ncol) {
            // log.err("Indice out of bounds. Tried: .layout[{d}][{d}] Max: .layout[{d}][{d}]", .{
            //     row,
            //     col,
            //     self.nrow - 1,
            //     self.ncol - 1,
            // });
            return error.IndexOutOfBounds;
        }

        return self.layout[row * self.ncol + col];
    }

    fn toFlatIdx(self: *const Schematic, row: usize, col: usize) usize {
        return row * self.ncol + col;
    }

    fn toMatIdx(self: *const Schematic, idx: usize) struct { usize, usize } {
        assert(self.ncol != 0);
        return .{ @divTrunc(idx, self.ncol), idx % self.ncol };
    }
};

const PartNumIterator = struct {
    input: []const u8,
    index: usize = 0,

    // returns the number, start index, end index
    fn next(self: *PartNumIterator) !?struct { u64, usize, usize } {
        var start: usize = self.index;
        var end: usize = self.input.len;

        if (start >= end) return null;

        start = mem.indexOfAnyPos(u8, self.input, start, "0123456789") orelse {
            self.index = self.input.len;
            return null;
        };

        var idx = start;
        while (ascii.isDigit(self.input[idx])) : (idx += 1) {
            if (idx == self.input.len - 1 and ascii.isDigit(self.input[idx])) {
                break;
            } else {
                continue;
            }
            unreachable;
        }

        assert(idx < self.input.len);
        end = if (idx == self.input.len - 1) idx + 1 else idx;
        self.index = end;

        return .{ try fmt.parseInt(u64, self.input[start..end], 10), start, end };
    }
};

const Part = struct {
    schema: *const Schematic,
    part: u64,
    indice: []usize, // 1D indice of part

    fn countPartsFromString(input: []const u8) usize {
        var out: usize = 0;

        var peek: u8 = 0;
        for (input, 0..) |chr, idx| {
            peek = if (idx >= input.len - 1) 0 else input[idx + 1];
            if (ascii.isDigit(chr) and !ascii.isDigit(peek)) {
                out += 1;
            }
        }

        return out;
    }

    fn symbolAdj(self: *const Part) bool {
        defer debug.print("\n", .{});
        for (self.indice) |ind| {
            const row, const col = self.schema.toMatIdx(ind);

            const neighbors = [_]u8{
                self.schema.get(@subWithOverflow(row, 1)[0], col) catch '.', // up
                self.schema.get(row + 1, col) catch '.', // down
                self.schema.get(row, @subWithOverflow(col, 1)[0]) catch '.', // left
                self.schema.get(row, col + 1) catch '.', // right
                self.schema.get(@subWithOverflow(row, 1)[0], @subWithOverflow(col, 1)[0]) catch '.', // upleft
                self.schema.get(@subWithOverflow(row, 1)[0], col + 1) catch '.', // upright
                self.schema.get(row + 1, @subWithOverflow(col, 1)[0]) catch '.', // downleft
                self.schema.get(row + 1, col + 1) catch '.', // downright
            };

            debug.print("Pos: [{d:<3}][{d:<3}]{c:<3}Neighbors: ", .{ row, col, ' ' });
            for (neighbors) |neig| {
                debug.print(" {c}", .{neig});
                if (neig != '.' and !ascii.isDigit(neig)) {
                    debug.print("\n", .{});
                    return true;
                }
            }
            debug.print("\n", .{});
        }
        return false;
    }
};

fn seqAlloc(allocator: mem.Allocator, start: usize, end: usize) ![]usize {
    assert(start < end);
    const len = end - start;
    const out = try allocator.alloc(usize, len);
    for (out, start..end) |*val, index| {
        val.* = index;
    }
    return out;
}

test "parse schematic" {
    debug.print("\n", .{});
    const input =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    var schem = try Schematic.init(t.allocator, input);
    defer schem.deinit();

    try t.expectEqual(10, schem.nrow);
    try t.expectEqual(10, schem.ncol);

    const expected = "467..114.....*........35..633.......#...617*...........+.58...592...........755....$.*.....664.598..";
    try t.expectEqualStrings(expected, schem.layout);
}

test "parse schematic newline" {
    debug.print("\n", .{});
    const input =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
        \\
    ;

    var schem = try Schematic.init(t.allocator, input);
    defer schem.deinit();

    try t.expectEqual(10, schem.nrow);
    try t.expectEqual(10, schem.ncol);

    const expected = "467..114.....*........35..633.......#...617*...........+.58...592...........755....$.*.....664.598..";
    try t.expectEqualStrings(expected, schem.layout);
}

test "get values schematic unbalanced" {
    debug.print("\n", .{});
    const input =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    var schem = try Schematic.init(t.allocator, input);
    defer schem.deinit();

    const expected_layout = "467..114.....*........35..633.......#...617*............755....$.*.....664.598..";

    try t.expectEqualStrings(expected_layout, schem.layout);

    // with get function
    var idx: usize = 0;
    for (0..schem.nrow) |row| {
        for (0..schem.ncol) |col| {
            const chr = try schem.get(row, col);
            try t.expectEqual(schem.layout[idx], chr);
            idx += 1;
        }
    }
}

test "indice conversions" {
    debug.print("\n", .{});
    const input =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    var schem = try Schematic.init(t.allocator, input);
    defer schem.deinit();

    var idx: usize = 0;
    for (0..schem.nrow) |row| {
        for (0..schem.ncol) |col| {
            const idx_converted = schem.toFlatIdx(row, col);
            try t.expectEqual(idx, idx_converted);
            const indice_converted = schem.toMatIdx(idx);
            try t.expectEqualDeep(.{ row, col }, indice_converted);
            idx += 1;
        }
    }
}

test "parsing parts minimal" {
    debug.print("\n", .{});
    const input =
        \\467..114..
        \\...*...420
    ;

    var schem = try Schematic.init(t.allocator, input);
    defer schem.deinit();

    try schem.initParts(t.allocator);

    const expected_nums = [_]u64{ 467, 114, 420 };
    const expected_indice = [_][3]usize{
        .{ 0, 1, 2 },
        .{ 5, 6, 7 },
        .{ 17, 18, 19 },
    };

    for (expected_nums, 0..) |expected, idx| {
        try t.expectEqual(expected, schem.parts.?[idx].part);
    }

    for (expected_indice, 0..) |expected, idx| {
        try t.expectEqualSlices(usize, &expected, schem.parts.?[idx].indice);
    }
}

test "full part 1 example" {
    debug.print("\n", .{});
    const input =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    var schem = try Schematic.init(t.allocator, input);
    defer schem.deinit();

    try schem.initParts(t.allocator);

    const expected: u64 = 4361;

    var sum: u64 = 0;
    for (schem.parts.?) |part| {
        sum += if (part.symbolAdj()) part.part else 0;
    }

    try t.expectEqual(expected, sum);
}

pub fn part1(input: []const u8) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var schem = try Schematic.init(allocator, input);
    defer schem.deinit();

    try schem.initParts(allocator);

    var sum: u64 = 0;
    for (schem.parts.?) |part| {
        sum += if (part.symbolAdj()) part.part else 0;
    }

    return sum;
}

test "part 1 example synthetic" {
    debug.print("\n", .{});
    const input =
        \\....$..........$....$...........
        \\.1..1.1.$1..1$..1..1..1..1......
        \\......$..............$....$.....
        \\..%..............%.....%........
        \\.10..10.%10..10%.10..10..10..10.
        \\......%.................%......%
        \\...*..................*......*..
        \\.100..100.*100..100*.100..100...
        \\........*.......................
        \\................................
        \\.100..100.......................
        \\..*......*......................
        \\................................
        \\.1.1-1.1.1.1.1.1.1.1.1.1.1.1.1.1
        \\................................
        \\100.100.100.100-100.100.100.100.
        \\................................
        \\.1..............................
        \\111.............................
        \\.1..............................
        \\................................
        \\................................
        \\................................
    ;

    var schem = try Schematic.init(t.allocator, input);
    defer schem.deinit();

    try schem.initParts(t.allocator);

    const expected: u64 = 1090;

    var sum: u64 = 0;
    for (schem.parts.?) |part| {
        sum += if (part.symbolAdj()) part.part else 0;
    }

    try t.expectEqual(expected, sum);
}
