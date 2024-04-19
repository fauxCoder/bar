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

//const Node = struct {
//    amount: u64,
//    children: std.StringHashMap(Node),
//
//    fn init(amount: u64, allocator: std.mem.Allocator) Node {
//        return .{ .amount = amount, .children = std.StringHashMap(Node).init(allocator) };
//    }
//
//    fn deinit(self: *Node) void {
//        _ = self;
//    }
//};

