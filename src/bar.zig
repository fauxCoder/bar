const std = @import("std");

pub const BarGraph = struct {
    pub const Division = struct {
        pub const Name = struct {
            name: []const u8,
            amount: u64,
        };
        names: std.ArrayList(Name),
    };
    divisions: std.ArrayList(Division),
};

pub const Node = struct {
    amount: i64,
    allocator: std.mem.Allocator,
    children: std.StringHashMap(Node),

    pub fn init(amount: i64, allocator: std.mem.Allocator) Node {
        return .{ .amount = amount, .allocator = allocator, .children = std.StringHashMap(Node).init(allocator) };
    }

    pub fn deinit(self: *Node) void {
        var vals = self.children.valueIterator();
        while (vals.next()) |val| {
            val.deinit();
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

        const entry = try self.children.getOrPutValue(name, Node.init(0, self.allocator));
        var child = entry.value_ptr;
        try child.add(rest, amount);

        // std.debug.print("Node: {s}  {d}c\n", .{name, self.amount});
        // std.debug.print("children: {d}\n", .{self.children.count()});
    }
};

