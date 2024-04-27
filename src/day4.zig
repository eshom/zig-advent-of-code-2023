const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const testing = std.testing;
const debug = std.debug;
const sort = std.sort;
const math = std.math;
const log = std.log;
const heap = std.heap;

const assert = std.debug.assert;

const winning_numbers_capacity = 10;
const numbers_have_capacity = 25;
pub const max_cards = 213;
const card_winner_sentinel = 777;
const card_have_sentinel = 999;

fn vprint(v: anytype) void {
    debug.print("{any}\n", .{v});
}

fn dprint(comptime s: []const u8) void {
    debug.print(s, .{});
}

const Card = struct {
    card_id: usize,
    winning_numbers: [winning_numbers_capacity]u64 = [_]u64{card_winner_sentinel} ** winning_numbers_capacity,
    numbers_have: [numbers_have_capacity]u64 = [_]u64{card_have_sentinel} ** numbers_have_capacity,
    winner: [winning_numbers_capacity]bool = [_]bool{false} ** winning_numbers_capacity,
    // out of bound index = not a winner
    winner_ind: [winning_numbers_capacity]usize = [_]usize{numbers_have_capacity} ** winning_numbers_capacity,

    fn parseLine(input: []const u8) Card {
        assert(mem.count(u8, input, ":") == 1);
        assert(mem.count(u8, input, "|") == 1);
        assert(mem.eql(u8, "Card ", input[0..5]));

        const semicolon_ind = mem.indexOfScalar(u8, input, ':').?;
        assert(semicolon_ind > 5);

        const card_id_str_dirty = input[5..semicolon_ind];
        const card_id_str = mem.trim(u8, card_id_str_dirty, " ");
        assert(mem.indexOfNone(u8, card_id_str, "0123456789") == null);
        const card_id = fmt.parseInt(u64, card_id_str, 10) catch unreachable;

        const number_section_dirty = input[semicolon_ind + 1 ..];
        const number_section = mem.trim(u8, number_section_dirty, " \r\n");
        assert(number_section[0] != ' ');

        var section_iter = mem.splitScalar(u8, number_section, '|');
        const winning_numbers_str = section_iter.next().?;
        const numbers_have_str = section_iter.next().?;

        var winning_iter = mem.splitScalar(u8, winning_numbers_str, ' ');
        var numbers_have_iter = mem.splitScalar(u8, numbers_have_str, ' ');

        var card_out = Card{ .card_id = card_id };

        var idx: usize = 0;
        while (winning_iter.next()) |str| {
            if (mem.indexOfAny(u8, str, "01234567890") == null) continue;
            card_out.winning_numbers[idx] = fmt.parseInt(u64, mem.trim(u8, str, " \r\n"), 10) catch unreachable;
            idx += 1;
        }

        idx = 0;
        while (numbers_have_iter.next()) |str| {
            if (mem.indexOfAny(u8, str, "01234567890") == null) continue;
            card_out.numbers_have[idx] = fmt.parseInt(u64, mem.trim(u8, str, " \r\n"), 10) catch unreachable;
            idx += 1;
        }

        // sorting numbers now for binary search later
        sort.block(u64, &card_out.winning_numbers, {}, sort.asc(u64));
        sort.block(u64, &card_out.numbers_have, {}, sort.asc(u64));

        return card_out;
    }

    fn order_u64(context: void, lhs: u64, rhs: u64) math.Order {
        _ = context;
        return math.order(lhs, rhs);
    }

    fn updateWinners(self: *Card) void {
        for (self.winning_numbers, 0..) |wnum, idx| {
            const winner_ind_maybe = sort.binarySearch(u64, wnum, &self.numbers_have, {}, order_u64);
            if (winner_ind_maybe) |wind| {
                self.winner[idx] = true;
                self.winner_ind[idx] = wind;
            } else {
                self.winner[idx] = false;
            }
        }
    }

    fn winSum(self: *const Card) u64 {
        var sum: u64 = 0;
        for (self.winner) |win| {
            sum += @intFromBool(win);
        }
        return sum;
    }

    fn points(self: *const Card) u64 {
        if (self.winSum() == 0) return 0;

        return math.powi(u64, 2, self.winSum() - 1) catch |err| {
            log.err("{!} while calculating points: ", .{err});
            return 0;
        };
    }

    fn parseAllCardsWithWinners(allocator: mem.Allocator, input: []const u8, max: usize) ![]Card {
        var line_iter = mem.splitScalar(u8, input, '\n');
        const cards = try allocator.alloc(Card, max);
        while (line_iter.next()) |line| {
            if (line.len < 2) continue;
            var card = Card.parseLine(line);
            card.updateWinners();
            assert(card.card_id > 0 and card.card_id <= max);
            cards[card.card_id - 1] = card;
        }

        return cards;
    }

    fn nextCards(self: *const Card, deck: []const Card) ?[]const Card {
        const wins = @as(usize, self.winSum());
        if (wins == 0) return null;
        const out = deck[self.card_id .. self.card_id + wins]; // input guranteed not to overflow
        return out;
    }
};

