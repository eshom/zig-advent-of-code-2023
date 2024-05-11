const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const assert = std.debug.assert;
const dprint = std.debug.print;
const panic = std.debug.panic;

const Allocator = mem.Allocator;

const Tile = enum(u8) {
    up_down = '|',
    left_right = '-',
    up_right = 'L',
    up_left = 'J',
    down_left = '7',
    down_right = 'F',
    ground = '.',
    start = 'S',

    fn next(self: Tile, idx: Index) NextTile {
        switch (self) {
            .up_down => return .{
                .prev = .{ .row = idx.row - 1, .col = idx.col },
                .next = .{ .row = idx.row + 1, .col = idx.col },
            },
            .left_right => return .{
                .prev = .{ .row = idx.row, .col = idx.col - 1 },
                .next = .{ .row = idx.row, .col = idx.col + 1 },
            },
            .up_right => return .{
                .prev = .{ .row = idx.row - 1, .col = idx.col },
                .next = .{ .row = idx.row, .col = idx.col + 1 },
            },
            .up_left => return .{
                .prev = .{ .row = idx.row - 1, .col = idx.col },
                .next = .{ .row = idx.row, .col = idx.col - 1 },
            },
            .down_left => return .{
                .prev = .{ .row = idx.row + 1, .col = idx.col },
                .next = .{ .row = idx.row, .col = idx.col - 1 },
            },
            .down_right => return .{
                .prev = .{ .row = idx.row + 1, .col = idx.col },
                .next = .{ .row = idx.row, .col = idx.col + 1 },
            },
            .ground => return .{
                .prev = idx,
                .next = idx,
            },
            .start => return .{
                .prev = idx,
                .next = idx,
            },
        }
    }
};

const Index = struct {
    row: usize,
    col: usize,
};

// next and prev correspond to tile name
// i.e. up_down = (prev_next)
const NextTile = struct {
    next: Index = .{ .row = 0, .col = 0 },
    prev: Index = .{ .row = 0, .col = 0 },
};

const valid_tiles = "|-LJ7F.S";

fn Grid(rows: comptime_int, cols: comptime_int) type {
    return struct {
        const Self = @This();
        const ReferenceGrid = Self;

        tiles: [rows][cols]Tile = [_][cols]Tile{[_]Tile{.ground} ** cols} ** rows,

        fn parse(allocator: Allocator, input: []const u8) !*Self {
            var out = try allocator.create(Self);
            errdefer allocator.destroy(out);

            const input_sripped = try allocator.alloc(u8, input.len - rows + 1);
            defer allocator.free(input_sripped);

            var idx: usize = 0;
            for (input) |chr| {
                if (chr == '\n') continue;
                input_sripped[idx] = chr;
                idx += 1;
            }

            for (&out.tiles, 0..) |*row, rdx| {
                for (row, 0..) |*col, cdx| {
                    const tile = input_sripped[rdx * cols + cdx];
                    _ = mem.indexOfScalar(u8, valid_tiles, tile) orelse return error.InvalidTile;
                    col.* = @enumFromInt(tile);
                }
            }

            return out;
        }

        fn indexOfStart(self: *const Self) ?Index {
            for (self.tiles, 0..) |row, rdx| {
                for (row, 0..) |tile, cdx| {
                    if (tile == .start) return .{ .row = rdx, .col = cdx };
                }
            } else {
                return null;
            }
        }

        const TileIter = struct {
            grid: *const Self,
            tile: Tile = .ground,
            index: Index = .{ .row = 0, .col = 0 },
            index_prev: Index = .{ .row = 0, .col = 0 },

            fn init(grid: *const ReferenceGrid) TileIter {
                const start = grid.indexOfStart() orelse panic("cannot find start point, can't recover\n", .{});

                return .{
                    .grid = grid,
                    .tile = .start,
                    .index = start,
                    .index_prev = start,
                };
            }

            fn next(self: *TileIter) Tile {
                switch (self.tile) {
                    .start => {
                        self.index = self.grid.startPipe(self.index) orelse panic("cannot find start pipe, can't recover\n", .{});
                        self.tile = self.grid.tiles[self.index.row][self.index.col];
                        return self.tile;
                    },
                    .ground => unreachable,
                    else => {
                        const next_tile = self.tile.next(self.index);

                        const tmp = self.index;
                        defer self.index_prev = tmp;

                        // dprint("prev ind: {any}, cur ind: {any}, ", .{ self.index_prev, self.index });

                        if (next_tile.next.row == self.index_prev.row and next_tile.next.col == self.index_prev.col) {
                            self.index = next_tile.prev;
                        } else {
                            self.index = next_tile.next;
                        }
                        self.tile = self.grid.tiles[self.index.row][self.index.col];

                        // dprint("next ind: {any}\n", .{self.index});

                        return self.tile;
                    },
                }
            }
        };

        // Returns optional index of the first connected pipe found
        fn startPipe(self: *const Self, start_index: Index) ?Index {
            var check_indice: [4]Index = undefined;

            if (start_index.row == 0) {
                check_indice[0] = .{ .row = start_index.row, .col = start_index.col }; // up
            } else {
                check_indice[0] = .{ .row = start_index.row - 1, .col = start_index.col }; // up
            }

            if (start_index.row == rows - 1) {
                check_indice[1] = .{ .row = start_index.row, .col = start_index.col }; // down
            } else {
                check_indice[1] = .{ .row = start_index.row + 1, .col = start_index.col }; // down
            }

            if (start_index.col == 0) {
                check_indice[2] = .{ .row = start_index.row, .col = start_index.col }; // left
            } else {
                check_indice[2] = .{ .row = start_index.row, .col = start_index.col - 1 }; // left
            }

            if (start_index.col == 0) {
                check_indice[3] = .{ .row = start_index.row, .col = start_index.col }; // right
            } else {
                check_indice[3] = .{ .row = start_index.row, .col = start_index.col + 1 }; // right
            }

            const up = self.tiles[check_indice[0].row][check_indice[0].col];
            const down = self.tiles[check_indice[1].row][check_indice[1].col];
            const left = self.tiles[check_indice[2].row][check_indice[2].col];
            const right = self.tiles[check_indice[3].row][check_indice[3].col];

            if (mem.indexOfScalar(Tile, &[_]Tile{ .up_down, .down_left, .down_right }, up) != null) {
                return check_indice[0];
            }
            if (mem.indexOfScalar(Tile, &[_]Tile{ .up_down, .up_left, .up_right }, down) != null) {
                return check_indice[1];
            }

            if (mem.indexOfScalar(Tile, &[_]Tile{ .left_right, .up_right, .down_right }, left) != null) {
                return check_indice[2];
            }

            if (mem.indexOfScalar(Tile, &[_]Tile{ .left_right, .up_left, .down_left }, right) != null) {
                return check_indice[3];
            }

            return null;
        }
    };
}

