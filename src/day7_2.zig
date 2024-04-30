const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const fmt = std.fmt;
const assert = std.debug.assert;

const Card = union(enum) {
    invalid: u8,
    jack: u8,
    two: u8,
    three: u8,
    four: u8,
    five: u8,
    six: u8,
    seven: u8,
    eight: u8,
    nine: u8,
    ten: u8,
    queen: u8,
    king: u8,
    ace: u8,

    fn eql(a: Card, b: Card) bool {
        return @intFromEnum(a) < @intFromEnum(b);
    }

    fn lessThan(a: Card, b: Card) bool {
        return @intFromEnum(a) < @intFromEnum(b);
    }

    fn lessThanSort(_: void, a: Card, b: Card) bool {
        return lessThan(a, b);
    }

    fn toCard(chr: u8) Card {
        return switch (chr) {
            '2' => @unionInit(Card, "two", chr),
            '3' => @unionInit(Card, "three", chr),
            '4' => @unionInit(Card, "four", chr),
            '5' => @unionInit(Card, "five", chr),
            '6' => @unionInit(Card, "six", chr),
            '7' => @unionInit(Card, "seven", chr),
            '8' => @unionInit(Card, "eight", chr),
            '9' => @unionInit(Card, "nine", chr),
            'T' => @unionInit(Card, "ten", chr),
            'J' => @unionInit(Card, "jack", chr),
            'Q' => @unionInit(Card, "queen", chr),
            'K' => @unionInit(Card, "king", chr),
            'A' => @unionInit(Card, "ace", chr),
            else => @unionInit(Card, "invalid", chr),
        };
    }
};

test "card less than" {
    std.debug.print("\n", .{});

    const cards_a = [_]Card{
        Card.toCard('1'),
        Card.toCard('2'),
        Card.toCard('3'),
        Card.toCard('4'),
        Card.toCard('5'),
        Card.toCard('6'),
        Card.toCard('7'),
        Card.toCard('8'),
        Card.toCard('9'),
        Card.toCard('T'),
        Card.toCard('J'),
        Card.toCard('Q'),
        Card.toCard('K'),
        Card.toCard('A'),
    };

    const cards_b = [_]Card{
        Card.toCard('1'),
        Card.toCard('3'),
        Card.toCard('2'),
        Card.toCard('5'),
        Card.toCard('4'),
        Card.toCard('7'),
        Card.toCard('6'),
        Card.toCard('9'),
        Card.toCard('8'),
        Card.toCard('J'),
        Card.toCard('J'),
        Card.toCard('J'),
        Card.toCard('J'),
        Card.toCard('A'),
    };

    const expected = [_]bool{ false, true, false, true, false, true, false, true, false, false, false, false, false, false };
    var actual: [14]bool = undefined;

    for (&actual, cards_a, cards_b) |*item, a, b| {
        item.* = Card.lessThan(a, b);
    }

    try testing.expectEqualSlices(bool, &expected, &actual);
}

const HandType = enum {
    high_card,
    one_pair,
    two_pair,
    three_of_a_kind,
    full_house,
    four_of_a_kind,
    five_of_a_kind,

    fn lessThan(a: HandType, b: HandType) bool {
        return @intFromEnum(a) < @intFromEnum(b);
    }

    fn eql(a: HandType, b: HandType) bool {
        return @intFromEnum(a) == @intFromEnum(b);
    }

    fn whichType(hand: []const Card) HandType {
        assert(hand.len == 5);

        const joker_idx: usize = @intFromEnum(std.meta.Tag(Card).jack);
        var card_counter = [_]usize{0} ** 14;
        for (hand) |card| {
            card_counter[@as(usize, @intFromEnum(card))] += 1;
        }

        const joker_count = card_counter[joker_idx];
        card_counter[joker_idx] = 0;
        std.sort.block(usize, &card_counter, {}, std.sort.desc(usize));
        card_counter[0] += joker_count;

        switch (card_counter[0]) {
            5 => return .five_of_a_kind,
            4 => return .four_of_a_kind,
            3 => if (card_counter[1] == 2) return .full_house else return .three_of_a_kind,
            2 => if (card_counter[1] == 2) return .two_pair else return .one_pair,
            1 => return .high_card,
            else => unreachable,
        }
    }
};

