const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const testing = std.testing;

fn seeds(allocator: mem.Allocator, input: []const u8) ![]u64 {
    var seeds_line_iter = mem.splitScalar(u8, input, '\n');
    const seeds_line = seeds_line_iter.first();
    var seeds_str_iter = mem.splitScalar(u8, seeds_line, ':');
    _ = seeds_str_iter.next();
    const seeds_str = seeds_str_iter.next().?;
    const seeds_str_trimmed = mem.trim(u8, seeds_str, " ");
    const seed_count = mem.count(u8, seeds_str_trimmed, " ") + 1;
    const out_seeds = try allocator.alloc(u64, seed_count);

    var to_parse_iter = mem.splitScalar(u8, seeds_str_trimmed, ' ');

    var idx: usize = 0;
    while (to_parse_iter.next()) |num_str| : (idx += 1) {
        out_seeds[idx] = try fmt.parseInt(u8, num_str, 10);
    }

    return out_seeds;
}

test "parse start seeds" {
    std.debug.print("\n", .{});

    const input =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;

    const expected = [_]u64{ 79, 14, 55, 13 };
    const actual = try seeds(testing.allocator, input);
    defer testing.allocator.free(actual);

    try testing.expectEqualSlices(u64, &expected, actual);
}

fn mapSection(map: *std.AutoHashMap(usize, usize), section: []const u8) !void {
    var line_iter = mem.splitScalar(u8, section, '\n');
    while (line_iter.next()) |line| {
        if (line.len <= 1) continue;

        var num_iter = mem.splitScalar(u8, mem.trim(u8, line, " "), ' ');
        const dest = try fmt.parseInt(usize, num_iter.next().?, 10);
        const src = try fmt.parseInt(usize, num_iter.next().?, 10);
        const len = try fmt.parseInt(usize, num_iter.next().?, 10);

        for (0..len) |offset| {
            try map.putNoClobber(src + offset, dest + offset);
        }
    }
}

fn seedToSoilMap(allocator: mem.Allocator, input: []const u8) !std.AutoHashMap(usize, usize) {
    const section_start = mem.indexOf(u8, input, "seed-to-soil map:\n").?;
    const section_end = mem.indexOfPos(u8, input, section_start, "soil-to-fertilizer map:\n").?;

    const section_dirty = input[section_start..section_end];
    const section = mem.trimLeft(u8, section_dirty, "seed-to-soil map:\n");

    var out_map = std.AutoHashMap(usize, usize).init(allocator);
    try mapSection(&out_map, section);

    return out_map;
}

fn soilToFertilizerMap(allocator: mem.Allocator, input: []const u8) !std.AutoHashMap(usize, usize) {
    const section_start = mem.indexOf(u8, input, "soil-to-fertilizer map:\n").?;
    const section_end = mem.indexOfPos(u8, input, section_start, "fertilizer-to-water map:\n").?;

    const section_dirty = input[section_start..section_end];
    const section = mem.trimLeft(u8, section_dirty, "soil-to-fertilizer map:\n");

    var out_map = std.AutoHashMap(usize, usize).init(allocator);
    try mapSection(&out_map, section);

    return out_map;
}

fn fertilizerToWaterMap(allocator: mem.Allocator, input: []const u8) !std.AutoHashMap(usize, usize) {
    const section_start = mem.indexOf(u8, input, "fertilizer-to-water map:\n").?;
    const section_end = mem.indexOfPos(u8, input, section_start, "water-to-light map:\n").?;

    const section_dirty = input[section_start..section_end];
    const section = mem.trimLeft(u8, section_dirty, "fertilizer-to-water map:\n");

    var out_map = std.AutoHashMap(usize, usize).init(allocator);
    try mapSection(&out_map, section);

    return out_map;
}

fn waterToLightMap(allocator: mem.Allocator, input: []const u8) !std.AutoHashMap(usize, usize) {
    const section_start = mem.indexOf(u8, input, "water-to-light map:\n").?;
    const section_end = mem.indexOfPos(u8, input, section_start, "light-to-temperature map:\n").?;

    const section_dirty = input[section_start..section_end];
    const section = mem.trimLeft(u8, section_dirty, "water-to-light map:\n");

    var out_map = std.AutoHashMap(usize, usize).init(allocator);
    try mapSection(&out_map, section);

    return out_map;
}

fn lightToTemperatureMap(allocator: mem.Allocator, input: []const u8) !std.AutoHashMap(usize, usize) {
    const section_start = mem.indexOf(u8, input, "light-to-temperature map:\n").?;
    const section_end = mem.indexOfPos(u8, input, section_start, "temperature-to-humidity map:\n").?;

    const section_dirty = input[section_start..section_end];
    const section = mem.trimLeft(u8, section_dirty, "light-to-temperature map:\n");

    var out_map = std.AutoHashMap(usize, usize).init(allocator);
    try mapSection(&out_map, section);

    return out_map;
}

