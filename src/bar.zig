const std = @import("std");

pub const BarGraph = struct {
    pub const Division = struct {
        pub const Name = struct {
            name: []const u8,
            amount: i64,
        };
        names: std.ArrayList(Name),
        width: i64,
    };
    allocator: std.mem.Allocator,
    divisions: std.ArrayList(Division),

    pub fn init(allocator: std.mem.Allocator) BarGraph {
        return .{ .allocator = allocator, .divisions = std.ArrayList(Division).init(allocator) };
    }

    pub fn deinit(self: *BarGraph) void {
        for (self.divisions.items) |div| {
            div.names.deinit();
        }
        self.divisions.deinit();
    }

    pub fn addDivision(self: *BarGraph, width: i64) !void {
        try self.divisions.append(.{ .names = std.ArrayList(Division.Name).init(self.allocator), .width = width });
    }

    pub fn addName(self: *BarGraph, name: []const u8, amount: i64) !void {
        var back = &self.divisions.items[self.divisions.items.len - 1];
        try back.names.append(.{ .name = name, .amount = amount });
    }
};

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
        return .{ .key = key, .amount = amount, .allocator = allocator, .children = std.HashMap(Node, void, NodeContext, 80).init(allocator) };
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
                break :blk account.?[name.len+1..];
            }
        };

        const entry = try self.children.getOrPutValue(Node.init(name, 0, self.allocator), {});
        var child = entry.key_ptr;
        try child.add(rest, amount);

        // std.debug.print("Node: {s}  {d}c\n", .{name, self.amount});
        // std.debug.print("children: {d}\n", .{self.children.count()});
    }

    pub fn show(self: *Node, depth: u32) !void {
        if (depth > 1) {
            return;
        }
        var amounts_total: i64 = 0;
        var items = self.children.iterator();
        while (items.next()) |item| {
            try item.key_ptr.show(depth+1);
            amounts_total += item.key_ptr.amount;
        }
        if (depth == 0) {
            return;
        }

        const full_budget: i64 = 120;
        var current_spend: i64 = 0;

        var graph = BarGraph.init(self.allocator);
        defer graph.deinit();

        const Portion = struct {
            portion: i64,
            node: *const Node,
        };
        var portions = std.ArrayList(Portion).init(self.allocator);
        defer portions.deinit();
        var nodes = self.children.keyIterator();
        while (nodes.next()) |node| {
            const portion = @divFloor(full_budget * node.amount, amounts_total);
            try portions.append(.{ .portion = portion, .node = node});
            current_spend += portion;
        }

        std.sort.insertion(Portion, portions.items, {},
            struct {
                fn cmp(_: void, a: Portion, b: Portion) bool {
                    if (a.portion == b.portion) {
                        return std.mem.lessThan(u8, a.node.key, b.node.key);
                    } else {
                        return a.portion > b.portion;
                    }
                }
            }.cmp
        );

        for (portions.items) |*item| {
            if (current_spend < full_budget) {
                item.portion += 1;
                current_spend += 1;
            }
        }

        var first_zero = true;
        for (portions.items) |item| {
            if (item.portion != 0) {
                try graph.addDivision(item.portion);
                try graph.addName(item.node.key, item.node.amount);
            } else {
                if (first_zero) {
                    try graph.addDivision(0);
                    first_zero = false;
                }
                try graph.addName(item.node.key, item.node.amount);
            }
        }

        for (graph.divisions.items) |div| {
            if (div.names.items.len == 1) {
                std.debug.print("{s}, ", .{div.names.items[0].name});
            }
        }
    }
};