test "parse tiles" {
    const input =
        \\.....
        \\.F-7.
        \\.S.|.
        \\.L-J.
        \\.....
    ;

    const expected = [5][5]Tile{
        [5]Tile{ .ground, .ground, .ground, .ground, .ground },
        [5]Tile{ .ground, .down_right, .left_right, .down_left, .ground },
        [5]Tile{ .ground, .start, .ground, .up_down, .ground },
        [5]Tile{ .ground, .up_right, .left_right, .up_left, .ground },
        [5]Tile{ .ground, .ground, .ground, .ground, .ground },
    };

    const actual = try Grid(5, 5).parse(testing.allocator, input);
    defer testing.allocator.destroy(actual);

    try testing.expectEqualDeep(expected, actual.tiles);
}

test "go through simple pipe loop" {
    const input =
        \\.....
        \\.S-7.
        \\.|.|.
        \\.L-J.
        \\.....
    ;

    const Grid5x5 = Grid(5, 5);
    const grid = try Grid5x5.parse(testing.allocator, input);
    defer testing.allocator.destroy(grid);

    var tile_it = Grid5x5.TileIter.init(grid);

    try testing.expectEqual('|', @intFromEnum(tile_it.next()));
    try testing.expectEqual('L', @intFromEnum(tile_it.next()));
    try testing.expectEqual('-', @intFromEnum(tile_it.next()));
    try testing.expectEqual('J', @intFromEnum(tile_it.next()));
    try testing.expectEqual('|', @intFromEnum(tile_it.next()));
    try testing.expectEqual('7', @intFromEnum(tile_it.next()));
    try testing.expectEqual('-', @intFromEnum(tile_it.next()));
    try testing.expectEqual('S', @intFromEnum(tile_it.next()));

    try testing.expectEqual('|', @intFromEnum(tile_it.next()));
    try testing.expectEqual('L', @intFromEnum(tile_it.next()));
    try testing.expectEqual('-', @intFromEnum(tile_it.next()));
    try testing.expectEqual('J', @intFromEnum(tile_it.next()));
    try testing.expectEqual('|', @intFromEnum(tile_it.next()));
    try testing.expectEqual('7', @intFromEnum(tile_it.next()));
    try testing.expectEqual('-', @intFromEnum(tile_it.next()));
    try testing.expectEqual('S', @intFromEnum(tile_it.next()));
}

