const std = @import("std");
const vec = @import("vec.zig");

min: f64,
max: f64,
const Self = @This();

const empty: Self = .{
    .min = vec.infinity,
    .max = -vec.infinity,
};

const universe: Self = .{
    .min = -vec.infinity,
    .max = vec.infinity,
};

pub fn contains(self: Self, x: f64) bool {
    return self.min <= x and x <= self.max;
}

pub fn surrounds(self: Self, x: f64) bool {
    return self.min < x and x < self.max;
}

pub fn clamp(self: Self, x: f64) f64 {
    return std.math.clamp(x, self.min, self.max);
}