const Hand = struct {
    cards: [5]Card,
    handtype: HandType,

    fn weaker(a: *const Hand, b: *const Hand) bool {
        if (HandType.lessThan(a.handtype, b.handtype)) {
            return true;
        } else if (HandType.eql(a.handtype, b.handtype)) {
            var copy_a: [5]Card = undefined;
            var copy_b: [5]Card = undefined;
            @memcpy(&copy_a, &a.cards);
            @memcpy(&copy_b, &b.cards);

            for (copy_a, copy_b) |ca, cb| {
                if (Card.lessThan(ca, cb)) return true;
                if (Card.lessThan(cb, ca)) return false;
            }
            unreachable; // when the hands are exactly the same
        } else {
            return false;
        }
    }

    fn init(hand_str: []const u8) Hand {
        assert(hand_str.len == 5);
        var hand: [5]Card = undefined;
        for (hand_str, &hand) |chr, *hnd| {
            hnd.* = Card.toCard(chr);
        }

        return Hand{ .cards = hand, .handtype = HandType.whichType(&hand) };
    }

    fn weakerSortFn(_: void, a: Hand, b: Hand) bool {
        return weaker(&a, &b);
    }
};

test "compare hand types" {
    std.debug.print("\n", .{});

    const hand1 = Hand{
        .cards = .{
            Card.toCard('2'),
            Card.toCard('2'),
            Card.toCard('2'),
            Card.toCard('J'),
            Card.toCard('J'),
        },
        .handtype = .full_house,
    };
    const hand2 = Hand{
        .cards = .{
            Card.toCard('A'),
            Card.toCard('A'),
            Card.toCard('A'),
            Card.toCard('J'),
            Card.toCard('2'),
        },
        .handtype = .three_of_a_kind,
    };
    const hand3 = Hand{
        .cards = .{
            Card.toCard('A'),
            Card.toCard('3'),
            Card.toCard('4'),
            Card.toCard('T'),
            Card.toCard('7'),
        },
        .handtype = .high_card,
    };
    const hand4 = Hand{
        .cards = .{
            Card.toCard('A'),
            Card.toCard('3'),
            Card.toCard('4'),
            Card.toCard('T'),
            Card.toCard('9'),
        },
        .handtype = .high_card,
    };

    try testing.expectEqual(false, Hand.weaker(&hand1, &hand2));
    try testing.expectEqual(true, Hand.weaker(&hand2, &hand1));
    try testing.expectEqual(true, Hand.weaker(&hand3, &hand4));
    try testing.expectEqual(false, Hand.weaker(&hand4, &hand3));
}

test "hand types" {
    std.debug.print("\n", .{});
    const hand1 = Hand.init("AAAAA");
    try testing.expectEqual(.five_of_a_kind, hand1.handtype);

    const hand2 = Hand.init("2AAAA");
    try testing.expectEqual(.four_of_a_kind, hand2.handtype);

    const hand3 = Hand.init("22AAA");
    try testing.expectEqual(.full_house, hand3.handtype);

    const hand4 = Hand.init("J2AAA");
    try testing.expectEqual(.four_of_a_kind, hand4.handtype);

    const hand5 = Hand.init("JJ2AA");
    try testing.expectEqual(.four_of_a_kind, hand5.handtype);

    const hand6 = Hand.init("JK77Q");
    try testing.expectEqual(.three_of_a_kind, hand6.handtype);

    const hand7 = Hand.init("3A78Q");
    try testing.expectEqual(.high_card, hand7.handtype);
}