fn temperatureToHumidityMap(allocator: mem.Allocator, input: []const u8) !std.AutoHashMap(usize, usize) {
    const section_start = mem.indexOf(u8, input, "temperature-to-humidity map:\n").?;
    const section_end = mem.indexOfPos(u8, input, section_start, "humidity-to-location map:\n").?;

    const section_dirty = input[section_start..section_end];
    const section = mem.trimLeft(u8, section_dirty, "temperature-to-humidity map:\n");

    var out_map = std.AutoHashMap(usize, usize).init(allocator);
    try mapSection(&out_map, section);

    return out_map;
}

fn humidityToLocationMap(allocator: mem.Allocator, input: []const u8) !std.AutoHashMap(usize, usize) {
    const section_start = mem.indexOf(u8, input, "humidity-to-location map:\n").?;

    const section_dirty = input[section_start..];
    const section = mem.trimLeft(u8, section_dirty, "humidity-to-location map:\n");

    var out_map = std.AutoHashMap(usize, usize).init(allocator);
    try mapSection(&out_map, section);

    return out_map;
}

test "prase seed to soil map" {
    std.debug.print("\n", .{});

    const input =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;

    var expected = std.AutoHashMap(usize, usize).init(testing.allocator);
    defer expected.deinit();
    try expected.putNoClobber(50, 52);
    try expected.putNoClobber(51, 53);
    try expected.putNoClobber(98, 50);
    try expected.putNoClobber(99, 51);

    var actual = try seedToSoilMap(testing.allocator, input);
    defer actual.deinit();

    try testing.expectEqual(expected.get(50).?, actual.get(50).?);
    try testing.expectEqual(expected.get(51).?, actual.get(51).?);
    try testing.expectEqual(expected.get(98).?, actual.get(98).?);
    try testing.expectEqual(expected.get(99).?, actual.get(99).?);
}

fn destination(map: std.AutoHashMap(usize, usize), key: usize) usize {
    return map.get(key) orelse key;
}

test "destination from seed to soil" {
    std.debug.print("\n", .{});

    const input =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;

    var map = try seedToSoilMap(testing.allocator, input);
    defer map.deinit();

    try testing.expectEqual(0, destination(map, 0));
    try testing.expectEqual(1, destination(map, 1));
    try testing.expectEqual(48, destination(map, 48));
    try testing.expectEqual(49, destination(map, 49));
    try testing.expectEqual(52, destination(map, 50));
    try testing.expectEqual(53, destination(map, 51));
    try testing.expectEqual(82, destination(map, 80));
    try testing.expectEqual(98, destination(map, 96));
    try testing.expectEqual(99, destination(map, 97));
    try testing.expectEqual(50, destination(map, 98));
    try testing.expectEqual(51, destination(map, 99));
}

const ProductionMap = struct {
    allocator: mem.Allocator,
    map: [7]std.AutoHashMap(usize, usize),

    fn init(allocator: mem.Allocator, input: []const u8) !ProductionMap {
        var seed = try seedToSoilMap(allocator, input);
        errdefer seed.deinit();

        var soil = try soilToFertilizerMap(allocator, input);
        errdefer soil.deinit();

        var fert = try fertilizerToWaterMap(allocator, input);
        errdefer fert.deinit();

        var wate = try waterToLightMap(allocator, input);
        errdefer wate.deinit();

        var ligh = try lightToTemperatureMap(allocator, input);
        errdefer ligh.deinit();

        var temp = try temperatureToHumidityMap(allocator, input);
        errdefer temp.deinit();

        var humi = try humidityToLocationMap(allocator, input);
        errdefer humi.deinit();

        return .{
            .allocator = allocator,
            .map = .{ seed, soil, fert, wate, ligh, temp, humi },
        };
    }

    fn deinit(self: *ProductionMap) void {
        for (self.map) |map| {
            const map_p = @constCast(&map); // map becomes const in for loop capture I think
            map_p.deinit();
        }
    }

    fn traverseToLocation(self: *const ProductionMap, start: usize) usize {
        var location = start;
        for (self.map) |map| {
            location = destination(map, location);
        }
        return location;
    }
};

test "seeds to locations" {
    std.debug.print("\n", .{});

    const input =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;

    var pmap = try ProductionMap.init(testing.allocator, input);
    defer pmap.deinit();

    const start_seeds = try seeds(testing.allocator, input);
    defer testing.allocator.free(start_seeds);

    try testing.expectEqual(82, pmap.traverseToLocation(start_seeds[0]));
    try testing.expectEqual(43, pmap.traverseToLocation(start_seeds[1]));
    try testing.expectEqual(86, pmap.traverseToLocation(start_seeds[2]));
    try testing.expectEqual(35, pmap.traverseToLocation(start_seeds[3]));
}

pub fn part1(input: []const u8) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var pmap = try ProductionMap.init(allocator, input);
    defer pmap.deinit();

    const start_seeds = try seeds(allocator, input);
    defer allocator.free(start_seeds);

    var min: usize = std.math.maxInt(usize);
    for (start_seeds) |seed| {
        min = @min(pmap.traverseToLocation(seed), min);
    }

    return @as(u64, min);
}

test "part 1 example" {
    std.debug.print("\n", .{});

    const input =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;

    try testing.expectEqual(35, try part1(input));
}
