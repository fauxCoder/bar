const std = @import("std");

const clr = @import("colour.zig");

const line_hori = "\u{2500}";
const line_vert = "\u{2502}";
const corner = "\u{2518}";
const joint = "\u{2524}";

const left_margin = 1;

fn generateColour(i: usize) clr.Colour {
    const boost = 70;
    const baselines = [_]u8{ 150, 60, 70 };
    var rand = std.rand.DefaultPrng.init(64 *% i + 1);
    return clr.Colour{
        .r = baselines[@mod(i + 0, 3)] + rand.random().uintAtMost(u8, boost),
        .g = baselines[@mod(i + 1, 3)] + rand.random().uintAtMost(u8, boost),
        .b = baselines[@mod(i + 2, 3)] + rand.random().uintAtMost(u8, boost),
    };
}

fn paddedWrite(writer: anytype, width: u64, str: []const u8) !void {
    const extra = width - str.len;
    const pre = extra / 2;
    const post = pre + @rem(extra, 2);
    _ = try writer.writeByteNTimes(' ', pre);
    _ = try writer.write(str);
    _ = try writer.writeByteNTimes(' ', post);
}

pub const NodeContext = struct {
    pub fn hash(ctx: NodeContext, key: Node) u64 {
        _ = ctx;
        return std.hash.Wyhash.hash(0, key.key);
    }

    pub fn eql(ctx: NodeContext, a: Node, b: Node) bool {
        _ = ctx;
        return std.mem.eql(u8, a.key, b.key);
    }
};

