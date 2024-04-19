const std = @import("std");

pub const Date = struct {
    year: u16,
    month: u8,
    day: u8,

    pub fn lessThan(self: Date, rhs: Date) bool {
        if (self.year == rhs.year) {
            if (self.month == rhs.month) {
                return self.day < rhs.day;
            } else {
                return self.month < rhs.month;
            }
        } else {
            return self.year < rhs.year;
        }
    }

    pub fn distance(self: Date, rhs: Date) i64 {
        return countDays(self) - countDays(rhs);
    }
};

pub fn parseDate(str: []const u8) !Date {
    var datevs = std.mem.split(u8, str, "/");
    const ret: Date = .{
        .year = try std.fmt.parseInt(u16, datevs.next().?, 10),
        .month = try std.fmt.parseInt(u8, datevs.next().?, 10),
        .day = try std.fmt.parseInt(u8, datevs.next().?, 10),
    };
    if (ret.month < 1 or ret.month > 12) {
        return error.BadDate;
    } else if (ret.day < 1 or ret.day > daysInMonth(ret.year, ret.month)) {
        return error.BadDate;
    }
    return ret;
}

fn isLeapYear(year: u16) bool {
    return year % 4 == 0
        and (year % 100 != 0
            or year % 400 == 0);
}

fn daysInMonth(year: u16, month: u8) i64 {
    return switch (month) {
        1,3,5,7,8,10,12 => 31,
        2 => if (isLeapYear(year)) 29 else 28,
        4,6,9,11 => 30,
        else => 0,
    };
}

fn countDays(date: Date) i64 {
    var ret: i64 = 0;

    for (1..date.year) |year| {
        ret += if (isLeapYear(@intCast(year))) 366 else 365;
    }

    for (0..date.month) |month| {
        ret += daysInMonth(date.year, @intCast(month));
    }

    ret += date.day;

    return ret;
}