test "parse real card" {
    dprint("\n");
    const line = "Card  33:  3 91 62 38 44 42 81 66 17 12 | 62 80 12 39 77 52 19 71 17 26 35 91 34 25  5 11 98  1 24  9 94 49 66 93 58";

    const expected = Card{
        .card_id = 33,
        .winning_numbers = .{ 3, 12, 17, 38, 42, 44, 62, 66, 81, 91 },
        .numbers_have = .{ 1, 5, 9, 11, 12, 17, 19, 24, 25, 26, 34, 35, 39, 49, 52, 58, 62, 66, 71, 77, 80, 91, 93, 94, 98 },
    };

    const actual = Card.parseLine(line);

    try testing.expectEqualDeep(expected, actual);
}

test "find winners" {
    dprint("\n");
    const line = "Card  33:  3 91 62 38 44 42 81 66 17 12 | 62 80 12 39 77 52 19 71 17 26 35 91 34 25  5 11 98  1 24  9 94 49 66 93 58";

    const expected_winners = [10]bool{ false, true, true, false, false, false, true, true, false, true };
    const expected_ind = [10]usize{ 25, 4, 5, 25, 25, 25, 16, 17, 25, 21 };

    var card = Card.parseLine(line);
    card.updateWinners();

    try testing.expectEqual(5, card.winSum());
    try testing.expectEqual(16, card.points());
    try testing.expectEqualSlices(bool, &expected_winners, &card.winner);
    try testing.expectEqualSlices(usize, &expected_ind, &card.winner_ind);
}

test "part 1 example" {
    dprint("\n");
    const input =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;

    const expected_total: u64 = 13;

    var line_iter = mem.splitScalar(u8, input, '\n');

    var sum: u64 = 0;
    while (line_iter.next()) |line| {
        var card = Card.parseLine(line);
        card.updateWinners();
        sum += card.points();
    }

    try testing.expectEqual(expected_total, sum);
}

pub fn part1(input: []const u8) u64 {
    var line_iter = mem.splitScalar(u8, input, '\n');
    var sum: u64 = 0;
    while (line_iter.next()) |line| {
        if (line.len < 2) continue;
        var card = Card.parseLine(line);
        card.updateWinners();
        sum += card.points();
    }
    return sum;
}

test "parse all cards" {
    dprint("\n");
    const input =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;

    const cards = try Card.parseAllCardsWithWinners(testing.allocator, input, 6);
    defer testing.allocator.free(cards);

    const expected_card_ids = [_]usize{ 1, 2, 3, 4, 5, 6 };
    const actual_card_ids = [_]usize{
        cards[0].card_id,
        cards[1].card_id,
        cards[2].card_id,
        cards[3].card_id,
        cards[4].card_id,
        cards[5].card_id,
    };

    try testing.expectEqualSlices(usize, &expected_card_ids, &actual_card_ids);
}

test "get next cards" {
    dprint("\n");
    const input =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;

    const cards = try Card.parseAllCardsWithWinners(testing.allocator, input, 6);
    defer testing.allocator.free(cards);

    const expected_cards = cards[1..5];
    const actual_cards = cards[0].nextCards(cards).?;

    try testing.expectEqualDeep(expected_cards, actual_cards);
}

pub fn part2(input: []const u8, deck_size: usize) !u64 {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const deck = try Card.parseAllCardsWithWinners(allocator, input, deck_size);
    defer allocator.free(deck);

    // const tmp_max_iter = 1000;
    // var iter: usize = 0;

    var total_cards: u64 = 0;
    var stack = try std.ArrayList(Card).initCapacity(allocator, max_cards * 2);
    defer stack.deinit();
    assert(stack.items.len == 0);
    try stack.appendSlice(deck);
    assert(stack.items.len == deck.len);

    while (stack.items.len > 0) {
        // defer {
        //     if (iter >= tmp_max_iter) @panic("Too many iterations");
        //     iter += 1;
        // }

        const card = stack.pop();
        total_cards += 1;

        const more_cards = card.nextCards(deck) orelse continue;
        try stack.appendSlice(more_cards);
    }

    return total_cards;
}

test "part 2 example" {
    dprint("\n");
    const input =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;

    const expected: u64 = 30;
    const actual = try part2(input, 6);

    try testing.expectEqual(expected, actual);
}