pub const Node = struct {
    key: []const u8,
    amount: i64,
    allocator: std.mem.Allocator,
    children: std.HashMap(Node, void, NodeContext, 80),

    pub fn init(key: []const u8, amount: i64, allocator: std.mem.Allocator) Node {
        return .{
            .key = key,
            .amount = amount,
            .allocator = allocator,
            .children = std.HashMap(Node, void, NodeContext, 80).init(allocator),
        };
    }

    pub fn deinit(self: *Node) void {
        var nodes = self.children.keyIterator();
        while (nodes.next()) |node| {
            node.deinit();
        }
        self.children.deinit();
    }

    pub fn add(self: *Node, account: ?[]const u8, amount: i64) !void {
        self.amount += amount;

        if (account == null) {
            return;
        }

        var name_it = std.mem.split(u8, account.?, ":");
        const name = name_it.next().?;
        const rest = blk: {
            if (name_it.next() == null) {
                break :blk null;
            } else {
                break :blk account.?[name.len + 1 ..];
            }
        };

        const entry = try self.children.getOrPutValue(Node.init(name, 0, self.allocator), {});
        var child = entry.key_ptr;
        try child.add(rest, amount);
    }

    pub fn printGraph(self: *Node, width: u64, colour_index: *usize, writer: anytype) !void {
        if (self.children.count() == 0) {
            return;
        }

        _ = try writer.write(self.key);
        _ = try writer.write("\n");

        // 1st pass: calculate total
        var amounts_total: u64 = 0;
        var nodes = self.children.keyIterator();
        while (nodes.next()) |node| {
            amounts_total += @abs(node.amount);
        }

        // 2nd pass: locate names with width < 1 to be combined
        const Name = struct {
            name: []const u8,
            amount: u64,
        };
        const Division = struct {
            names: std.ArrayList(Name),
            amount: u64,
            portion: u64,
        };
        var divisions = std.ArrayList(Division).init(self.allocator);
        defer {
            for (divisions.items) |item| {
                item.names.deinit();
            }
            divisions.deinit();
        }
        var zero_division: Division = .{
            .names = std.ArrayList(Name).init(self.allocator),
            .amount = 0,
            .portion = 0,
        };
        nodes = self.children.keyIterator();
        while (nodes.next()) |node| {
            const portion = @divFloor(width * @abs(node.amount), amounts_total);
            if (portion == 0) {
                try zero_division.names.append(.{
                    .name = node.key,
                    .amount = @abs(node.amount),
                });
                zero_division.amount += @abs(node.amount);
            } else {
                const div = try divisions.addOne();
                div.* = .{
                    .names = std.ArrayList(Name).init(self.allocator),
                    .amount = @abs(node.amount),
                    .portion = 0,
                };
                try div.names.append(.{
                    .name = node.key,
                    .amount = @abs(node.amount),
                });
            }
        }

        // sort by amount...
        std.sort.insertion(Division, divisions.items, {}, struct {
            fn cmp(_: void, a: Division, b: Division) bool {
                return a.amount > b.amount;
            }
        }.cmp);

        var current_spend: u64 = 0;

        // ...but the combined division always sits at the end
        if (zero_division.names.items.len > 0) {
            std.sort.insertion(Name, zero_division.names.items, {}, struct {
                fn cmp(_: void, a: Name, b: Name) bool {
                    return a.amount > b.amount;
                }
            }.cmp);
            const portion = @divFloor(width * @abs(zero_division.amount), amounts_total);
            if (portion == 0) {
                zero_division.portion += 1;
                current_spend += 1;
            }
            try divisions.append(zero_division);
        }

        // 3rd pass: calculate final portions
        for (divisions.items) |*div| {
            const portion = @divFloor(width * @abs(div.amount), amounts_total);
            div.portion += portion;
            current_spend += portion;
        }

        // 4th pass: increase portions to fill width
        for (divisions.items) |*div| {
            if (current_spend < width) {
                div.portion += 1;
                current_spend += 1;
            }
        }

        const Tail = struct {
            div: *const Division,
            offset: u64,
        };
        var tails = std.ArrayList(Tail).init(self.allocator);
        defer tails.deinit();

        const starting_cap = width * 2;
        var offset: u64 = left_margin;

        var amount_buffer = std.ArrayList(u8).init(self.allocator);
        defer amount_buffer.deinit();

        var buffer0 = try std.ArrayList(u8).initCapacity(self.allocator, starting_cap);
        defer buffer0.deinit();
        var buffer1 = try std.ArrayList(u8).initCapacity(self.allocator, starting_cap);
        defer buffer1.deinit();

        const writer0 = buffer0.writer();
        const writer1 = buffer1.writer();

        _ = try writer0.writeByteNTimes(' ', left_margin);
        _ = try writer1.writeByteNTimes(' ', left_margin);

        for (divisions.items) |*div| {
            defer {
                colour_index.* += 1;
                offset += div.portion;
            }

            try clr.ansiBgFg(writer0, generateColour(colour_index.*), clr.Colour{ .r = 12, .g = 12, .b = 12 });
            try clr.ansiBgFg(writer1, generateColour(colour_index.*), clr.Colour{ .r = 12, .g = 12, .b = 12 });

            if (div.names.items.len == 1) {
                amount_buffer.clearRetainingCapacity();
                try amount_buffer.writer().print("${d:.02}", .{@as(f32, @floatFromInt(div.names.items[0].amount)) / 100.0});
                const name_len = div.names.items[0].name.len;
                if (div.portion > name_len + 2 and div.portion > amount_buffer.items.len + 2) {
                    try paddedWrite(writer0, div.portion, div.names.items[0].name);
                    try paddedWrite(writer1, div.portion, amount_buffer.items);
                    continue;
                }
            }

            _ = try writer0.writeByteNTimes(' ', div.portion);
            _ = try writer1.writeByteNTimes(' ', div.portion);

            try tails.append(.{
                .div = div,
                .offset = offset,
            });

            try clr.ansiReset(writer0);
            try clr.ansiReset(writer1);
        }

        _ = try writer0.writeByte('\n');
        _ = try writer1.writeByte('\n');

        _ = try writer.write(buffer0.items);
        _ = try writer.write(buffer1.items);

        for (0..tails.items.len) |i| {
            var written: usize = 0;
            for (tails.items, 0..) |tail, j| {
                const midpoint = tail.offset + (tail.div.portion / 2);
                if (j == i) {
                    for (tail.div.names.items, 0..) |name, k| {
                        if (k > 0) {
                            _ = try writer.write("\n");
                            written = 0;
                        }
                        amount_buffer.clearRetainingCapacity();
                        try amount_buffer.writer().print("{s} ${d:.02} ", .{
                            name.name,
                            @as(f32, @floatFromInt(name.amount)) / 100.0,
                        });
                        const padding = midpoint -| (amount_buffer.items.len + 1 + written);
                        try writer.writeByteNTimes(' ', padding);
                        written += padding;
                        written += try writer.write(amount_buffer.items);
                        _ = try writer.write(line_hori);
                        written += 1;
                        if (k == (tail.div.names.items.len - 1)) {
                            _ = try writer.write(corner);
                        } else {
                            _ = try writer.write(joint);
                        }
                        written += 1;
                    }
                } else if (j > i) {
                    const padding = midpoint -| written;
                    try writer.writeByteNTimes(' ', padding);
                    written += padding;
                    _ = try writer.write(line_vert);
                    written += 1;
                }
            }
            try writer.writeByte('\n');
        }

        try writer.writeByte('\n');

        // propogate to child nodes
        nodes = self.children.keyIterator();
        while (nodes.next()) |node| {
            try node.printGraph(width, colour_index, writer);
        }
    }
};
