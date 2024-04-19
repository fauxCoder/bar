const std = @import("std");
const fmt = std.fmt;

const colour = @import("colour.zig");
const colourPrintLine = colour.colourPrintLine;

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

    var first_date: ?date.Date = null;
    var last_date: ?date.Date = null;

    var expenses_cents: i64 = 0;
    var income_cents: i64 = 0;

    const cin = std.io.getStdIn().reader();
    while (cin.readUntilDelimiterAlloc(allocator, '\n', 2048)) |buf| {
        defer allocator.free(buf);

        var csvs = std.mem.split(u8, buf, ",");

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
        if (csvs.next()) |token| {
            const expenses_prefix = "expenses:";
            const income_prefix = "income:";
            if (std.mem.startsWith(u8, token, expenses_prefix)) {
                expense = true;
            } else if (std.mem.startsWith(u8, token, income_prefix)) {
                expense = false;
            }
        } else {
            return error.ExpectedAccount;
        }

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

        } else {
            return error.ExpectedAmount;
        }

    } else |err| if (err != error.EndOfStream) {
        return err;
    }

    try cout.print("days: {d}\n", .{ last_date.?.distance(first_date.?) + 1 });

    try cout.print("expenses: {d}\n", .{expenses_cents});
    try cout.print("income: {d}\n", .{income_cents});

    const colours: colour.Colours = .{
        .fg = colour.Colour{
            .r = 255, .b = 255, .g = 255
        },
        .bg = colour.Colour{
            .r = 64, .b = 8, .g = 64
        }
    };

    try colourPrintLine(cout, colours, "      ");
    try colourPrintLine(cout, colours, " tax  ");
    try colourPrintLine(cout, colours, "      ");

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