const Game = struct {
    hands: []Hand,
    bids: []u64,
    allocator: mem.Allocator,

    fn init(allocator: mem.Allocator, input: []const u8) !Game {
        const line_count = mem.count(u8, input, "\n");
        const hands = try allocator.alloc(Hand, line_count);
        errdefer allocator.free(hands);
        const bids = try allocator.alloc(u64, line_count);
        errdefer allocator.free(bids);

        var idx: usize = 0;
        var line_iter = mem.tokenizeScalar(u8, input, '\n');
        while (line_iter.next()) |hand_bid| : (idx += 1) {
            var hand_bid_iter = mem.tokenizeScalar(u8, hand_bid, ' ');
            const hand_str = hand_bid_iter.next().?;
            const bid_str = hand_bid_iter.next().?;
            hands[idx] = Hand.init(hand_str);
            bids[idx] = try fmt.parseInt(u64, bid_str, 10);
        }

        return Game{
            .hands = hands,
            .bids = bids,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Game) void {
        self.allocator.free(self.bids);
        self.allocator.free(self.hands);
    }
};

test "parse game" {
    std.debug.print("\n", .{});
    const input =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
        \\
    ;

    var game = try Game.init(testing.allocator, input);
    defer game.deinit();

    var exhands = [5]Hand{
        Hand.init("32T3K"),
        Hand.init("T55J5"),
        Hand.init("KK677"),
        Hand.init("KTJJT"),
        Hand.init("QQQJA"),
    };
    var exbids = [5]u64{ 765, 684, 28, 220, 483 };
    const expected = Game{ .hands = &exhands, .bids = &exbids, .allocator = testing.allocator };

    try testing.expectEqualDeep(expected, game);
}

pub fn part2(input: []const u8) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() != .ok) @panic("Memory Leak!");
    }
    const allocator = gpa.allocator();

    var game = try Game.init(allocator, input);
    defer game.deinit();

    bubbleSortAlong(game.hands, game.bids);
    var winnings: u64 = 0;
    for (game.bids, 1..game.bids.len + 1) |bid, rank| {
        winnings += bid * rank;
    }

    return winnings;
}

// Sorts hand by the handtype, and also sorts bids along
fn bubbleSortAlong(hand: []Hand, bid: []u64) void {
    var last: usize = hand.len - 1;

    while (last > 0) : (last -= 1) {
        for (0..last) |idx| {
            if (Hand.weaker(&hand[idx + 1], &hand[idx])) {
                mem.swap(Hand, &hand[idx], &hand[idx + 1]);
                mem.swap(u64, &bid[idx], &bid[idx + 1]); // this is the "along" part
            }
        }
    }
}

test "sort along" {
    std.debug.print("\n", .{});

    var hands_to_sort = [_]Hand{
        Hand.init("AAAAA"),
        Hand.init("AAAA2"),
        Hand.init("AAA22"),
        Hand.init("AAJ22"),
        Hand.init("AKJ22"),
    };

    const expected_hands = [_]Hand{
        Hand.init("AKJ22"),
        Hand.init("AAJ22"),
        Hand.init("AAA22"),
        Hand.init("AAAA2"),
        Hand.init("AAAAA"),
    };

    var bids_to_sort = [_]u64{ 1, 2, 3, 4, 5 };
    const expected_bids = [_]u64{ 5, 4, 3, 2, 1 };

    bubbleSortAlong(&hands_to_sort, &bids_to_sort);

    try testing.expectEqualSlices(Hand, &expected_hands, &hands_to_sort);
    try testing.expectEqualSlices(u64, &expected_bids, &bids_to_sort);
}

test "part 1 example" {
    std.debug.print("\n", .{});
    const input =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
        \\
    ;

    const expected: u64 = 5905;
    const actual: u64 = try part2(input);

    try testing.expectEqual(expected, actual);
}
