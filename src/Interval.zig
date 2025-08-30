const std = @import("std");
const vec = @import("vec.zig");

min: f64,
max: f64,
const Interval = @This();

const empty: Interval = .{
    .min = vec.infinity,
    .max = -vec.infinity,
};

const universe: Interval = .{
    .min = -vec.infinity,
    .max = vec.infinity,
};

pub fn init(min: f64, max: f64) Interval {
    return .{ .min = min, .max = max };
}

pub fn contains(self: Interval, x: f64) bool {
    return self.min <= x and x <= self.max;
}

pub fn surrounds(self: Interval, x: f64) bool {
    return self.min < x and x < self.max;
}