test "go through simple pipe loop with distractions" {
    const input =
        \\-L|F7
        \\7S-7|
        \\L|7||
        \\-L-J|
        \\L|-JF
    ;

    const Grid5x5 = Grid(5, 5);
    const grid = try Grid5x5.parse(testing.allocator, input);
    defer testing.allocator.destroy(grid);

    var tile_it = Grid5x5.TileIter.init(grid);

    try testing.expectEqual('|', @intFromEnum(tile_it.next()));
    try testing.expectEqual('L', @intFromEnum(tile_it.next()));
    try testing.expectEqual('-', @intFromEnum(tile_it.next()));
    try testing.expectEqual('J', @intFromEnum(tile_it.next()));
    try testing.expectEqual('|', @intFromEnum(tile_it.next()));
    try testing.expectEqual('7', @intFromEnum(tile_it.next()));
    try testing.expectEqual('-', @intFromEnum(tile_it.next()));
    try testing.expectEqual('S', @intFromEnum(tile_it.next()));

    try testing.expectEqual('|', @intFromEnum(tile_it.next()));
    try testing.expectEqual('L', @intFromEnum(tile_it.next()));
    try testing.expectEqual('-', @intFromEnum(tile_it.next()));
    try testing.expectEqual('J', @intFromEnum(tile_it.next()));
    try testing.expectEqual('|', @intFromEnum(tile_it.next()));
    try testing.expectEqual('7', @intFromEnum(tile_it.next()));
    try testing.expectEqual('-', @intFromEnum(tile_it.next()));
    try testing.expectEqual('S', @intFromEnum(tile_it.next()));
}

pub fn part1(input: []const u8, grid_rows: comptime_int, grid_cols: comptime_int) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const GridT = Grid(grid_rows, grid_cols);
    const grid = try GridT.parse(allocator, input);
    defer allocator.destroy(grid);

    var tile_it = GridT.TileIter.init(grid);

    var count: usize = 1;
    while (tile_it.next() != .start) : (count += 1) {}

    assert(count % 2 == 0);
    return @as(u64, @divExact(count, 2));
}

test "example 1 part 1" {
    const input =
        \\.....
        \\.S-7.
        \\.|.|.
        \\.L-J.
        \\.....
    ;

    const answer = try part1(input, 5, 5);

    try testing.expectEqual(4, answer);
}

test "go through complex pipe loop" {
    const input =
        \\..F7.
        \\.FJ|.
        \\SJ.L7
        \\|F--J
        \\LJ...
    ;

    const Grid5x5 = Grid(5, 5);
    const grid = try Grid5x5.parse(testing.allocator, input);
    defer testing.allocator.destroy(grid);

    var tile_it = Grid5x5.TileIter.init(grid);

    try testing.expectEqual('|', @intFromEnum(tile_it.next()));
    try testing.expectEqual('L', @intFromEnum(tile_it.next()));
    try testing.expectEqual('J', @intFromEnum(tile_it.next()));
    try testing.expectEqual('F', @intFromEnum(tile_it.next()));
    try testing.expectEqual('-', @intFromEnum(tile_it.next()));
    try testing.expectEqual('-', @intFromEnum(tile_it.next()));
    try testing.expectEqual('J', @intFromEnum(tile_it.next()));
    try testing.expectEqual('7', @intFromEnum(tile_it.next()));
    try testing.expectEqual('L', @intFromEnum(tile_it.next()));
    try testing.expectEqual('|', @intFromEnum(tile_it.next()));
    try testing.expectEqual('7', @intFromEnum(tile_it.next()));
    try testing.expectEqual('F', @intFromEnum(tile_it.next()));
    try testing.expectEqual('J', @intFromEnum(tile_it.next()));
    try testing.expectEqual('F', @intFromEnum(tile_it.next()));
    try testing.expectEqual('J', @intFromEnum(tile_it.next()));
    try testing.expectEqual('S', @intFromEnum(tile_it.next()));
}

test "example 2 part 1" {
    const input =
        \\..F7.
        \\.FJ|.
        \\SJ.L7
        \\|F--J
        \\LJ...
    ;

    const answer = try part1(input, 5, 5);

    try testing.expectEqual(8, answer);
}
