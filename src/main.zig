const std = @import("std");
const fmt = std.fmt;

const clr = @import("colour.zig");

const date = @import("date.zig");

const bar = @import("bar.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cout = std.io.getStdOut().writer();

    const user_input = try parseUserInput(allocator);

    if (user_input.average) |num| {
        try cout.print("average: {d}\n", .{num});
    }
    try cout.print("cols: {d}\n", .{user_input.cols});

    var root = bar.Node.init("", 0, allocator);
    defer root.deinit();

    var first_date: ?date.Date = null;
    var last_date: ?date.Date = null;

    var expenses_cents: i64 = 0;
    var income_cents: i64 = 0;

    const cin = std.io.getStdIn().reader();
    const storage = try cin.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(storage);

    var lines = std.mem.split(u8, storage, "\n");

    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        var csvs = std.mem.split(u8, line, ",");

        if (csvs.next()) |token| {
            const date_val = try date.parseDate(token);

            if (first_date == null or date_val.lessThan(first_date.?)) {
                first_date = date_val;
            }

            if (last_date == null or last_date.?.lessThan(date_val)) {
                last_date = date_val;
            }

        } else {
            return error.ExpectedDate;
        }

        var expense = true;
        const account = blk: {
            if (csvs.next()) |token| {
                const expenses_prefix = "expenses:";
                const income_prefix = "income:";
                if (std.mem.startsWith(u8, token, expenses_prefix)) {
                    expense = true;
                } else if (std.mem.startsWith(u8, token, income_prefix)) {
                    expense = false;
                }
                break :blk token;
            } else {
                return error.ExpectedAccount;
            }
        };

        if (csvs.next()) |token| {
            var dci = std.mem.split(u8, token, ".");
            var amount: i64 = 0;
            if (dci.next()) |wholes| {
                amount = 100 * try std.fmt.parseInt(i64, wholes, 10);
            }

            if (dci.next()) |cents| {
                const cents_int = try std.fmt.parseInt(i32, cents, 10);
                amount += if (amount < 0) -cents_int else cents_int;
            }

            if (expense) {
                expenses_cents += amount;
            } else {
                income_cents += amount;
            }

            try root.add(account, amount);

        } else {
            return error.ExpectedAmount;
        }
    }

    try root.show(0);

    try cout.print("days: {d}\n", .{ last_date.?.distance(first_date.?) + 1 });

    try cout.print("expenses: {d}\n", .{expenses_cents});
    try cout.print("income: {d}\n", .{income_cents});

    //const colours: clr.Colours = .{
    //    .fg = clr.Colour{
    //        .r = 255, .b = 255, .g = 255
    //    },
    //    .bg = clr.Colour{
    //        .r = 64, .b = 8, .g = 64
    //    }
    //};

    //try clr.print(cout, colours, "  tax  ");
    //try cout.print("\n", .{});
    //try clr.print(cout, colours, " $100  ");
    //try cout.print("\n", .{});

    // var graph: bar.BarGraph = .{ .divisions = std.ArrayList(bar.BarGraph.Division).init(allocator) };
    // defer graph.divisions.deinit();
    // try graph.divisions.append(.{ .names = std.ArrayList(bar.BarGraph.Division.Name).init(allocator) });
    // defer graph.divisions.items[0].names.deinit();
    // try graph.divisions.items[0].names.append(.{ .name = "tax", .amount = 5000 });
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
