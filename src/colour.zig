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

pub fn print(writer: anytype, colours: Colours, str: []const u8) !void {
    try ansiBg(writer, colours.bg);
    try ansiFg(writer, colours.fg);
    try writer.writeAll(str);
    try ansiReset(writer);
}

pub fn ansiBg(writer: anytype, colour: Colour) !void {
    try writer.print("\x1b[48;2;{};{};{}m", .{ colour.r, colour.g, colour.b });
}

pub fn ansiFg(writer: anytype, colour: Colour) !void {
    try writer.print("\x1b[38;2;{};{};{}m", .{ colour.r, colour.g, colour.b });
}

pub fn ansiBgFg(writer: anytype, colour_bg: Colour, colour_fg: Colour) !void {
    try writer.print("\x1b[48;2;{};{};{}m", .{ colour_bg.r, colour_bg.g, colour_bg.b });
    try writer.print("\x1b[38;2;{};{};{}m", .{ colour_fg.r, colour_fg.g, colour_fg.b });
}

pub fn ansiReset(writer: anytype) !void {
    try writer.writeAll("\x1b[0m");
}
