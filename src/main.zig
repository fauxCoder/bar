const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cout = std.io.getStdOut().writer();

    const userInput = try parseUserInput(allocator);

    if (userInput.average) |num| {
        try cout.print("average: {d}\n", .{num});
    }
    try cout.print("cols: {d}\n", .{userInput.cols});
}

const UserInput = struct {
    average: ?u32 = null,
    cols: u32 = 80,
};

fn parseUserInput(allocator: std.mem.Allocator) !UserInput {
    var ret = UserInput{};

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // skip first arg
    _ = args.next();

    while (args.next()) |opt| {
        if (isGenericOpt("average", opt)) {
            const arg = args.next().?;
            ret.average = try std.fmt.parseUnsigned(u32, arg, 10);
        } else if (isGenericOpt("cols", opt)) {
            const arg = args.next().?;
            ret.cols = try std.fmt.parseUnsigned(u32, arg, 10);
        } else {
            return error.UnhandledArgument;
        }
    }

    return ret;
}

fn isGenericOpt(comptime name: [:0]const u8, opt: [:0]const u8) bool {
    return (opt.len >= 2 and std.mem.eql(u8, opt[0..2], "--") and std.mem.eql(u8, opt[2..], name)) or
        (opt.len >= 1 and std.mem.eql(u8, opt[0..1], "-") and std.mem.eql(u8, opt[1..], name[0..1]));
}
