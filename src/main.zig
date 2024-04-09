const std = @import("std");
const fmt = std.fmt;

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

    const cin = std.io.getStdIn().reader();
    while (cin.readUntilDelimiterAlloc(allocator, '\n', 2048)) |buf| {
        defer allocator.free(buf);
        try cout.print("{s}\n", .{buf});
    } else |err| if (err != error.EndOfStream) {
        return err;
    }

    try cout.print("mine: {s}{s}{s}{s}\n", .{ansiFg(0, 255, 255), ansiBg(255, 0, 0), "----", ansiReset()});
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

fn ansiFg(comptime r: u8, comptime g: u8, comptime b: u8) [:0]const u8 {
    return fmt.comptimePrint("\x1b[38;2;{};{};{}m", .{r, g, b});
}

fn ansiBg(comptime r: u8, comptime g: u8, comptime b: u8) [:0]const u8 {
    return fmt.comptimePrint("\x1b[48;2;{};{};{}m", .{r, g, b});
}

fn ansiReset() [:0]const u8 {
    return "\x1b[0m";
}
