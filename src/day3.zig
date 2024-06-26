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

const Neighbors = struct {
    up: ?usize,
    down: ?usize,
    left: ?usize,
    right: ?usize,
    upleft: ?usize,
    upright: ?usize,
    downleft: ?usize,
    downright: ?usize,

    fn array(self: *const Neighbors) [8]?usize {
        return [8]?usize{
            self.up,
            self.down,
            self.left,
            self.right,
            self.upleft,
            self.upright,
            self.downleft,
            self.downright,
        };
    }
};

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
        const part_count = Part.countPartsFromString(self);

        var partit = PartNumIterator{ .input = self.layout, .schema = self };

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

        if (try partit.next()) |val| {
            log.err("Got unexpected extra part number: {d}\n", .{val.@"0"});
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

    fn neighborInd(self: *const Schematic, row: usize, col: usize) Neighbors {
        const up: ?usize = math.sub(usize, row, 1) catch null;
        const left: ?usize = math.sub(usize, col, 1) catch null;
        const right: ?usize = if (col + 1 >= self.ncol) null else col + 1;
        const down: ?usize = if (row + 1 >= self.nrow) null else row + 1;
        return .{
            .up = if (up) |val| self.toFlatIdx(val, col) else null,
            .down = if (down) |val| self.toFlatIdx(val, col) else null,
            .left = if (left) |val| self.toFlatIdx(row, val) else null,
            .right = if (right) |val| self.toFlatIdx(row, val) else null,
            .upleft = if (up != null and left != null) self.toFlatIdx(up.?, left.?) else null,
            .upright = if (up != null and right != null) self.toFlatIdx(up.?, right.?) else null,
            .downleft = if (down != null and left != null) self.toFlatIdx(down.?, left.?) else null,
            .downright = if (down != null and right != null) self.toFlatIdx(down.?, right.?) else null,
        };
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
    schema: *const Schematic,
    input: []const u8,
    index: usize = 0,

    // returns the number, start index, end index
    fn next(self: *PartNumIterator) !?struct { u64, usize, usize } {
        var start: usize = self.index;

        if (start >= self.input.len) return null;

        start = mem.indexOfAnyPos(u8, self.input, start, "0123456789") orelse {
            self.index = self.input.len;
            return null;
        };

        // get start row and column to detect wrap around
        const start_row, const start_col = self.schema.toMatIdx(start);
        _ = start_col;

        // There are no part numbers with more than 3 digits
        var end: usize = start;
        var loop_local_end: usize = end;
        for (0..3) |_| {
            defer end = loop_local_end;
            loop_local_end = end + 1;
            const row, _ = self.schema.toMatIdx(loop_local_end);

            if (loop_local_end >= self.input.len) break;
            if (start_row != row) break; // wrap around

            if (!ascii.isDigit(self.input[loop_local_end])) {
                break;
            }
        }
        assert(end <= self.input.len);
        self.index = end;

        const final = self.input[start..end];

        return .{ try fmt.parseInt(u64, final, 10), start, end };
    }
};

const Part = struct {
    schema: *const Schematic,
    part: u64,
    indice: []usize, // 1D indice of part

    fn countPartsFromString(schem: *const Schematic) usize {
        const input = schem.layout;
        var out: usize = 0;

        var idx: usize = 0;
        // var prev_row: usize = 0;
        // var row, _ = schem.toMatIdx(idx);
        while (idx < input.len) : (idx += 1) {
            // prev_row = row;
            if (ascii.isDigit(input[idx])) {
                out += 1;

                while (idx < input.len and ascii.isDigit(input[idx])) : (idx += 1) {
                    // make sure not to skip numbers that start new rows
                    _, const col = schem.toMatIdx(idx);
                    if (col >= schem.ncol - 1) break;
                }
            }
        }
        return out;
    }

    fn symbolAdj(self: *const Part) bool {
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

            for (neighbors) |neig| {
                if (neig != '.' and !ascii.isDigit(neig)) {
                    return true;
                }
            }
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

    errdefer debug.print("\n{s}\n\n", .{input});

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

    errdefer debug.print("\n{s}\n\n", .{input});

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

    errdefer debug.print("\n{s}\n\n", .{input});

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

    errdefer debug.print("\n{s}\n\n", .{input});

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

    errdefer debug.print("\n{s}\n\n", .{input});

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

test "parsing parts minimal2" {
    debug.print("\n", .{});
    const input =
        \\467..114..
        \\...*...420
        \\776.......
    ;

    errdefer debug.print("\n{s}\n\n", .{input});

    var schem = try Schematic.init(t.allocator, input);
    defer schem.deinit();

    try schem.initParts(t.allocator);

    const expected_nums = [_]u64{ 467, 114, 420, 776 };
    const expected_indice = [_][3]usize{
        .{ 0, 1, 2 },
        .{ 5, 6, 7 },
        .{ 17, 18, 19 },
        .{ 20, 21, 22 },
    };

    try t.expectEqual(4, schem.parts.?.len);

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

    errdefer debug.print("\n{s}\n\n", .{input});

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

test "should not wrap" {
    debug.print("\n", .{});
    const input =
        \\.........*1
        \\0..........
    ;
    errdefer debug.print("\n{s}\n\n", .{input});

    var schem = try Schematic.init(t.allocator, input);
    defer schem.deinit();

    try schem.initParts(t.allocator);

    const expected: u64 = 1;

    var sum: u64 = 0;
    for (schem.parts.?) |part| {
        sum += if (part.symbolAdj()) part.part else 0;
    }

    try t.expectEqual(expected, sum);
}

test "try to detect more edge cases making me fail day 3" {
    debug.print("\n", .{});
    const input =
        \\1.2.3.33.4
        \\22..55*...
        \\..........
        \\9.........
        \\8.........
        \\777.......
        \\..........
        \\..........
        \\..........
        \\..........
    ;
    errdefer debug.print("\n{s}\n\n", .{input});

    var schem = try Schematic.init(t.allocator, input);
    defer schem.deinit();

    try schem.initParts(t.allocator);

    const expected = [_]u64{ 1, 2, 3, 33, 4, 22, 55, 9, 8, 777 };

    const actual = try t.allocator.alloc(u64, schem.parts.?.len);
    defer t.allocator.free(actual);

    for (actual, 0..) |*act, idx| {
        act.* = schem.parts.?[idx].part;
    }

    try t.expectEqualSlices(u64, &expected, actual);
}

test "neighbor indice" {
    debug.print("\n", .{});
    const input =
        //0123456789
        \\*0..*1..2*
        \\..........
        \\..........
        \\*3..*4..5*
    ;
    errdefer debug.print("\n{s}\n\n", .{input});

    var schem = try Schematic.init(t.allocator, input);
    defer schem.deinit();

    try schem.initParts(t.allocator);

    const expected = [_]Neighbors{
        .{ //0,0
            .up = null,
            .down = 10,
            .left = null,
            .right = 1,
            .upleft = null,
            .upright = null,
            .downleft = null,
            .downright = 11,
        },
        .{ //0,4
            .up = null,
            .down = 14,
            .left = 3,
            .right = 5,
            .upleft = null,
            .upright = null,
            .downleft = 13,
            .downright = 15,
        },
        .{ //0,9
            .up = null,
            .down = 19,
            .left = 8,
            .right = null,
            .upleft = null,
            .upright = null,
            .downleft = 18,
            .downright = null,
        },
        .{ //3,0
            .up = 20,
            .down = null,
            .left = null,
            .right = 31,
            .upleft = null,
            .upright = 21,
            .downleft = null,
            .downright = null,
        },
        .{ //3,4
            .up = 24,
            .down = null,
            .left = 33,
            .right = 35,
            .upleft = 23,
            .upright = 25,
            .downleft = null,
            .downright = null,
        },
        .{ //3,9
            .up = 29,
            .down = null,
            .left = 38,
            .right = null,
            .upleft = 28,
            .upright = null,
            .downleft = null,
            .downright = null,
        },
    };

    const actual = [_]Neighbors{
        schem.neighborInd(0, 0),
        schem.neighborInd(0, 4),
        schem.neighborInd(0, 9),
        schem.neighborInd(3, 0),
        schem.neighborInd(3, 4),
        schem.neighborInd(3, 9),
    };

    try t.expectEqualDeep(expected, actual);
}

test "part 2 example" {
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

    errdefer debug.print("\n{s}\n\n", .{input});

    var schem = try Schematic.init(t.allocator, input);
    defer schem.deinit();

    try schem.initParts(t.allocator);

    const expected: u64 = 467835;

    const gears_ind = try gearsInds(t.allocator, &schem);
    defer t.allocator.free(gears_ind);

    try t.expectEqualSlices(usize, &[_]usize{ 13, 43, 85 }, gears_ind);

    const gears_ind_mat = [_]struct { usize, usize }{
        schem.toMatIdx(gears_ind[0]),
        schem.toMatIdx(gears_ind[1]),
        schem.toMatIdx(gears_ind[2]),
    };

    const gear_neighs = [_]Neighbors{
        schem.neighborInd(gears_ind_mat[0].@"0", gears_ind_mat[0].@"1"),
        schem.neighborInd(gears_ind_mat[1].@"0", gears_ind_mat[1].@"1"),
        schem.neighborInd(gears_ind_mat[2].@"0", gears_ind_mat[2].@"1"),
    };

    var actual: u64 = 0;

    const found_gear_parts = try findGearPartNums(t.allocator, &schem, &gear_neighs);
    defer t.allocator.free(found_gear_parts);

    for (found_gear_parts) |parts_maybe| {
        if (parts_maybe) |part| {
            actual += part[0] * part[1];
        }
    }

    try t.expectEqual(expected, actual);
}

// Caller should free memory
fn gearsInds(allocator: mem.Allocator, schema: *const Schematic) ![]usize {
    const gear_count = mem.count(u8, schema.layout, "*");
    const gears_index = try allocator.alloc(usize, gear_count);
    var start: usize = 0;
    for (gears_index) |*ind| {
        if (mem.indexOfScalarPos(u8, schema.layout, start, '*')) |found| {
            ind.* = found;
            start = found + 1;
        } else {
            break;
        }
    }

    return gears_index;
}

fn findGearPartNums(
    allocator: mem.Allocator,
    schema: *const Schematic,
    gear_neighbors: []const Neighbors,
) ![]?[2]u64 {
    const out = try allocator.alloc(?[2]u64, gear_neighbors.len);
    for (gear_neighbors, 0..) |neigh, outer_idx| {
        var part_count: usize = 0;
        var found_nums = [2]u64{ 0, 0 };

        const indice = neigh.array();
        for (indice) |ind| {
            if (ind == null) continue;

            for (schema.parts.?) |part| {
                if (mem.indexOfScalar(usize, part.indice, ind.?) != null) {
                    if (part_count >= 2) break;
                    found_nums[part_count] = part.part;
                    part_count += 1;
                }
            }
        }
        assert(part_count <= 2);
        if (part_count == 2) {
            out[outer_idx] = found_nums;
        } else {
            out[outer_idx] = null;
        }
    }

    return out;
}

pub fn part2(input: []const u8) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var schem = try Schematic.init(allocator, input);
    defer schem.deinit();

    try schem.initParts(allocator);

    const gears_ind = try gearsInds(allocator, &schem);
    defer allocator.free(gears_ind);

    const gears_ind_mat = try allocator.alloc(struct { usize, usize }, gears_ind.len);
    defer allocator.free(gears_ind_mat);
    for (gears_ind_mat, gears_ind) |*mat, flat| {
        mat.* = schem.toMatIdx(flat);
    }

    const neighbors = try allocator.alloc(Neighbors, gears_ind_mat.len);
    defer allocator.free(neighbors);
    for (neighbors, gears_ind_mat) |*neigh, indice| {
        neigh.* = schem.neighborInd(indice.@"0", indice.@"1");
    }

    const found_gear_parts = try findGearPartNums(allocator, &schem, neighbors);
    defer allocator.free(found_gear_parts);

    var sum: u64 = 0;
    for (found_gear_parts) |parts_maybe| {
        if (parts_maybe) |part| {
            sum += part[0] * part[1];
        }
    }

    return sum;
}

test "part 2 function for example" {
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

    errdefer debug.print("\n{s}\n\n", .{input});

    const expected: u64 = 467835;
    const actual: u64 = try part2(input);

    try t.expectEqual(expected, actual);
}
