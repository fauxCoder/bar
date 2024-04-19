const std = @import("std");
const fmt = std.fmt;

pub const Colour = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const Colours = struct {
    fg: Colour,
    bg: Colour,
};

pub fn colourPrintLine(writer: anytype, colours: Colours, str: []const u8) !void {
    try ansiFg(writer, colours.fg);
    try ansiBg(writer, colours.bg);
    try writer.writeAll(str);
    try ansiReset(writer);
    try writer.writeAll("\n");
}

fn ansiFg(writer: anytype, colour: Colour) !void {
    try writer.print("\x1b[38;2;{};{};{}m", .{ colour.r, colour.g, colour.b });
}

fn ansiBg(writer: anytype, colour: Colour) !void {
    try writer.print("\x1b[48;2;{};{};{}m", .{ colour.r, colour.g, colour.b });
}

fn ansiReset(writer: anytype) !void {
    try writer.writeAll("\x1b[0m");
}
